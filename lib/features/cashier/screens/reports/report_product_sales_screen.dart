import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// DESIGN SYSTEM - KONSISTEN
// ============================================================
class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const ground = Color(0xFFEAF0F6); 
  static const surface = Colors.white;
  static const border = Color(0xFFD2DCE8); 
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);

  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
  ];
}

class ReportProductSalesScreen extends StatefulWidget {
  const ReportProductSalesScreen({super.key});

  @override
  State<ReportProductSalesScreen> createState() => _ReportProductSalesScreenState();
}

class _ReportProductSalesScreenState extends State<ReportProductSalesScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 49)); 
  DateTime _endDate = DateTime.now();

  double _totalPenjualan = 0;
  int _jumlahTransaksi = 0;
  double _rataRata = 0;
  
  List<Map<String, dynamic>> _ringkasanItem = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return str == '0' ? '0' : buffer.toString();
  }

  String _formatDateStr(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year.toString().substring(2)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2023), lastDate: DateTime.now(), initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _DS.blue)), child: child!),
    );
    if (picked != null) {
      setState(() { _startDate = picked.start; _endDate = picked.end; });
      await _loadData(); 
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final startStr = '${_startDate.year}-${_startDate.month.toString().padLeft(2, '0')}-${_startDate.day.toString().padLeft(2, '0')}T00:00:00';
      final endStr = '${_endDate.year}-${_endDate.month.toString().padLeft(2, '0')}-${_endDate.day.toString().padLeft(2, '0')}T23:59:59';

      final res = await _supabase.from('orders')
          .select('id, total_harga, order_items(jumlah, harga_satuan, subtotal, services(nama))')
          .gte('created_at', startStr).lte('created_at', endStr).neq('status', 'dibatalkan');

      double total = 0;
      int transaksi = res.length;
      Map<String, Map<String, dynamic>> groupedItems = {};

      for (var order in res) {
        total += (order['total_harga'] as num?)?.toDouble() ?? 0;
        final items = order['order_items'] as List<dynamic>? ?? [];
        
        for (var item in items) {
          String nama = 'Item Terhapus';
          if (item['services'] != null) {
            if (item['services'] is Map) nama = item['services']['nama'] ?? nama;
            else if (item['services'] is List && item['services'].isNotEmpty) nama = item['services'][0]['nama'] ?? nama;
          }
          final qty = (item['jumlah'] as num?)?.toInt() ?? 0;
          final hargaSatuan = (item['harga_satuan'] as num?)?.toDouble() ?? 0;
          final sub = (item['subtotal'] as num?)?.toDouble() ?? 0;

          if (groupedItems.containsKey(nama)) {
            groupedItems[nama]!['qty'] += qty;
            groupedItems[nama]!['subtotal'] += sub;
          } else {
            groupedItems[nama] = {'nama': nama, 'qty': qty, 'harga_satuan': hargaSatuan, 'subtotal': sub};
          }
        }
      }

      final diffDays = _endDate.difference(_startDate).inDays + 1;
      final rataRata = total / diffDays;

      final sortedItems = groupedItems.values.toList();
      sortedItems.sort((a, b) => (b['subtotal'] as double).compareTo(a['subtotal'] as double));

      if (mounted) {
        setState(() {
          _totalPenjualan = total;
          _jumlahTransaksi = transaksi;
          _rataRata = rataRata;
          _ringkasanItem = sortedItems;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Laporan Penjualan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy, foregroundColor: Colors.white, elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.calendar_month_rounded), onPressed: _pickDate)],
      ),
      body: _isLoading
        ? const Center(child: CircularProgressIndicator(color: _DS.blue))
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CARD KESELURUHAN (MENGAMBANG)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                  child: Column(
                    children: [
                      const Text('Total Penjualan', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textSecondary)),
                      const SizedBox(height: 8),
                      Text('Rp ${_formatRupiah(_totalPenjualan)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 28, color: _DS.blue, letterSpacing: -0.5)),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(child: Column(children: [const Text('Rata-Rata / Hari', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _DS.textSecondary)), const SizedBox(height: 6), Text('Rp ${_formatRupiah(_rataRata)}', style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 16))])),
                          Container(width: 1, height: 40, color: _DS.border),
                          Expanded(child: Column(children: [const Text('Jml. Transaksi', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _DS.textSecondary)), const SizedBox(height: 6), Text('$_jumlahTransaksi', style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 16))])),
                        ],
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Ringkasan Terlaris', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _DS.textPrimary)),
                    Text('${_formatDateStr(_startDate)} s/d ${_formatDateStr(_endDate)}', style: const TextStyle(color: _DS.blue, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 16),

                // DAFTAR ITEM (CARD STYLE)
                if (_ringkasanItem.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Belum ada penjualan', style: TextStyle(color: _DS.textSecondary))))
                else
                  ..._ringkasanItem.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['nama'], style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 15)),
                              const SizedBox(height: 6),
                              Text('Rp ${_formatRupiah(item['harga_satuan'])} x${item['qty']} Pcs', style: const TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Text(_formatRupiah(item['subtotal']), style: const TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 16)),
                      ],
                    ),
                  )),
                const SizedBox(height: 40),
              ],
            ),
          ),
    );
  }
}