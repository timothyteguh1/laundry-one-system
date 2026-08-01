import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/cashier/screens/kasir_management_screen.dart';
import 'package:laundry_one/features/cashier/screens/branch_management_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/cashier/screens/inventory_screen.dart';
import 'package:laundry_one/features/cashier/screens/purchase_screen.dart';
import 'package:laundry_one/features/cashier/screens/services_management_screen.dart';
import 'package:laundry_one/features/cashier/screens/reports/report_product_sales_screen.dart';
import 'package:laundry_one/features/cashier/screens/reports/report_cash_flow_screen.dart';
import 'package:laundry_one/features/cashier/screens/reports/report_coin_screen.dart';
import 'package:laundry_one/features/cashier/screens/reward_management_screen.dart';

// ============================================================
// DESIGN SYSTEM - MODERN & CLEAR
// ============================================================
class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const sky = Color(0xFFE8F0FE);
  static const ground = Color(0xFFEAF0F6);
  static const surface = Colors.white;
  static const border = Color(0xFFD2DCE8);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);

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
}

class ReportTab extends StatefulWidget {
  const ReportTab({super.key});

  @override
  State<ReportTab> createState() => _ReportTabState();
}

class _ReportTabState extends State<ReportTab> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    setState(() => _isLoading = true);

    try {
      final myId = _supabase.auth.currentUser!.id;
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', myId)
          .maybeSingle();

      if (mounted && profile != null) {
        setState(() {
          _isAdmin = profile['role'] == 'super_admin';
        });
      }
    } catch (e) {
      debugPrint('Error role check: $e');
    }

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // CUSTOM ROUTE ANIMATION (FADE + SLIDE UP)
  // ============================================================
  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.05); // Muncul dari bawah sedikit
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideTween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(slideTween),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _DS.navy,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER NAVY
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_DS.navy, _DS.blue],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kelola & Laporan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Pusat manajemen data dan ringkasan operasional',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Container(
                color: _DS.ground,
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(color: _DS.blue),
                      )
                    : RefreshIndicator(
                        onRefresh: _checkRoleAndLoad,
                        color: _DS.blue,
                        backgroundColor: _DS.surface,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                          children: [
                            if (_isAdmin) ...[
                              const Padding(
                                padding: EdgeInsets.only(left: 8, bottom: 12),
                                child: Text(
                                  'MANAJEMEN PENGGUNA & AKSES',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12,
                                    color: _DS.textSecondary,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ),
                              _MenuCardItem(
                                icon: Icons.store_rounded,
                                iconColor: Colors.deepPurple.shade600,
                                bgColor: Colors.deepPurple.shade50,
                                title: 'Kelola Cabang',
                                subtitle:
                                    'Tambah, edit, & kelola cabang laundry',
                                onTap: () => Navigator.push(
                                  context,
                                  _createRoute(const BranchManagementScreen()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _MenuCardItem(
                                icon: Icons.manage_accounts_rounded,
                                iconColor: Colors.indigo.shade600,
                                bgColor: Colors.indigo.shade50,
                                title: 'Kelola Kasir',
                                subtitle:
                                    'Persetujuan, reset sandi, & hapus akun kasir',
                                onTap: () => Navigator.push(
                                  context,
                                  _createRoute(const KasirManagementScreen()),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ],

                            const Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 12),
                              child: Text(
                                'MANAJEMEN DATA',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: _DS.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),

                            _MenuCardItem(
                              icon: Icons.inventory_2_rounded,
                              iconColor: Colors.brown.shade600,
                              bgColor: Colors.brown.shade50,
                              title: 'Stok Barang Fisik',
                              subtitle: 'Atur produk jualan & restock barang',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const InventoryScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _MenuCardItem(
                              icon: Icons.add_shopping_cart_rounded,
                              iconColor: Colors.green.shade600,
                              bgColor: Colors.green.shade50,
                              title: 'Pembelian & Restock',
                              subtitle: 'Catat nota belanja grosir 1 pintu',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const PurchaseScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _MenuCardItem(
                              icon: Icons.local_laundry_service_rounded,
                              iconColor: Colors.purple.shade600,
                              bgColor: Colors.purple.shade50,
                              title: 'Layanan Jasa Cuci',
                              subtitle: 'Tambah & atur tarif cucian',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const ServicesManagementScreen()),
                              ),
                            ),

                            const SizedBox(height: 32),
                            const Padding(
                              padding: EdgeInsets.only(left: 8, bottom: 12),
                              child: Text(
                                'LAPORAN KEUANGAN',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: _DS.textSecondary,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),

                            _MenuCardItem(
                              icon: Icons.bar_chart_rounded,
                              iconColor: _DS.blue,
                              bgColor: _DS.sky,
                              title: 'Laporan Penjualan',
                              subtitle: 'Statistik item terlaris & omset',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const ReportProductSalesScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _MenuCardItem(
                              icon: Icons.account_balance_wallet_rounded,
                              iconColor: Colors.teal.shade600,
                              bgColor: Colors.teal.shade50,
                              title: 'Laporan Arus Kas',
                              subtitle: 'Rincian uang masuk & pengeluaran',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const ReportCashFlowScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _MenuCardItem(
                              icon: Icons.monetization_on_rounded,
                              iconColor: Colors.orange.shade600,
                              bgColor: Colors.orange.shade50,
                              title: 'Laporan Koin',
                              subtitle:
                                  'Riwayat top-up & penukaran koin loyalitas',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const ReportCoinScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),

                            _MenuCardItem(
                              icon: Icons.card_giftcard_rounded,
                              iconColor: Colors.pink.shade600,
                              bgColor: Colors.pink.shade50,
                              title: 'Katalog Hadiah (Rewards)',
                              subtitle:
                                  'Atur daftar voucher diskon untuk pelanggan',
                              onTap: () => Navigator.push(
                                context,
                                _createRoute(const RewardManagementScreen()),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
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

// ============================================================
// WIDGET KARTU MENU INTERAKTIF (DENGAN ANIMASI MEMBAL)
// ============================================================
class _MenuCardItem extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuCardItem({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<_MenuCardItem> createState() => _MenuCardItemState();
}

class _MenuCardItemState extends State<_MenuCardItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        HapticFeedback.selectionClick();
        widget.onTap(); // Panggil navigasi setelah diklik
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0, // Menyusut ke 96% saat ditekan
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Container(
          decoration: BoxDecoration(
            color: _DS.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _DS.border, width: 1.5),
            boxShadow: _DS.cardShadow,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.bgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(widget.icon, color: widget.iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: _DS.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subtitle,
                        style: const TextStyle(
                          color: _DS.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: _DS.ground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.chevron_right_rounded,
                    color: _DS.textSecondary,
                    size: 20,
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
