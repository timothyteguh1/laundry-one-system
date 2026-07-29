import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/core/tokens/app_tokens.dart'; 

class ReportProductSalesScreen extends StatefulWidget {
  const ReportProductSalesScreen({super.key});

  @override
  State<ReportProductSalesScreen> createState() => _ReportProductSalesScreenState();
}

class _ReportProductSalesScreenState extends State<ReportProductSalesScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  String? _errorMessage;

  DateTime _startDate = DateTime.now(); 
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

  String _formatDateStr(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year.toString().substring(2)}';
  }

  Future<void> _pickDate() async {
    final picked = await showDateRangePicker(
      context: context, 
      firstDate: DateTime(2023), 
      lastDate: DateTime.now(), 
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTokens.primarySeed)
        ), 
        child: child!
      ),
    );
    if (picked != null) {
      setState(() { 
        _startDate = picked.start; 
        _endDate = picked.end; 
      });
      await _loadData(); 
    }
  }

  // Logika Bisnis Asli Tidak Diubah Sama Sekali
  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final startLocal = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0);
      final endLocal = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59);

      final startStr = startLocal.toUtc().toIso8601String();
      final endStr = endLocal.toUtc().toIso8601String();

      final res = await _supabase.from('orders')
          .select('id, total_harga, order_items(jumlah, harga_satuan, subtotal, services(nama))')
          .gte('created_at', startStr)
          .lte('created_at', endStr)
          .neq('status', 'dibatalkan');

      double total = 0;
      int transaksi = res.length;
      Map<String, Map<String, dynamic>> groupedItems = {};

      for (var order in res) {
        total += (order['total_harga'] as num?)?.toDouble() ?? 0;
        final items = order['order_items'] as List<dynamic>? ?? [];
        
        for (var item in items) {
          String nama = 'Item Terhapus';
          if (item['services'] != null) {
            if (item['services'] is Map) {
              nama = item['services']['nama'] ?? nama;
            } else if (item['services'] is List && item['services'].isNotEmpty) {
              nama = item['services'][0]['nama'] ?? nama;
            }
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
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTokens.ground,
      appBar: AppBar(
        title: Text('Laporan Penjualan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.surface)),
        backgroundColor: AppTokens.navy, 
        foregroundColor: AppTokens.surface, 
        elevation: 0,
        actions: [
          Semantics(
            button: true,
            label: 'Pilih Rentang Tanggal',
            child: IconButton(
              icon: const Icon(Icons.calendar_month_rounded), 
              onPressed: _pickDate,
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48), // Aksesibilitas tap target
            ),
          )
        ],
      ),
      // LayoutBuilder untuk memastikan tampilan bagus di Tablet Kasir
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 600;
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isTablet ? 800 : double.infinity),
              child: _buildBody(textTheme),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    // 1. STATE: LOADING
    if (_isLoading) {
      return const _ReportSkeletonShimmer();
    }

    // 2. STATE: ERROR
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
              const SizedBox(height: AppTokens.space16),
              Text('Gagal memuat laporan', style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: AppTokens.textPrimary)),
              const SizedBox(height: AppTokens.space8),
              Text(_errorMessage!, textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: AppTokens.textSecondary)),
              const SizedBox(height: AppTokens.space24),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTokens.primarySeed, foregroundColor: AppTokens.surface),
                onPressed: _loadData,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold)),
              )
            ],
          ),
        ),
      );
    }

    // 3. STATE: DATA READY
    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTokens.blue,
      backgroundColor: AppTokens.surface,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(AppTokens.space20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SalesSummaryCard(
              totalPenjualan: _totalPenjualan,
              rataRata: _rataRata,
              jumlahTransaksi: _jumlahTransaksi,
              textTheme: textTheme,
            ),
            
            const SizedBox(height: AppTokens.space32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Ringkasan Terlaris', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.textPrimary)),
                Text('${_formatDateStr(_startDate)} s/d ${_formatDateStr(_endDate)}', style: textTheme.labelSmall?.copyWith(color: AppTokens.blue, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: AppTokens.space16),

            // 4. STATE: EMPTY
            if (_ringkasanItem.isEmpty)
              Padding(
                padding: const EdgeInsets.all(AppTokens.space32), 
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.inventory_2_outlined, size: 64, color: AppTokens.border),
                      const SizedBox(height: AppTokens.space16),
                      Text('Belum ada penjualan pada periode ini.', style: textTheme.bodyMedium?.copyWith(color: AppTokens.textSecondary, fontWeight: FontWeight.w600)),
                    ],
                  )
                )
              )
            else
              // OPTIMASI: Membungkus list dinamis agar render lebih cepat saat scroll
              RepaintBoundary( 
                child: ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ringkasanItem.length,
                  itemBuilder: (ctx, i) => _SalesItemCard(item: _ringkasanItem[i], textTheme: textTheme),
                ),
              ),
            const SizedBox(height: AppTokens.space48),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// WIDGETS EKSTRAKSI AGAR BUILD() TIDAK PANJANG
