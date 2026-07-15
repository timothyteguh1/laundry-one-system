import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/cashier/screens/point_settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/cashier/screens/create_order_screen.dart';
import 'package:laundry_one/features/cashier/screens/inventory_screen.dart';
import 'package:laundry_one/features/cashier/screens/tabs/report_tab.dart';
import 'package:laundry_one/features/cashier/screens/tabs/pelanggan_tab.dart';
import 'package:laundry_one/features/cashier/screens/invoice_screen.dart';

// ============================================================
// DESIGN SYSTEM — Laundry One POS
// ============================================================

class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const sky = Color(0xFFE8F0FE);
  static const surface = Colors.white;

  static const ground = Color(0xFFEAF0F6);
  static const border = Color(0xFFD2DCE8);

  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
  static const textHint = Color(0xFFB0BAD1);

  static const statusDiproses = Color(0xFFE65100);
  static const statusSelesai = Color(0xFF00897B);
  static const statusLunas = Color(0xFF757575);

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.09),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> fabShadow = [
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.25),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

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

  String? _kasirNama;

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
    _loadUserProfile();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _fabAnim?.dispose();
    super.dispose();
  }

  // =========================================================
  // CUSTOM DIALOG (Sesuai Referensi Gambar Anda)
  // =========================================================
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
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
                  color: _DS.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: _DS.textSecondary,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _DS.blue,
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

  Widget _buildDrawer() {
    final role = _userProfile?['role'] ?? 'cashier';
    final isAdmin = role == 'super_admin';
    final nama = _userProfile?['nama_lengkap'] ?? _kasirNama ?? 'Memuat...';

    return Drawer(
      backgroundColor: _DS.surface,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: _DS.navy),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, color: _DS.navy, size: 40),
            ),
            accountName: Text(
              nama,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            accountEmail: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isAdmin ? Colors.orange : _DS.blue,
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
                      color: _DS.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.home_outlined,
                    color: _DS.textPrimary,
                  ),
                  title: const Text(
                    'Beranda',
                    style: TextStyle(
                      color: _DS.textPrimary,
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
                    color: _DS.textPrimary,
                  ),
                  title: const Text(
                    'Riwayat Transaksi',
                    style: TextStyle(
                      color: _DS.textPrimary,
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
                      color: _DS.textSecondary,
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
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await _authService.logout();
                    if (mounted)
                      Navigator.pushReplacement(
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
                            ),
                          ),
                        ),
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
            primary: _DS.blue,
            onPrimary: Colors.white,
            surface: _DS.surface,
            onSurface: _DS.textPrimary,
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
      await _loadData();
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
                        final res = await _supabase
                            .from('reward_redemptions')
                            .select('*, rewards_catalog(nama)')
                            .eq('kode_voucher', kode)
                            .eq('status', 'aktif')
                            .maybeSingle();
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
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();

    // [FIX TIMEZONE] Bangun batas waktu sebagai WIB (local time) lalu convert ke UTC
      // agar filter Supabase presisi sesuai jam lokal, bukan digeser 7 jam.
      final startOfRangeLocal = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final endOfRangeLocal = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);
      final startOfTodayLocal = DateTime(now.year, now.month, now.day, 0, 0, 0);
      final endOfTodayLocal = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final startStr = startOfRangeLocal.toUtc().toIso8601String();
      final endStr = endOfRangeLocal.toUtc().toIso8601String();
      final todayStart = startOfTodayLocal.toUtc().toIso8601String();
      final todayEnd = endOfTodayLocal.toUtc().toIso8601String();

      final queryStr =
          'id, nomor_order, status, total_harga, is_piutang, metode_bayar_awal, created_at, estimasi_selesai, jatuh_tempo, customer_id, poin_didapat, poin_sudah_diberikan, customers(profiles(nama_lengkap, nomor_hp)), profiles!orders_cashier_id_fkey(nama_lengkap), order_items(jumlah, harga_satuan, services(nama))';

      final results = await Future.wait([
        _supabase.from('orders').select(queryStr).gte('created_at', startStr).lte('created_at', endStr).order('created_at', ascending: false),
        _supabase.from('orders').select(queryStr).gte('created_at', todayStart).lte('created_at', todayEnd).order('created_at', ascending: false),
        _supabase.from('orders').select(queryStr).eq('is_piutang', true).neq('status', 'dibatalkan').order('created_at', ascending: false),
        _supabase.from('order_payments').select('jumlah, metode').gte('created_at', todayStart).lte('created_at', todayEnd),
      ]);

      final tabOrdersData = List<Map<String, dynamic>>.from(results[0]);
      final todayOrdersData = List<Map<String, dynamic>>.from(results[1]);
      final allPiutangData = List<Map<String, dynamic>>.from(results[2]);
      final todayPaymentsData = List<Map<String, dynamic>>.from(results[3]);

      // 🔍 DEBUG: cek bentuk field 'profiles' (kasir) hasil join dari Supabase.
      // Buka Chrome DevTools (F12) -> tab Console untuk melihat output ini.
      if (todayOrdersData.isNotEmpty) {
        debugPrint('=== DEBUG _loadData: ORDER[0] RAW ===');
        debugPrint('order_id           : ${todayOrdersData[0]['id']}');
        debugPrint('nomor_order        : ${todayOrdersData[0]['nomor_order']}');
        debugPrint('cashier_id (FK)    : ${todayOrdersData[0]['cashier_id']}');
        debugPrint('profiles (raw)     : ${todayOrdersData[0]['profiles']}');
        debugPrint('profiles.runtimeType: ${todayOrdersData[0]['profiles'].runtimeType}');
        debugPrint('======================================');
      } else {
        debugPrint('=== DEBUG _loadData: todayOrdersData KOSONG ===');
      }

      // [UPDATE LOGIKA 2]: Pemisahan Omset (pesanan) vs Kas Masuk (pembayaran)
      double kasTunaiHariIni = 0;
      double kasNonTunaiHariIni = 0;
      for (final p in todayPaymentsData) {
        final amt = (p['jumlah'] ?? 0).toDouble();
        if (p['metode'] == 'cash') kasTunaiHariIni += amt;
        else kasNonTunaiHariIni += amt;
      }

      double omsetHariIni = 0;
      for (final o in todayOrdersData) {
        if (o['status'] != 'dibatalkan') {
          omsetHariIni += (o['total_harga'] ?? 0).toDouble();
        }
      }

      if (mounted) {
        setState(() {
          _tabOrders = tabOrdersData;
          _todayOrders = todayOrdersData;
          _allPiutangOrders = allPiutangData;
          _totalPenjualanHariIni = omsetHariIni; 
          _totalCashHariIni = kasTunaiHariIni;
          _totalNonCashHariIni = kasNonTunaiHariIni;
           // [FIX] Isi statistik header (sebelumnya selalu 0 karena tidak pernah di-assign)
          _todayTotalOrder = todayOrdersData
              .where((o) => o['status'] != 'dibatalkan')
              .length;
          _todayAktif = todayOrdersData
              .where((o) => o['status'] == 'diproses')
              .length;
          _todaySelesai = todayOrdersData
              .where((o) =>
                  o['status'] == 'selesai' || o['status'] == 'dibayar_lunas')
              .length;

          _totalPiutangAllTime = allPiutangData.fold(
            0.0,
            (sum, o) => sum + (o['total_harga'] ?? 0).toDouble(),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  void _subscribeRealtime() {
    _supabase
        .channel('orders_rt')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (_) => _loadData(),
        )
        .subscribe();
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
      await _loadData();
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
                  color: _DS.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Order: ${order['nomor_order']} • $namaPelanggan',
                style: const TextStyle(color: _DS.textSecondary, fontSize: 13),
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
                      _formatRupiah(total),
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
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          HapticFeedback.heavyImpact();
                          setModalState(() => isSubmitting = true);
                          try {
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
                              _loadData();
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
                  child: isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Konfirmasi Pelunasan',
                          style: TextStyle(
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.navy,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Container(
                  color: _DS.ground,
                  child: IndexedStack(
                    index: _currentTab,
                    children: [
                      _buildTabBeranda(),
                      _PesananTab(
                        orders: _tabOrders,
                        isLoading: _isLoading,
                        onRefresh: _loadData,
                        onUpdate: _handleUpdateStatus,
                        onDetail: _showDetail,
                        dateText: _dateRangeText,
                        onPickDate: _pickDate,
                      ),
                      const PelangganTab(),
                      _buildTabLaporan(),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // [UPDATE UX] Loading Overlay Sederhana Tanpa Kotak Putih
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
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
                  boxShadow: _DS.fabShadow,
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
                    if (r == true) _loadData();
                  },
                  backgroundColor: _DS.blue,
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
      color: _DS.navy,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _loadData,
          color: _DS.blue,
          backgroundColor: _DS.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(color: _DS.ground),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _DS.sky,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _DS.blue.withOpacity(0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: _DS.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Menampilkan ringkasan transaksi khusus Hari Ini (${_formatDateStr(DateTime.now())}).',
                                style: TextStyle(
                                  color: _DS.blue,
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
                            Expanded(child: _buildPenjualanCard()),
                            const SizedBox(width: 12),
                            Expanded(child: _buildPiutangCard()),
                          ],
                        ),
                      ),

                      if (siap.isNotEmpty) ...[
                        _buildSectionHeader(
                          '✅  Pesanan Selesai',
                          count: siap.length,
                          countColor: _DS.statusSelesai,
                          topPad: 24,
                        ),
                        ...siap
                            .map(
                              (o) => Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
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
                        countColor: _DS.statusDiproses,
                        topPad: siap.isNotEmpty ? 8 : 24,
                        action: _todayAktif > 5
                            ? () => setState(() => _currentTab = 1)
                            : null,
                        actionLabel: 'Lihat Semua',
                      ),

                      if (_isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: CircularProgressIndicator(color: _DS.blue),
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  10,
                                ),
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
                            Text(
                              _greeting(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 13,
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
                        ),
                      ],
                    ),
                  ),
                  if (_userProfile?['role'] == 'super_admin') ...[
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
                      onTap: () async {
                        HapticFeedback.mediumImpact();
                        await AuthService().logout();
                        if (mounted)
                          Navigator.pushReplacement(
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
                                  tagline:
                                      'Kelola pesanan dengan cepat & mudah',
                                  homeScreen: HomeCashierScreen(),
                                  showRegister: true,
                                ),
                              ),
                            ),
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
                    color: _DS.statusSelesai,
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

  Widget _buildPenjualanCard() {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: _DS.cardShadow,
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showPenjualanDetail();
          },
          borderRadius: BorderRadius.circular(20),
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
                  _formatRupiah(_totalPenjualanHariIni),
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

  Widget _buildPiutangCard() {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _DS.border, width: 1.5),
          boxShadow: _DS.cardShadow,
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            _showPiutangList();
          },
          borderRadius: BorderRadius.circular(20),
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
                    color: _DS.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRupiah(_totalPiutangAllTime),
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
          color: _DS.ground,
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
                        color: _DS.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _DS.sky,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.today_rounded, color: _DS.blue, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'HARI INI',
                            style: TextStyle(
                              color: _DS.blue,
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
                    color: _DS.navy,
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
                            _formatRupiah(totalPembayaranDiterima),
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
  String _extractCashierName(Map<String, dynamic> order) {
    try {
      final kasirData = order['kasir'];
      
      if (kasirData == null) return 'Sistem';

      // Jika Supabase mengembalikannya sebagai Map { 'nama_lengkap': 'toti1' }
      if (kasirData is Map<String, dynamic>) {
        return kasirData['nama_lengkap']?.toString() ?? 'Sistem';
      }
      
      // Jika Supabase mengembalikannya sebagai List [ { 'nama_lengkap': 'toti1' } ]
      if (kasirData is List && kasirData.isNotEmpty) {
        final firstItem = kasirData.first;
        if (firstItem is Map<String, dynamic>) {
          return firstItem['nama_lengkap']?.toString() ?? 'Sistem';
        }
      }
      
      return 'Sistem';
    } catch (e) {
      debugPrint('Error ekstrak nama kasir: $e');
      return 'Sistem';
    }
  }

  Future<void> _showDetail(Map<String, dynamic> order) async {
    HapticFeedback.lightImpact();
    
    final List<Map<String, dynamic>> mappedItems =
        (order['order_items'] as List? ?? [])
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

    // ==========================================
    // LOGIKA DETEKTIF: AMBIL NAMA KASIR AKURAT
    // ==========================================
    String namaKasirFinal = 'Sistem';
    final dataKasir = order['profiles'];

    // 🔍 DEBUG: cek bentuk field 'profiles' (kasir) tepat sebelum diparse.
    // Buka Chrome DevTools (F12) -> tab Console untuk melihat output ini.
    debugPrint('--- DEBUG _showDetail: cek data kasir ---');
    debugPrint('order[id]           : ${order['id']}');
    debugPrint('order[nomor_order]  : ${order['nomor_order']}');
    debugPrint('order[cashier_id]   : ${order['cashier_id']}');
    debugPrint('order[profiles] raw : $dataKasir');
    debugPrint('order[profiles] type: ${dataKasir.runtimeType}');
    debugPrint('------------------------------------------');
    
    if (dataKasir != null) {
      // Jika Supabase mengirimkannya sebagai List (Array)
      if (dataKasir is List && dataKasir.isNotEmpty) {
        namaKasirFinal = dataKasir[0]['nama_lengkap']?.toString() ?? 'Sistem';
      } 
      // Jika Supabase mengirimkannya sebagai Objek (Map)
      else if (dataKasir is Map) {
        namaKasirFinal = dataKasir['nama_lengkap']?.toString() ?? 'Sistem';
      }
    }

    // 🔍 DEBUG: hasil akhir nama kasir yang akan ditampilkan di nota
    debugPrint('DEBUG _showDetail: namaKasirFinal = $namaKasirFinal');
    // ==========================================

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
          
          // Masukkan variabel yang sudah diekstrak dengan aman
          namaKasir: namaKasirFinal,
          
          items: mappedItems,
          subtotal: (order['total_harga'] ?? 0).toDouble(),
          diskon: 0,
          total: (order['total_harga'] ?? 0).toDouble(),
          metodeBayar: order['metode_bayar_awal'] ?? 'cash',
          isPiutang: order['is_piutang'] == true,
          created_at: order['created_at'],
        ),
      ),
    );
    
    if (action == 'selesai')
      _handleUpdateStatus(order, 'selesai');
    else if (action == 'dibayar_lunas')
      _handleUpdateStatus(order, 'dibayar_lunas');
    else if (action == 'dihapus')
      _loadData();
  }

  Widget _buildSectionHeader(
    String title, {
    int count = 0,
    Color countColor = _DS.blue,
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
              color: _DS.textPrimary,
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
                  color: _DS.blue,
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
          border: Border.all(color: _DS.border),
          boxShadow: _DS.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                color: _DS.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatRupiah(amount),
              style: const TextStyle(
                color: _DS.textPrimary,
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
                    'Pesanan',
                    badge: _todayAktif > 0 ? '$_todayAktif' : null,
                  ),
                  // const Expanded(flex: 2, child: SizedBox()),
                  _buildNavItem(
                    2,
                    Icons.people_alt_rounded,
                    Icons.people_alt_outlined,
                    'Pelanggan',
                  ),
                  _buildNavItem(
                    3,
                    Icons.bar_chart_rounded,
                    Icons.bar_chart_outlined,
                    'Kelola',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int idx,
    IconData activeIcon,
    IconData inactiveIcon,
    String label, {
    String? badge,
  }) {
    final active = _currentTab == idx;
    return Expanded(
      flex: 2,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _currentTab = idx);
        },
        behavior: HitTestBehavior.opaque,
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
                    color: active ? _DS.sky : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    active ? activeIcon : inactiveIcon,
                    color: active ? _DS.blue : _DS.textHint,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    color: active ? _DS.blue : _DS.textHint,
                  ),
                ),
              ],
            ),
            if (badge != null)
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
                    badge,
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

  String _formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }
}

