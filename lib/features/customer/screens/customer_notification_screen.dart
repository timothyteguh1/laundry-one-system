import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';

class CustomerNotificationScreen extends StatefulWidget {
  const CustomerNotificationScreen({super.key});

  @override
  State<CustomerNotificationScreen> createState() => _CustomerNotificationScreenState();
}

class _CustomerNotificationScreenState extends State<CustomerNotificationScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _notifications = [];

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Ambil customer_id
      final customerData = await _supabase
          .from('customers')
          .select('id')
          .eq('profile_id', userId)
          .single();
      
      final customerId = customerData['id'];

      // Ambil data notifikasi
      final notifResponse = await _supabase
          .from('notifications')
          .select()
          .eq('customer_id', customerId)
          .order('created_at', ascending: false);

      setState(() {
        _notifications = List<Map<String, dynamic>>.from(notifResponse);
      });

      // 👇 UPDATE: Logika pembersih badge yang disempurnakan
      if (_notifications.any((n) => n['is_read'] == false)) {
        // 1. Update di Database Supabase
        await _supabase
            .from('notifications')
            .update({'is_read': true})
            .eq('customer_id', customerId)
            .eq('is_read', false); 
            
        // 2. Update status lokal agar titik merah di layar ini langsung hilang seketika
        setState(() {
          for (var n in _notifications) {
            n['is_read'] = true;
          }
        });
      }
    } catch (e) {
      debugPrint("Gagal mengambil notifikasi: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Tentukan Ikon berdasarkan Tipe
  IconData _getIconForType(String type) {
    switch (type) {
      case 'promo': return Icons.local_offer_rounded;
      case 'voucher_aktif': return Icons.card_giftcard_rounded;
      case 'order_selesai': return Icons.check_circle_outline_rounded;
      case 'poin_masuk': return Icons.monetization_on_rounded;
      default: return Icons.notifications_active_rounded;
    }
  }

  // Tentukan Warna berdasarkan Tipe (Menggunakan tema)
  Color _getColorForType(String type) {
    switch (type) {
      case 'promo': return Colors.orange;
      case 'voucher_aktif': return Colors.green;
      case 'order_selesai': return CustomerTheme.primary;
      case 'poin_masuk': return Colors.amber;
      default: return CustomerTheme.textSecondary;
    }
  }

  // Format tanggal simpel
  String _formatDate(String isoDate) {
    final date = DateTime.parse(isoDate).toLocal();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Hari ini, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Kemarin, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
    return "${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CustomerTheme.ground, 
      appBar: AppBar(
        title: const Text('Kotak Masuk', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CustomerTheme.textPrimary)),
        backgroundColor: CustomerTheme.surface,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: CustomerTheme.textPrimary),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: CustomerTheme.primary))
          : _notifications.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _fetchNotifications,
                  color: CustomerTheme.primary,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: _notifications.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final notif = _notifications[index];
                      final isRead = notif['is_read'] ?? true;

                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isRead ? CustomerTheme.surface : CustomerTheme.primaryLight.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: CustomerTheme.border, width: 1.0),
                          boxShadow: CustomerTheme.softShadow,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _getColorForType(notif['tipe']).withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getIconForType(notif['tipe']),
                                color: _getColorForType(notif['tipe']),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notif['judul'] ?? 'Notifikasi Baru',
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CustomerTheme.textPrimary),
                                        ),
                                      ),
                                      if (!isRead) 
                                        Container(
                                          width: 8, height: 8,
                                          decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                        )
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    notif['isi'] ?? '',
                                    style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _formatDate(notif['created_at']),
                                    style: const TextStyle(color: CustomerTheme.textHint, fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: CustomerTheme.border.withOpacity(0.3), shape: BoxShape.circle),
            child: const Icon(Icons.notifications_off_rounded, size: 64, color: CustomerTheme.textHint),
          ),
          const SizedBox(height: 24),
          const Text('Belum Ada Notifikasi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: CustomerTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Pesan, promo, dan info pesananmu\nakan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: CustomerTheme.textSecondary, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}