// ============================================================

class _SalesSummaryCard extends StatelessWidget {
  final double totalPenjualan;
  final double rataRata;
  final int jumlahTransaksi;
  final TextTheme textTheme;

  const _SalesSummaryCard({
    required this.totalPenjualan,
    required this.rataRata,
    required this.jumlahTransaksi,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTokens.space24, horizontal: AppTokens.space16),
      decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppTokens.radius20), border: Border.all(color: AppTokens.border, width: 1.5), boxShadow: AppTokens.cardShadow),
      child: Column(
        children: [
          Text('Total Penjualan', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: AppTokens.textSecondary)),
          const SizedBox(height: AppTokens.space8),
          Text('Rp ${AppTokens.formatRupiah(totalPenjualan)}', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.blue, letterSpacing: -0.5)),
          const SizedBox(height: AppTokens.space24),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Rata-Rata / Hari', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTokens.textSecondary)), 
                    const SizedBox(height: AppTokens.space4), 
                    Text('Rp ${AppTokens.formatRupiah(rataRata)}', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.textPrimary))
                  ]
                )
              ),
              Container(width: 1, height: 40, color: AppTokens.border),
              Expanded(
                child: Column(
                  children: [
                    Text('Jml. Transaksi', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600, color: AppTokens.textSecondary)), 
                    const SizedBox(height: AppTokens.space4), 
                    Text('$jumlahTransaksi', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.textPrimary))
                  ]
                )
              ),
            ],
          )
        ],
      ),
    );
  }
}

// Diubah menjadi StatefulWidget agar bisa ada animasi ditekan (Micro-interaction)
class _SalesItemCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final TextTheme textTheme;

  const _SalesItemCard({required this.item, required this.textTheme});

  @override
  State<_SalesItemCard> createState() => _SalesItemCardState();
}

class _SalesItemCardState extends State<_SalesItemCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTokens.space12),
          padding: const EdgeInsets.all(AppTokens.space16),
          decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppTokens.radius16), border: Border.all(color: AppTokens.border, width: 1.5), boxShadow: AppTokens.cardShadow),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.item['nama'], style: widget.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.textPrimary)),
                    const SizedBox(height: AppTokens.space4),
                    Text('Rp ${AppTokens.formatRupiah(widget.item['harga_satuan'])} x${widget.item['qty']} Pcs', style: widget.textTheme.labelMedium?.copyWith(color: AppTokens.textSecondary, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Text('Rp ${AppTokens.formatRupiah(widget.item['subtotal'])}', style: widget.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: AppTokens.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

// Widget Loading Kerangka Halus (Pengganti Spinner)
class _ReportSkeletonShimmer extends StatefulWidget {
  const _ReportSkeletonShimmer();

  @override
  State<_ReportSkeletonShimmer> createState() => _ReportSkeletonShimmerState();
}

class _ReportSkeletonShimmerState extends State<_ReportSkeletonShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(_anim),
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space20),
        child: Column(
          children: [
            Container(height: 180, decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppTokens.radius20), border: Border.all(color: AppTokens.border))),
            const SizedBox(height: AppTokens.space32),
            Container(height: 70, decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppTokens.radius16), border: Border.all(color: AppTokens.border))),
            const SizedBox(height: AppTokens.space12),
            Container(height: 70, decoration: BoxDecoration(color: AppTokens.surface, borderRadius: BorderRadius.circular(AppTokens.radius16), border: Border.all(color: AppTokens.border))),
          ],
        ),
      ),
    );
  }
}