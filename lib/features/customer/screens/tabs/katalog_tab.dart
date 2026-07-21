import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/customer/widgets/customer_shared_widgets.dart';

class KatalogTab extends StatefulWidget {
  final String? customerId;
  final int currentPoin;
  final Future<void> Function() onRefresh;

  const KatalogTab({
    super.key,
    required this.customerId,
    required this.currentPoin,
    required this.onRefresh,
  });

  @override
  State<KatalogTab> createState() => _KatalogTabState();
}

class _KatalogTabState extends State<KatalogTab> {
  final _supabase = Supabase.instance.client;
  
  int _selectedFilter = 0; 
  List<Map<String, dynamic>> _rewards = [];
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _activeVouchers = []; 
  
  Map<String, DateTime> _lastUsedRewards = {}; 
  Map<String, DateTime> _lastExpiredRewards = {}; 
  
  bool _isLoading = true;
  bool _isProcessing = false; 

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final resRewards = await _supabase.from('rewards_catalog').select().eq('is_active', true).order('poin_dibutuhkan', ascending: true);
      final resServices = await _supabase.from('services').select().eq('is_active', true).order('nama', ascending: true);
      
      List<Map<String, dynamic>> validVouchers = [];
      Map<String, DateTime> usedDates = {};
      Map<String, DateTime> expiredDates = {}; 
      
