import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; 
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart';
import 'package:laundry_one/features/customer/screens/customer_invoice_screen.dart'; 
import 'package:laundry_one/features/customer/screens/customer_notification_screen.dart'; 
import 'package:laundry_one/features/customer/screens/tabs/aktivitas_tab.dart'; 

class BerandaTab extends StatelessWidget {
  final String nama;
  final int poin;
  final List<Map<String, dynamic>> activeOrders;
  
  // [GELOMBANG 3]: Variabel Multi-Wallet
  final List<Map<String, dynamic>> myWallets;
  final Map<String, dynamic>? activeWallet;
  final Function(Map<String, dynamic>) onSwitchWallet;
  final VoidCallback onOpenNewBranch;
  
  final Future<void> Function() onRefresh;

  const BerandaTab({
    super.key, 
    required this.nama, 
    required this.poin, 
    required this.activeOrders, 
    required this.myWallets,
    required this.activeWallet,
    required this.onSwitchWallet,
    required this.onOpenNewBranch,
    required this.onRefresh,
  });

  // [GELOMBANG 3]: Widget Dropdown ala Instagram
  // [GELOMBANG 3]: Widget Dropdown ala Instagram (UI Diperbaiki & Anti-Overflow)
  Widget _buildWalletDropdown(BuildContext context) {
    if (activeWallet == null) return const Text('Memuat...');
    final String currentBranchName = activeWallet!['branches']?['nama_cabang'] ?? 'Cabang';

    return Container(
      // [PERBAIKAN UI]: Padding diperkecil agar tidak terlihat "numpuk"
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CustomerTheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CustomerTheme.primary.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isDense: true,
          value: activeWallet!['id'],
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: CustomerTheme.primary, size: 18),
          selectedItemBuilder: (BuildContext context) {
            return myWallets.map<Widget>((wallet) {
              return Container(
                alignment: Alignment.centerLeft,
                // [PERBAIKAN UI]: Batasi lebar nama cabang saat menu tertutup
                constraints: const BoxConstraints(maxWidth: 140), 
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storefront_rounded, color: CustomerTheme.primary, size: 14),
                    const SizedBox(width: 6),
                    Flexible( // <--- Kunci Anti-Meleber
                      child: Text(
                        currentBranchName,
                        style: const TextStyle(color: CustomerTheme.primary, fontSize: 13, fontWeight: FontWeight.w800),
                        overflow: TextOverflow.ellipsis, // Teks jadi "..." jika kepanjangan
                      ),
                    ),
                  ],
                ),
              );
            }).toList();
          },
          items: [
            ...myWallets.map((wallet) {
              return DropdownMenuItem<String>(
                value: wallet['id'],
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180), // Batasi lebar kotak popup
                  child: Text(
                    wallet['branches']?['nama_cabang'] ?? 'Cabang',
                    style: TextStyle(
                      fontWeight: wallet['id'] == activeWallet!['id'] ? FontWeight.w800 : FontWeight.w600,
                      color: wallet['id'] == activeWallet!['id'] ? CustomerTheme.primary : CustomerTheme.textPrimary,
                      fontSize: 13, // Font sedikit dikecilkan agar rapi
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }),
            DropdownMenuItem<String>(
              value: 'tambah_baru',
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 180), // Kunci lebar row agar tidak menabrak batas
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_circle_outline_rounded, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Flexible( // <--- Kunci Anti-Meleber untuk "Buka Cabang Lain"
                      child: Text(
                        'Buka Cabang Lain',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.w800, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          onChanged: (val) {
            if (val == 'tambah_baru') {
              onOpenNewBranch();
            } else if (val != null && val != activeWallet!['id']) {
              final selected = myWallets.firstWhere((w) => w['id'] == val);
              onSwitchWallet(selected);
            }
          },
        ),
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Container(
      color: CustomerTheme.surface, 
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: onRefresh, 
          color: CustomerTheme.primary,
          backgroundColor: Colors.white,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Stack(
                    children: [
                      Positioned.fill(top: 120, child: Container(color: CustomerTheme.ground)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FadeInAnimation(
                            delay: 0,
                            child: Container(
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
                                            // [GELOMBANG 3]: Teks diganti menjadi Dropdown
                                            _buildWalletDropdown(context),
                                            const SizedBox(height: 4),
                                            Text(nama, style: const TextStyle(color: CustomerTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            PageRouteBuilder(
                                              pageBuilder: (ctx, anim, secAnim) => const CustomerNotificationScreen(),
                                              transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
                                            )
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
                                  
                                  Container(
                                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [CustomerTheme.primary, CustomerTheme.primaryDark], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20), boxShadow: CustomerTheme.cardShadow),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(20),
                                        onTap: () {
                                          Navigator.push(
                                            context, 
                                            PageRouteBuilder(
                                              pageBuilder: (ctx, anim, secAnim) => AktivitasTab(isStandalone: true, initialFilter: 1, onRefresh: onRefresh),
                                              transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
                                            )
                                          );
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Row(
                                            children: [
                                              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 28)),
                                              const SizedBox(width: 16),
                                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Saldo Koin Cabang Ini', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text('$poin Koin', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800))])),
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
                          ),
                          const SizedBox(height: 24),
                          
                          FadeInAnimation(
                            delay: 150,
                            child: Padding(
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
                                            Icon(Icons.local_laundry_service_outlined, size: 48, color: CustomerTheme.textHint), SizedBox(height: 16), Text('Belum ada cucian aktif', style: TextStyle(fontWeight: FontWeight.w700, color: CustomerTheme.textPrimary)), SizedBox(height: 4), Text('Cucian Anda yang sedang diproses akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 12)),
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
                                            PageRouteBuilder(
                                              pageBuilder: (ctx, anim, secAnim) => CustomerInvoiceScreen(order: order),
                                              transitionsBuilder: (ctx, anim, secAnim, child) => FadeTransition(opacity: anim, child: child),
                                            )
                                          );
                                        }
                                      )
                                    )).toList()
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
  List<String> _customerIds = [];

  @override
  void initState() {
    super.initState();
    _fetchCustomerIds();
  }

  Future<void> _fetchCustomerIds() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final data = await Supabase.instance.client.from('customers').select('id').eq('profile_id', userId);
      if (data.isNotEmpty && mounted) {
        setState(() { _customerIds = List<String>.from(data.map((e) => e['id'])); });
      }
    } catch (e) { }
  }

  @override
  Widget build(BuildContext context) {
    if (_customerIds.isEmpty) return const SizedBox.shrink();
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: Supabase.instance.client.from('notifications').stream(primaryKey: ['id']).map((data) => data.where((n) => _customerIds.contains(n['customer_id']) && n['is_read'] == false).toList()),
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