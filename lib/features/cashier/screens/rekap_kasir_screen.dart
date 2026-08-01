import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/core/services/app_state.dart';

// ============================================================
// DESIGN SYSTEM - Sesuai dengan Laundry One POS
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
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.09),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];
}

class RekapPendapatanScreen extends StatefulWidget {
  const RekapPendapatanScreen({super.key});

  @override
  State<RekapPendapatanScreen> createState() => _RekapPendapatanScreenState();
}

class _RekapPendapatanScreenState extends State<RekapPendapatanScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;

  // State Filter Tanggal (Default 30 Hari)
  late DateTime _startDate;
  late DateTime _endDate;

  // State Filter Kasir (Khusus Admin)
  List<Map<String, dynamic>> _kasirList = [];
  String? _selectedKasirId;
  String? _selectedKasirName;

  // State Data Grouping
  final Map<String, Map<String, double>> _dailyData = {};
  final List<String> _sortedDates = [];

  // State Grand Total (Untuk Header)
  double _totalCash = 0;
  double _totalNonCash = 0;
  double _totalSemua = 0;

  String _userRole = 'cashier';

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _endDate = now;
    _startDate = now.subtract(const Duration(days: 30));
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _dailyData.clear();
      _sortedDates.clear();
      _totalCash = 0;
      _totalNonCash = 0;
      _totalSemua = 0;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Cek Role User Saat Ini
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      _userRole = profile['role'] ?? 'cashier';

      // [FITUR BARU]: Tarik daftar kasir jika super_admin dan list masih kosong
      if (_userRole == 'super_admin' && _kasirList.isEmpty) {
        final kasirData = await _supabase
            .from('profiles')
            .select('id, nama_lengkap')
            .eq('role', 'cashier')
            .order('nama_lengkap', ascending: true);
        
        _kasirList = List<Map<String, dynamic>>.from(kasirData);
      }

      // 2. Siapkan Rentang Waktu
      final startIso = DateTime(
        _startDate.year,
        _startDate.month,
        _startDate.day,
        0,
        0,
        0,
      ).toUtc().toIso8601String();
      final endIso = DateTime(
        _endDate.year,
        _endDate.month,
        _endDate.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

       // 3. Bangun Query Efisien (Hanya ke order_payments)
       final branchId = await AppState.getBranchId();

       var query = _supabase
           .from('order_payments')
           .select('jumlah, metode, created_at, orders!inner(branch_id)');

       // [LOGIKA UTAMA FILTER KASIR]
       if (_userRole != 'super_admin') {
         // Jika Kasir: Kunci paksa ke ID dia sendiri
         query = query.eq('diterima_oleh', user.id);
       } else if (_userRole == 'super_admin' && _selectedKasirId != null) {
         // Jika Admin dan memilih kasir tertentu dari dropdown
         query = query.eq('diterima_oleh', _selectedKasirId!);
       }

       // [MULTI-BRANCH]: Filter berdasarkan cabang (kasir) atau cabang yang dipilih (super admin)
       if (branchId != null) {
         query = query.eq('orders.branch_id', branchId);
       }

       // Akhiri query dengan rentang tanggal dan sorting
       final payments = await query
           .gte('created_at', startIso)
           .lte('created_at', endIso)
           .order('created_at', ascending: false);

      const months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
      ];

      // 4. Logika Grouping
      for (var p in payments) {
        final date = DateTime.parse(p['created_at']).toLocal();
        final dateStr =
            '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';

        if (!_dailyData.containsKey(dateStr)) {
          _dailyData[dateStr] = {'cash': 0, 'non_cash': 0, 'total': 0};
          _sortedDates.add(dateStr);
        }

        final amount = (p['jumlah'] as num).toDouble();

        // Tambah ke Grand Total Header
        _totalSemua += amount;

        // Tambah ke Total Harian
        _dailyData[dateStr]!['total'] = _dailyData[dateStr]!['total']! + amount;

        if (p['metode'] == 'cash') {
          _dailyData[dateStr]!['cash'] = _dailyData[dateStr]!['cash']! + amount;
          _totalCash += amount;
        } else {
          _dailyData[dateStr]!['non_cash'] =
              _dailyData[dateStr]!['non_cash']! + amount;
          _totalNonCash += amount;
        }
      }
    } catch (e) {
      debugPrint("Gagal menarik laporan: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Pemilih Tanggal Kalender
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
      HapticFeedback.lightImpact();
      _fetchData();
    }
  }

  String _formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  String _formatDateStr(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Penentuan Judul Header Dinamis
    String judulHeader = 'Total Pendapatan Anda';
    if (_userRole == 'super_admin') {
      judulHeader = _selectedKasirId == null
          ? 'Total Pendapatan (Semua Kasir)'
          : 'Total Pendapatan (${_selectedKasirName ?? 'Kasir'})';
    }

    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text(
          'Rekap Kasir',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ==============================
          // HEADER KESELURUHAN & FILTER
          // ==============================
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_DS.navy, _DS.blue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(28),
              ),
              boxShadow: _DS.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        judulHeader,
                        style: const TextStyle(
                          color: _DS.sky,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (_userRole == 'super_admin')
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'ADMIN MODE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatRupiah(_totalSemua),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 20),

                // Rincian Grand Total Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cash (Tunai)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _formatRupiah(_totalCash),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Non-Cash (TF/QRIS)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 11,
                            ),
                          ),
                          Text(
                            _formatRupiah(_totalNonCash),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tombol Filter Tanggal
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${_formatDateStr(_startDate)} - ${_formatDateStr(_endDate)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // [FITUR BARU]: Dropdown Pilih Kasir Khusus Admin
                if (_userRole == 'super_admin') ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        isExpanded: true,
                        dropdownColor: _DS.navy,
                        icon: const Icon(Icons.person_outline_rounded, color: Colors.white, size: 20),
                        value: _selectedKasirId,
                        hint: const Text(
                          'Semua Kasir', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Semua Kasir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                          ..._kasirList.map((k) {
                            return DropdownMenuItem<String?>(
                              value: k['id'],
                              child: Text(k['nama_lengkap'] ?? 'Kasir', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            );
                          }),
                        ],
                        onChanged: (val) {
                          setState(() {
                            _selectedKasirId = val;
                            if (val == null) {
                              _selectedKasirName = null;
                            } else {
                              final kasir = _kasirList.firstWhere((k) => k['id'] == val);
                              _selectedKasirName = kasir['nama_lengkap'];
                            }
                          });
                          HapticFeedback.lightImpact();
                          _fetchData(); // Load ulang data dengan filter baru
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ==============================
          // LIST REKAP HARIAN BAWAH
          // ==============================
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _DS.blue),
                  )
                : _sortedDates.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada pendapatan pada rentang filter ini.',
                      style: TextStyle(color: _DS.textHint),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    itemCount: _sortedDates.length,
                    itemBuilder: (ctx, i) {
                      final dateStr = _sortedDates[i];
                      final data = _dailyData[dateStr]!;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _DS.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _DS.border),
                          boxShadow: _DS.softShadow,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: _DS.textPrimary,
                                  ),
                                ),
                                Text(
                                  _formatRupiah(data['total']!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: _DS.blue,
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: _DS.border, height: 1),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _StatPill(
                                    title: 'Setoran Tunai',
                                    amount: _formatRupiah(data['cash']!),
                                    icon: Icons.payments_rounded,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _StatPill(
                                    title: 'Non-Tunai',
                                    amount: _formatRupiah(data['non_cash']!),
                                    icon: Icons.qr_code_scanner_rounded,
                                    color: Colors.purple,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// Komponen Kotak Rincian
class _StatPill extends StatelessWidget {
  final String title;
  final String amount;
  final IconData icon;
  final MaterialColor color;

  const _StatPill({
    required this.title,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color.shade700, size: 18),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: color.shade800,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              color: color.shade900,
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }
}