      if (widget.customerId != null) {
        final resVouchers = await _supabase
            .from('reward_redemptions')
            .select('*, rewards_catalog(nama, tipe_reward)')
            .eq('customer_id', widget.customerId!);

        final nowUtc = DateTime.now().toUtc();
        
        for (var v in resVouchers) {
          final safeRewardId = v['reward_id']?.toString() ?? '';

          if (v['status'] == 'dipakai' && v['dipakai_at'] != null) {
            final usedAt = DateTime.parse(v['dipakai_at']).toUtc();
            final current = usedDates[safeRewardId];
            if (current == null || usedAt.isAfter(current)) {
              usedDates[safeRewardId] = usedAt;
            }
          } 
          else if (v['status'] == 'aktif' || (v['status'] == 'expired' && v['berlaku_sampai'] != null)) {
            final expiredAtUtc = DateTime.parse(v['berlaku_sampai']).toUtc();
            
            if (nowUtc.isAfter(expiredAtUtc)) {
              final currentExp = expiredDates[safeRewardId];
              if (currentExp == null || expiredAtUtc.isAfter(currentExp)) {
                expiredDates[safeRewardId] = expiredAtUtc;
              }
              
              if (v['status'] == 'aktif') {
                _supabase.from('reward_redemptions').update({'status': 'expired'}).eq('id', v['id']).catchError((_) {});
              }
              
            } else {
              if (v['status'] == 'aktif') {
                validVouchers.add(v);
              }
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _rewards = resRewards;
          _services = resServices;
          _activeVouchers = validVouchers;
          _lastUsedRewards = usedDates;
          _lastExpiredRewards = expiredDates; 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _tukarPoin(Map<String, dynamic> reward) async {
    if (widget.customerId == null) return;
    
    final bool isBarang = reward['tipe_reward'] == 'gratis_layanan';
    final String safeRewardId = reward['id']?.toString() ?? '';
    final poinDibutuhkan = int.tryParse(reward['poin_dibutuhkan']?.toString() ?? '0') ?? 0;
    final namaReward = reward['nama']?.toString() ?? 'Hadiah';

    if (!isBarang) {
      if (_lastUsedRewards.containsKey(safeRewardId)) {
        final lastUsed = _lastUsedRewards[safeRewardId]!;
        final cooldownEnd = lastUsed.add(const Duration(days: 90));
        if (DateTime.now().toUtc().isBefore(cooldownEnd)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voucher ini baru bisa ditukar lagi setelah 3 bulan!'), backgroundColor: Colors.orange));
          return;
        }
      }

      if (_lastExpiredRewards.containsKey(safeRewardId)) {
        final lastExpired = _lastExpiredRewards[safeRewardId]!;
        final expCooldownEnd = lastExpired.add(const Duration(hours: 1));
        if (DateTime.now().toUtc().isBefore(expCooldownEnd)) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voucher sebelumnya hangus! Tunggu 1 jam untuk menukar lagi.'), backgroundColor: Colors.orange));
          return;
        }
      }

      if (_activeVouchers.length >= 2) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit Tercapai! Maksimal hanya boleh memiliki 2 voucher aktif.'), backgroundColor: Colors.orange));
        return;
      }
      
      if (_activeVouchers.any((v) => v['reward_id']?.toString() == safeRewardId)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda masih memiliki voucher jenis ini yang sedang aktif!'), backgroundColor: Colors.orange));
        return;
      }
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tukar Poin?', style: TextStyle(fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary)),
        content: Text(
          isBarang 
            ? 'Tukar $poinDibutuhkan koin untuk "$namaReward"?\n\nTunjukkan bukti potong koin di menu Riwayat ke Kasir untuk mengambil barang.'
            : 'Tukar $poinDibutuhkan koin untuk "$namaReward"?\n\nVoucher hanya berlaku selama 5 Menit!'
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: CustomerTheme.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: CustomerTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Ya, Tukar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      )
    );

    if (confirm != true) return;

    setState(() => _isProcessing = true);
    try {
      final custData = await _supabase.from('customers').select('poin_saldo').eq('id', widget.customerId!).single();
      final currentDbPoin = int.tryParse(custData['poin_saldo']?.toString() ?? '0') ?? 0;
      
      if (currentDbPoin < poinDibutuhkan) throw Exception('Poin di database tidak mencukupi.');

      final newSaldo = currentDbPoin - poinDibutuhkan;
      final randomCode = isBarang 
          ? 'BRG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}'
          : 'VCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      final nowUtcStr = DateTime.now().toUtc().toIso8601String();
      final expiredTimeUtc = DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

      // [PERBAIKAN]: Buat wadah untuk menangkap hasil Insert
      Map<String, dynamic> insertedVoucher;

      if (isBarang) {
        // [PERBAIKAN]: Tambahkan .select().single()
        insertedVoucher = await _supabase.from('reward_redemptions').insert({
          'customer_id': widget.customerId,
          'reward_id': safeRewardId,
          'kode_voucher': randomCode,
          'status': 'dipakai',
          'dipakai_at': nowUtcStr,
          'berlaku_sampai': nowUtcStr, 
          'poin_digunakan': poinDibutuhkan,
        }).select().single();
      } else {
        // [PERBAIKAN]: Tambahkan .select().single()
        insertedVoucher = await _supabase.from('reward_redemptions').insert({
          'customer_id': widget.customerId,
          'reward_id': safeRewardId,
          'kode_voucher': randomCode,
          'status': 'aktif',
          'berlaku_sampai': expiredTimeUtc, 
          'poin_digunakan': poinDibutuhkan,
        }).select().single();
      }

      await _supabase.from('points_ledger').insert({
        'customer_id': widget.customerId,
        'tipe': 'redeemed',
        'jumlah': -poinDibutuhkan,
        'saldo_sebelum': currentDbPoin,
        'saldo_sesudah': newSaldo,
        'redemption_id': insertedVoucher['id'], // <--- [PERBAIKAN UTAMA]: Ini benang merahnya!
        'catatan': isBarang ? 'Ambil Barang: $namaReward' : 'Tukar Voucher: $namaReward'
      });

      await _supabase.from('customers').update({'poin_saldo': newSaldo}).eq('id', widget.customerId!);

      await _fetchData();
      await widget.onRefresh();

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isBarang ? 'Berhasil! Cek Mutasi Poin dan tunjukkan ke Kasir.' : 'Berhasil! Tunjukkan kode ke Kasir.'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menukarkan: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _formatCurrency(num value) {
    final str = value.toInt().toString();
    var result = '';
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && i % 3 == 0) result = '.$result';
      result = str[str.length - 1 - i] + result;
    }
    return 'Rp $result';
  }

  // ============================================================
  // [UPDATE REVISI FINAL]: PEMISAHAN LOGIKA BARANG FISIK & DISKON
  // ============================================================
  String _getRewardDescription(Map<String, dynamic> r) {
    final tipe = r['tipe_reward']?.toString() ?? '';
    final nilai = int.tryParse(r['nilai_reward']?.toString() ?? '0') ?? 0;
    final minTx = int.tryParse(r['min_transaksi']?.toString() ?? '0') ?? 0;
    final maksD = int.tryParse(r['maks_diskon']?.toString() ?? '0') ?? 0;
    
    final deskripsiManual = r['deskripsi']?.toString() ?? '';
    
    // Bersihkan deskripsi dari string error lama database (jika telanjur tersimpan)
    String deskripsiBersih = '';
    if (deskripsiManual.isNotEmpty && !deskripsiManual.toLowerCase().contains('layanan sebesar rp 0')) {
      deskripsiBersih = deskripsiManual;
    }
    
    // 1. LOGIKA KHUSUS BARANG FISIK
    if (tipe == 'gratis_layanan') {
      if (deskripsiBersih.isNotEmpty) {
        return deskripsiBersih;
      } else {
        return 'Tukarkan koin Anda untuk mendapatkan hadiah fisik ini.';
      }
    } 
    // 2. LOGIKA KHUSUS VOUCHER DISKON
    else {
      String hasil = '';
      if (tipe == 'diskon_nominal') {
        hasil = 'Memotong tagihan sebesar ${_formatCurrency(nilai)}';
        if (minTx > 0) hasil += '\n(Min. Transaksi ${_formatCurrency(minTx)})';
      } else if (tipe == 'diskon_persen') {
        hasil = 'Diskon sebesar $nilai% dari total transaksi';
        if (maksD > 0) hasil += ' (Maks. ${_formatCurrency(maksD)})';
        if (minTx > 0) hasil += '\n(Min. Transaksi ${_formatCurrency(minTx)})';
      }

      if (deskripsiBersih.isNotEmpty) {
        return '$deskripsiBersih\n\n$hasil';
      }
      return hasil;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack( 
      children: [
        SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Katalog', style: TextStyle(color: CustomerTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded, color: Colors.amber, size: 16),
                          const SizedBox(width: 6),
                          Text('${widget.currentPoin} Koin', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.amber.shade800, fontSize: 13)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: CustomerTheme.border.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      _buildToggleBtn(0, 'Diskon', Icons.percent_rounded),
                      _buildToggleBtn(1, 'Barang', Icons.inventory_2_rounded),
                      _buildToggleBtn(2, 'Harga', Icons.list_alt_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: _isLoading 
                    ? const Center(child: ModernSpinner()) 
                    : _selectedFilter == 2 ? _buildListHarga() : _buildListRewards(),
              )
            ],
          ),
        ),
        
        if (_isProcessing)
          const GlassmorphismOverlay(message: 'Memproses Penukaran...'),
      ],
    );
  }

