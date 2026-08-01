import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/auth/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';

import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart'; 
import 'package:laundry_one/features/customer/screens/tabs/beranda_tab.dart';
import 'package:laundry_one/features/customer/screens/tabs/aktivitas_tab.dart';
import 'package:laundry_one/features/customer/screens/tabs/katalog_tab.dart';
import 'package:laundry_one/features/customer/screens/tabs/profil_tab.dart';
import 'package:laundry_one/features/customer/screens/register_customer_screen.dart'; 

class HomeCustomerScreen extends StatefulWidget {
  const HomeCustomerScreen({super.key});

  @override
  State<HomeCustomerScreen> createState() => _HomeCustomerScreenState();
}

class _HomeCustomerScreenState extends State<HomeCustomerScreen> {
  final _supabase = Supabase.instance.client;
  int _currentTab = 0;
  
  bool _isLoading = true;
  String? _errorMessage; 

  Map<String, dynamic>? _profile;
  
  // =========================================================
  // [GELOMBANG 2] MESIN MULTI-WALLET
  // =========================================================
  List<Map<String, dynamic>> _myWallets = [];
  Map<String, dynamic>? _activeWallet;
  
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];

  StreamSubscription? _profileSubscription;
  StreamSubscription? _customerSubscription;
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
    NotificationService.setupPushNotifications();
    _loadAllData();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _customerSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('Sesi login tidak ditemukan. Silakan login ulang.');

      await _fetchInitialData(user.id);
      _setupRealtimeHooks(user.id);
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _errorMessage = e.toString().replaceAll('Exception: ', ''); });
    }
  }

  Future<void> _fetchInitialData(String userId) async {
      final profileData = await _supabase.from('profiles').select().eq('id', userId).single();
      
      // [MULTI-WALLET]: Tarik SEMUA dompet cabang milik pelanggan ini
      final walletsData = await _supabase
          .from('customers')
          .select('*, branches(nama_cabang, alamat)')
          .eq('profile_id', userId);
          
      List<Map<String, dynamic>> wallets = List<Map<String, dynamic>>.from(walletsData);
      Map<String, dynamic>? activeWallet = _activeWallet;

      if (wallets.isNotEmpty) {
        if (activeWallet == null || !wallets.any((w) => w['id'] == activeWallet!['id'])) {
          activeWallet = wallets.first; // Default: Pilih dompet pertama
        } else {
          activeWallet = wallets.firstWhere((w) => w['id'] == activeWallet!['id']); // Update data dompet aktif jika ada refresh
        }
      } else {
        activeWallet = null;
      }

      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> history = [];

      if (activeWallet != null) {
        final customerId = activeWallet['id'];
        final ordersData = await _supabase
            .from('orders')
            .select('*, customers(profiles(nama_lengkap, nomor_hp)), profiles!orders_cashier_id_fkey(nama_lengkap), order_items(jumlah, harga_satuan, services(nama))')
            .eq('customer_id', customerId) // Isolasi: Tarik order khusus di dompet ini
            .order('created_at', ascending: false);

        for (var order in ordersData) {
          if (order['status'] == 'diproses') { active.add(order); } else { history.add(order); }
        }
      }

      if (mounted) {
        setState(() {
          _profile = profileData; 
          _myWallets = wallets;
          _activeWallet = activeWallet;
          _activeOrders = active; 
          _historyOrders = history; 
          _isLoading = false;
        });
      }
  }

  // [MULTI-WALLET]: Fungsi ganti cabang/dompet (Akan dihubungkan ke UI di Gelombang 3)
  void switchWallet(Map<String, dynamic> newWallet) {
     setState(() {
        _activeWallet = newWallet;
        _isLoading = true;
     });
     _fetchInitialData(_supabase.auth.currentUser!.id);
  }

  void _setupRealtimeHooks(String userId) {
    _profileSubscription = _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', userId).listen((data) {
      if (data.isNotEmpty && mounted) setState(() => _profile = data.first);
    });

    _customerSubscription = _supabase.from('customers').stream(primaryKey: ['id']).eq('profile_id', userId).listen((data) {
      _fetchInitialData(userId);
    });

    // Menghapus filter spesifik ID di stream agar fleksibel saat pindah dompet (Data tetap aman karena RLS database).
    _ordersSubscription = _supabase.from('orders').stream(primaryKey: ['id']).listen((data) {
       _fetchInitialData(userId);
    });
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    await AuthService().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil( 
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            config: LoginConfig(
              roleName: 'Pelanggan',
              roleDatabase: 'customer',
              labelIdentifier: 'Nomor HP',
              hint: '081234567890',
              keyboardType: TextInputType.phone,
              primaryColor: CustomerTheme.primary,
              secondaryColor: CustomerTheme.primaryDark,
              backgroundColor: Colors.white,
              icon: Icons.local_laundry_service_rounded,
              tagline: 'Lacak cucian & kumpulkan poinnya',
              homeScreen: HomeCustomerScreen(),
              showRegister: true,
              registerScreen: RegisterCustomerScreen(), 
            ),
          ),
        ),
        (route) => false, 
      );
    }
  }
  

  @override
  Widget build(BuildContext context) {
    final nama = _profile?['nama_lengkap'] ?? 'Pelanggan';
    final noHp = _profile?['nomor_hp'] ?? '-';
    
    // [MULTI-WALLET]: Saldo dan ID diambil dari Dompet Aktif
    final poin = _activeWallet?['poin_saldo'] ?? 0;
    final activeCustomerId = _activeWallet?['id'];

    return Scaffold(
      backgroundColor: CustomerTheme.ground,
      body: _isLoading 
        ? const Center(child: ModernSpinner(size: 48)) 
        : _errorMessage != null
            ? _buildErrorScreen()
            : IndexedStack(
                index: _currentTab,
                children: [
                  // [GELOMBANG 3]: Menyambungkan Multi-Wallet ke UI
                  BerandaTab(
                    nama: nama, 
                    poin: poin, 
                    activeOrders: _activeOrders, 
                    myWallets: _myWallets,              // <--- DATA BARU YANG DIMINTA FLUTTER
                    activeWallet: _activeWallet,        // <--- DATA BARU YANG DIMINTA FLUTTER
                    onSwitchWallet: switchWallet,       // <--- DATA BARU YANG DIMINTA FLUTTER
                    onOpenNewBranch: _showBukaCabangSheet, // <--- DATA BARU YANG DIMINTA FLUTTER
                    onRefresh: () => _fetchInitialData(_supabase.auth.currentUser!.id)
                  ),
                  AktivitasTab(
                    historyOrders: _historyOrders, 
                    customerId: activeCustomerId, 
                    onRefresh: () => _fetchInitialData(_supabase.auth.currentUser!.id)
                  ),
                  KatalogTab(
                    customerId: activeCustomerId, 
                    activeBranchId: _activeWallet?['branch_id'], // Isolasi Cabang
                    currentPoin: poin,
                    onRefresh: () => _fetchInitialData(_supabase.auth.currentUser!.id),
                  ),
                ],
              ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildErrorScreen() {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: FadeInAnimation( 
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: const Icon(Icons.wifi_off_rounded, size: 48, color: Colors.red)),
                const SizedBox(height: 24), const Text('Koneksi Terputus', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary)), const SizedBox(height: 8),
                Text(_errorMessage ?? 'Gagal terhubung ke server.', textAlign: TextAlign.center, style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 14)),
                const SizedBox(height: 32),
                SizedBox(width: double.infinity, height: 52, child: ElevatedButton.icon(onPressed: _loadAllData, icon: const Icon(Icons.refresh_rounded), label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), style: ElevatedButton.styleFrom(backgroundColor: CustomerTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, boxShadow: CustomerTheme.bottomNavShadow),
      child: BottomAppBar(
        color: Colors.transparent, elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Beranda'),
              _buildNavItem(1, Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Aktivitas'),
              _buildNavItem(2, Icons.local_offer_rounded, Icons.local_offer_outlined, 'Rewards'),
              _buildNavItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _currentTab = index); },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), decoration: BoxDecoration(color: isActive ? CustomerTheme.primaryLight : Colors.transparent, borderRadius: BorderRadius.circular(20)), child: Icon(isActive ? activeIcon : inactiveIcon, color: isActive ? CustomerTheme.primary : CustomerTheme.textHint, size: 24)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? CustomerTheme.primary : CustomerTheme.textHint)),
          ],
        ),
      ),
    );
  }

  // =========================================================
  // [GELOMBANG 3]: POPUP BUKA CABANG LAIN
  // =========================================================
  Future<void> _showBukaCabangSheet() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _NewBranchSheet(
        myWallets: _myWallets,
        onSuccess: (newWallet) async {
           Navigator.pop(ctx);
           setState(() => _isLoading = true);
           await _fetchInitialData(_supabase.auth.currentUser!.id);
           
           // Cari dompet yang baru saja dibuat agar otomatis terpilih
           final newlyAdded = _myWallets.firstWhere(
             (w) => w['branch_id'] == newWallet['branch_id'], 
             orElse: () => _myWallets.first
           );
           switchWallet(newlyAdded);
        }
      )
    );
  }
} // <--- PASTIKAN TANDA KURUNG INI ADA (Ini penutup _HomeCustomerScreenState Anda)

