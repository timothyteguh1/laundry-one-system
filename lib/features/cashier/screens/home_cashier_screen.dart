import 'dart:ui';
import 'dart:math' as math;
import 'dart:async'; // Untuk Timer AJAX (Debounce)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/cashier/screens/point_settings_screen.dart';
import 'package:laundry_one/features/cashier/screens/branch_management_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/cashier/screens/create_order_screen.dart';
import 'package:laundry_one/features/cashier/screens/inventory_screen.dart';
import 'package:laundry_one/features/cashier/screens/tabs/report_tab.dart';
import 'package:laundry_one/features/cashier/screens/tabs/pelanggan_tab.dart';
import 'package:laundry_one/features/cashier/screens/invoice_screen.dart';
import 'package:laundry_one/features/auth/screens/register_screen.dart';
import 'package:laundry_one/features/cashier/screens/rekap_kasir_screen.dart';

// Mengimpor AppTokens terpusat, pastikan path ini sesuai proyek Anda
import 'package:laundry_one/core/tokens/app_tokens.dart';
import 'package:laundry_one/core/services/app_state.dart';

class HomeCashierScreen extends StatefulWidget {
  const HomeCashierScreen({super.key});

  @override
  State<HomeCashierScreen> createState() => _HomeCashierScreenState();
}