// ============================================================
// WIDGET HELPER UI
// ============================================================

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
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? Colors.blue.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Colors.blue : _DS.border),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: selected ? Colors.blue : _DS.textHint,
                size: 22,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.blue : _DS.textSecondary,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
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
      return {'label': 'Diproses', 'color': _DS.statusDiproses};
    if (status == 'selesai')
      return {
        'label': isPiutang ? 'Belum Lunas' : 'Selesai',
        'color': isPiutang ? Colors.orange : _DS.statusSelesai,
      };
    if (status == 'dibayar_lunas')
      return {'label': 'Lunas', 'color': _DS.statusSelesai};
    return {'label': status, 'color': _DS.statusLunas};
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
              color: _DS.sky,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 36, color: _DS.blue),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              color: _DS.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: const TextStyle(color: _DS.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// KOMPONEN: PIUTANG BOTTOM SHEET
// ============================================================

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

  String _formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
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
        color: _DS.ground,
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
                    color: _DS.textPrimary,
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
                border: Border.all(color: _DS.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari nama pelanggan...',
                  hintStyle: const TextStyle(color: _DS.textHint, fontSize: 14),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _DS.textHint,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
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
                top: BorderSide(color: _DS.border),
                bottom: BorderSide(color: _DS.border),
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
                        color: _DS.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatRupiah(totalUtangTertampil.toDouble()),
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
                      style: TextStyle(color: _DS.textHint),
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
                          border: Border.all(color: _DS.border),
                          boxShadow: _DS.softShadow,
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
                                color: _DS.textPrimary,
                              ),
                            ),
                            subtitle: Text(
                              '${orders.length} Nota Belum Lunas • ${_formatRupiah(totalUtangCustomer.toDouble())}',
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
                                    color: _DS.ground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _DS.border),
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
                                                color: _DS.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _formatRupiah(total),
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

