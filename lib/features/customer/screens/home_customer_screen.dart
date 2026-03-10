import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';

import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/screens/tabs/beranda_tab.dart';
import 'package:laundry_one/features/customer/screens/tabs/aktivitas_tab.dart';
import 'package:laundry_one/features/customer/screens/tabs/katalog_tab.dart';
import 'package:laundry_one/features/customer/screens/tabs/profil_tab.dart';

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
  Map<String, dynamic>? _customerData;
  List<Map<String, dynamic>> _activeOrders = [];
  List<Map<String, dynamic>> _historyOrders = [];

  StreamSubscription? _profileSubscription;
  StreamSubscription? _customerSubscription;
  StreamSubscription? _ordersSubscription;

  @override
  void initState() {
    super.initState();
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
      final custData = await _supabase.from('customers').select().eq('profile_id', userId).maybeSingle();
      final customerId = custData?['id'];

      List<Map<String, dynamic>> active = [];
      List<Map<String, dynamic>> history = [];

      if (customerId != null) {
        // PERHATIKAN PENAMBAHAN 'profiles!orders_cashier_id_fkey(nama_lengkap)'
        final ordersData = await _supabase
            .from('orders')
            .select('*, customers(profiles(nama_lengkap, nomor_hp)), profiles!orders_cashier_id_fkey(nama_lengkap), order_items(jumlah, harga_satuan, services(nama))')
            .eq('customer_id', customerId)
            .order('created_at', ascending: false);

        for (var order in ordersData) {
          if (order['status'] == 'diproses') { active.add(order); } else { history.add(order); }
        }
      }

      if (mounted) {
        setState(() {
          _profile = profileData; _customerData = custData; _activeOrders = active; _historyOrders = history; _isLoading = false;
        });
      }
  }

  void _setupRealtimeHooks(String userId) {
    _profileSubscription = _supabase.from('profiles').stream(primaryKey: ['id']).eq('id', userId).listen((data) {
      if (data.isNotEmpty && mounted) setState(() => _profile = data.first);
    });

    _customerSubscription = _supabase.from('customers').stream(primaryKey: ['id']).eq('profile_id', userId).listen((data) {
      if (data.isNotEmpty && mounted) setState(() => _customerData = data.first);
    });

    final customerId = _customerData?['id'];
    if (customerId != null) {
      _ordersSubscription = _supabase.from('orders').stream(primaryKey: ['id']).eq('customer_id', customerId).listen((data) {
        _fetchInitialData(userId);
      });
    }
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();
    await AuthService().logout();
    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen(config: LoginConfig(roleName: 'Pelanggan', roleDatabase: 'customer', labelIdentifier: 'Nomor HP', hint: '081234567890', keyboardType: TextInputType.phone, primaryColor: CustomerTheme.primary, secondaryColor: CustomerTheme.primaryDark, backgroundColor: Colors.white, icon: Icons.local_laundry_service_rounded, tagline: 'Lacak cucian & kumpulkan poinnya', homeScreen: HomeCustomerScreen(), showRegister: true))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final nama = _profile?['nama_lengkap'] ?? 'Pelanggan';
    final noHp = _profile?['nomor_hp'] ?? '-';
    final poin = _customerData?['poin_saldo'] ?? 0;

    return Scaffold(
      backgroundColor: CustomerTheme.ground,
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: CustomerTheme.primary))
        : _errorMessage != null
            ? _buildErrorScreen()
            : IndexedStack(
                index: _currentTab,
                children: [
                  BerandaTab(nama: nama, poin: poin, activeOrders: _activeOrders, onRefresh: () => _fetchInitialData(_supabase.auth.currentUser!.id)),
                  AktivitasTab(
                    historyOrders: _historyOrders, 
                    customerId: _customerData?['id'], 
                    onRefresh: () => _fetchInitialData(_supabase.auth.currentUser!.id)
                  ),
                  const KatalogTab(),
                  ProfilTab(nama: nama, noHp: noHp, avatarUrl: _profile?['avatar_url'], onLogout: _handleLogout),
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
}