import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart';
import 'package:laundry_one/features/customer/screens/customer_invoice_screen.dart'; 
import 'package:laundry_one/features/customer/screens/customer_notification_screen.dart'; 

// 👇 IMPORT AKTIVITAS TAB
import 'package:laundry_one/features/customer/screens/tabs/aktivitas_tab.dart'; 

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
                      // TOMBOL NOTIFIKASI DENGAN BADGE MERAH
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CustomerNotificationScreen()),
                          );
                        },
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12), 
                              decoration: const BoxDecoration(
                                color: CustomerTheme.primaryLight, 
                                shape: BoxShape.circle
                              ), 
                              child: const Icon(Icons.notifications_none_rounded, color: CustomerTheme.primary)
                            ),
                            const NotificationBadge(),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // 👇 UPDATE: KOTAK KOIN NAVIGASI LANGSUNG KE AKTIVITAS (MUTASI POIN)
                  Container(
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [CustomerTheme.primary, CustomerTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: CustomerTheme.cardShadow),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => AktivitasTab(
                              isStandalone: true,    // Tampilkan tombol back
                              initialFilter: 1,      // Langsung buka Mutasi Poin
                              onRefresh: onRefresh,  // Bawa fungsi refresh
                            ))
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28)),
                              const SizedBox(width: 16),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Saldo Koin Laundry', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text('$poin Koin', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))])),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
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

class NotificationBadge extends StatefulWidget {
  const NotificationBadge({super.key});
  @override
  State<NotificationBadge> createState() => _NotificationBadgeState();
}

class _NotificationBadgeState extends State<NotificationBadge> {
  String? _customerId;

  @override
  void initState() {
    super.initState();
    _fetchCustomerId();
  }

  Future<void> _fetchCustomerId() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client.from('customers').select('id').eq('profile_id', userId).maybeSingle();
      if (data != null && mounted) {
        setState(() { _customerId = data['id']; });
      }
    } catch (e) { }
  }

  @override
  Widget build(BuildContext context) {
    if (_customerId == null) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('notifications').stream(primaryKey: ['id']).eq('customer_id', _customerId!).map((data) => data.where((n) => n['is_read'] == false).toList()),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink(); 
        final unreadCount = snapshot.data!.length;
        return Positioned(
          right: -2, top: -2,
          child: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: CustomerTheme.surface, width: 2)),
            child: Text(unreadCount > 9 ? '9+' : unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, height: 1), textAlign: TextAlign.center),
          ),
        );
      },
    );
  }
}