class _HomeCashierScreenState extends State<HomeCashierScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _userProfile;
  final AuthService _authService = AuthService();

  int _currentTab = 0;
  AnimationController? _fabAnim;

  List<Map<String, dynamic>> _tabOrders = [];
  List<Map<String, dynamic>> _todayOrders = [];
  List<Map<String, dynamic>> _allPiutangOrders = [];

  bool _isLoading = true;
  bool _isProcessing = false;

  // PAGINASI & PENCARIAN (AJAX SILENT SEARCH)
  int _orderPage = 0;
  final int _perPage = 25;
  bool _hasMoreOrders = true;
  bool _isLoadingMore = false;

  bool _isSearching = false;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  Timer? _searchDebounce;

  Timer? _rtDebounce;

  static const String _orderSelectFields =
      'id, nomor_order, cashier_id, status, total_harga, is_piutang, '
      'metode_bayar_awal, created_at, estimasi_selesai, jatuh_tempo, '
      'customer_id, poin_didapat, poin_sudah_diberikan, '
      'customers(profiles(nama_lengkap, nomor_hp)), '
      'profiles!orders_cashier_id_fkey(nama_lengkap)';

  String? _kasirNama;

  List<Map<String, dynamic>> _branches = [];
  String? _selectedBranchId;
  String? _selectedBranchName;
  bool _isSwitchingBranch = false;

  int _todayTotalOrder = 0;
  int _todayAktif = 0;
  int _todaySelesai = 0;

  double _totalPenjualanHariIni = 0;
  double _totalCashHariIni = 0;
  double _totalNonCashHariIni = 0;
  double _totalPiutangAllTime = 0;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    
    // [PERBAIKAN UX]: Beri jeda 150 milidetik agar animasi Loading sempat muncul
    // Ini akan mencegah layar terasa stuck/freeze.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 150)); 
      
      _loadUserProfile();
      _loadBranchesForSwitcher();
      _refreshAll(showFullLoading: true);
      _subscribeRealtime();
    });
  }

  @override
  void dispose() {
    _fabAnim?.dispose();
    _searchCtrl.dispose();
    _searchDebounce?.cancel();
    _rtDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      setState(() => _searchQuery = val);
      _loadOrdersList(reset: true, showFullLoading: false);
    });
  }

  void _showCustomDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle : Icons.cancel,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTokens.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: AppTokens.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTokens.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', _supabase.auth.currentUser!.id)
          .single();
      if (mounted) setState(() => _userProfile = profile);
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }
  }

  Future<void> _loadBranchesForSwitcher() async {
    final role = await AppState.getRole();
    if (role != 'super_admin') return;
    try {
      final data = await _supabase.from('branches').select('id, nama_cabang').eq('is_active', true).order('nama_cabang');
      final branchId = await AppState.getBranchId();
      final branchName = await AppState.getBranchName();
      if (mounted) {
        setState(() {
          _branches = List<Map<String, dynamic>>.from(data);
          if (branchId != null) {
            _selectedBranchId = branchId;
            _selectedBranchName = branchName;
          } else if (_branches.isNotEmpty) {
            // Default ke cabang utama jika belum pernah pilih
            _selectedBranchId = _branches.first['id'] as String;
            _selectedBranchName = _branches.first['nama_cabang'] as String? ?? 'Cabang';
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading branches for switcher: $e');
    }
  }

  Future<void> _switchBranch(String? branchId, String branchName) async {
    setState(() => _isSwitchingBranch = true);
    await AppState.saveBranch(branchId: branchId, branchName: branchName);
    if (mounted) setState(() => _selectedBranchId = branchId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cabang: $branchName'), backgroundColor: Colors.green.shade800),
      );
    }
    await _refreshAll(showFullLoading: true);
    if (mounted) setState(() => _isSwitchingBranch = false);
  }

  Widget _buildDrawer() {
    final role = _userProfile?['role'] ?? 'cashier';
    final isAdmin = role == 'super_admin';
    final nama = _userProfile?['nama_lengkap'] ?? _kasirNama ?? 'Memuat...';

    return Drawer(
      backgroundColor: AppTokens.surface,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: AppTokens.navy),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: AppTokens.navy, size: 40),
            ),
            accountName: Text(
              nama,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.orange : AppTokens.blue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAdmin ? 'Super Admin' : 'Kasir',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
                  child: Text(
                    'MENU KASIR',
                    style: TextStyle(
                      color: AppTokens.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.home_outlined,
                    color: AppTokens.textPrimary,
                  ),
                  title: const Text(
                    'Beranda',
                    style: TextStyle(
                      color: AppTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentTab = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.receipt_long_outlined,
                    color: AppTokens.textPrimary,
                  ),
                  title: const Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      color: AppTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentTab = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.qr_code_scanner_rounded,
                    color: Color(0xFF0F2557),
                  ),
                  title: const Text(
                    'Proses Voucher (VCH)',
                    style: TextStyle(
                      color: Color(0xFF0F2557),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRedeemVoucherDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.analytics_outlined,
                    color: AppTokens.textPrimary,
                  ),
                  title: const Text(
                    'Rekap Kasir (30 Hari)',
                    style: TextStyle(
                      color: AppTokens.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const RekapPendapatanScreen(),
                      ),
                    );
                  },
                ),
                if (isAdmin) ...[
                  const Divider(height: 32),
                  const Padding(
                    padding: EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'ADMIN MENU',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.bar_chart_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Laporan Pendapatan & Koin',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentTab = 3);
                    },
                  ),
                  ListTile(
                    leading: const Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Master Data (Jasa & Barang)',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                     onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const InventoryScreen(),
                        ),
                      );
                    },
                   ),
                   ListTile(
                     leading: const Icon(
                       Icons.store_rounded,
                       color: Colors.red,
                     ),
                     title: const Text(
                       'Kelola Cabang',
                       style: TextStyle(
                         color: Colors.red,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     onTap: () {
                       Navigator.pop(context);
                       Navigator.push(
                         context,
                         MaterialPageRoute(
                           builder: (_) => const BranchManagementScreen(),
                         ),
                       );
                     },
                   ),
                  ListTile(
                    leading: const Icon(
                      Icons.settings_suggest_rounded,
                      color: Colors.red,
                    ),
                    title: const Text(
                      'Pengaturan Koin',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PointSettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
                const Divider(height: 32),
                const Padding(
                  padding: EdgeInsets.only(left: 16, bottom: 8),
                  child: Text(
                    'SISTEM',
                    style: TextStyle(
                      color: AppTokens.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    'Keluar',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _authService.logout();
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoginScreen(
                          config: LoginConfig(
                            roleName: 'Staf Kasir',
                            roleDatabase: 'cashier',
                            labelIdentifier: 'Nomor HP / Email',
                            hint: '081234567890',
                            keyboardType: TextInputType.phone,
                            primaryColor: Color(0xFF1565C0),
                            secondaryColor: Color(0xFF0D47A1),
                            backgroundColor: Colors.white,
                            icon: Icons.point_of_sale_rounded,
                            tagline: 'Kelola pesanan dengan cepat & mudah',
                            homeScreen: HomeCashierScreen(),
                            showRegister: true,
                            registerScreen: RegisterScreen(),
                          ),
                        ),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateStr(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Ags',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _dateRangeText {
    final now = DateTime.now();
    if (_startDate.year == _endDate.year &&
        _startDate.month == _endDate.month &&
        _startDate.day == _endDate.day) {
      if (_startDate.day == now.day &&
          _startDate.month == now.month &&
          _startDate.year == now.year)
        return 'Hari Ini';
      return _formatDateStr(_startDate);
    }
    return '${_formatDateStr(_startDate)} - ${_formatDateStr(_endDate)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppTokens.blue,
            onPrimary: Colors.white,
            surface: AppTokens.surface,
            onSurface: AppTokens.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      await _loadOrdersList(reset: true, showFullLoading: true);
    }
  }

  Future<void> _showRedeemVoucherDialog() async {
    final codeCtrl = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cek & Gunakan Voucher',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Masukkan kode (VCH-xxxx) yang ada di HP Pelanggan:',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: codeCtrl,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Contoh: VCH-123456',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final kode = codeCtrl.text.trim();
                      if (kode.isEmpty) return;

                      setModalState(() => isSubmitting = true);
                       try {
                         final branchId = await AppState.getBranchId();
                         var voucherQuery = _supabase
                             .from('reward_redemptions')
                             .select('*, rewards_catalog(nama)')
                             .eq('kode_voucher', kode)
                             .eq('status', 'aktif');

                         // [MULTI-BRANCH]: Hanya izinkan pakai voucher dari cabang aktif
                         if (branchId != null) {
                           voucherQuery = voucherQuery.eq('branch_id', branchId);
                         }

                         final res = await voucherQuery.maybeSingle();
                        if (res == null)
                          throw 'Voucher tidak ditemukan, palsu, atau sudah hangus (lewat 5 menit)!';

                        await _supabase
                            .from('reward_redemptions')
                            .update({
                              'status': 'dipakai',
                              'dipakai_at': DateTime.now()
                                  .toUtc()
                                  .toIso8601String(),
                            })
                            .eq('id', res['id']);

                        if (mounted) {
                          Navigator.pop(ctx);
                          _showCustomDialog(
                            title: 'Voucher Valid!',
                            message:
                                'Silakan berikan diskon "${res['rewards_catalog']['nama']}" pada pesanan pelanggan ini.',
                            isSuccess: true,
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setModalState(() => isSubmitting = false);
                          Navigator.pop(ctx);
                          _showCustomDialog(
                            title: 'Gagal Memproses Voucher',
                            message: e.toString(),
                            isSuccess: false,
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 40,
                      height: 16,
                      child: Center(
                        child: _ModernLoadingDots(color: Colors.white, size: 8),
                      ),
                    )
                  : const Text(
                      'Verifikasi',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAll({bool showFullLoading = false}) async {
    await Future.wait([
      _loadStatsAndPiutang(),
      _loadOrdersList(reset: true, showFullLoading: showFullLoading),
    ]);
  }

  Future<void> _loadStatsAndPiutang() async {
    try {
      final now = DateTime.now();
      final startOfTodayLocal = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfTodayLocal = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      );
      final todayStart = startOfTodayLocal.toUtc().toIso8601String();
      final todayEnd = endOfTodayLocal.toUtc().toIso8601String();

      final branchId = await AppState.getBranchId();

      var ordersTodayQuery = _supabase
          .from('orders')
          .select(_orderSelectFields)
          .gte('created_at', todayStart)
          .lte('created_at', todayEnd);

      var piutangQuery = _supabase
          .from('orders')
          .select(_orderSelectFields)
          .eq('is_piutang', true)
          .neq('status', 'dibatalkan');

      var paymentsQuery = _supabase
          .from('order_payments')
          .select('jumlah, metode, orders!inner(branch_id)')
          .gte('created_at', todayStart)
          .lte('created_at', todayEnd);

      // [MULTI-BRANCH]: Filter semua query berdasarkan cabang yang aktif
      if (branchId != null) {
        ordersTodayQuery = ordersTodayQuery.eq('branch_id', branchId);
        piutangQuery = piutangQuery.eq('branch_id', branchId);
        paymentsQuery = paymentsQuery.eq('orders.branch_id', branchId);
      }

      final results = await Future.wait([
        ordersTodayQuery.order('created_at', ascending: false),
        piutangQuery.order('created_at', ascending: false),
        paymentsQuery.order('created_at', ascending: false),
      ]);

      final todayOrdersData = List<Map<String, dynamic>>.from(results[0]);
      final allPiutangData = List<Map<String, dynamic>>.from(results[1]);
      final todayPaymentsData = List<Map<String, dynamic>>.from(results[2]);

      double kasTunaiHariIni = 0;
      double kasNonTunaiHariIni = 0;
      for (final p in todayPaymentsData) {
        final amt = (p['jumlah'] ?? 0).toDouble();
        if (p['metode'] == 'cash')
          kasTunaiHariIni += amt;
        else
          kasNonTunaiHariIni += amt;
      }

      double omsetHariIni = 0;
      for (final o in todayOrdersData) {
        if (o['status'] != 'dibatalkan')
          omsetHariIni += (o['total_harga'] ?? 0).toDouble();
      }

      if (mounted) {
        setState(() {
          _todayOrders = todayOrdersData;
          _allPiutangOrders = allPiutangData;
          _totalPenjualanHariIni = omsetHariIni;
          _totalCashHariIni = kasTunaiHariIni;
          _totalNonCashHariIni = kasNonTunaiHariIni;

          _todayTotalOrder = todayOrdersData
              .where((o) => o['status'] != 'dibatalkan')
              .length;
          _todayAktif = todayOrdersData
              .where((o) => o['status'] == 'diproses')
              .length;
          _todaySelesai = todayOrdersData
              .where(
                (o) =>
                    o['status'] == 'selesai' || o['status'] == 'dibayar_lunas',
              )
              .length;

          _totalPiutangAllTime = allPiutangData.fold(
            0.0,
            (sum, o) => sum + (o['total_harga'] ?? 0).toDouble(),
          );
        });
      }
    } catch (e) {
      debugPrint('Error loading stats: $e');
    }
  }

  Future<void> _loadOrdersList({
    bool reset = true,
    bool showFullLoading = false,
  }) async {
    if (reset) {
      _orderPage = 0;
      _hasMoreOrders = true;
    } else {
      if (_isLoadingMore || !_hasMoreOrders) return;
      if (mounted) setState(() => _isLoadingMore = true);
      _orderPage++;
    }

    if (showFullLoading && mounted) setState(() => _isLoading = true);

    try {
      final startOfRangeLocal = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        0,
        0,
        0,
      );
      final endOfRangeLocal = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      );
      final startStr = startOfRangeLocal.toUtc().toIso8601String();
      final endStr = endOfRangeLocal.toUtc().toIso8601String();

      final branchId = await AppState.getBranchId();

      var query = _supabase
          .from('orders')
          .select(_orderSelectFields)
          .gte('created_at', startStr)
          .lte('created_at', endStr);

      // [MULTI-BRANCH]: Filter order hanya dari cabang yang aktif
      if (branchId != null) {
        query = query.eq('branch_id', branchId);
      }

      final q = _searchQuery.trim();
      final bool isSearchActive = q.isNotEmpty;

      if (isSearchActive) {
        List<Map<String, dynamic>> matchedCustomers = [];
        try {
          var custQuery = _supabase
              .from('customers')
              .select('id, profiles!inner(nama_lengkap)')
              .ilike('profiles.nama_lengkap', '%$q%');

          // [MULTI-BRANCH]: Filter pencarian pelanggan hanya dari cabang yang aktif
          if (branchId != null) {
            custQuery = custQuery.eq('branch_id', branchId);
          }

          matchedCustomers = List<Map<String, dynamic>>.from(await custQuery);
        } catch (e) {
          debugPrint('Error searching customers: $e');
        }

        final custIds = matchedCustomers
            .map((c) => c['id']?.toString())
            .where((id) => id != null && id.isNotEmpty)
            .join(',');

        final orClauses = <String>['nomor_order.ilike.%$q%'];
        if (custIds.isNotEmpty) {
          orClauses.add('customer_id.in.($custIds)');
        }
        
        // [PERBAIKAN PENCARIAN UMUM]
        // Jika pencarian mengandung "umum" (case-insensitive), sertakan juga
        // nota yang customer_id-nya NULL (Karena Flutter akan merendernya sbg "Umum")
        if ('umum'.contains(q.toLowerCase())) {
          orClauses.add('customer_id.is.null');
        }

        query = query.or(orClauses.join(','));
      }

      final List<dynamic> data;
      if (isSearchActive) {
        data = await query.order('created_at', ascending: false);
        _hasMoreOrders = false; 
      } else {
        final startRow = _orderPage * _perPage;
        final endRow = startRow + _perPage - 1;
        data = await query
            .order('created_at', ascending: false)
            .range(startRow, endRow);
        if (data.length < _perPage) _hasMoreOrders = false;
      }

      final newOrders = List<Map<String, dynamic>>.from(data);

      if (mounted) {
        setState(() {
          _tabOrders = reset ? newOrders : [..._tabOrders, ...newOrders];
          _isLoadingMore = false;
          _isSearching = false;
          if (showFullLoading) _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading orders list: $e');
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _isSearching = false;
          if (showFullLoading) _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreOrders() async {
    await _loadOrdersList(reset: false);
  }

  void _subscribeRealtime() {
    final userId = _supabase.auth.currentUser!.id;
    _supabase
        .channel('orders_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) {
            _rtDebounce?.cancel();
            _rtDebounce = Timer(const Duration(milliseconds: 500), () {
              _refreshAll(showFullLoading: false);
            });
          },
        )
        .subscribe();
    _supabase
        .channel('kasir_status_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'kasir',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'profile_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.newRecord['status'] == 'rejected')
              _forceLogout('Akses Anda telah dicabut oleh Admin.');
          },
        )
        .subscribe();
    _supabase
        .channel('kasir_delete_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.delete,
          schema: 'public',
          table: 'profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) {
            _forceLogout('Akun Kasir Anda telah dihapus permanen.');
          },
        )
        .subscribe();
  }

  Future<void> _forceLogout(String pesan) async {
    _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const LoginScreen(
            config: LoginConfig(
              roleName: 'Staf Kasir',
              roleDatabase: 'cashier',
              labelIdentifier: 'Nomor HP / Email',
              hint: '081234567890',
              keyboardType: TextInputType.phone,
              primaryColor: Color(0xFF1565C0),
              secondaryColor: Color(0xFF0D47A1),
              backgroundColor: Colors.white,
              icon: Icons.point_of_sale_rounded,
              tagline: 'Kelola pesanan dengan cepat & mudah',
              homeScreen: HomeCashierScreen(),
              showRegister: true,
              registerScreen: RegisterScreen(),
            ),
          ),
        ),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sesi diakhiri: $pesan'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _handleUpdateStatus(Map<String, dynamic> order, String newStatus) {
    HapticFeedback.lightImpact();
    if (newStatus == 'dibayar_lunas' && order['is_piutang'] == true) {
      _showPelunasanSheet(order);
    } else {
      _updateStatusDb(order['id'], newStatus);
    }
  }

  Future<void> _updateStatusDb(String orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    setState(() => _isProcessing = true);
    try {
      await _supabase
          .from('orders')
          .update({'status': newStatus})
          .eq('id', orderId);
      await _refreshAll(showFullLoading: false);
      if (mounted)
        _showCustomDialog(
          title: 'Status Diperbarui',
          message: 'Status pesanan berhasil diubah menjadi $newStatus.',
          isSuccess: true,
        );
    } catch (e) {
      if (mounted)
        _showCustomDialog(
          title: 'Gagal Update Status',
          message: e.toString(),
          isSuccess: false,
        );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showPelunasanSheet(Map<String, dynamic> order) {
    String metodeBayar = 'cash';
    bool isSubmitting = false;
    final total = (order['total_harga'] ?? 0).toDouble();
    final namaPelanggan =
        order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            16,
            24,
            MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
              const SizedBox(height: 20),
              const Text(
                'Pelunasan Piutang',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTokens.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order: ${order['nomor_order']} • $namaPelanggan',
                style: const TextStyle(color: AppTokens.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Total Tagihan',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppTokens.formatRupiah(total),
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Pilih Metode Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // HAPUS Expanded di sini, panggil _PayOption langsung
                  _PayOption(
                    label: 'Cash',
                    icon: Icons.payments_outlined,
                    selected: metodeBayar == 'cash',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setModalState(() => metodeBayar = 'cash');
                    },
                  ),
                  const SizedBox(width: 8),
                  _PayOption(
                    label: 'Transfer',
                    icon: Icons.account_balance_wallet_outlined,
                    selected: metodeBayar == 'transfer',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setModalState(() => metodeBayar = 'transfer');
                    },
                  ),
                  const SizedBox(width: 8),
                  _PayOption(
                    label: 'QRIS',
                    icon: Icons.qr_code_scanner_outlined,
                    selected: metodeBayar == 'qris',
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setModalState(() => metodeBayar = 'qris');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isSubmitting
                      ? null
                      : () async {
                          HapticFeedback.heavyImpact();
                           setModalState(() => isSubmitting = true);
                           try {
                             final branchId = await AppState.getBranchId();
                             final currentStatus = order['status'];
                            String newStatus = currentStatus;
                            if (currentStatus == 'selesai')
                              newStatus = 'dibayar_lunas';

                            final orderId = order['id'];
                            final kasirId = _supabase.auth.currentUser!.id;
                            final customerId = order['customer_id'];
                            final poinDidapat = order['poin_didapat'] ?? 0;
                            final poinSudahDiberikan =
                                order['poin_sudah_diberikan'] == true;
                            final nomorOrder = order['nomor_order'];

                            await _supabase
                                .from('orders')
                                .update({
                                  'status': newStatus,
                                  'is_piutang': false,
                                  'total_dibayar': total.toInt(),
                                  'poin_sudah_diberikan': true,
                                })
                                .eq('id', orderId);
                             await _supabase.from('order_payments').insert({
                               'order_id': orderId,
                               'branch_id': branchId,
                               'jumlah': total.toInt(),
                               'metode': metodeBayar,
                               'diterima_oleh': kasirId,
                             });

                            if (customerId != null &&
                                poinDidapat > 0 &&
                                !poinSudahDiberikan) {
                              final cust = await _supabase
                                  .from('customers')
                                  .select('poin_saldo')
                                  .eq('id', customerId)
                                  .single();
                              final saldoSebelum = (cust['poin_saldo'] as num)
                                  .toInt();
                              final saldoSesudah = saldoSebelum + poinDidapat;

                              await _supabase
                                  .from('customers')
                                  .update({'poin_saldo': saldoSesudah})
                                  .eq('id', customerId);
                              await _supabase.from('points_ledger').insert({
                                'customer_id': customerId,
                                'branch_id': branchId,
                                'tipe': 'earned',
                                'jumlah': poinDidapat,
                                'saldo_sebelum': saldoSebelum,
                                'saldo_sesudah': saldoSesudah,
                                'order_id': orderId,
                                'dilakukan_oleh': kasirId,
                                'catatan':
                                    'Poin Pelunasan Piutang ($nomorOrder)',
                              });
                            }

                            if (mounted) {
                              Navigator.pop(ctx);
                              _refreshAll(showFullLoading: false);
                              _showCustomDialog(
                                title: 'Pelunasan Berhasil',
                                message:
                                    'Nota telah dilunasi dan Poin (jika ada) telah masuk ke dompet pelanggan.',
                                isSuccess: true,
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              setModalState(() => isSubmitting = false);
                              _showCustomDialog(
                                title: 'Gagal Melunasi',
                                message: e.toString(),
                                isSuccess: false,
                              );
                            }
                          }
                        },
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    height: 52,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isSubmitting ? Colors.green.withOpacity(0.6) : Colors.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Center(
                      child: isSubmitting
                          ? const SizedBox(
                              width: 100,
                              height: 22,
                              child: Center(
                                child: _ModernLoadingDots(
                                  color: Colors.white,
                                  size: 10,
                                ),
                              ),
                            )
                          : const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: FittedBox( // <--- KUNCI ANTI-MELEBER
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Konfirmasi Pelunasan',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.navy,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  color: AppTokens.ground,
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _buildTabBeranda(),
                      _PesananTab(
                        orders: _tabOrders,
                        isLoading: _isLoading,
                        isLoadingMore: _isLoadingMore,
                        hasMore: _hasMoreOrders,
                        isSearching: _isSearching,
                        onLoadMore: _loadMoreOrders,
                        onRefresh: _refreshAll,
                        onUpdate: _handleUpdateStatus,
                        onDetail: _showDetail,
                        dateText: _dateRangeText,
                        onPickDate: _pickDate,
                        searchQuery: _searchQuery,
                        searchCtrl: _searchCtrl,
                        onSearchChanged: _onSearchChanged,
                      ),
                      PelangganTab(isActive: _currentTab == 2),
                      _buildTabLaporan(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // [PERBAIKAN UX]: Loading akan muncul saat _isLoading ATAU _isProcessing
          if (_isLoading || _isProcessing)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: AppTokens.navy.withOpacity(0.3),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppTokens.navy.withOpacity(0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _ModernLoadingDots(color: AppTokens.blue, size: 14),
                          const SizedBox(height: 20),
                          Text(
                            _isProcessing ? 'Memproses...' : 'Memuat Data...',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppTokens.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _fabAnim == null
          ? const SizedBox()
          : ScaleTransition(
              scale: CurvedAnimation(
                parent: _fabAnim!,
                curve: Curves.elasticOut,
              ),
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: AppTokens.fabShadow,
                ),
                child: FloatingActionButton.extended(
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final r = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CreateOrderScreen(),
                      ),
                    );
                    if (r == true) _refreshAll(showFullLoading: false);
                  },
                  backgroundColor: AppTokens.blue,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  icon: const Icon(Icons.add_rounded, size: 22),
                  label: const Text(
                    'Buat Pesanan',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTabBeranda() {
    final siap = _todayOrders
        .where(
          (o) => o['status'] == 'selesai' || o['status'] == 'dibayar_lunas',
        )
        .toList();
    final aktif = _todayOrders
        .where((o) => o['status'] == 'diproses')
        .take(5)
        .toList();

    return Container(
      color: AppTokens.navy,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _refreshAll(showFullLoading: false),
          color: AppTokens.blue,
          backgroundColor: AppTokens.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(color: AppTokens.ground),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: AppTokens.sky,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTokens.blue.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppTokens.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Menampilkan ringkasan transaksi khusus Hari Ini (${_formatDateStr(DateTime.now())}).',
                                style: const TextStyle(
                                  color: AppTokens.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: _AnimatedPenjualanCard(
                                totalPenjualan: _totalPenjualanHariIni,
                                onTap: _showPenjualanDetail,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _AnimatedPiutangCard(
                                totalPiutang: _totalPiutangAllTime,
                                onTap: _showPiutangList,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (siap.isNotEmpty) ...[
                        _buildSectionHeader(
                          '✅  Pesanan Selesai',
                          count: siap.length,
                          countColor: AppTokens.statusSelesai,
                          topPad: 24,
                        ),
                        ...siap
                            .map(
                              (o) => Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: _PremiumOrderCard(
                                  order: o,
                                  onUpdate: _handleUpdateStatus,
                                  onTap: () => _showDetail(o),
                                ),
                              ),
                            )
                            .toList(),
                      ],
                      _buildSectionHeader(
                        'Sedang Diproses',
                        count: _todayAktif,
                        countColor: AppTokens.statusDiproses,
                        topPad: siap.isNotEmpty ? 8 : 24,
                        action: _todayAktif > 5
                            ? () => setState(() => _currentTab = 1)
                            : null,
                        actionLabel: 'Lihat Semua',
                      ),

                      if (_isLoading)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: List.generate(
                              3,
                              (index) => const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: _SkeletonOrderCard(),
                              ),
                            ),
                          ),
                        )
                      else if (aktif.isEmpty)
                        const _EmptyState(
                          icon: Icons.check_circle_outline_rounded,
                          message: 'Belum ada pesanan aktif hari ini',
                          sub: 'Tap tombol + untuk buat pesanan baru',
                        )
                      else
                        ...aktif
                            .map(
                              (o) => Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                                child: _PremiumOrderCard(
                                  order: o,
                                  onUpdate: _handleUpdateStatus,
                                  onTap: () => _showDetail(o),
                                ),
                              ),
                            )
                            .toList(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2557), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Builder(
                    builder: (ctx) => Material(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Scaffold.of(ctx).openDrawer();
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.menu_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible( // <--- BUNGKUS DENGAN FLEXIBLE AGAR BISA MENGALAH
                              child: Text(
                                _greeting(),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis, // <--- TAMBAHKAN ELLIPSIS
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _greetingEmoji(),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _kasirNama ?? 'Kasir',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          overflow: TextOverflow.ellipsis, // <--- TAMBAHKAN ELLIPSIS AGAR AMAN
                        ),
                      ],
                    ),
                  ),
                  if (_userProfile?['role'] == 'super_admin') ...[
                    if (_branches.isNotEmpty)
                      Flexible( // <--- 1. BUNGKUS DENGAN FLEXIBLE AGAR TIDAK NABRAK LAYAR
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible( // <--- 2. DROPDOWN JUGA DIBUNGKUS FLEXIBLE
                                child: DropdownButton<String>(
                                  isExpanded: true, // <--- 3. WAJIB! Agar teks kepanjangan jadi titik-titik (ellipsis)
                                  value: _selectedBranchId,
                                  hint: Text(
                                    (_selectedBranchName ?? _branches.first['nama_cabang'] as String? ?? 'Cabang'),
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    overflow: TextOverflow.ellipsis, // <--- 4. EFEK TITIK-TITIK
                                  ),
                                  items: [
                                    for (final b in _branches)
                                      DropdownMenuItem<String>(
                                        value: b['id'] as String,
                                        child: Text(
                                          b['nama_cabang'] as String? ?? '-', 
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: _isSwitchingBranch
                                      ? null
                                      : (val) {
                                          final name = (_branches.firstWhere((b) => b['id'] == val, orElse: () => {})['nama_cabang'] as String? ?? 'Cabang');
                                          _switchBranch(val, name);
                                        },
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                  dropdownColor: const Color(0xFF1565C0),
                                  underline: const SizedBox.shrink(),
                                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                                ),
                              ),
                              if (_isSwitchingBranch) ...[
                                const SizedBox(width: 4),
                                const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white70),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const InventoryScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Material(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _authService.logout();
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(
                              config: LoginConfig(
                                roleName: 'Staf Kasir',
                                roleDatabase: 'cashier',
                                labelIdentifier: 'Nomor HP',
                                hint: '081234567890',
                                keyboardType: TextInputType.phone,
                                primaryColor: Color(0xFF1565C0),
                                secondaryColor: Color(0xFF0D47A1),
                                backgroundColor: Colors.white,
                                icon: Icons.point_of_sale_rounded,
                                tagline: 'Kelola pesanan dengan cepat & mudah',
                                homeScreen: HomeCashierScreen(),
                                showRegister: true,
                                registerScreen: RegisterScreen(),
                              ),
                            ),
                          ),
                          (route) => false,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: Icon(
                          Icons.logout_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  _StatChip(
                    value: '$_todayTotalOrder',
                    label: 'Order',
                    icon: Icons.receipt_rounded,
                    color: Colors.blue.shade200,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    value: '$_todayAktif',
                    label: 'Aktif',
                    icon: Icons.autorenew_rounded,
                    color: Colors.orange.shade200,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    value: '$_todaySelesai',
                    label: 'Selesai',
                    icon: Icons.check_circle_outline_rounded,
                    color: AppTokens.statusSelesai,
                    highlight: _todaySelesai > 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPenjualanDetail() {
    final totalPembayaranDiterima = _totalCashHariIni + _totalNonCashHariIni;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: AppTokens.ground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rincian Penjualan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppTokens.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTokens.sky,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.today_rounded, color: AppTokens.blue, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'HARI INI',
                            style: TextStyle(
                              color: AppTokens.blue,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTokens.navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Pembayaran Diterima',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            AppTokens.formatRupiah(totalPembayaranDiterima),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    _buildMiniStatCard(
                      'Tunai (Cash)',
                      _totalCashHariIni,
                      Icons.payments_rounded,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildMiniStatCard(
                      'Non-Tunai',
                      _totalNonCashHariIni,
                      Icons.qr_code_scanner_rounded,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showPiutangList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PiutangBottomSheet(
        allPiutangOrders: _allPiutangOrders,
        onNotaTapped: (order) {
          Navigator.pop(context);
          _showDetail(order);
        },
      ),
    );
  }

  Future<void> _showDetail(Map<String, dynamic> order) async {
    HapticFeedback.lightImpact();

    // [FIX]: Tampilkan overlay loading "Memproses..." agar layar tidak terlihat freeze
    setState(() => _isProcessing = true);

    List<Map<String, dynamic>> orderItemsRaw = [];
    try {
      orderItemsRaw = List<Map<String, dynamic>>.from(
        await _supabase
            .from('order_items')
            .select('jumlah, harga_satuan, services(nama)')
            .eq('order_id', order['id']),
      );
    } catch (e) {
      debugPrint('Error loading order items: $e');
    }

    final List<Map<String, dynamic>> mappedItems = orderItemsRaw
        .map(
          (i) => {
            'qty': (i['jumlah'] as num?)?.toInt() ?? 0,
            'subtotal':
                (i['harga_satuan'] as num?)?.toDouble() ??
                0 * ((i['jumlah'] as num?)?.toInt() ?? 0),
            'service': {'nama': i['services']?['nama'] ?? 'Item'},
          },
        )
        .toList();

    String namaKasirFinal = 'Sistem';
    final dataKasir = order['profiles'];
    if (dataKasir != null) {
      if (dataKasir is List && dataKasir.isNotEmpty)
        namaKasirFinal = dataKasir[0]['nama_lengkap']?.toString() ?? 'Sistem';
      else if (dataKasir is Map)
        namaKasirFinal = dataKasir['nama_lengkap']?.toString() ?? 'Sistem';
    }

    // [FIX]: Matikan overlay loading tepat sebelum layar berpindah
    if (mounted) setState(() => _isProcessing = false);

    final action = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceScreen(
          isFromHome: true,
          status: order['status'],
          orderId: order['id'],
          nomorOrder: order['nomor_order'],
          namaPelanggan:
              order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum',
          nomorHp: order['customers']?['profiles']?['nomor_hp'] ?? '-',
          namaKasir: namaKasirFinal,
          items: mappedItems,
          subtotal: (order['total_harga'] ?? 0).toDouble(),
          diskon: 0,
          total: (order['total_harga'] ?? 0).toDouble(),
          metodeBayar: order['metode_bayar_awal'] ?? 'cash',
          isPiutang: order['is_piutang'] == true,
          created_at: order['created_at'],
          isAdmin: _userProfile?['role'] == 'super_admin',
        ),
      ),
    );
    if (action == 'selesai')
      _handleUpdateStatus(order, 'selesai');
    else if (action == 'dibayar_lunas')
      _handleUpdateStatus(order, 'dibayar_lunas');
    else if (action == 'dihapus')
      _refreshAll(showFullLoading: false);
  }

  Widget _buildSectionHeader(
    String title, {
    int count = 0,
    Color countColor = AppTokens.blue,
    double topPad = 20,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, topPad, 16, 10),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 16,
            decoration: BoxDecoration(
              color: countColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: AppTokens.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: countColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: countColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: action,
              child: Text(
                actionLabel ?? 'Lihat Semua',
                style: const TextStyle(
                  color: AppTokens.blue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(
    String title,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTokens.border),
          boxShadow: AppTokens.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: AppTokens.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              AppTokens.formatRupiah(amount),
              style: const TextStyle(
                color: AppTokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.transparent,
        elevation: 0,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  _AnimatedNavItem(
                    idx: 0,
                    currentTab: _currentTab,
                    activeIcon: Icons.home_rounded,
                    inactiveIcon: Icons.home_outlined,
                    label: 'Beranda',
                    onTap: (idx) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentTab = idx);
                    },
                  ),
                  _AnimatedNavItem(
                    idx: 1,
                    currentTab: _currentTab,
                    activeIcon: Icons.receipt_long_rounded,
                    inactiveIcon: Icons.receipt_long_outlined,
                    label: 'Pesanan',
                    badge: _todayAktif > 0 ? '$_todayAktif' : null,
                    onTap: (idx) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentTab = idx);
                    },
                  ),
                  _AnimatedNavItem(
                    idx: 2,
                    currentTab: _currentTab,
                    activeIcon: Icons.people_alt_rounded,
                    inactiveIcon: Icons.people_alt_outlined,
                    label: 'Pelanggan',
                    onTap: (idx) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentTab = idx);
                    },
                  ),
                  _AnimatedNavItem(
                    idx: 3,
                    currentTab: _currentTab,
                    activeIcon: Icons.bar_chart_rounded,
                    inactiveIcon: Icons.bar_chart_outlined,
                    label: 'Kelola',
                    onTap: (idx) {
                      HapticFeedback.selectionClick();
                      setState(() => _currentTab = idx);
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabLaporan() {
    return const ReportTab();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _greetingEmoji() {
    final hour = DateTime.now().hour;
    if (hour < 12) return '☀️';
    if (hour < 15) return '🌤️';
    if (hour < 18) return '🌅';
    return '🌙';
  }
}

// ============================================================
// WIDGET HELPER UI & MICRO-INTERACTIONS
// ============================================================

class _AnimatedNavItem extends StatefulWidget {
  final int idx;
  final int currentTab;
  final IconData activeIcon;
  final IconData inactiveIcon;
  final String label;
  final String? badge;
  final ValueChanged<int> onTap;

  const _AnimatedNavItem({
    required this.idx,
    required this.currentTab,
    required this.activeIcon,
    required this.inactiveIcon,
    required this.label,
    required this.onTap,
    this.badge,
  });

  @override
  State<_AnimatedNavItem> createState() => _AnimatedNavItemState();
}

class _AnimatedNavItemState extends State<_AnimatedNavItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.currentTab == widget.idx;
    return Expanded(
      flex: 2,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap(widget.idx);
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: active ? AppTokens.sky : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      active ? widget.activeIcon : widget.inactiveIcon,
                      color: active ? AppTokens.blue : AppTokens.textHint,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                      color: active ? AppTokens.blue : AppTokens.textHint,
                    ),
                  ),
                ],
              ),
              if (widget.badge != null)
                Positioned(
                  top: 4,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.red.shade500,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedPenjualanCard extends StatefulWidget {
  final double totalPenjualan;
  final VoidCallback onTap;

  const _AnimatedPenjualanCard({
    required this.totalPenjualan,
    required this.onTap,
  });

  @override
  State<_AnimatedPenjualanCard> createState() => _AnimatedPenjualanCardState();
}

class _AnimatedPenjualanCardState extends State<_AnimatedPenjualanCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.payments_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Penjualan Hari Ini',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTokens.formatRupiah(widget.totalPenjualan),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedPiutangCard extends StatefulWidget {
  final double totalPiutang;
  final VoidCallback onTap;

  const _AnimatedPiutangCard({
    required this.totalPiutang,
    required this.onTap,
  });

  @override
  State<_AnimatedPiutangCard> createState() => _AnimatedPiutangCardState();
}

class _AnimatedPiutangCardState extends State<_AnimatedPiutangCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTokens.border, width: 1.5),
            boxShadow: AppTokens.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    color: Colors.orange.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Piutang All-time',
                  style: TextStyle(
                    color: AppTokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppTokens.formatRupiah(widget.totalPiutang),
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PremiumOrderCard extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(Map<String, dynamic>, String) onUpdate;
  final VoidCallback onTap;

  const _PremiumOrderCard({
    required this.order,
    required this.onUpdate,
    required this.onTap,
  });

  @override
  State<_PremiumOrderCard> createState() => _PremiumOrderCardState();
}

class _PremiumOrderCardState extends State<_PremiumOrderCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final status = widget.order['status'] ?? 'diproses';
    final nama = widget.order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';
    final isPiutang = widget.order['is_piutang'] == true;
    final cfg = _cfg(status, isPiutang);
    final nextSt = _next(status, isPiutang);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTokens.border),
            boxShadow: AppTokens.softShadow,
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: cfg['color'],
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: (cfg['color'] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  nama.toString().trim().isNotEmpty
                                      ? nama.toString().trim()[0].toUpperCase()
                                      : '?',
                                  style: TextStyle(
                                    color: cfg['color'],
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nama,
                                    style: const TextStyle(
                                      color: AppTokens.textPrimary,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.order['nomor_order'],
                                    style: const TextStyle(
                                      color: AppTokens.textSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: (cfg['color'] as Color).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                cfg['label'],
                                style: TextStyle(
                                  color: cfg['color'],
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Text(
                              _fmt((widget.order['total_harga'] ?? 0).toDouble()),
                              style: const TextStyle(
                                color: AppTokens.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: -0.5,
                              ),
                            ),
                            if (isPiutang) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.red.shade200),
                                ),
                                child: Text(
                                  'PIUTANG',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            if (nextSt != null)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  widget.onUpdate(widget.order, nextSt);
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cfg['color'],
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (cfg['color'] as Color)
                                            .withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    _nextLabel(status, isPiutang),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
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

  Map<String, dynamic> _cfg(String s, bool p) {
    if (s == 'diproses')
      return {'label': 'Diproses', 'color': AppTokens.statusDiproses};
    if (s == 'selesai')
      return {
        'label': p ? 'Belum Lunas' : 'Selesai',
        'color': p ? Colors.orange : AppTokens.statusSelesai,
      };
    if (s == 'dibayar_lunas')
      return {'label': 'Lunas', 'color': AppTokens.statusSelesai};
    return {'label': s, 'color': AppTokens.statusLunas};
  }

  String? _next(String s, bool p) {
    if (s == 'diproses') return 'selesai';
    if (s == 'selesai' && p) return 'dibayar_lunas';
    return null;
  }

  String _nextLabel(String s, bool p) {
    if (s == 'diproses') return 'Tandai Selesai';
    if (s == 'selesai' && p) return 'Lunasi Piutang';
    return '';
  }

  String _fmt(double a) {
    return AppTokens.formatRupiah(a);
  }
}

class _PayOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _PayOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // _PayOption sudah punya Expanded dari asalnya, jadi kita biarkan!
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          // Tambahkan sedikit horizontal padding agar teks punya ruang napas
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.blue : AppTokens.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Cegah error vertikal
            children: [
              Icon(
                icon,
                color: selected ? Colors.blue : AppTokens.textHint,
                size: 22,
              ),
              const SizedBox(height: 4),
              // KUNCI ANTI-MELEBER: Bungkus Teks dengan FittedBox
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.blue : AppTokens.textSecondary,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool highlight;
  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    this.highlight = false,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 20,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  final bool isPiutang;
  const _StatusPill({required this.status, required this.isPiutang});
  @override
  Widget build(BuildContext context) {
    final cfg = _cfg();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (cfg['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        cfg['label'],
        style: TextStyle(
          color: cfg['color'],
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Map<String, dynamic> _cfg() {
    if (status == 'diproses')
      return {'label': 'Diproses', 'color': AppTokens.statusDiproses};
    if (status == 'selesai')
      return {
        'label': isPiutang ? 'Belum Lunas' : 'Selesai',
        'color': isPiutang ? Colors.orange : AppTokens.statusSelesai,
      };
    if (status == 'dibayar_lunas')
      return {'label': 'Lunas', 'color': AppTokens.statusSelesai};
    return {'label': status, 'color': AppTokens.statusLunas};
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;
  const _EmptyState({required this.icon, required this.message, this.sub});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: AppTokens.sky,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: AppTokens.blue),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: AppTokens.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: const TextStyle(color: AppTokens.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class _PiutangBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> allPiutangOrders;
  final Function(Map<String, dynamic>) onNotaTapped;
  const _PiutangBottomSheet({
    required this.allPiutangOrders,
    required this.onNotaTapped,
  });
  @override
  State<_PiutangBottomSheet> createState() => _PiutangBottomSheetState();
}

class _PiutangBottomSheetState extends State<_PiutangBottomSheet> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.allPiutangOrders.where((order) {
      final nama = (order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum')
          .toString()
          .toLowerCase();
      return nama.contains(_searchQuery.toLowerCase());
    }).toList();

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var order in filtered) {
      final nama = order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';
      if (!grouped.containsKey(nama)) grouped[nama] = [];
      grouped[nama]!.add(order);
    }
    final totalUtangTertampil = filtered.fold(
      0,
      (sum, o) => sum + ((o['total_harga'] as num?)?.toInt() ?? 0),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppTokens.ground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 20),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Daftar Piutang',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTokens.textPrimary,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 14,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'ALL TIME',
                        style: TextStyle(
                          color: Colors.orange,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTokens.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: const InputDecoration(
                  hintText: 'Cari nama pelanggan...',
                  hintStyle: TextStyle(color: AppTokens.textHint, fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppTokens.textHint,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: AppTokens.border),
                bottom: BorderSide(color: AppTokens.border),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Hutang (Pencarian)',
                      style: TextStyle(
                        color: AppTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppTokens.formatRupiah(totalUtangTertampil.toDouble()),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${filtered.length} Nota',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: grouped.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada pelanggan berhutang',
                      style: TextStyle(color: AppTokens.textHint),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    itemCount: grouped.length,
                    itemBuilder: (ctx, i) {
                      final customerName = grouped.keys.elementAt(i);
                      final orders = grouped[customerName]!;
                      final totalUtangCustomer = orders.fold(
                        0,
                        (sum, o) =>
                            sum + ((o['total_harga'] as num?)?.toInt() ?? 0),
                      );
                      final isNamaValid =
                          customerName.trim().isNotEmpty &&
                          customerName != 'Umum';
                      final inisialNama = isNamaValid
                          ? customerName.trim()[0].toUpperCase()
                          : '?';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTokens.border),
                          boxShadow: AppTokens.softShadow,
                        ),
                        child: Theme(
                          data: Theme.of(
                            context,
                          ).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Center(
                                child: Text(
                                  inisialNama,
                                  style: TextStyle(
                                    color: Colors.orange.shade600,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              customerName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTokens.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${orders.length} Nota Belum Lunas • ${AppTokens.formatRupiah(totalUtangCustomer.toDouble())}',
                              style: TextStyle(
                                color: Colors.orange.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              16,
                            ),
                            children: orders.map((order) {
                              final total = (order['total_harga'] ?? 0)
                                  .toDouble();
                              return InkWell(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onNotaTapped(order);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  margin: const EdgeInsets.only(top: 8),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: AppTokens.ground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTokens.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              order['nomor_order'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: AppTokens.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              AppTokens.formatRupiah(total),
                                              style: TextStyle(
                                                color: Colors.orange.shade700,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          'UNPAID',
                                          style: TextStyle(
                                            color: Colors.red.shade600,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PesananTab extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final bool isSearching;
  final VoidCallback onLoadMore;
  final Future<void> Function({bool showFullLoading}) onRefresh;
  final Function(Map<String, dynamic>, String) onUpdate;
  final Function(Map<String, dynamic>) onDetail;
  final String dateText;
  final Future<void> Function() onPickDate;

  final String searchQuery;
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearchChanged;

  const _PesananTab({
    required this.orders,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasMore,
    required this.isSearching,
    required this.onLoadMore,
    required this.onRefresh,
    required this.onUpdate,
    required this.onDetail,
    required this.dateText,
    required this.onPickDate,
    required this.searchQuery,
    required this.searchCtrl,
    required this.onSearchChanged,
  });

  @override
  State<_PesananTab> createState() => _PesananTabState();
}

class _PesananTabState extends State<_PesananTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final List<String> _tabs = ['Aktif', 'Selesai'];

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(String tab) {
    return tab == 'Aktif'
        ? widget.orders.where((o) => o['status'] == 'diproses').toList()
        : widget.orders
              .where(
                (o) =>
                    o['status'] == 'selesai' || o['status'] == 'dibayar_lunas',
              )
              .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTokens.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(color: AppTokens.navy),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pesanan',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.orders.length} order',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: widget.onPickDate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.dateText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: widget.searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Cari nama atau no order...',
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 13,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: Colors.white.withOpacity(0.5),
                          size: 18,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                        // [KEMBALI KE GAMBAR 2]: Menggunakan Spinner Lingkaran
                        suffixIcon: widget.isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : widget.searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(
                                  Icons.clear,
                                  color: Colors.white.withOpacity(0.5),
                                ),
                                onPressed: () {
                                  widget.searchCtrl.clear();
                                  widget.onSearchChanged('');
                                },
                              )
                            : null,
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TabBar(
                    controller: _tc,
                    isScrollable: false,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white.withOpacity(0.5),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                    indicator: const UnderlineTabIndicator(
                      borderSide: BorderSide(color: Colors.white, width: 3),
                      insets: EdgeInsets.symmetric(horizontal: 4),
                    ),
                    tabs: _tabs.map<Widget>((String t) {
                      final c = t == 'Aktif'
                          ? widget.orders
                                .where((o) => o['status'] == 'diproses')
                                .length
                          : widget.orders
                                .where(
                                  (o) =>
                                      o['status'] == 'selesai' ||
                                      o['status'] == 'dibayar_lunas',
                                )
                                .length;
                      return Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t),
                            if (c > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$c',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: AppTokens.ground,
                child: NotificationListener<ScrollNotification>(
                  onNotification: (ScrollNotification scrollInfo) {
                    if (!widget.isLoadingMore &&
                        widget.hasMore &&
                        scrollInfo.metrics.pixels >=
                            scrollInfo.metrics.maxScrollExtent - 100) {
                      widget.onLoadMore();
                    }
                    return false;
                  },
                  child: TabBarView(
                    controller: _tc,
                    children: _tabs.map<Widget>((String tab) {
                      final list = _filtered(tab);
                      
                      // [UPDATE UX]: Tampilkan titik 3 di tengah layar, bukan skeleton kasar
                      if (widget.isLoading || widget.isSearching) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _ModernLoadingDots(color: AppTokens.blue, size: 14),
                              SizedBox(height: 16),
                              Text(
                                'Mencari data...',
                                style: TextStyle(
                                  color: AppTokens.textHint,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      if (list.isEmpty)
                        return widget.searchQuery.isNotEmpty
                            ? const _EmptyState(
                                icon: Icons.search_off_rounded,
                                message: 'Pesanan tidak ditemukan',
                              )
                            : const _EmptyState(
                                icon: Icons.inbox_outlined,
                                message: 'Tidak ada pesanan',
                              );
                      return RefreshIndicator(
                        onRefresh: () =>
                            widget.onRefresh(showFullLoading: false),
                        color: AppTokens.blue,
                        backgroundColor: AppTokens.surface,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          itemCount: list.length + (widget.hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == list.length) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                child: Center(
                                  child: widget.isLoadingMore
                                      ? const _ModernLoadingDots(
                                          color: AppTokens.blue,
                                          size: 10,
                                        )
                                      : const SizedBox(),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PremiumOrderCard(
                                order: list[i],
                                onUpdate: widget.onUpdate,
                                onTap: () => widget.onDetail(list[i]),
                              ),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonOrderCard extends StatefulWidget {
  const _SkeletonOrderCard();
  @override
  State<_SkeletonOrderCard> createState() => _SkeletonOrderCardState();
}

class _SkeletonOrderCardState extends State<_SkeletonOrderCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_anim),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTokens.border),
          boxShadow: AppTokens.softShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 4,
                decoration: const BoxDecoration(
                  color: AppTokens.ground,
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppTokens.ground,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 14,
                                  width: double.infinity,
                                  color: AppTokens.ground,
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  height: 10,
                                  width: 100,
                                  color: AppTokens.ground,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(height: 18, width: 120, color: AppTokens.ground),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernLoadingDots extends StatefulWidget {
  final Color color;
  final double size;
  const _ModernLoadingDots({
    required this.color,
    required this.size,
  });

  @override
  State<_ModernLoadingDots> createState() => _ModernLoadingDotsState();
}

class _ModernLoadingDotsState extends State<_ModernLoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final delay = index * 0.2;
            var val = (_controller.value - delay) % 1.0;
            if (val < 0) val += 1.0;

            final offset = math.sin(val * math.pi * 2) * (widget.size / 2.5);
            final opacity = (math.cos(val * math.pi * 2) + 1) / 2 * 0.5 + 0.5;

            return Transform.translate(
              offset: Offset(0, offset < 0 ? offset : 0),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.color,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }
}