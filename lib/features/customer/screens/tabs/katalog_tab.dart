import 'dart:async'; // TAMBAHAN: Wajib untuk fungsi Timer
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
  Set<String> _usedRewardIds = {}; 
  
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
      Set<String> usedIds = {};
      
      if (widget.customerId != null) {
        final resVouchers = await _supabase
            .from('reward_redemptions')
            .select('*, rewards_catalog(nama)')
            .eq('customer_id', widget.customerId!);

        final nowUtc = DateTime.now().toUtc();
        
        for (var v in resVouchers) {
          if (v['status'] == 'dipakai') {
            usedIds.add(v['reward_id']); 
          } else if (v['status'] == 'aktif') {
            final expiredAtUtc = DateTime.parse(v['berlaku_sampai']).toUtc();
            if (nowUtc.isAfter(expiredAtUtc)) {
              // Jika sudah lewat waktunya, hanguskan di database
              // Ini akan otomatis memicu Trigger DB untuk refund poin!
              await _supabase.from('reward_redemptions').update({'status': 'expired'}).eq('id', v['id']);
            } else {
              validVouchers.add(v);
            }
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _rewards = resRewards;
          _services = resServices;
          _activeVouchers = validVouchers;
          _usedRewardIds = usedIds;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _tukarPoin(Map<String, dynamic> reward) async {
    if (widget.customerId == null) return;
    
    if (_usedRewardIds.contains(reward['id'])) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda sudah pernah menggunakan promo ini sebelumnya!'), backgroundColor: Colors.orange));
      return;
    }

    if (_activeVouchers.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Limit Tercapai! Maksimal hanya boleh memiliki 2 voucher aktif.'), backgroundColor: Colors.orange));
      return;
    }

    final hasActive = _activeVouchers.any((v) => v['reward_id'] == reward['id']);
    if (hasActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anda masih memiliki voucher jenis ini yang sedang aktif!'), backgroundColor: Colors.orange));
      return;
    }

    final poinDibutuhkan = reward['poin_dibutuhkan'] as int;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Tukar Poin?', style: TextStyle(fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary)),
        content: Text('Tukar $poinDibutuhkan koin untuk "${reward['nama']}"?\n\nVoucher hanya berlaku selama 5 Menit!'),
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
      final currentDbPoin = custData['poin_saldo'] as int;
      
      if (currentDbPoin < poinDibutuhkan) throw Exception('Poin di database tidak mencukupi.');

      final randomCode = 'VCH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      
      final expiredTimeUtc = DateTime.now().toUtc().add(const Duration(minutes: 5)).toIso8601String();

      await _supabase.from('reward_redemptions').insert({
        'customer_id': widget.customerId,
        'reward_id': reward['id'],
        'kode_voucher': randomCode,
        'berlaku_sampai': expiredTimeUtc, 
        'poin_digunakan': poinDibutuhkan,
      });

      final newSaldo = currentDbPoin - poinDibutuhkan;
      await _supabase.from('points_ledger').insert({
        'customer_id': widget.customerId,
        'tipe': 'redeemed',
        'jumlah': poinDibutuhkan,
        'saldo_sebelum': currentDbPoin,
        'saldo_sesudah': newSaldo,
        'catatan': 'Tukar voucher: ${reward['nama']}'
      });

      await _supabase.from('customers').update({'poin_saldo': newSaldo}).eq('id', widget.customerId!);

      await _fetchData();
      await widget.onRefresh();

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Berhasil! Tunjukkan kode ke Kasir sebelum hangus.'), backgroundColor: Colors.green));
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

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Rewards & Katalog', style: TextStyle(color: CustomerTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
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
                  _buildToggleBtn(0, 'Tukar Poin', Icons.card_giftcard_rounded),
                  _buildToggleBtn(1, 'Daftar Harga', Icons.list_alt_rounded),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: CustomerTheme.primary))
                : _selectedFilter == 0 ? _buildListRewards() : _buildListHarga(),
          )
        ],
      ),
    );
  }

  Widget _buildToggleBtn(int index, String title, IconData icon) {
    final isActive = _selectedFilter == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = index),
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

  Widget _buildListRewards() {
    final isLimitReached = _activeVouchers.length >= 2;

    return Stack(
      children: [
        RefreshIndicator(
          color: CustomerTheme.primary,
          onRefresh: _fetchData,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              if (_activeVouchers.isNotEmpty) ...[
                const Text('Voucher Aktif Saya', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CustomerTheme.textPrimary)),
                const SizedBox(height: 12),
                
                // 👇 DI SINI KITA GUNAKAN WIDGET TIMER KITA 👇
                ..._activeVouchers.map((v) => ActiveVoucherCard(
                  voucherData: v,
                  onExpired: () async {
                    // Ketika waktu habis, jalankan fetch data agar UI dan Database terupdate otomatis!
                    await _fetchData();
                    await widget.onRefresh(); // Supaya poin di header Beranda juga ikut ter-update
                  },
                )),
                
                const Divider(height: 32, color: CustomerTheme.border, thickness: 1.5),
              ],

              const Text('Katalog Hadiah', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: CustomerTheme.textPrimary)),
              const SizedBox(height: 12),
              if (_rewards.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Belum ada katalog hadiah.')))
              else
                ..._rewards.map((r) {
                  final poinDibutuhkan = r['poin_dibutuhkan'] ?? 0;
                  final bisaDitebus = widget.currentPoin >= poinDibutuhkan;
                  
                  final isAlreadyUsed = _usedRewardIds.contains(r['id']);
                  final isAlreadyActive = _activeVouchers.any((v) => v['reward_id'] == r['id']);
                  final isButtonDisabled = !bisaDitebus || isAlreadyActive || isLimitReached || isAlreadyUsed;

                  String btnText;
                  if (isAlreadyUsed) {
                    btnText = 'Pernah Dipakai';
                  } else if (isAlreadyActive) {
                    btnText = 'Sedang Aktif';
                  } else if (isLimitReached) {
                    btnText = 'Limit Tercapai';
                  } else if (!bisaDitebus) {
                    btnText = 'Butuh $poinDibutuhkan Koin';
                  } else {
                    btnText = 'Tukar $poinDibutuhkan Koin';
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
                          child: const Icon(Icons.discount_rounded, color: CustomerTheme.primary, size: 32),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: CustomerTheme.textPrimary)),
                              const SizedBox(height: 4),
                              Text(r['deskripsi'] ?? '', style: const TextStyle(fontSize: 12, color: CustomerTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
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
        ),
        if (_isProcessing)
          Container(color: Colors.white.withOpacity(0.5), child: const Center(child: CircularProgressIndicator(color: CustomerTheme.primary)))
      ],
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
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: CustomerTheme.menuDecoration,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: CustomerTheme.ground, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.local_laundry_service_rounded, color: CustomerTheme.textSecondary),
              ),
              title: Text(s['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: CustomerTheme.textPrimary)),
              subtitle: Text('Estimasi: ${s['estimasi_hari']} hari', style: const TextStyle(fontSize: 12, color: CustomerTheme.textHint)),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_formatCurrency(s['harga_per_satuan'] ?? 0), style: const TextStyle(fontWeight: FontWeight.w800, color: CustomerTheme.primary, fontSize: 14)),
                  Text('/ ${s['satuan']}', style: const TextStyle(fontSize: 10, color: CustomerTheme.textSecondary)),
                ],
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
    // Ambil waktu dari database yang sudah dalam format UTC
    final expiredAtUtc = DateTime.parse(widget.voucherData['berlaku_sampai']).toUtc();
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final nowUtc = DateTime.now().toUtc();
      
      if (nowUtc.isAfter(expiredAtUtc)) {
        // Waktu habis! Matikan timer dan panggil fungsi onExpired (fetch data)
        _timer?.cancel();
        widget.onExpired();
      } else {
        // Hitung selisih waktu untuk ditampilkan
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
    _timer?.cancel(); // Sangat penting agar tidak memory leak
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Format timer (04:59)
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
                Text(widget.voucherData['rewards_catalog']?['nama'] ?? 'Voucher', style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(widget.voucherData['kode_voucher'] ?? '-', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                const SizedBox(height: 4),
                // Tampilkan hitung mundur yang berjalan
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