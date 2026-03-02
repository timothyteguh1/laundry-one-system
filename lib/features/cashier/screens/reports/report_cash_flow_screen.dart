import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// DESIGN SYSTEM - KONSISTEN
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
  static const textHint = Color(0xFFB0BAD1); 

  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
  ];
}

class ReportCashFlowScreen extends StatefulWidget {
  const ReportCashFlowScreen({super.key});

  @override
  State<ReportCashFlowScreen> createState() => _ReportCashFlowScreenState();
}

class _ReportCashFlowScreenState extends State<ReportCashFlowScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 49)); 
  DateTime _endDate = DateTime.now();

  double _totalCash = 0;
  double _totalQris = 0;
  double _totalTransfer = 0;
  double _totalPengeluaran = 0;

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
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day}-${months[d.month - 1]}-${d.year.toString().substring(2)}';
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

      final resPayments = await _supabase.from('order_payments').select('jumlah, metode').gte('created_at', startStr).lte('created_at', endStr);
      double cash = 0, qris = 0, transfer = 0;
      for (var p in resPayments) {
        final amt = (p['jumlah'] ?? 0).toDouble();
        final method = p['metode'];
        if (method == 'cash') cash += amt;
        else if (method == 'qris') qris += amt;
        else if (method == 'transfer') transfer += amt;
      }

      final resExpenses = await _supabase.from('expenses').select('nominal').gte('created_at', startStr).lte('created_at', endStr);
      double keluar = 0;
      for (var e in resExpenses) { keluar += (e['nominal'] ?? 0).toDouble(); }

      if (mounted) {
        setState(() {
          _totalCash = cash;
          _totalQris = qris;
          _totalTransfer = transfer;
          _totalPengeluaran = keluar;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPendapatan = _totalCash + _totalQris + _totalTransfer;

    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Laporan Kas', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
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
                // HEADER PUTIH (CARD)
                Container(
                  width: double.infinity, 
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                  decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                  child: Column(
                    children: [
                      const Text('Laporan\nPendapatan & Pengeluaran', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textPrimary)),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Periode', style: TextStyle(color: _DS.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                            Text('${_formatDateStr(_startDate)} s/d ${_formatDateStr(_endDate)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _DS.textPrimary)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                const Text('Metode Transaksi Pembayaran', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                const SizedBox(height: 16),
                
                // ISI TABEL DENGAN WARNA YANG BERBEDA (COLOR CODING)
                _buildRowCard(
                  title: 'Cash (Tunai)', 
                  value: _totalCash, 
                  icon: Icons.payments_rounded, 
                  primaryColor: Colors.green.shade700, // Hijau identik dengan Uang Tunai
                  bgColor: Colors.green.shade50
                ),
                const SizedBox(height: 12),
                _buildRowCard(
                  title: 'QRIS', 
                  value: _totalQris, 
                  icon: Icons.qr_code_scanner_rounded, 
                  primaryColor: Colors.blue.shade700, // Biru identik dengan Dompet Digital
                  bgColor: Colors.blue.shade50
                ),
                const SizedBox(height: 12),
                _buildRowCard(
                  title: 'Transfer Bank', 
                  value: _totalTransfer, 
                  icon: Icons.account_balance_rounded, 
                  primaryColor: Colors.purple.shade700, // Ungu identik dengan Bank/Transfer
                  bgColor: Colors.purple.shade50
                ),
                
                const SizedBox(height: 32),
                
                // TOTAL PENDAPATAN & PENGELUARAN
                _buildRowCard(
                  title: 'Total Pendapatan', 
                  value: totalPendapatan, 
                  icon: Icons.trending_up_rounded, 
                  primaryColor: _DS.blue, 
                  bgColor: _DS.sky
                ),
                const SizedBox(height: 12),
                _buildRowCard(
                  title: 'Total Pengeluaran', 
                  value: _totalPengeluaran, 
                  icon: Icons.trending_down_rounded, 
                  primaryColor: Colors.red.shade700, // Merah identik dengan Pengeluaran (Minus)
                  bgColor: Colors.red.shade50
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: Text('Powered by LaundryOne', style: TextStyle(color: _DS.textHint, fontWeight: FontWeight.w700, fontSize: 12))),
                )
              ],
            ),
          ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))]),
          child: TextButton.icon(
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 18), foregroundColor: _DS.textSecondary),
            onPressed: () {}, icon: const Icon(Icons.share, size: 20), label: const Text('Share Laporan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }

  // FUNGSI WIDGET YANG SUDAH DINAMIS WARNANYA
  Widget _buildRowCard({required String title, required double value, required IconData icon, required Color primaryColor, required Color bgColor}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _DS.textPrimary))),
          // Warna angka dibuat senada dengan warna ikon agar semakin jelas identitasnya
          Text(_formatRupiah(value), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: primaryColor)),
        ],
      ),
    );
  }
}