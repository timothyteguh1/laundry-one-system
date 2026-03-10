import 'package:flutter/material.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart';
import 'package:laundry_one/features/customer/screens/customer_invoice_screen.dart'; // IMPORT NOTA

class BerandaTab extends StatelessWidget {
  final String nama;
  final int poin;
  final List<Map<String, dynamic>> activeOrders;
  final Future<void> Function() onRefresh;

  const BerandaTab({
    super.key, required this.nama, required this.poin, required this.activeOrders, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: onRefresh, color: CustomerTheme.primary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          children: [
            // HEADER & SALDO KOIN
            Container(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              decoration: BoxDecoration(
                color: CustomerTheme.surface,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: CustomerTheme.headerShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Halo, apa kabar? 👋', style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(nama, style: const TextStyle(color: CustomerTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(padding: const EdgeInsets.all(12), decoration: const BoxDecoration(color: CustomerTheme.primaryLight, shape: BoxShape.circle), child: const Icon(Icons.notifications_none_rounded, color: CustomerTheme.primary))
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [CustomerTheme.primary, CustomerTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: CustomerTheme.cardShadow),
                    child: Row(
                      children: [
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28)),
                        const SizedBox(width: 16),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Saldo Koin Laundry', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text('$poin Koin', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))])),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // LIVE TRACKING CUCIAN AKTIF
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Cucian Aktif Anda', style: TextStyle(color: CustomerTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800)), if (activeOrders.isNotEmpty) Text('${activeOrders.length} Proses', style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w800))]),
                  const SizedBox(height: 16),
                  
                  if (activeOrders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: CustomerTheme.cardDecoration,
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.local_laundry_service_outlined, size: 48, color: CustomerTheme.textHint), const SizedBox(height: 16), const Text('Belum ada cucian aktif', style: TextStyle(fontWeight: FontWeight.w700, color: CustomerTheme.textPrimary)), const SizedBox(height: 4), const Text('Cucian Anda yang sedang diproses akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    ...activeOrders.map((order) => Padding(
                      padding: const EdgeInsets.only(bottom: 12), 
                      child: PremiumOrderCard(
                        order: order, 
                        isCustomerView: true, 
                        onTap: () {
                          // BUKA LAYAR NOTA DIGITAL
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => CustomerInvoiceScreen(order: order)),
                          );
                        }
                      )
                    )).toList()
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}