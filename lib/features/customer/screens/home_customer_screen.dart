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

  // [FIX] Penjaga agar pop-up email tidak muncul berulang kali
  bool _emailSudahDitangani = false;
  bool _popupEmailSedangTampil = false;

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
    // [FIX] Cukup panggil versi aman (try/catch) sekali saja.
    // Pemanggilan langsung sebelumnya membuat crash di Web.
    _inisialisasiNotifikasiAman();
    _loadAllData();
  }

  Future<void> _inisialisasiNotifikasiAman() async {
    try {
      await NotificationService.setupPushNotifications();
    } catch (e) {
      debugPrint('Notifikasi dilewati (Biasanya karena dites di Web): $e');
    }
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    _customerSubscription?.cancel();
    _ordersSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final user = _supabase.auth.currentUser;
      if (user == null)
        throw Exception('Sesi login tidak ditemukan. Silakan login ulang.');

      await _fetchInitialData(user.id);
      _setupRealtimeHooks(user.id);
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
    }
  }

  Future<void> _fetchInitialData(String userId) async {
    final profileData = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    // ==========================================================
    // 1. CEK EMAIL (Cukup simpan statusnya dulu, jangan panggil popup di sini)
    // ==========================================================
    final String? userEmail = profileData['email']?.toString().trim();
    final bool isEmailKosong = userEmail == null || userEmail.isEmpty;
    final bool isEmailPalsu = userEmail != null &&
        (userEmail.contains('@laundry.local') ||
            !userEmail.contains('@') ||
            !userEmail.contains('.'));

    // ==========================================================
    // 2. AMBIL DATA WALLET & TRANSAKSI
    // ==========================================================
    final walletsData = await _supabase
        .from('customers')
        .select('*, branches(nama_cabang, alamat)')
        .eq('profile_id', userId);

    List<Map<String, dynamic>> wallets = List<Map<String, dynamic>>.from(walletsData);
    Map<String, dynamic>? activeWallet = _activeWallet;

    if (wallets.isNotEmpty) {
      if (activeWallet == null ||
          !wallets.any((w) => w['id'] == activeWallet!['id'])) {
        activeWallet = wallets.first;
      } else {
        activeWallet = wallets.firstWhere(
          (w) => w['id'] == activeWallet!['id'],
        );
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
          .select(
            '*, customers(profiles(nama_lengkap, nomor_hp)), profiles!orders_cashier_id_fkey(nama_lengkap), order_items(jumlah, harga_satuan, services(nama))',
          )
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      for (var order in ordersData) {
        if (order['status'] == 'diproses') {
          active.add(order);
        } else {
          history.add(order);
        }
      }
    }

    // ==========================================================
    // 3. SET STATE & MATIKAN LOADING DI PALING BAWAH
    // ==========================================================
    if (mounted) {
      setState(() {
        _profile = profileData;
        _myWallets = wallets;
        _activeWallet = activeWallet;
        _activeOrders = active;
        _historyOrders = history;
        _isLoading = false; // <--- LAYAR BERANDA SELESAI DIGAMBAR DI SINI
      });

      // ==========================================================
      // 4. TAMPILKAN POP-UP SETELAH BERANDA STABIL
      // ==========================================================
      // [FIX] Jika email sudah valid, kunci selamanya agar pop-up tidak pernah muncul lagi
      if (!isEmailKosong && !isEmailPalsu) {
        _emailSudahDitangani = true;
      }

      if ((isEmailKosong || isEmailPalsu) &&
          !_emailSudahDitangani &&
          !_popupEmailSedangTampil) {
        // Beri jeda 0.6 detik agar animasi loading hilang dulu dan Beranda muncul utuh
        Future.delayed(const Duration(milliseconds: 600), () {
          // [FIX] Cek ulang setelah delay: bisa jadi user sudah menyimpan email
          // atau pop-up lain sudah terlanjur tampil selama jeda ini.
          if (!mounted || _emailSudahDitangani || _popupEmailSedangTampil) return;
          _tampilkanPopupLengkapiEmail(userId);
        });
      }
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
    // [FIX PENTING] Batalkan langganan lama dulu.
    // Tanpa ini, setiap _loadAllData() menambah stream baru yang menumpuk,
    // sehingga _fetchInitialData() terpanggil berkali-kali dan pop-up muncul terus.
    _profileSubscription?.cancel();
    _customerSubscription?.cancel();
    _ordersSubscription?.cancel();

    _profileSubscription = _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .listen((data) {
          if (data.isNotEmpty && mounted) {
            // [FIX] Ikut perbarui status email dari realtime, biar pop-up
            // langsung berhenti muncul begitu email tersimpan di database.
            final String? emailBaru = data.first['email']?.toString().trim();
            if (emailBaru != null &&
                emailBaru.isNotEmpty &&
                !emailBaru.contains('@laundry.local') &&
                emailBaru.contains('@') &&
                emailBaru.contains('.')) {
              _emailSudahDitangani = true;
            }
            setState(() => _profile = data.first);
          }
        });

    _customerSubscription = _supabase
        .from('customers')
        .stream(primaryKey: ['id'])
        .eq('profile_id', userId)
        .listen((data) {
          _fetchInitialData(userId);
        });

    // Menghapus filter spesifik ID di stream agar fleksibel saat pindah dompet (Data tetap aman karena RLS database).
    _ordersSubscription = _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .listen((data) {
          _fetchInitialData(userId);
        });
  }

  // =========================================================
  // FUNGSI POP-UP LENGKAPI EMAIL (FIX POPSCOPE)
  // =========================================================
  void _tampilkanPopupLengkapiEmail(String userId) {
    // [FIX] Tandai bahwa pop-up sedang tampil, agar tidak ada pop-up kedua
    // yang menumpuk di atasnya.
    _popupEmailSedangTampil = true;
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSaving = false;
    String? popupError; 
    
    // 1. TAMBAHKAN KUNCI GEMBOK INI
    bool allowClose = false; 

    showDialog(
      context: context,
      barrierDismissible: false, // Layar dikunci
      builder: (ctx) => PopScope(
        // 2. PASANG GEMBOKNYA DI SINI
        canPop: allowClose, 
        child: StatefulBuilder(
          builder: (context, setPopupState) {
            return Dialog(
              backgroundColor: CustomerTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CustomerTheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_unread_rounded,
                          size: 40,
                          color: CustomerTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Lengkapi Data Email',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: CustomerTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Masukkan alamat email Anda untuk keamanan akun dan fitur pemulihan kata sandi (OTP).',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          color: CustomerTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Kotak Pesan Error Merah
                      if (popupError != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  popupError!,
                                  style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),

                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          labelText: 'Alamat Email',
                          hintText: 'contoh@email.com',
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Colors.grey,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: CustomerTheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty)
                            return 'Email wajib diisi';
                          if (!val.contains('@') || !val.contains('.'))
                            return 'Format email tidak valid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CustomerTheme.primary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: isSaving
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  
                                  setPopupState(() {
                                    isSaving = true;
                                    popupError = null;
                                  });
                                  
                                  try {
                                    await _supabase
                                        .from('profiles')
                                        .update({
                                          'email': emailController.text.trim(),
                                        })
                                        .eq('id', userId);

                                    // [FIX] Kunci flag SEBELUM pop-up ditutup,
                                    // supaya callback Future.delayed yang masih
                                    // antre tidak memunculkan pop-up lagi.
                                    _emailSudahDitangani = true;
                                    _popupEmailSedangTampil = false;

                                    if (mounted) {
                                      final messenger = ScaffoldMessenger.of(context);
                                      
                                      // 3. BUKA GEMBOK SEBELUM POP-UP DITUTUP
                                      setPopupState(() => allowClose = true);
                                      Navigator.pop(ctx);
                                      
                                      messenger.showSnackBar(
                                        const SnackBar(
                                          content: Text('Email berhasil disimpan! 🎉', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          backgroundColor: Colors.green,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                      
                                      _loadAllData();
                                    }
                                  } on PostgrestException catch (e) {
                                    setPopupState(() {
                                      isSaving = false;
                                      if (e.code == '23505') {
                                        popupError = 'Email sudah terdaftar. Silakan gunakan email lain.';
                                      } else {
                                        popupError = 'Gagal menyimpan: ${e.message}';
                                      }
                                    });
                                  } catch (e) {
                                    setPopupState(() {
                                      isSaving = false;
                                      popupError = 'Terjadi kesalahan sistem.';
                                    });
                                  }
                                },
                          child: isSaving
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Simpan Email',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ).then((_) {
      // [FIX] Pop-up sudah benar-benar tertutup, lepas penanda.
      _popupEmailSedangTampil = false;
    });
  }

  Future<void> _handleLogout() async {
    HapticFeedback.mediumImpact();

    // ==========================================================
    // [PERBAIKAN UX]: TAMPILKAN EFEK LOADING SAAT KELUAR
    // ==========================================================
    showDialog(
      context: context,
      barrierDismissible:
          false, // Kunci layar agar tidak bisa di-klik sembarangan
      barrierColor: Colors.black.withOpacity(
        0.6,
      ), // Layar belakang agak digelapkan
      builder: (ctx) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ModernSpinner(size: 48, color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Sedang Keluar...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration
                    .none, // Wajib agar teks tidak bergaris bawah kuning
              ),
            ),
          ],
        ),
      ),
    );
    // ==========================================================

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
                BerandaTab(
                  nama: nama,
                  poin: poin,
                  activeOrders: _activeOrders,
                  myWallets: _myWallets,
                  activeWallet: _activeWallet,
                  onSwitchWallet: switchWallet,
                  onOpenNewBranch: _showBukaCabangSheet,
                  onRefresh: () =>
                      _fetchInitialData(_supabase.auth.currentUser!.id),
                ),
                AktivitasTab(
                  historyOrders: _historyOrders,
                  customerId: activeCustomerId,
                  onRefresh: () =>
                      _fetchInitialData(_supabase.auth.currentUser!.id),
                ),
                KatalogTab(
                  customerId: activeCustomerId,
                  activeBranchId: _activeWallet?['branch_id'],
                  currentPoin: poin,
                  onRefresh: () =>
                      _fetchInitialData(_supabase.auth.currentUser!.id),
                ),
                ProfilTab(
                  nama: nama,
                  noHp: noHp,
                  avatarUrl: _profile?['avatar_url'],
                  onLogout: _handleLogout,
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
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Koneksi Terputus',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: CustomerTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'Gagal terhubung ke server.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: CustomerTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _loadAllData,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CustomerTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: CustomerTheme.bottomNavShadow,
      ),
      child: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.home_rounded,
                Icons.home_outlined,
                'Beranda',
              ),
              _buildNavItem(
                1,
                Icons.receipt_long_rounded,
                Icons.receipt_long_outlined,
                'Aktivitas',
              ),
              _buildNavItem(
                2,
                Icons.local_offer_rounded,
                Icons.local_offer_outlined,
                'Rewards',
              ),
              _buildNavItem(
                3,
                Icons.person_rounded,
                Icons.person_outline_rounded,
                'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final isActive = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentTab = index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: isActive
                    ? CustomerTheme.primaryLight
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isActive ? activeIcon : inactiveIcon,
                color: isActive
                    ? CustomerTheme.primary
                    : CustomerTheme.textHint,
                size: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive
                    ? CustomerTheme.primary
                    : CustomerTheme.textHint,
              ),
            ),
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
            orElse: () => _myWallets.first,
          );
          switchWallet(newlyAdded);
        },
      ),
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
      final existingBranchIds = widget.myWallets
          .map((w) => w['branch_id'])
          .toList();
      final data = await _supabase
          .from('branches')
          .select()
          .eq('is_active', true);

      // Filter: Hanya tampilkan cabang yang BELUM dimiliki oleh user
      final available = List<Map<String, dynamic>>.from(
        data,
      ).where((b) => !existingBranchIds.contains(b['id'])).toList();

      setState(() {
        _availableBranches = available;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _buatDompet(Map<String, dynamic> branch) async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;
      final newWallet = await _supabase
          .from('customers')
          .insert({
            'profile_id': userId,
            'branch_id': branch['id'],
            'poin_saldo': 0,
          })
          .select()
          .single();

      widget.onSuccess(newWallet);
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuat dompet: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Buka Dompet Cabang',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: CustomerTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pilih cabang lain untuk mulai mengumpulkan koin di sana.',
            style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: ModernSpinner()),
            )
          else if (_availableBranches.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'Anda sudah memiliki dompet di semua cabang kami!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: CustomerTheme.textHint),
                ),
              ),
            )
          else
            ..._availableBranches
                .map(
                  (branch) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: CustomerTheme.menuDecoration,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_business_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        branch['nama_cabang'],
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        branch['alamat'] ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CustomerTheme.primary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => _buatDompet(branch),
                        child: const Text(
                          'Buka',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}