// =========================================================
// WIDGET KHUSUS: LEMBAR BUKA CABANG (Taro di paling bawah file)
// =========================================================
class _NewBranchSheet extends StatefulWidget {
  final List<Map<String, dynamic>> myWallets;
  final Function(Map<String, dynamic>) onSuccess;

  const _NewBranchSheet({required this.myWallets, required this.onSuccess});

  @override
  State<_NewBranchSheet> createState() => _NewBranchSheetState();
}

class _NewBranchSheetState extends State<_NewBranchSheet> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _availableBranches = [];

  @override
  void initState() {
    super.initState();
    _loadBranches();
  }

  Future<void> _loadBranches() async {
    try {
      final existingBranchIds = widget.myWallets.map((w) => w['branch_id']).toList();
      final data = await _supabase.from('branches').select().eq('is_active', true);
      
      // Filter: Hanya tampilkan cabang yang BELUM dimiliki oleh user
      final available = List<Map<String, dynamic>>.from(data)
          .where((b) => !existingBranchIds.contains(b['id'])).toList();
          
      setState(() { _availableBranches = available; _isLoading = false; });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buatDompet(Map<String, dynamic> branch) async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final newWallet = await _supabase.from('customers').insert({
        'profile_id': userId,
        'branch_id': branch['id'],
        'poin_saldo': 0,
      }).select().single();
      
      widget.onSuccess(newWallet);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat dompet: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: CustomerTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          const Text('Buka Dompet Cabang', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Pilih cabang lain untuk mulai mengumpulkan koin di sana.', style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          
          if (_isLoading)
            const Padding(padding: EdgeInsets.all(32), child: Center(child: ModernSpinner()))
          else if (_availableBranches.isEmpty)
             const Padding(
               padding: EdgeInsets.all(32),
               child: Center(child: Text('Anda sudah memiliki dompet di semua cabang kami!', textAlign: TextAlign.center, style: TextStyle(color: CustomerTheme.textHint))),
             )
          else
            ..._availableBranches.map((branch) => 
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: CustomerTheme.menuDecoration,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.add_business_rounded, color: Colors.green, size: 20),
                  ),
                  title: Text(branch['nama_cabang'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  subtitle: Text(branch['alamat'] ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                  trailing: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: CustomerTheme.primary, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: () => _buatDompet(branch),
                    child: const Text('Buka', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ),
              )
            ).toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}