// ============================================================
// TAB: PESANAN
// ============================================================

class _PesananTab extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(Map<String, dynamic>, String) onUpdate;
  final Function(Map<String, dynamic>) onDetail;
  final String dateText;
  final Future<void> Function() onPickDate;

  const _PesananTab({
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onUpdate,
    required this.onDetail,
    required this.dateText,
    required this.onPickDate,
  });

  @override
  State<_PesananTab> createState() => _PesananTabState();
}

class _PesananTabState extends State<_PesananTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final List<String> _tabs = ['Aktif', 'Selesai'];

  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tc.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filtered(String tab) {
    List<Map<String, dynamic>> listData = tab == 'Aktif'
        ? widget.orders.where((o) => o['status'] == 'diproses').toList()
        : widget.orders
              .where(
                (o) =>
                    o['status'] == 'selesai' || o['status'] == 'dibayar_lunas',
              )
              .toList();
    if (_searchQuery.trim().isNotEmpty) {
      listData = listData.where((order) {
        final nama =
            (order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum')
                .toString()
                .toLowerCase();
        final noOrder = (order['nomor_order'] ?? '').toString().toLowerCase();
        return nama.contains(_searchQuery.toLowerCase()) ||
            noOrder.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    return listData;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _DS.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(color: _DS.navy),
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
                      controller: _searchCtrl,
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
                      ),
                      onChanged: (val) => setState(() => _searchQuery = val),
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
                color: _DS.ground,
                child: TabBarView(
                  controller: _tc,
                  children: _tabs.map<Widget>((String tab) {
                    final list = _filtered(tab);
                    if (widget.isLoading)
                      return const Center(
                        child: CircularProgressIndicator(color: _DS.blue),
                      );
                    if (list.isEmpty)
                      return _searchQuery.isNotEmpty
                          ? const _EmptyState(
                              icon: Icons.search_off_rounded,
                              message: 'Pesanan tidak ditemukan',
                            )
                          : const _EmptyState(
                              icon: Icons.inbox_outlined,
                              message: 'Tidak ada pesanan',
                            );
                    return RefreshIndicator(
                      onRefresh: widget.onRefresh,
                      color: _DS.blue,
                      backgroundColor: _DS.surface,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: list.length,
                        itemBuilder: (_, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PremiumOrderCard(
                            order: list[i],
                            onUpdate: widget.onUpdate,
                            onTap: () => widget.onDetail(list[i]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(Map<String, dynamic>, String) onUpdate;
  final VoidCallback onTap;

  const _PremiumOrderCard({
    required this.order,
    required this.onUpdate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'diproses';
    final nama = order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';
    final isPiutang = order['is_piutang'] == true;
    final cfg = _cfg(status, isPiutang);
    final nextSt = _next(status, isPiutang);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _DS.border),
          boxShadow: _DS.softShadow,
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
                                    color: _DS.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  order['nomor_order'],
                                  style: const TextStyle(
                                    color: _DS.textSecondary,
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
                            _fmt((order['total_harga'] ?? 0).toDouble()),
                            style: const TextStyle(
                              color: _DS.textPrimary,
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
                                onUpdate(order, nextSt);
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
    );
  }

  Map<String, dynamic> _cfg(String s, bool p) {
    if (s == 'diproses')
      return {'label': 'Diproses', 'color': _DS.statusDiproses};
    if (s == 'selesai')
      return {
        'label': p ? 'Belum Lunas' : 'Selesai',
        'color': p ? Colors.orange : _DS.statusSelesai,
      };
    if (s == 'dibayar_lunas')
      return {'label': 'Lunas', 'color': _DS.statusSelesai};
    return {'label': s, 'color': _DS.statusLunas};
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
    final str = a.toStringAsFixed(0);
    final b = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) b.write('.');
      b.write(str[i]);
    }
    return 'Rp ${b.toString()}';
  }
}