import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// DESIGN SYSTEM
// ============================================================
class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const surface = Colors.white;
  static const ground = Color(0xFFEAF0F6);
  static const border = Color(0xFFD2DCE8);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
  
  // Tambahkan baris ini 👇
  static const textHint = Color(0xFFB0BAD1); 
  
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}

class ReportCoinScreen extends StatefulWidget {
  const ReportCoinScreen({super.key});

  @override
  State<ReportCoinScreen> createState() => _ReportCoinScreenState();
}

class _ReportCoinScreenState extends State<ReportCoinScreen> {
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _logs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  final _searchCtrl = TextEditingController();

  bool _isLoading = true;

  int _totalDiberikan = 0;
  int _totalDitukar = 0;

  // Set default ke 1 hari (Hari Ini)
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // LOGIC: LOAD & FILTER DATA
  // =========================================================
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Format tanggal untuk query Supabase (00:00:00 s/d 23:59:59)
      final startLocal = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final endLocal = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      final startStr = startLocal.toUtc().toIso8601String();
      final endStr = endLocal.toUtc().toIso8601String();

      final response = await _supabase
          .from('points_ledger')
          .select('*, customers(profiles(nama_lengkap))')
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _applyFilter(); 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load coin report error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilter() {
    final query = _searchCtrl.text.toLowerCase();
    
    setState(() {
      if (query.isEmpty) {
        _filteredLogs = _logs;
      } else {
        _filteredLogs = _logs.where((log) {
          final custName = (log['customers']?['profiles']?['nama_lengkap'] ?? 'Pelanggan').toString().toLowerCase();
          return custName.contains(query);
        }).toList();
      }

      // Hitung ulang total berdasarkan data yang terfilter & rentang waktu
      _totalDiberikan = 0;
      _totalDitukar = 0;
      
      for (var log in _filteredLogs) {
        final amt = (log['jumlah'] as num).toInt();
        if (log['tipe'] == 'earned') {
          _totalDiberikan += amt;
        } else if (log['tipe'] == 'redeemed') {
          _totalDitukar += amt.abs(); 
        }
      }
    });
  }

  // =========================================================
  // LOGIC: DATE PICKER
  // =========================================================
  String _formatDateStr(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  String get _dateRangeText {
    final now = DateTime.now();
    if (_startDate.year == _endDate.year && _startDate.month == _endDate.month && _startDate.day == _endDate.day) {
      if (_startDate.day == now.day && _startDate.month == now.month && _startDate.year == now.year) {
        return 'Hari Ini';
      }
      return _formatDateStr(_startDate);
    }
    return '${_formatDateStr(_startDate)} - ${_formatDateStr(_endDate)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context, 
      firstDate: DateTime(2023), 
      lastDate: DateTime.now(), 
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _DS.blue,
            onPrimary: Colors.white,
            surface: _DS.surface,
            onSurface: _DS.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() { 
        _startDate = picked.start; 
        _endDate = picked.end; 
      });
      _loadData(); 
    }
  }

  String _formatDate(String isoStr) {
    final dt = DateTime.parse(isoStr).toLocal();
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Laporan Koin', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // HEADER: STATISTIK & FILTER TANGGAL
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(
              color: _DS.navy,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Statistik Koin', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15), 
                          borderRadius: BorderRadius.circular(12), 
                          border: Border.all(color: Colors.white.withOpacity(0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min, 
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14), 
                            const SizedBox(width: 6), 
                            Text(_dateRangeText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Diberikan', style: TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('$_totalDiberikan', style: const TextStyle(color: Colors.green, fontSize: 24, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total Ditukar', style: TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Text('$_totalDitukar', style: const TextStyle(color: Colors.orange, fontSize: 24, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
          
          // KOLOM PENCARIAN
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: _DS.surface, 
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _DS.border),
                boxShadow: _DS.softShadow,
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari nama pelanggan...', 
                  hintStyle: const TextStyle(color: _DS.textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded, color: _DS.textHint, size: 20),
                  border: InputBorder.none, 
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _searchCtrl.text.isNotEmpty 
                    ? IconButton(icon: const Icon(Icons.clear, color: _DS.textHint), onPressed: () { _searchCtrl.clear(); _applyFilter(); }) 
                    : null,
                ),
                onChanged: (_) => _applyFilter(),
              ),
            ),
          ),

          // LIST DATA
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: _DS.blue))
              : _filteredLogs.isEmpty
                  ? Center(
                      child: Text(
                        _searchCtrl.text.isEmpty ? 'Belum ada transaksi koin.' : 'Pelanggan tidak ditemukan.', 
                        style: const TextStyle(color: _DS.textHint),
                      ),
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      padding: const EdgeInsets.all(20),
                      itemCount: _filteredLogs.length,
                      itemBuilder: (context, index) {
                        final log = _filteredLogs[index];
                        final String tipe = log['tipe'];
                        final int amount = (log['jumlah'] as num).toInt();
                        final String custName = log['customers']?['profiles']?['nama_lengkap'] ?? 'Pelanggan';

                        bool isMasuk = true;
                        Color color = Colors.green;
                        String sign = '+';

                        if (tipe == 'redeemed' || (tipe == 'adjusted' && amount < 0)) {
                          isMasuk = false;
                          color = Colors.red;
                          sign = '';
                        } else if (tipe == 'adjusted' && amount > 0) {
                          color = Colors.blue;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: _DS.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: _DS.border),
                            boxShadow: _DS.softShadow,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                              child: Icon(isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 20),
                            ),
                            title: Text(custName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _DS.textPrimary)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(log['catatan'] ?? tipe, style: const TextStyle(fontSize: 12, color: _DS.textSecondary)),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$sign$amount', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                                const SizedBox(height: 4),
                                Text(_formatDate(log['created_at']), style: const TextStyle(color: _DS.textSecondary, fontSize: 10, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          )
        ],
      ),
    );
  }
}