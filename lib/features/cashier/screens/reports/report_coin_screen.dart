import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _DS {
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const surface = Colors.white;
  static const ground = Color(0xFFEAF0F6);
  static const border = Color(0xFFD2DCE8);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
}

class ReportCoinScreen extends StatefulWidget {
  const ReportCoinScreen({super.key});

  @override
  State<ReportCoinScreen> createState() => _ReportCoinScreenState();
}

class _ReportCoinScreenState extends State<ReportCoinScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  int _totalDiberikan = 0;
  int _totalDitukar = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // Ambil data termasuk saldo sebelum & sesudah
      final response = await _supabase
          .from('points_ledger')
          .select('tipe, jumlah, saldo_sebelum, saldo_sesudah, catatan, created_at, customers(profiles(nama_lengkap))')
          .order('created_at', ascending: false);

      final logs = List<Map<String, dynamic>>.from(response);
      
      int diberikan = 0;
      int ditukar = 0;

      for (var log in logs) {
        final t = log['tipe'];
        final int amt = (log['jumlah'] as num).toInt().abs();
        final int sebelum = (log['saldo_sebelum'] as num?)?.toInt() ?? 0;
        final int sesudah = (log['saldo_sesudah'] as num?)?.toInt() ?? 0;
        
        // Logika mutlak membandingkan saldo
        bool isMasuk = false;
        if (t == 'earned' || t == 'reversed') {
          isMasuk = true;
        } else if (t == 'adjusted') {
          isMasuk = sesudah >= sebelum; // Jika bertambah, berarti masuk
        } else {
          isMasuk = false;
        }

        if (isMasuk) {
          diberikan += amt;
        } else {
          ditukar += amt;
        }
      }

      if (mounted) {
        setState(() {
          _logs = logs;
          _totalDiberikan = diberikan;
          _totalDitukar = ditukar;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading coins: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String isoStr) {
    try {
      final d = DateTime.parse(isoStr).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '-';
    }
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _DS.blue))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _DS.surface,
                    border: const Border(bottom: BorderSide(color: _DS.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Koin Masuk', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('+$_totalDiberikan', style: TextStyle(color: Colors.green.shade700, fontSize: 20, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.orange.shade200)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Koin Keluar', style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600)),
                              const SizedBox(height: 4),
                              Text('-$_totalDitukar', style: TextStyle(color: Colors.orange.shade700, fontSize: 20, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final log = _logs[i];
                      final tipe = log['tipe'];
                      final int amount = (log['jumlah'] as num).toInt().abs();
                      final int sebelum = (log['saldo_sebelum'] as num?)?.toInt() ?? 0;
                      final int sesudah = (log['saldo_sesudah'] as num?)?.toInt() ?? 0;
                      
                      // Logika Mutlak Masuk/Keluar
                      bool isMasuk = false;
                      if (tipe == 'earned' || tipe == 'reversed') {
                        isMasuk = true;
                      } else if (tipe == 'adjusted') {
                        isMasuk = sesudah >= sebelum;
                      } else {
                        isMasuk = false;
                      }

                      final color = isMasuk ? Colors.green : Colors.orange;
                      final sign = isMasuk ? '+' : '-';
                      final custName = log['customers']?['profiles']?['nama_lengkap'] ?? 'Pelanggan';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: color, size: 20),
                          ),
                          title: Text(custName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _DS.textPrimary)),
                          subtitle: Text(log['catatan'] ?? tipe, style: const TextStyle(fontSize: 12, color: _DS.textSecondary)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('$sign$amount', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
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