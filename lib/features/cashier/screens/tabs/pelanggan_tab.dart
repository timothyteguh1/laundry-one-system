import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart'; // TAMBAHIN kalau belum ada

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
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.09),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.05),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
  // TAMBAHIN INI
  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];
}

class PelangganTab extends StatefulWidget {
  const PelangganTab({super.key});

  @override
  State<PelangganTab> createState() => _PelangganTabState();
}

class _PelangganTabState extends State<PelangganTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  final _searchCtrl = TextEditingController();
  bool _isLoading = true;
  bool _isAdmin = false; // TAMBAHIN INI

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad(); // GANTI dari _loadCustomers()
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // TAMBAHIN METHOD INI
  Future<void> _checkRoleAndLoad() async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      final myProfile = await _supabase.from('profiles').select('role').eq('id', myId).single();
      _isAdmin = myProfile['role'] == 'super_admin';
    } catch (e) {
      debugPrint('Role check error: $e');
    }
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('profiles')
          .select('id, nama_lengkap, nomor_hp, customers(id, poin_saldo)')
          .eq('role', 'customer')
          .eq('is_active', true)
          .order('nama_lengkap');

      if (mounted) {
        setState(() {
          _allCustomers = List<Map<String, dynamic>>.from(data);
          _filteredCustomers = _allCustomers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load customers error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _searchCustomer(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final n = (c['nama_lengkap'] ?? '').toString().toLowerCase();
          final hp = (c['nomor_hp'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return n.contains(q) || hp.contains(q);
        }).toList();
      }
    });
  }

  // TAMBAHIN HELPER INI - ekstrak poin & customerId aman utk List atau Map
  Map<String, dynamic> _extractCustData(dynamic custData) {
    if (custData is List && custData.isNotEmpty) {
      return {
        'customerId': custData[0]['id'],
        'poin': (custData[0]['poin_saldo'] as num?)?.toInt() ?? 0,
      };
    } else if (custData is Map) {
      return {
        'customerId': custData['id'],
        'poin': (custData['poin_saldo'] as num?)?.toInt() ?? 0,
      };
    }
    return {'customerId': null, 'poin': 0};
  }

  void _showCustomerDetail(Map<String, dynamic> customer) {
    final profileId = customer['id'];
    final namaLengkap = customer['nama_lengkap'] ?? 'Pelanggan';

    final extracted = _extractCustData(customer['customers']);
    final customerId = extracted['customerId'];
    final int poinSaldo = extracted['poin'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomerDetailModal(
        profileId: profileId,
        customerId: customerId,
        namaLengkap: namaLengkap,
        poinSaldoAwal: poinSaldo,
        onPoinBerubah: _loadCustomers,
      ),
    );
  }

  // TAMBAHIN METHOD INI - dari versi lama
  Future<void> _hapusPelanggan(String profileId, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Hapus Pelanggan?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        content: Text('Yakin ingin menghapus $nama? Data pelanggan akan disembunyikan tapi nota lama tetap aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.heavyImpact();
      try {
        await _supabase.from('profiles').update({'is_active': false}).eq('id', profileId);
        _loadCustomers();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Pelanggan berhasil dihapus'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red));
      }
    }
  }

  // TAMBAHIN METHOD INI - dari versi lama
  void _showAdjustPointsSheet(String custId, String nama, int currentPoin) {
    int tipeAdjust = 1;
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 32),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text('Koreksi Poin: $nama', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _DS.textPrimary)),
              const SizedBox(height: 4),
              Text('Poin pelanggan saat ini: $currentPoin', style: const TextStyle(color: _DS.textSecondary, fontSize: 14)),
              const SizedBox(height: 24),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); setModalState(() => tipeAdjust = 1); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: tipeAdjust == 1 ? Colors.green.shade50 : Colors.white, border: Border.all(color: tipeAdjust == 1 ? Colors.green : _DS.border), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text('+ Tambah Poin', style: TextStyle(color: tipeAdjust == 1 ? Colors.green.shade700 : _DS.textSecondary, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () { HapticFeedback.selectionClick(); setModalState(() => tipeAdjust = -1); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(color: tipeAdjust == -1 ? Colors.red.shade50 : Colors.white, border: Border.all(color: tipeAdjust == -1 ? Colors.red : _DS.border), borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text('- Kurangi Poin', style: TextStyle(color: tipeAdjust == -1 ? Colors.red.shade700 : _DS.textSecondary, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: amtCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: 'Jumlah Poin', hintText: 'Contoh: 10', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: noteCtrl,
                decoration: InputDecoration(labelText: 'Catatan/Alasan (Wajib)', hintText: 'Contoh: Kompensasi cucian tertukar', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                  onPressed: isSubmitting ? null : () async {
                    final val = int.tryParse(amtCtrl.text.trim()) ?? 0;
                    final note = noteCtrl.text.trim();

                    if (val <= 0 || note.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Jumlah poin harus lebih dari 0 dan Catatan wajib diisi!'), backgroundColor: Colors.orange));
                      return;
                    }

                    final saldoSesudah = currentPoin + (val * tipeAdjust);
                    if (saldoSesudah < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Koreksi gagal: Poin pelanggan tidak boleh minus!'), backgroundColor: Colors.red));
                      return;
                    }

                    HapticFeedback.heavyImpact();
                    setModalState(() => isSubmitting = true);

                    try {
                      final adminId = _supabase.auth.currentUser!.id;

                      await _supabase.from('customers').update({'poin_saldo': saldoSesudah}).eq('id', custId);

                      await _supabase.from('points_ledger').insert({
                        'customer_id': custId,
                        'tipe': 'adjusted',
                        'jumlah': val,
                        'saldo_sebelum': currentPoin,
                        'saldo_sesudah': saldoSesudah,
                        'dilakukan_oleh': adminId,
                        'catatan': note
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        _loadCustomers();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Poin berhasil dikoreksi!'), backgroundColor: Colors.green));
                      }
                    } catch (e) {
                      setModalState(() => isSubmitting = false);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  },
                  child: isSubmitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Data Pelanggan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border), boxShadow: _DS.cardShadow),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor HP...', hintStyle: const TextStyle(color: _DS.textHint, fontSize: 14), prefixIcon: const Icon(Icons.search, color: _DS.textHint),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, color: _DS.textHint), onPressed: () { _searchCtrl.clear(); _searchCustomer(''); }) : null,
                ),
                onChanged: _searchCustomer,
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _DS.blue))
                : _filteredCustomers.isEmpty
                    ? const Center(child: Text('Pelanggan tidak ditemukan.', style: TextStyle(color: _DS.textHint)))
                    : ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, i) {
                          final c = _filteredCustomers[i];
                          final extracted = _extractCustData(c['customers']); // GANTI cara ekstraksi
                          final poin = extracted['poin'];
                          final custId = extracted['customerId'];

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12)), child: Center(child: Text(c['nama_lengkap']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: _DS.blue, fontWeight: FontWeight.w800, fontSize: 16)))),
                              title: Text(c['nama_lengkap'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                              subtitle: Text(c['nomor_hp'] ?? '-', style: const TextStyle(color: _DS.textSecondary, fontSize: 12)),
                              trailing: Row( // GANTI dari Container tunggal jadi Row + PopupMenuButton
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(10)),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.stars_rounded, color: Colors.amber.shade600, size: 16),
                                        const SizedBox(width: 4),
                                        Text('$poin', style: TextStyle(color: Colors.amber.shade900, fontWeight: FontWeight.w800, fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  if (_isAdmin) ...[
                                    const SizedBox(width: 4),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert_rounded, color: _DS.textHint),
                                      onSelected: (val) {
                                        if (val == 'edit_poin') {
                                          if (custId != null) {
                                            _showAdjustPointsSheet(custId, c['nama_lengkap'] ?? 'Pelanggan', poin);
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data pelanggan belum lengkap (Dompet Poin kosong).'), backgroundColor: Colors.orange));
                                          }
                                        } else if (val == 'hapus') {
                                          _hapusPelanggan(c['id'], c['nama_lengkap'] ?? 'Pelanggan');
                                        }
                                      },
                                      itemBuilder: (context) => [
                                        const PopupMenuItem(value: 'edit_poin', child: Row(children: [Icon(Icons.edit_note_rounded, color: _DS.blue, size: 20), SizedBox(width: 8), Text('Koreksi Poin')])),
                                        const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Hapus Akun', style: TextStyle(color: Colors.red))])),
                                      ],
                                    ),
                                  ]
                                ],
                              ),
                              onTap: () => _showCustomerDetail(c),
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

