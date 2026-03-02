import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/cashier/screens/inventory_screen.dart';
import 'package:laundry_one/features/cashier/screens/services_management_screen.dart';
import 'package:laundry_one/features/cashier/screens/reports/report_product_sales_screen.dart';
import 'package:laundry_one/features/cashier/screens/reports/report_cash_flow_screen.dart';

// ============================================================
// DESIGN SYSTEM - MODERN & CLEAR
// ============================================================
class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const sky = Color(0xFFE8F0FE);
  static const ground = Color(0xFFEAF0F6); // Sesuai parameter kamu
  static const surface = Colors.white;
  static const border = Color(0xFFD2DCE8); // Sesuai parameter kamu
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);

  // MENGGUNAKAN PARAMETER SHADOW YANG KAMU KIRIM
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

class ReportTab extends StatelessWidget {
  const ReportTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _DS.ground,
      child: SafeArea(
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
                  Text('Kelola & Laporan', 
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                  SizedBox(height: 6),
                  Text('Pusat manajemen data dan ringkasan operasional', 
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12), 
                    child: Text('MANAJEMEN DATA', 
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _DS.textSecondary, letterSpacing: 1.2))
                  ),
                  
                  _buildMenuCard(
                    context, 
                    icon: Icons.inventory_2_rounded, iconColor: Colors.brown.shade600, bgColor: Colors.brown.shade50,
                    title: 'Stok Barang Fisik', subtitle: 'Atur produk jualan & barang gudang',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen())),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuCard(
                    context, 
                    icon: Icons.local_laundry_service_rounded, iconColor: Colors.purple.shade600, bgColor: Colors.purple.shade50,
                    title: 'Layanan Jasa Cuci', subtitle: 'Tambah & atur tarif cucian',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServicesManagementScreen())), 
                  ),

                  const SizedBox(height: 32),
                  const Padding(
                    padding: EdgeInsets.only(left: 8, bottom: 12), 
                    child: Text('LAPORAN KEUANGAN', 
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: _DS.textSecondary, letterSpacing: 1.2))
                  ),
                  
                  _buildMenuCard(
                    context, 
                    icon: Icons.bar_chart_rounded, iconColor: _DS.blue, bgColor: _DS.sky,
                    title: 'Laporan Penjualan', subtitle: 'Statistik item terlaris & omset',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportProductSalesScreen())),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuCard(
                    context, 
                    icon: Icons.account_balance_wallet_rounded, iconColor: Colors.teal.shade600, bgColor: Colors.teal.shade50,
                    title: 'Laporan Arus Kas', subtitle: 'Rincian uang masuk & pengeluaran',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportCashFlowScreen())),
                  ),
                  const SizedBox(height: 12),

                  _buildMenuCard(
                    context, 
                    icon: Icons.monetization_on_rounded, iconColor: Colors.orange.shade600, bgColor: Colors.orange.shade50,
                    title: 'Laporan Koin', subtitle: 'Riwayat top-up deposit pelanggan',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Fitur Laporan Koin segera hadir!', 
                          style: TextStyle(fontWeight: FontWeight.w600)), 
                        backgroundColor: Colors.orange.shade800, 
                        behavior: SnackBarBehavior.floating, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    },
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, {required IconData icon, required Color iconColor, required Color bgColor, required String title, required String subtitle, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(
        color: _DS.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _DS.border, width: 1.5), // Mengikuti parameter border kamu
        boxShadow: _DS.cardShadow, // Menggunakan cardShadow yang kamu minta
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: bgColor, 
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, 
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _DS.textPrimary, letterSpacing: -0.3)),
                      const SizedBox(height: 4),
                      Text(subtitle, 
                        style: const TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _DS.ground, 
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.chevron_right_rounded, color: _DS.textSecondary, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}