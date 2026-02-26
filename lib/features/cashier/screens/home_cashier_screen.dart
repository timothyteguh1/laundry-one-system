import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/cashier/screens/create_order_screen.dart';

// ============================================================
// DESIGN SYSTEM — Laundry One POS
// Tone: Refined Professional — clean depth, clear hierarchy
// Palette:
//   Navy    #0F2557  (header, primary text)
//   Blue    #1565C0  (primary action, active)
//   Sky     #E8F0FE  (chip background)
//   Surface #FFFFFF  (cards)
//   Ground  #F4F7FB  (background)
//   Border  #E8EDF5
// ============================================================

class _DS {
  // Colors
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const blueLight = Color(0xFF1976D2);
  static const sky = Color(0xFFE8F0FE);
  static const surface = Colors.white;
  static const ground = Color(0xFFF4F7FB);
  static const border = Color(0xFFE8EDF5);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
  static const textHint = Color(0xFFB0BAD1);

  // Status
  static const statusDiterima = Color(0xFF1565C0);
  static const statusDiproses = Color(0xFFE65100);
  static const statusSelesai = Color(0xFF00897B);
  static const statusSiap = Color(0xFF2E7D32);
  static const statusLunas = Color(0xFF757575);
  static const statusPiutang = Color(0xFFC62828);

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 20,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.04),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> fabShadow = [
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.35),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.2),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

// ============================================================
// HOME CASHIER SCREEN
// ============================================================
class HomeCashierScreen extends StatefulWidget {
  const HomeCashierScreen({super.key});

  @override
  State<HomeCashierScreen> createState() => _HomeCashierScreenState();
}