// =========================================================
// WIDGET BOTTOM SHEET (DETAIL & REDEEM)
// =========================================================
class _CustomerDetailModal extends StatefulWidget {
  final String profileId;
  final String? customerId;
  final String namaLengkap;
  final int poinSaldoAwal;
  final VoidCallback onPoinBerubah;

  const _CustomerDetailModal({
    required this.profileId,
    required this.customerId,
    required this.namaLengkap,
    required this.poinSaldoAwal,
    required this.onPoinBerubah,
  });

  @override
  State<_CustomerDetailModal> createState() => _CustomerDetailModalState();
}

class _CustomerDetailModalState extends State<_CustomerDetailModal>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  late TabController _tabController;

  int _currentPoin = 0;
  List<Map<String, dynamic>> _mutasiList = [];
  List<Map<String, dynamic>> _fisikRewards = [];
  bool _isLoading = true;
  bool _isRedeeming = false;

  @override
  void initState() {
    super.initState();
    _currentPoin = widget.poinSaldoAwal;
    _tabController = TabController(length: 2, vsync: this);
    _loadDetailData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetailData() async {
    if (widget.customerId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Ambil Mutasi Terakhir (Descending agar yang terbaru di atas)
      final mutasiData = await _supabase
          .from('points_ledger')
          .select()
          .eq('customer_id', widget.customerId!)
          .order('created_at', ascending: false);

      // 2. Ambil Katalog Barang Fisik (Gratis Layanan)
      final rewardData = await _supabase
          .from('rewards_catalog')
          .select()
          .eq('tipe_reward', 'gratis_layanan')
          .eq('is_active', true)
          .order('poin_dibutuhkan');

      // 3. Update Saldo Terkini
      final custFresh = await _supabase
          .from('customers')
          .select('poin_saldo')
          .eq('id', widget.customerId!)
          .single();

      if (mounted) {
        setState(() {
          _mutasiList = List<Map<String, dynamic>>.from(mutasiData);
          _fisikRewards = List<Map<String, dynamic>>.from(rewardData);
          _currentPoin = (custFresh['poin_saldo'] as num).toInt();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Load detail error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _prosesTukarFisik(Map<String, dynamic> reward) async {
    final int poinReq = (reward['poin_dibutuhkan'] as num).toInt();
    final String rewardName = reward['nama'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Tukar Barang?',
          style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary),
        ),
        content: Text(
          'Tukarkan $poinReq koin milik ${widget.namaLengkap} dengan $rewardName?\n\nKoin akan otomatis terpotong permanen.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: _DS.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _DS.blue,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Tukar Koin',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRedeeming = true);

    try {
      // 1. Identifikasi Kasir/Admin
      final kasirId = _supabase.auth.currentUser!.id;
      final kasirProfile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', kasirId)
          .single();
      final roleName = kasirProfile['role'] == 'super_admin'
          ? 'admin'
          : 'kasir';

      // 2. Kunci Saldo & Potong
      final custData = await _supabase
          .from('customers')
          .select('poin_saldo')
          .eq('id', widget.customerId!)
          .single();
      final int saldoSblm = (custData['poin_saldo'] as num).toInt();

      if (saldoSblm < poinReq) throw 'Koin pelanggan tidak cukup!';
      final int saldoSsdh = saldoSblm - poinReq;

      await _supabase
          .from('customers')
          .update({'poin_saldo': saldoSsdh})
          .eq('id', widget.customerId!);

      // 3. Catat di Riwayat dengan Cap Eksekutor
      await _supabase.from('points_ledger').insert({
        'customer_id': widget.customerId!,
        'tipe': 'redeemed',
        'jumlah': -poinReq,
        'saldo_sebelum': saldoSblm,
        'saldo_sesudah': saldoSsdh,
        'dilakukan_oleh': kasirId,
        'eksekutor': roleName,
        'catatan': 'Penukaran Fisik: $rewardName',
      });

      // Refresh Data
      await _loadDetailData();
      widget.onPoinBerubah();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $rewardName berhasil ditukar!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
    } finally {
      setState(() => _isRedeeming = false);
    }
  }

  String _formatTgl(String isoString) {
    final d = DateTime.parse(isoString).toLocal();
    return DateFormat('dd MMM yyyy, HH:mm').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: _DS.ground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // HEADER PROFIL
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            decoration: BoxDecoration(
              color: _DS.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: _DS.navy.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.namaLengkap,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: _DS.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Detail Loyalitas Pelanggan',
                          style: TextStyle(
                            color: _DS.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.stars_rounded,
                            color: Colors.amber.shade600,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$_currentPoin',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // TAB BAR
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: _DS.ground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: _DS.surface,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: _DS.softShadow,
                    ),
                    labelColor: _DS.blue,
                    unselectedLabelColor: _DS.textSecondary,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Riwayat Mutasi'),
                      Tab(text: 'Tukar Fisik'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // KONTEN TAB
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _DS.blue),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 1: MUTASI POIN
                      _mutasiList.isEmpty
                          ? const Center(
                              child: Text(
                                'Belum ada riwayat koin.',
                                style: TextStyle(color: _DS.textHint),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _mutasiList.length,
                              itemBuilder: (ctx, i) {
                                final m = _mutasiList[i];
                                final isPlus = m['tipe'] == 'earned';
                                final jumlah = m['jumlah'] > 0
                                    ? '+${m['jumlah']}'
                                    : '${m['jumlah']}';
                                final eksekutor =
                                    m['eksekutor'] ??
                                    'pelanggan'; // Pelacakan Anti-Kecurangan

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: _DS.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: _DS.border,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: isPlus
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isPlus
                                              ? Icons.add_business_rounded
                                              : Icons.outbox_rounded,
                                          color: isPlus
                                              ? Colors.green
                                              : Colors.red,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              m['catatan'] ?? 'Transaksi Koin',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                                color: _DS.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Text(
                                                  _formatTgl(m['created_at']),
                                                  style: const TextStyle(
                                                    color: _DS.textSecondary,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                if (eksekutor !=
                                                    'pelanggan') ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _DS.sky,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'by $eksekutor',
                                                      style: const TextStyle(
                                                        color: _DS.blue,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        jumlah,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: isPlus
                                              ? Colors.green.shade700
                                              : Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),

                      // TAB 2: BARANG FISIK
                      _fisikRewards.isEmpty
                          ? const Center(
                              child: Text(
                                'Tidak ada hadiah fisik tersedia.',
                                style: TextStyle(color: _DS.textHint),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(20),
                              physics: const BouncingScrollPhysics(),
                              itemCount: _fisikRewards.length,
                              itemBuilder: (ctx, i) {
                                final r = _fisikRewards[i];
                                final poinReq = (r['poin_dibutuhkan'] as num)
                                    .toInt();
                                final isEnough = _currentPoin >= poinReq;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: isEnough
                                        ? _DS.surface
                                        : _DS.border.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: _DS.border),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isEnough
                                            ? Colors.amber.shade50
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(
                                        Icons.inventory_2_rounded,
                                        color: isEnough
                                            ? Colors.amber.shade700
                                            : Colors.grey,
                                      ),
                                    ),
                                    title: Text(
                                      r['nama'] ?? '-',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                        color: isEnough
                                            ? _DS.textPrimary
                                            : _DS.textSecondary,
                                      ),
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '$poinReq Koin',
                                        style: TextStyle(
                                          color: isEnough
                                              ? _DS.blue
                                              : _DS.textHint,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    trailing: isEnough
                                        ? ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _DS.blue,
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: _isRedeeming
                                                ? null
                                                : () => _prosesTukarFisik(r),
                                            child: const Text(
                                              'Tukar',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          )
                                        : const Text(
                                            'Koin Kurang',
                                            style: TextStyle(
                                              color: _DS.textHint,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                  ),
                                );
                              },
                            ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
