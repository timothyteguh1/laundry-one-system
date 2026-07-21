import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart';
import 'package:laundry_one/features/customer/screens/customer_invoice_screen.dart';

class AktivitasTab extends StatefulWidget {
  final List<Map<String, dynamic>> historyOrders;
  final String? customerId;
  final Future<void> Function() onRefresh;

  final int initialFilter;
  final bool isStandalone;

  const AktivitasTab({
    super.key,
    this.historyOrders = const [],
    this.customerId,
    required this.onRefresh,
    this.initialFilter = 0,
    this.isStandalone = false,
  });

  @override
  State<AktivitasTab> createState() => _AktivitasTabState();
}

class _AktivitasTabState extends State<AktivitasTab> {
  final _supabase = Supabase.instance.client;
  late int _selectedFilter;

  List<Map<String, dynamic>> _pointsHistory = [];
  bool _isLoadingPoin = false;

  // ==========================================
  // VARIABEL PAGINASI (INFINITE SCROLL)
  // ==========================================
  int _pagePoin = 0;
  final int _perPage = 15;
  bool _hasMorePoin = true;
  bool _isLoadingMorePoin = false;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    if (_selectedFilter == 1) _loadPointsHistory();
  }

  // ==========================================
  // FUNGSI LOAD DATA AWAL (HALAMAN 1)
  // ==========================================
  Future<void> _loadPointsHistory({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _pagePoin = 0;
        _hasMorePoin = true;
      });
    } else {
      setState(() => _isLoadingPoin = true);
      _pagePoin = 0;
      _hasMorePoin = true;
    }

    try {
      String? targetCustomerId = widget.customerId;
      if (targetCustomerId == null) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          final custData = await _supabase
              .from('customers')
              .select('id')
              .eq('profile_id', userId)
              .maybeSingle();
          targetCustomerId = custData?['id'];
        }
      }

      if (targetCustomerId == null) throw Exception('Customer ID not found');

      final data = await _supabase
          .from('points_ledger')
          .select('tipe, jumlah, created_at, catatan, saldo_sesudah')
          .eq('customer_id', targetCustomerId)
          .order('created_at', ascending: false)
          .range(0, _perPage - 1); // <--- [UPDATE] Batasi hanya 15 data pertama

      if (mounted) {
        setState(() {
          _pointsHistory = List<Map<String, dynamic>>.from(data);
          if (data.length < _perPage)
            _hasMorePoin = false; // Matikan jika data sudah habis
          _isLoadingPoin = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingPoin = false);
    }
  }

  // ==========================================
  // FUNGSI LOAD DATA TAMBAHAN (SCROLL BAWAH)
  // ==========================================
  Future<void> _loadMorePointsHistory() async {
    if (_isLoadingMorePoin || !_hasMorePoin) return;
    setState(() => _isLoadingMorePoin = true);

    try {
      _pagePoin++;
      final start = _pagePoin * _perPage;
      final end = start + _perPage - 1;

      String? targetCustomerId = widget.customerId;
      if (targetCustomerId == null) {
        final userId = _supabase.auth.currentUser?.id;
        if (userId != null) {
          final custData = await _supabase
              .from('customers')
              .select('id')
              .eq('profile_id', userId)
              .maybeSingle();
          targetCustomerId = custData?['id'];
        }
      }

      final data = await _supabase
          .from('points_ledger')
          .select('tipe, jumlah, created_at, catatan, saldo_sesudah')
          .eq('customer_id', targetCustomerId!)
          .order('created_at', ascending: false)
          .range(start, end); // <--- [UPDATE] Tarik data rentang selanjutnya

      if (mounted) {
        setState(() {
          final newData = List<Map<String, dynamic>>.from(data);
          if (newData.length < _perPage)
            _hasMorePoin = false; // Matikan jika sudah habis
          _pointsHistory.addAll(
            newData,
          ); // Sambungkan data lama dengan data baru
          _isLoadingMorePoin = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMorePoin = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              widget.isStandalone ? 16 : 24,
              24,
              16,
            ),
            child: const Text(
              'Riwayat Aktivitas',
              style: TextStyle(
                color: CustomerTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: CustomerTheme.border.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleBtn(
                    0,
                    'Cucian Saya',
                    Icons.local_laundry_service_rounded,
                  ),
                  _buildToggleBtn(1, 'Mutasi Poin', Icons.stars_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: _selectedFilter == 0
                  ? KeyedSubtree(
                      key: const ValueKey(0),
                      child: _buildListCucian(),
                    )
                  : KeyedSubtree(
                      key: const ValueKey(1),
                      child: _buildListPoin(),
                    ),
            ),
          ),
        ],
      ),
    );

    if (widget.isStandalone) {
      return Scaffold(
        backgroundColor: CustomerTheme.ground,
        appBar: AppBar(
          backgroundColor: CustomerTheme.ground,
          foregroundColor: CustomerTheme.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: content,
      );
    }

    return content;
  }

  Widget _buildToggleBtn(int index, String title, IconData icon) {
    final isActive = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
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
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? CustomerTheme.primary
                    : CustomerTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive
                      ? CustomerTheme.primary
                      : CustomerTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCucian() {
    if (widget.historyOrders.isEmpty && widget.isStandalone) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Akses lewat Tab Bawah',
        sub: 'Silakan akses Cucian Saya melalui menu tab Aktivitas di bawah.',
      );
    }

    if (widget.historyOrders.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        message: 'Belum ada riwayat cucian',
        sub: 'Cucian yang sudah selesai atau diambil akan tampil di sini.',
      );
    }

    return RefreshIndicator(
      color: CustomerTheme.primary,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
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
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (ctx, anim, secAnim) =>
                        CustomerInvoiceScreen(order: order),
                    transitionsBuilder: (ctx, anim, secAnim, child) =>
                        FadeTransition(opacity: anim, child: child),
                  ),
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
      return const Center(child: ModernSpinner());
    }

    if (_pointsHistory.isEmpty) {
      return const EmptyState(
        icon: Icons.stars_rounded,
        message: 'Belum ada mutasi poin',
        sub: 'Lakukan transaksi untuk mulai mengumpulkan poin.',
      );
    }

    // [UPDATE] Membungkus dengan NotificationListener untuk mendeteksi scroll
    return NotificationListener<ScrollNotification>(
      onNotification: (ScrollNotification scrollInfo) {
        // Jika belum loading, masih ada data, dan scroll sudah hampir mentok bawah (sisa 100px)
        if (!_isLoadingMorePoin &&
            _hasMorePoin &&
            scrollInfo.metrics.pixels >=
                scrollInfo.metrics.maxScrollExtent - 100) {
          _loadMorePointsHistory();
        }
        return false;
      },
      child: RefreshIndicator(
        color: CustomerTheme.primary,
        onRefresh: () => _loadPointsHistory(isRefresh: true),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          // [UPDATE] Tambah 1 kotak ekstra di bawah untuk tempat loading spinner
          itemCount: _pointsHistory.length + (_hasMorePoin ? 1 : 0),
          itemBuilder: (context, index) {
            // Render spinner mini jika berada di index paling terakhir
            if (index == _pointsHistory.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: _isLoadingMorePoin
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: CustomerTheme.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const SizedBox(),
                ),
              );
            }

            final poin = _pointsHistory[index];
            final int nominal = (poin['jumlah'] as num?)?.toInt() ?? 0;
            final isMasuk = nominal > 0;
            final absNominal = nominal.abs();
            final nominalStr = isMasuk ? '+ $absNominal' : '- $absNominal';

            final iconData = isMasuk
                ? Icons.arrow_downward_rounded
                : Icons.arrow_upward_rounded;
            final color = isMasuk ? CustomerTheme.primary : Colors.red;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: CustomerTheme.menuDecoration,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, color: color, size: 20),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poin['catatan'] ?? _getLabelTipe(poin['tipe']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: CustomerTheme.textPrimary,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(poin['created_at']),
                          style: const TextStyle(
                            color: CustomerTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        nominalStr,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: color,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'Sisa: ${poin['saldo_sesudah'] ?? '-'}',
                        style: const TextStyle(
                          color: CustomerTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
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
      DateTime d = DateTime.parse(iso);
      if (!iso.endsWith('Z') && !iso.contains('+')) {
        d = DateTime.parse('${iso}Z');
      }
      d = d.toLocal();
      return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} WIB';
    } catch (e) {
      return '-';
    }
  }
}
