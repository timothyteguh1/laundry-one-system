import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart';
import 'package:laundry_one/features/customer/screens/customer_invoice_screen.dart'; // IMPORT NOTA

class AktivitasTab extends StatefulWidget {
  final List<Map<String, dynamic>> historyOrders;
  final String? customerId;
  final Future<void> Function() onRefresh;

  const AktivitasTab({
    super.key,
    required this.historyOrders,
    required this.customerId,
    required this.onRefresh,
  });

  @override
  State<AktivitasTab> createState() => _AktivitasTabState();
}

class _AktivitasTabState extends State<AktivitasTab> {
  final _supabase = Supabase.instance.client;
  int _selectedFilter = 0; 
  List<Map<String, dynamic>> _pointsHistory = [];
  bool _isLoadingPoin = false;

  @override
  void initState() {
    super.initState();
    _loadPointsHistory();
  }

  Future<void> _loadPointsHistory() async {
    if (widget.customerId == null) return;
    setState(() => _isLoadingPoin = true);
    try {
      final data = await _supabase
          .from('points_ledger')
          .select('tipe, jumlah, created_at, catatan')
          .eq('customer_id', widget.customerId!)
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _pointsHistory = data;
          _isLoadingPoin = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPoin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Text('Riwayat Aktivitas', style: TextStyle(color: CustomerTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: CustomerTheme.border.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _buildToggleBtn(0, 'Cucian Saya', Icons.local_laundry_service_rounded),
                  _buildToggleBtn(1, 'Mutasi Poin', Icons.stars_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _selectedFilter == 0 
                ? _buildListCucian() 
                : _buildListPoin(),
          )
        ],
      ),
    );
  }

  Widget _buildToggleBtn(int index, String title, IconData icon) {
    final isActive = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedFilter = index);
          if (index == 1 && _pointsHistory.isEmpty) _loadPointsHistory();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? CustomerTheme.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? CustomerTheme.softShadow : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? CustomerTheme.primary : CustomerTheme.textSecondary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? CustomerTheme.primary : CustomerTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCucian() {
    if (widget.historyOrders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined, 
        message: 'Belum ada riwayat cucian', 
        sub: 'Cucian yang sudah selesai atau diambil akan tampil di sini.'
      );
    }

    return RefreshIndicator(
      color: CustomerTheme.primary,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: widget.historyOrders.length,
        itemBuilder: (context, index) {
          final order = widget.historyOrders[index];
          return Padding(
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
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildListPoin() {
    if (_isLoadingPoin) {
      return const Center(child: CircularProgressIndicator(color: CustomerTheme.primary));
    }

    if (_pointsHistory.isEmpty) {
      return const EmptyState(
        icon: Icons.stars_rounded, 
        message: 'Belum ada mutasi poin', 
        sub: 'Lakukan transaksi untuk mulai mengumpulkan poin.'
      );
    }

    return RefreshIndicator(
      color: CustomerTheme.primary,
      onRefresh: _loadPointsHistory,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: _pointsHistory.length,
        itemBuilder: (context, index) {
          final poin = _pointsHistory[index];
          
          final isMasuk = poin['tipe'] == 'earned' || poin['tipe'] == 'adjusted';
          final jumlah = poin['jumlah'] ?? 0;
          final nominalStr = isMasuk ? '+ $jumlah' : '- $jumlah';
          final iconData = isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
          final color = isMasuk ? CustomerTheme.primary : Colors.red;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: CustomerTheme.menuDecoration,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
                  child: Icon(iconData, color: color, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(poin['catatan'] ?? _getLabelTipe(poin['tipe']), style: const TextStyle(fontWeight: FontWeight.w700, color: CustomerTheme.textPrimary, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(_formatDate(poin['created_at']), style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                Text(nominalStr, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 16)),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getLabelTipe(String? tipe) {
    if (tipe == 'earned') return 'Mendapatkan Poin';
    if (tipe == 'redeemed') return 'Tukar Voucher';
    if (tipe == 'expired') return 'Poin Kedaluwarsa';
    if (tipe == 'adjusted') return 'Penyesuaian Admin';
    if (tipe == 'reversed') return 'Pembatalan Poin';
    return 'Transaksi Poin';
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (e) { return '-'; }
  }
}