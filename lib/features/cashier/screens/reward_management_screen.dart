import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  static List<BoxShadow> softShadow = [
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
  ];
}

class RewardManagementScreen extends StatefulWidget {
  const RewardManagementScreen({super.key});

  @override
  State<RewardManagementScreen> createState() => _RewardManagementScreenState();
}

class _RewardManagementScreenState extends State<RewardManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _rewards = [];
  bool _isLoading = true;
  bool _isAdmin = false; 
  
  // [TAMBAHAN] 0 = Diskon, 1 = Barang Fisik
  int _selectedTab = 0; 

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  Future<void> _checkRoleAndLoad() async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      final myProfile = await _supabase.from('profiles').select('role').eq('id', myId).single();
      if (mounted) setState(() => _isAdmin = myProfile['role'] == 'super_admin');
    } catch (e) {
      debugPrint('Role check error: $e');
    }
    _loadRewards();
  }

  Future<void> _loadRewards() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('rewards_catalog').select().eq('is_active', true).order('poin_dibutuhkan');
      if (mounted) setState(() { _rewards = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      debugPrint('Load rewards error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _modernInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _DS.textHint, fontSize: 14),
      filled: true,
      fillColor: _DS.ground,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _DS.blue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Future<void> _hapusReward(String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Hapus Hadiah?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        content: Text('Yakin ingin menghapus hadiah "$nama"? Hadiah ini tidak akan bisa ditukarkan lagi oleh pelanggan.'),
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
        await _supabase.from('rewards_catalog').update({'is_active': false}).eq('id', id);
        _loadRewards();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Hadiah berhasil dihapus'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _showFormDialog({Map<String, dynamic>? reward}) {
    final isEdit = reward != null;
    
    final namaCtrl = TextEditingController(text: isEdit ? (reward['nama']?.toString() ?? '') : '');
    final deskripsiCtrl = TextEditingController(text: isEdit ? (reward['deskripsi']?.toString() ?? '') : '');
    final poinCtrl = TextEditingController(text: isEdit ? (reward['poin_dibutuhkan']?.toString() ?? '') : '');
    final nilaiCtrl = TextEditingController(text: isEdit ? (reward['nilai_reward']?.toString() ?? '') : '');
    
    // [UPDATE] Jika Tab Barang sedang terbuka dan bukan mode edit, otomatis pilih tipe Gratis Layanan
    String tipeSelected = isEdit 
        ? (reward['tipe_reward']?.toString() ?? 'diskon_nominal') 
        : (_selectedTab == 1 ? 'gratis_layanan' : 'diskon_nominal');
    
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isEdit ? 'Edit Hadiah' : 'Tambah Hadiah Baru', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: namaCtrl, textCapitalization: TextCapitalization.words, decoration: _modernInputDecoration('Nama Hadiah (Cth: Voucher 10Rb)')),
                const SizedBox(height: 12),
                
                TextField(controller: deskripsiCtrl, textCapitalization: TextCapitalization.sentences, maxLines: 2, decoration: _modernInputDecoration('Deskripsi (Opsional)')),
                const SizedBox(height: 12),
                
                TextField(controller: poinCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Koin yang dibutuhkan (Cth: 50)')),
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.circular(12)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: tipeSelected,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _DS.textHint),
                      items: const [
                        DropdownMenuItem(value: 'diskon_nominal', child: Text('Diskon Nominal (Rp)', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'diskon_persen', child: Text('Diskon Persentase (%)', style: TextStyle(fontSize: 14))),
                        DropdownMenuItem(value: 'gratis_layanan', child: Text('Gratis Layanan / Barang', style: TextStyle(fontSize: 14))),
                      ],
                      onChanged: (val) => setModalState(() => tipeSelected = val ?? 'diskon_nominal'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: nilaiCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration(tipeSelected == 'diskon_persen' ? 'Nilai Diskon (Cth: 10 untuk 10%)' : 'Nilai Hadiah (Cth: 10000 untuk Rp 10.000)')),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0),
              onPressed: isSubmitting ? null : () async {
                if (namaCtrl.text.isEmpty || poinCtrl.text.isEmpty || nilaiCtrl.text.isEmpty) return;
                setModalState(() => isSubmitting = true);
                
                final String? deskripsiFinal = deskripsiCtrl.text.trim().isNotEmpty ? deskripsiCtrl.text.trim() : null;

                final payload = {
                  'nama': namaCtrl.text.trim(),
                  'deskripsi': deskripsiFinal,
                  'poin_dibutuhkan': int.tryParse(poinCtrl.text.trim()) ?? 0,
                  'tipe_reward': tipeSelected,
                  'nilai_reward': int.tryParse(nilaiCtrl.text.trim()) ?? 0,
                  'is_active': true,
                };

                try {
                  if (isEdit) {
                    await _supabase.from('rewards_catalog').update(payload).eq('id', reward['id']);
                  } else {
                    await _supabase.from('rewards_catalog').insert(payload);
                  }
                  
                  if (mounted) { 
                    Navigator.pop(ctx); 
                    _loadRewards(); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? '✅ Hadiah diperbarui!' : '✅ Hadiah ditambahkan!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                }
              },
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          ],
        ),
      )
    );
  }

  String _formatRupiah(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  String _getSubtitle(Map<String, dynamic> r) {
    final deskripsiManual = r['deskripsi']?.toString() ?? '';
    if (deskripsiManual.isNotEmpty) return deskripsiManual;

    final tipe = r['tipe_reward']?.toString() ?? '';
    final nilai = int.tryParse(r['nilai_reward']?.toString() ?? '0') ?? 0;
    
    if (tipe == 'diskon_nominal') return 'Memotong tagihan sebesar ${_formatRupiah(nilai)}';
    if (tipe == 'diskon_persen') return 'Diskon sebesar $nilai% dari total transaksi';
    return 'Mendapatkan barang/layanan senilai ${_formatRupiah(nilai)}';
  }

  // [TAMBAHAN] Widget Tombol Tab
  Widget _buildTabBtn(int index, String title, IconData icon) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? _DS.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive ? _DS.softShadow : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? _DS.blue : _DS.textSecondary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: isActive ? FontWeight.w800 : FontWeight.w600, color: isActive ? _DS.blue : _DS.textSecondary, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Memfilter data berdasarkan Tab yang aktif
    final isBarangTab = _selectedTab == 1;
    final displayRewards = _rewards.where((r) {
      final tipe = r['tipe_reward'];
      if (isBarangTab) return tipe == 'gratis_layanan';
      return tipe == 'diskon_nominal' || tipe == 'diskon_persen';
    }).toList();

    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(title: const Text('Katalog Hadiah', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), backgroundColor: _DS.navy, foregroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          // UI Tab Selector
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: _DS.border.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  _buildTabBtn(0, 'Voucher Diskon', Icons.discount_rounded),
                  _buildTabBtn(1, 'Barang Fisik', Icons.inventory_2_rounded),
                ],
              ),
            ),
          ),
          
          // List Katalog
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: _DS.blue)) 
              : displayRewards.isEmpty
                  ? Center(child: Text(isBarangTab ? 'Belum ada barang fisik' : 'Belum ada voucher diskon', style: const TextStyle(color: _DS.textHint)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                      itemCount: displayRewards.length,
                      itemBuilder: (ctx, i) {
                        final r = displayRewards[i];
                        
                        final poin = int.tryParse(r['poin_dibutuhkan']?.toString() ?? '0') ?? 0;
                        final namaReward = r['nama']?.toString() ?? 'Hadiah';
                        final rewardId = r['id']?.toString() ?? '';
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            leading: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(14)),
                              child: Icon(isBarangTab ? Icons.inventory_2_rounded : Icons.card_giftcard_rounded, color: Colors.amber.shade700),
                            ),
                            title: Text(namaReward, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_getSubtitle(r), style: const TextStyle(color: _DS.textSecondary, fontSize: 11, fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 8),
                                  Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.stars_rounded, color: Colors.amber.shade600, size: 14), const SizedBox(width: 4), Text('$poin Koin', style: const TextStyle(color: _DS.blue, fontSize: 12, fontWeight: FontWeight.w800))])),
                                ],
                              ),
                            ),
                            trailing: _isAdmin ? PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: _DS.textHint),
                              onSelected: (val) {
                                if (val == 'edit') _showFormDialog(reward: r);
                                else if (val == 'hapus') _hapusReward(rewardId, namaReward);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_note_rounded, color: _DS.blue, size: 20), SizedBox(width: 8), Text('Edit Hadiah')])),
                                const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                              ],
                            ) : null,
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
      floatingActionButton: _isAdmin ? Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))]),
        child: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(),
          backgroundColor: _DS.blue, 
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: Text(isBarangTab ? 'Tambah Barang' : 'Tambah Voucher', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ) : null,
    );
  }
}