class _HomeCashierScreenState extends State<HomeCashierScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  int _currentTab = 0;
  AnimationController? _fabAnim; // Diubah jadi nullable agar aman saat Hot Reload

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _kasirNama;

  int _totalOrder = 0;
  int _totalAktif = 0;
  int _totalSiap = 0;
  
  // Data Keuangan
  double _totalPenjualan = 0;
  double _totalCash = 0;
  double _totalNonCash = 0;
  double _totalPiutang = 0;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
    _loadData();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _fabAnim?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _supabase
          .from('profiles')
          .select('nama_lengkap')
          .eq('id', _supabase.auth.currentUser!.id)
          .single();
      _kasirNama = profile['nama_lengkap'];

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Tambahan kolom metode_bayar_awal untuk filter cash / non-cash
      final orders = await _supabase
          .from('orders')
          .select('''
            id, nomor_order, status, total_harga, is_piutang, metode_bayar_awal, created_at,
            customers(profiles(nama_lengkap, nomor_hp)),
            order_items(jumlah, harga_satuan, services(nama))
          ''')
          .gte('created_at', '${todayStr}T00:00:00')
          .order('created_at', ascending: false);

      int aktif = 0, siap = 0;
      double penjualan = 0, cash = 0, nonCash = 0, piutang = 0;
      
      for (final o in orders) {
        final s = o['status'];
        final total = (o['total_harga'] ?? 0).toDouble();
        final isPiutang = o['is_piutang'] == true || s == 'diambil_belum_lunas';
        final metode = o['metode_bayar_awal'] ?? 'cash';

        if (['diterima', 'diproses', 'selesai'].contains(s)) aktif++;
        if (s == 'siap_diambil') siap++;

        // Hitung Pendapatan (Abaikan order yang draft/dibatalkan)
        if (s != 'dibatalkan' && s != 'draft') {
          penjualan += total;
          if (isPiutang) {
            piutang += total;
          } else {
            if (metode == 'cash') {
              cash += total;
            } else {
              nonCash += total;
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _orders = List<Map<String, dynamic>>.from(orders);
          _totalOrder = orders.length;
          _totalAktif = aktif;
          _totalSiap = siap;
          
          _totalPenjualan = penjualan;
          _totalCash = cash;
          _totalNonCash = nonCash;
          _totalPiutang = piutang;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      debugPrint('loadData error: $e');
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

  Future<void> _updateStatus(String orderId, String newStatus) async {
    HapticFeedback.mediumImpact();
    try {
      final updateData = {'status': newStatus};
      // Jika pesanan dilunasi, set piutang jadi false
      if (newStatus == 'dibayar_lunas') {
        updateData['is_piutang'] = 'false';
      }
      
      await _supabase.from('orders').update(updateData).eq('id', orderId);
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal update: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await AuthService().logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(
            config: LoginConfig(
              roleName: 'Staf Kasir',
              roleDatabase: 'cashier',
              labelIdentifier: 'Nomor HP',
              hint: '081234567890',
              keyboardType: TextInputType.phone,
              primaryColor: const Color(0xFF1565C0),
              secondaryColor: const Color(0xFF0D47A1),
              backgroundColor: Colors.white,
              icon: Icons.point_of_sale_rounded,
              tagline: 'Kelola pesanan dengan cepat & mudah',
              homeScreen: const HomeCashierScreen(),
              showRegister: true,
            ),
          ),
        ),
        (route) => false,
      );
    }
  }

  void _goCreateOrder() async {
    HapticFeedback.mediumImpact();
    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => const CreateOrderScreen(),
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      ),
    );
    if (result == true) _loadData();
  }

  void _showDetail(Map<String, dynamic> order) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        onUpdateStatus: (s) {
          _updateStatus(order['id'], s);
          Navigator.pop(context);
        },
      ),
    );
  }

  // Menampilkan Rincian Penjualan & Piutang
  void _showPenjualanDetail() {
    final listPiutang = _orders.where((o) => o['is_piutang'] == true || o['status'] == 'diambil_belum_lunas').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
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
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text('Rincian Penjualan Hari Ini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textPrimary)),
            ),
            const SizedBox(height: 20),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  _buildMiniStatCard('Tunai (Cash)', _totalCash, Icons.payments_rounded, Colors.green),
                  const SizedBox(width: 12),
                  _buildMiniStatCard('Non-Tunai', _totalNonCash, Icons.qr_code_scanner_rounded, Colors.blue),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Piutang', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
                      Text(_formatRupiah(_totalPiutang), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w800, fontSize: 18)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text('${listPiutang.length} Transaksi', style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w700, fontSize: 12)),
                  )
                ],
              ),
            ),

            Expanded(
              child: listPiutang.isEmpty
                ? Center(child: Text('Tidak ada piutang hari ini', style: TextStyle(color: Colors.grey.shade500)))
                : ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: listPiutang.length,
                    itemBuilder: (ctx, i) {
                      final order = listPiutang[i];
                      final nama = order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';
                      final total = (order['total_harga'] ?? 0).toDouble();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _DS.softShadow),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nama, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(order['nomor_order'], style: const TextStyle(color: _DS.textSecondary, fontSize: 11)),
                                  const SizedBox(height: 8),
                                  Text(_formatRupiah(total), style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w800, fontSize: 14)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green, foregroundColor: Colors.white,
                                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _updateStatus(order['id'], 'dibayar_lunas');
                              },
                              child: const Text('Lunasi', style: TextStyle(fontWeight: FontWeight.w700)),
                            )
                          ],
                        ),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStatCard(String title, double amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: _DS.softShadow),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(_formatRupiah(amount), style: TextStyle(color: _DS.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildTabBeranda(),
          _buildTabPesanan(),
          _buildTabPelanggan(),
          _buildTabLaporan(),
        ],
      ),
      floatingActionButton: _fabAnim == null ? const SizedBox() : ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim!, curve: Curves.elasticOut),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20), // Membuat tombol lebih naik
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: _DS.fabShadow,
          ),
          child: FloatingActionButton.extended(
            onPressed: _goCreateOrder,
            backgroundColor: _DS.blue,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text(
              'Buat Pesanan',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.2),
            ),
          ),
        ),
      ),
      // Mengubah posisi FAB agar floating overlap
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ============================================================
  // BOTTOM NAV
  // ============================================================
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: _DS.navy.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 10,
        color: Colors.transparent,
        elevation: 0,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _buildNavItem(0, Icons.home_rounded, Icons.home_outlined, 'Beranda'),
              _buildNavItem(1, Icons.receipt_long_rounded,
                  Icons.receipt_long_outlined, 'Pesanan',
                  badge: _totalAktif > 0 ? '$_totalAktif' : null),
              const Expanded(flex: 2, child: SizedBox()), // Ruang untuk FAB
              _buildNavItem(2, Icons.people_alt_rounded,
                  Icons.people_alt_outlined, 'Pelanggan'),
              _buildNavItem(
                  3, Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Laporan'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int idx, IconData activeIcon, IconData inactiveIcon,
      String label, {String? badge}) {
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                    fontWeight:
                        active ? FontWeight.w700 : FontWeight.w400,
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
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.red.shade600,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(badge,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TAB BERANDA
  // ============================================================
  Widget _buildTabBeranda() {
    final siap = _orders.where((o) => o['status'] == 'siap_diambil').toList();
    final aktif = _orders
        .where((o) => ['diterima', 'diproses'].contains(o['status']))
        .take(5)
        .toList();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: _DS.blue,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ===== HEADER =====
            SliverToBoxAdapter(child: _buildHeader()),

            // ===== PENJUALAN CARD =====
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: GestureDetector(
                  onTap: _showPenjualanDetail,
                  child: _buildPenjualanCard(),
                ),
              ),
            ),

            // ===== SIAP DIAMBIL =====
            if (siap.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: _buildSectionHeader(
                  '⚡  Siap Diambil',
                  count: siap.length,
                  countColor: _DS.statusSiap,
                  topPad: 20,
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _PremiumOrderCard(
                      order: siap[i],
                      onUpdate: _updateStatus,
                      onTap: () => _showDetail(siap[i]),
                    ),
                  ),
                  childCount: siap.length,
                ),
              ),
            ],

            // ===== AKTIF =====
            SliverToBoxAdapter(
              child: _buildSectionHeader(
                'Sedang Diproses',
                count: _totalAktif,
                countColor: _DS.statusDiproses,
                topPad: siap.isNotEmpty ? 8 : 20,
                action: _totalAktif > 5
                    ? () => setState(() => _currentTab = 1)
                    : null,
                actionLabel: 'Lihat Semua',
              ),
            ),

            if (_isLoading)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: _DS.blue),
                  ),
                ),
              )
            else if (aktif.isEmpty)
              const SliverToBoxAdapter(
                child: _EmptyState(
                  icon: Icons.check_circle_outline_rounded,
                  message: 'Semua pesanan sudah diproses',
                  sub: 'Tap + untuk buat pesanan baru',
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: _PremiumOrderCard(
                      order: aktif[i],
                      onUpdate: _updateStatus,
                      onTap: () => _showDetail(aktif[i]),
                    ),
                  ),
                  childCount: aktif.length,
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
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
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Positioned(
            bottom: 10,
            right: 60,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
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
                                Text(_greetingEmoji(),
                                    style: const TextStyle(fontSize: 13)),
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
                      Material(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: _logout,
                          borderRadius: BorderRadius.circular(12),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.logout_rounded,
                                color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _StatChip(
                        value: '$_totalOrder',
                        label: 'Order',
                        icon: Icons.receipt_rounded,
                        color: Colors.blue.shade200,
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        value: '$_totalAktif',
                        label: 'Aktif',
                        icon: Icons.autorenew_rounded,
                        color: Colors.orange.shade200,
                      ),
                      const SizedBox(width: 10),
                      _StatChip(
                        value: '$_totalSiap',
                        label: 'Siap',
                        icon: Icons.check_circle_outline_rounded,
                        color: _totalSiap > 0
                            ? Colors.green.shade300
                            : Colors.white24,
                        highlight: _totalSiap > 0,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPenjualanCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: _DS.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.payments_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Penjualan Hari Ini',
                    style: TextStyle(
                        color: _DS.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  _formatRupiah(_totalPenjualan),
                  style: const TextStyle(
                    color: _DS.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 24,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: _DS.textHint),
        ],
      ),
    );
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
                  fontWeight: FontWeight.w700,
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

  // ============================================================
  // TAB PESANAN
  // ============================================================
  Widget _buildTabPesanan() {
    return _PesananTab(
      orders: _orders,
      isLoading: _isLoading,
      onRefresh: _loadData,
      onUpdate: _updateStatus,
      onDetail: _showDetail,
    );
  }

  // ============================================================
  // TAB PELANGGAN
  // ============================================================
  Widget _buildTabPelanggan() {
    return const _PelangganTab();
  }

  // ============================================================
  // TAB LAPORAN
  // ============================================================
  Widget _buildTabLaporan() {
    return SafeArea(
      child: Column(
        children: [
          const _PremiumHeader(title: 'Laporan', subtitle: 'Rekap penjualan & omset'),
          Expanded(
            child: const Center(
              child: _EmptyState(
                icon: Icons.bar_chart_rounded,
                message: 'Laporan akan hadir segera',
                sub: 'Filter tanggal & rekap omset — Sprint 2',
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi,';
    if (h < 15) return 'Selamat siang,';
    if (h < 18) return 'Selamat sore,';
    return 'Selamat malam,';
  }

  String _greetingEmoji() {
    final h = DateTime.now().hour;
    if (h < 11) return '☀️';
    if (h < 15) return '🌤️';
    if (h < 18) return '🌅';
    return '🌙';
  }

  String _formatRupiah(double amount) {
    if (amount >= 1000000) {
      return 'Rp ${(amount / 1000000).toStringAsFixed(1)}jt';
    }
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
// TAB PESANAN WIDGET (Disederhanakan 2 Tab: Aktif & Selesai)
// ============================================================
class _PesananTab extends StatefulWidget {
  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Function(String, String) onUpdate;
  final Function(Map<String, dynamic>) onDetail;

  const _PesananTab({
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onUpdate,
    required this.onDetail,
  });

  @override
  State<_PesananTab> createState() => _PesananTabState();
}

class _PesananTabState extends State<_PesananTab>
    with SingleTickerProviderStateMixin {
  late TabController _tc;
  final _tabs = ['Aktif', 'Selesai'];
  final _filter = {
    'Aktif': ['draft', 'diterima', 'diproses', 'siap_diambil'],
    'Selesai': ['dibayar_lunas', 'diambil_belum_lunas'],
  };

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
    final f = _filter[tab];
    if (f == null) return widget.orders;
    return widget.orders.where((o) => f.contains(o['status'])).toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2557), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pesanan',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('${widget.orders.length} order hari ini',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.65),
                        fontSize: 12)),
                const SizedBox(height: 12),
                TabBar(
                  controller: _tc,
                  isScrollable: false,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white38,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                  unselectedLabelStyle:
                      const TextStyle(fontWeight: FontWeight.w500),
                  indicator: const UnderlineTabIndicator(
                    borderSide: BorderSide(color: Colors.white, width: 3),
                    insets: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  tabs: _tabs.map((t) {
                    final c = _filtered(t).length;
                    return Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(t),
                          if (c > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('$c',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700)),
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
            child: TabBarView(
              controller: _tc,
              children: _tabs.map((tab) {
                final list = _filtered(tab);
                if (widget.isLoading) {
                  return const Center(
                      child: CircularProgressIndicator(color: _DS.blue));
                }
                if (list.isEmpty) {
                  return const _EmptyState(
                    icon: Icons.inbox_outlined,
                    message: 'Tidak ada pesanan',
                  );
                }
                return RefreshIndicator(
                  onRefresh: widget.onRefresh,
                  color: _DS.blue,
                  child: ListView.builder(
                    physics: const BouncingScrollPhysics(),
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
        ],
      ),
    );
  }
}

// ============================================================
// PREMIUM ORDER CARD
// ============================================================
class _PremiumOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String, String) onUpdate;
  final VoidCallback onTap;

  const _PremiumOrderCard({
    required this.order,
    required this.onUpdate,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'diterima';
    final namaPelanggan =
        order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';
    final nomorOrder = order['nomor_order'] ?? '-';
    final total = (order['total_harga'] ?? 0).toDouble();
    final isPiutang = order['is_piutang'] == true || status == 'diambil_belum_lunas';
    final items = order['order_items'] as List? ?? [];
    final layanan = items.isNotEmpty
        ? items.map((i) => i['services']?['nama'] ?? '').where((n) => n.isNotEmpty).join(' • ')
        : 'Tidak ada item';

    final statusCfg = _statusConfig(status);
    final nextStatus = _nextStatus(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _DS.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _DS.cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  color: statusCfg['color'],
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(18),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: (statusCfg['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                namaPelanggan.isNotEmpty
                                    ? namaPelanggan[0].toUpperCase()
                                    : '?',
                                style: TextStyle(
                                  color: statusCfg['color'],
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  namaPelanggan,
                                  style: const TextStyle(
                                    color: _DS.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  nomorOrder,
                                  style: const TextStyle(
                                    color: _DS.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: (statusCfg['color'] as Color).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (statusCfg['color'] as Color).withOpacity(0.2),
                              ),
                            ),
                            child: Text(
                              statusCfg['label'],
                              style: TextStyle(
                                color: statusCfg['color'],
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(Icons.local_laundry_service_outlined,
                              size: 12, color: _DS.textHint),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              layanan,
                              style: const TextStyle(
                                color: _DS.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Text(
                            _formatRupiah(total),
                            style: const TextStyle(
                              color: _DS.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (isPiutang) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
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
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (nextStatus != null)
                            GestureDetector(
                              onTap: () => onUpdate(order['id'], nextStatus),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusCfg['color'],
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: (statusCfg['color'] as Color)
                                          .withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _nextStatusLabel(status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
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

  Map<String, dynamic> _statusConfig(String s) {
    switch (s) {
      case 'diterima': return {'label': 'Diterima', 'color': _DS.statusDiterima};
      case 'diproses': return {'label': 'Diproses', 'color': _DS.statusDiproses};
      case 'selesai': return {'label': 'Selesai', 'color': _DS.statusSelesai};
      case 'siap_diambil': return {'label': 'Siap Diambil', 'color': _DS.statusSiap};
      case 'dibayar_lunas': return {'label': 'Lunas', 'color': _DS.statusLunas};
      case 'diambil_belum_lunas': return {'label': 'Piutang', 'color': _DS.statusPiutang};
      default: return {'label': s, 'color': _DS.statusLunas};
    }
  }

  String? _nextStatus(String s) {
    const flow = {
      'diterima': 'diproses',
      'diproses': 'selesai',
      'selesai': 'siap_diambil',
    };
    return flow[s];
  }

  String _nextStatusLabel(String s) {
    const labels = {
      'diterima': '▶ Proses',
      'diproses': '✓ Selesai',
      'selesai': '📦 Siap',
    };
    return labels[s] ?? '';
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
// TAB PELANGGAN WIDGET
// ============================================================
class _PelangganTab extends StatefulWidget {
  const _PelangganTab();

  @override
  State<_PelangganTab> createState() => _PelangganTabState();
}

class _PelangganTabState extends State<_PelangganTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String q = '']) async {
    setState(() => _loading = true);
    try {
      var query = _supabase
          .from('profiles')
          .select('id, nama_lengkap, nomor_hp, customers(id, poin_saldo)')
          .eq('role', 'customer');
      if (q.isNotEmpty) {
        query = query.or('nama_lengkap.ilike.%$q%,nomor_hp.ilike.%$q%');
      }
      final data = await query.order('nama_lengkap');
      if (mounted) {
        setState(() {
          _list = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2557), Color(0xFF1565C0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pelanggan',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari nama atau nomor HP...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.5), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Colors.white.withOpacity(0.6), size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                    ),
                    onChanged: (v) => _load(v),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: _DS.blue))
                : _list.isEmpty
                    ? const _EmptyState(
                        icon: Icons.people_outline_rounded,
                        message: 'Tidak ada pelanggan',
                        sub: 'Daftarkan pelanggan saat buat pesanan',
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(_searchCtrl.text),
                        color: _DS.blue,
                        child: ListView.builder(
                          physics: const BouncingScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                          itemCount: _list.length,
                          itemBuilder: (_, i) {
                            final c = _list[i];
                            final poin = c['customers']?[0]?['poin_saldo'] ?? 0;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: _DS.surface,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: _DS.softShadow,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: _DS.sky,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      c['nama_lengkap']?[0]?.toUpperCase() ?? '?',
                                      style: const TextStyle(
                                        color: _DS.blue,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(c['nama_lengkap'] ?? '-',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: _DS.textPrimary,
                                        fontSize: 14)),
                                subtitle: Text(c['nomor_hp'] ?? '-',
                                    style: const TextStyle(
                                        color: _DS.textSecondary, fontSize: 12)),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: Colors.amber.shade200),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.stars_rounded,
                                          color: Colors.amber.shade600,
                                          size: 13),
                                      const SizedBox(width: 3),
                                      Text('$poin',
                                          style: TextStyle(
                                              color: Colors.amber.shade700,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// ORDER DETAIL BOTTOM SHEET
// ============================================================
class _OrderDetailSheet extends StatelessWidget {
  final Map<String, dynamic> order;
  final Function(String) onUpdateStatus;

  const _OrderDetailSheet(
      {required this.order, required this.onUpdateStatus});

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'diterima';
    final namaPelanggan =
        order['customers']?['profiles']?['nama_lengkap'] ?? 'Umum';
    final nomorHp = order['customers']?['profiles']?['nomor_hp'];
    final nomorOrder = order['nomor_order'] ?? '-';
    final total = (order['total_harga'] ?? 0).toDouble();
    final isPiutang = order['is_piutang'] == true || status == 'diambil_belum_lunas';
    final items = order['order_items'] as List? ?? [];
    final nextSt = _nextStatus(status);

    return Container(
      decoration: const BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _DS.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomorOrder,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _DS.textPrimary)),
                    const SizedBox(height: 2),
                    Text(
                      nomorHp != null
                          ? '$namaPelanggan • $nomorHp'
                          : namaPelanggan,
                      style: const TextStyle(
                          color: _DS.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              _StatusPill(status: status),
            ],
          ),

          const SizedBox(height: 16),
          Container(height: 1, color: _DS.border),
          const SizedBox(height: 14),

          const Text('Detail Pesanan',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: _DS.textSecondary)),
          const SizedBox(height: 8),
          ...items.map((item) {
            final nama = item['services']?['nama'] ?? '-';
            final jumlah = item['jumlah'] ?? 0;
            final harga = (item['harga_satuan'] ?? 0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text('$nama  ×  $jumlah',
                        style: const TextStyle(
                            fontSize: 13, color: _DS.textPrimary)),
                  ),
                  Text(_fmt(harga * jumlah),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: _DS.textPrimary)),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),
          Container(height: 1, color: _DS.border),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _DS.textPrimary)),
              Text(_fmt(total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                      color: _DS.blue)),
            ],
          ),
          if (isPiutang)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: Colors.red.shade600),
                    const SizedBox(width: 4),
                    Text('Belum Lunas (Piutang)',
                        style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          if (nextSt != null)
            _ActionButton(
              label: _nextStatusLabel(status),
              color: _DS.blue,
              onTap: () => onUpdateStatus(nextSt),
            ),
          if (status == 'diambil_belum_lunas')
            _ActionButton(
              label: '✓ Konfirmasi Lunas',
              color: _DS.statusSiap,
              onTap: () => onUpdateStatus('dibayar_lunas'),
            ),
          if (status == 'siap_diambil') ...[
            const SizedBox(height: 10),
            _ActionButton(
              label: '⚠️  Diambil Belum Lunas',
              color: _DS.statusPiutang,
              onTap: () => onUpdateStatus('diambil_belum_lunas'),
              outlined: true,
            ),
          ],
        ],
      ),
    );
  }

  String? _nextStatus(String s) {
    const flow = {
      'diterima': 'diproses',
      'diproses': 'selesai',
      'selesai': 'siap_diambil',
    };
    return flow[s];
  }

  String _nextStatusLabel(String s) {
    const labels = {
      'diterima': '▶  Mulai Proses',
      'diproses': '✓  Tandai Selesai',
      'selesai': '📦  Siap Diambil',
    };
    return labels[s] ?? 'Update Status';
  }

  String _fmt(double amount) {
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
// HELPER WIDGETS
// ============================================================
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
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: highlight
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: highlight
                ? Colors.amber.withOpacity(0.4)
                : Colors.white.withOpacity(0.15),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    letterSpacing: -0.5)),
            Text(label,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 10,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final cfg = _cfg();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (cfg['color'] as Color).withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (cfg['color'] as Color).withOpacity(0.25)),
      ),
      child: Text(cfg['label'],
          style: TextStyle(
              color: cfg['color'],
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }

  Map<String, dynamic> _cfg() {
    switch (status) {
      case 'diterima': return {'label': 'Diterima', 'color': _DS.statusDiterima};
      case 'diproses': return {'label': 'Diproses', 'color': _DS.statusDiproses};
      case 'selesai': return {'label': 'Selesai', 'color': _DS.statusSelesai};
      case 'siap_diambil': return {'label': 'Siap Diambil', 'color': _DS.statusSiap};
      case 'dibayar_lunas': return {'label': 'Lunas', 'color': _DS.statusLunas};
      case 'diambil_belum_lunas': return {'label': 'Piutang', 'color': _DS.statusPiutang};
      default: return {'label': status, 'color': _DS.statusLunas};
    }
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool outlined;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(16),
          border: outlined ? Border.all(color: color, width: 1.5) : null,
          boxShadow: outlined
              ? null
              : [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: outlined ? color : Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _PremiumHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2557), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.65), fontSize: 12)),
        ],
      ),
    );
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
            child: Icon(icon, size: 36, color: _DS.blue.withOpacity(0.4)),
          ),
          const SizedBox(height: 14),
          Text(message,
              style: const TextStyle(
                  color: _DS.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!,
                style: const TextStyle(
                    color: _DS.textHint, fontSize: 12),
                textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}