  Widget _buildToggleBtn(int index, String title, IconData icon) {
    final isActive = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () { HapticFeedback.selectionClick(); setState(() => _selectedFilter = index); },
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
              Icon(icon, size: 14, color: isActive ? CustomerTheme.primary : CustomerTheme.textSecondary),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? CustomerTheme.primary : CustomerTheme.textSecondary, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListRewards() {
    final bool isBarangTab = _selectedFilter == 1;
    final isLimitReached = _activeVouchers.length >= 2;

    final displayRewards = _rewards.where((r) {
      final tipe = r['tipe_reward'];
      if (isBarangTab) return tipe == 'gratis_layanan'; 
      return tipe == 'diskon_nominal' || tipe == 'diskon_persen'; 
    }).toList();

    final displayVouchers = _activeVouchers.where((v) {
      final tipe = v['rewards_catalog']?['tipe_reward'];
      return tipe == 'diskon_nominal' || tipe == 'diskon_persen';
    }).toList();

    return RefreshIndicator(
      color: CustomerTheme.primary,
      onRefresh: _fetchData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        children: [
          if (!isBarangTab && displayVouchers.isNotEmpty) ...[
            const Text('Voucher Aktif Saya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CustomerTheme.textPrimary)),
            const SizedBox(height: 12),
            
            ...displayVouchers.map((v) => ActiveVoucherCard(
              voucherData: v,
              onExpired: () async {
                await _fetchData();
                await widget.onRefresh(); 
              },
            )),
            
            const Divider(height: 32, color: CustomerTheme.border, thickness: 1.5),
          ],

          Text(isBarangTab ? 'Tukar Barang Fisik' : 'Katalog Diskon', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CustomerTheme.textPrimary)),
          const SizedBox(height: 12),
          
          if (displayRewards.isEmpty)
            Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(isBarangTab ? 'Belum ada barang fisik.' : 'Belum ada voucher diskon.')))
          else
            ...displayRewards.map((r) {
              final poinDibutuhkan = int.tryParse(r['poin_dibutuhkan']?.toString() ?? '0') ?? 0;
              final bisaDitebus = widget.currentPoin >= poinDibutuhkan;
              final String safeRewardId = r['id']?.toString() ?? '';
              final isAlreadyActive = _activeVouchers.any((v) => v['reward_id']?.toString() == safeRewardId);
              
              bool isCooldown = false;
              bool isExpiredCooldown = false;
              int daysLeft = 0;
              int minutesLeft = 0;
              
              if (!isBarangTab) {
                if (_lastUsedRewards.containsKey(safeRewardId)) {
                  final lastUsed = _lastUsedRewards[safeRewardId]!;
                  final expiryDate = lastUsed.add(const Duration(days: 90)); 
                  if (DateTime.now().toUtc().isBefore(expiryDate)) {
                    isCooldown = true;
                    daysLeft = expiryDate.difference(DateTime.now().toUtc()).inDays;
                    if (daysLeft == 0) daysLeft = 1; 
                  }
                }

                if (!isCooldown && _lastExpiredRewards.containsKey(safeRewardId)) {
                  final lastExpired = _lastExpiredRewards[safeRewardId]!;
                  final expCooldownDate = lastExpired.add(const Duration(hours: 1));
                  if (DateTime.now().toUtc().isBefore(expCooldownDate)) {
                    isExpiredCooldown = true;
                    minutesLeft = expCooldownDate.difference(DateTime.now().toUtc()).inMinutes;
                    if (minutesLeft <= 0) minutesLeft = 1;
                  }
                }
              }

              bool isButtonDisabled = !bisaDitebus;
              String btnText;

              if (isBarangTab) {
                if (!bisaDitebus) { btnText = 'Butuh $poinDibutuhkan Koin'; } else { btnText = 'Tukar $poinDibutuhkan Koin'; }
              } else {
                if (isCooldown) { 
                  btnText = 'Tersedia dlm $daysLeft hari'; 
                  isButtonDisabled = true; 
                } 
                else if (isExpiredCooldown) { 
                  btnText = 'Tunggu $minutesLeft mnt'; 
                  isButtonDisabled = true; 
                } 
                else if (isAlreadyActive) { 
                  btnText = 'Sedang Aktif'; 
                  isButtonDisabled = true; 
                } 
                else if (isLimitReached) { 
                  btnText = 'Limit Tercapai'; 
                  isButtonDisabled = true; 
                } 
                else if (!bisaDitebus) { 
                  btnText = 'Butuh $poinDibutuhkan Koin'; 
                } 
                else { 
                  btnText = 'Tukar $poinDibutuhkan Koin'; 
                }
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: CustomerTheme.cardDecoration,
                child: Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(color: CustomerTheme.primaryLight, borderRadius: BorderRadius.circular(12)),
                      child: Icon(isBarangTab ? Icons.inventory_2_rounded : Icons.discount_rounded, color: CustomerTheme.primary, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r['nama']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CustomerTheme.textPrimary)),
                          const SizedBox(height: 4),
                          Text(
                            _getRewardDescription(r), 
                            style: const TextStyle(fontSize: 12, color: CustomerTheme.textSecondary, height: 1.3), 
                            maxLines: 4, 
                            overflow: TextOverflow.ellipsis
                          ),
                          const SizedBox(height: 12),
                          
                          SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isButtonDisabled ? CustomerTheme.ground : CustomerTheme.primary,
                                foregroundColor: isButtonDisabled ? CustomerTheme.textHint : Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
                              ),
                              onPressed: (isButtonDisabled || _isProcessing) ? null : () => _tukarPoin(r),
                              child: Text(
                                btnText, 
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: isButtonDisabled ? CustomerTheme.textHint : Colors.white)
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildListHarga() {
    if (_services.isEmpty) {
      return const EmptyState(icon: Icons.list_alt_rounded, message: 'Katalog Kosong', sub: 'Daftar harga layanan belum tersedia.');
    }
    return RefreshIndicator(
      color: CustomerTheme.primary,
      onRefresh: _fetchData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        itemCount: _services.length,
        itemBuilder: (context, index) {
          final s = _services[index];
          final harga = int.tryParse(s['harga_per_satuan']?.toString() ?? '0') ?? 0;
          return FadeInAnimation( 
            delay: index * 50,
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: CustomerTheme.menuDecoration,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: CustomerTheme.ground, borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.local_laundry_service_rounded, color: CustomerTheme.textSecondary),
                ),
                title: Text(s['nama']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CustomerTheme.textPrimary)),
                subtitle: Text('Estimasi: ${s['estimasi_hari']} hari', style: const TextStyle(fontSize: 12, color: CustomerTheme.textHint)),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatCurrency(harga), style: const TextStyle(fontWeight: FontWeight.w800, color: CustomerTheme.primary, fontSize: 14)),
                    Text('/ ${s['satuan']}', style: const TextStyle(fontSize: 10, color: CustomerTheme.textSecondary)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==============================================================
// WIDGET KARTU VOUCHER KHUSUS DENGAN TIMER HITUNG MUNDUR
// ==============================================================
class ActiveVoucherCard extends StatefulWidget {
  final Map<String, dynamic> voucherData;
  final VoidCallback onExpired;

  const ActiveVoucherCard({
    super.key, 
    required this.voucherData, 
    required this.onExpired
  });

  @override
  State<ActiveVoucherCard> createState() => _ActiveVoucherCardState();
}

class _ActiveVoucherCardState extends State<ActiveVoucherCard> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    final expiredAtUtc = DateTime.parse(widget.voucherData['berlaku_sampai']).toUtc();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowUtc = DateTime.now().toUtc();
      
      if (nowUtc.isAfter(expiredAtUtc)) {
        _timer?.cancel();
        widget.onExpired();
      } else {
        if (mounted) {
          setState(() {
            _timeLeft = expiredAtUtc.difference(nowUtc);
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); 
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _timeLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _timeLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    final timeString = _timeLeft.isNegative ? "00:00" : "$minutes:$seconds";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [CustomerTheme.primary, CustomerTheme.primaryDark]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: CustomerTheme.cardShadow
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.voucherData['rewards_catalog']?['nama']?.toString() ?? 'Voucher', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(widget.voucherData['kode_voucher']?.toString() ?? '-', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, color: Colors.amber, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'Hangus dalam $timeString', 
                      style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w700)
                    ),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}