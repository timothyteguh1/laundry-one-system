import 'dart:ui';
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

  static List<BoxShadow> fabShadow = [
    BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2)),
  ];
}

class ServicesManagementScreen extends StatefulWidget {
  const ServicesManagementScreen({super.key});

  @override
  State<ServicesManagementScreen> createState() => _ServicesManagementScreenState();
}

class _ServicesManagementScreenState extends State<ServicesManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _filteredServices = [];
  final _searchCtrl = TextEditingController();
  
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRoleAndLoad();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // =========================================================
  // [UPDATE UX] CUSTOM DIALOG
  // Menggantikan Snackbar agar pesan tidak tertumpuk
  // =========================================================
  void _showCustomDialog({required String title, required String message, required bool isSuccess}) {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _DS.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: _DS.navy.withOpacity(0.15), blurRadius: 32, offset: const Offset(0, 12))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: _DS.textSecondary, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? _DS.blue : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkRoleAndLoad() async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      final myProfile = await _supabase.from('profiles').select('role').eq('id', myId).single();
      if (mounted) setState(() => _isAdmin = myProfile['role'] == 'super_admin');
    } catch (e) {
      debugPrint('Role check error: $e');
    }
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('services').select().eq('is_active', true).eq('tipe', 'jasa').order('nama');
      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(data);
          _applyFilterAndSort(); 
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomDialog(title: 'Gagal Memuat', message: e.toString(), isSuccess: false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _applyFilterAndSort();
  }

  void _applyFilterAndSort() {
    setState(() {
      final query = _searchCtrl.text.toLowerCase();
      List<Map<String, dynamic>> temp = _services;
      
      if (query.isNotEmpty) {
        temp = temp.where((s) => (s['nama'] ?? '').toString().toLowerCase().contains(query)).toList();
      }
      
      temp.sort((a, b) {
        final pinA = a['is_pinned'] == true ? 1 : 0;
        final pinB = b['is_pinned'] == true ? 1 : 0;
        
        if (pinA != pinB) return pinB.compareTo(pinA); 
        return (a['nama'] ?? '').toString().compareTo((b['nama'] ?? '').toString());
      });
      
      _filteredServices = temp;
    });
  }

  Future<void> _togglePin(String serviceId, bool currentStatus) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await _supabase.from('services').update({'is_pinned': !currentStatus}).eq('id', serviceId);
      await _loadServices();
      if (mounted) {
        _showCustomDialog(
          title: !currentStatus ? 'Berhasil Di-Pin' : 'Pin Dilepas', 
          message: !currentStatus ? 'Jasa telah disematkan ke bagian atas Layar Kasir.' : 'Jasa tidak lagi disematkan.', 
          isSuccess: true
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomDialog(title: 'Gagal Mengubah Pin', message: e.toString(), isSuccess: false);
      }
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

  Future<void> _hapusJasa(String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Hapus Jasa?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        content: Text('Yakin ingin menghapus layanan "$nama"? Jasa ini tidak akan bisa dipilih lagi oleh kasir saat membuat pesanan.'),
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
      setState(() => _isLoading = true);
      try {
        await _supabase.from('services').update({'is_active': false}).eq('id', id);
        await _loadServices();
        if (mounted) _showCustomDialog(title: 'Berhasil Dihapus', message: 'Layanan jasa berhasil dihapus dari sistem.', isSuccess: true);
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showCustomDialog(title: 'Gagal Menghapus', message: e.toString(), isSuccess: false);
        }
      }
    }
  }

  void _showFormDialog({Map<String, dynamic>? service}) {
    final isEdit = service != null;
    final namaCtrl = TextEditingController(text: isEdit ? service['nama'] : '');
    final hargaCtrl = TextEditingController(text: isEdit ? service['harga_per_satuan']?.toString() : '');
    
    String satuanSelected = isEdit ? (service['satuan'] ?? 'kg') : 'kg';
    bool isPinned = isEdit ? (service['is_pinned'] == true) : false;
    
    // Hilangkan loading di dalam dialog, kita pakai loading utama dengan BackdropFilter
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(isEdit ? 'Edit Layanan Jasa' : 'Tambah Jasa Baru', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: namaCtrl, textCapitalization: TextCapitalization.words, decoration: _modernInputDecoration('Nama Layanan (Cth: Cuci Komplit)')),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(flex: 2, child: TextField(controller: hargaCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Harga Jual (Rp)'))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: satuanSelected,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: _DS.textHint),
                            items: const [
                              DropdownMenuItem(value: 'kg', child: Text('/ kg', style: TextStyle(fontSize: 14))),
                              DropdownMenuItem(value: 'pcs', child: Text('/ pcs', style: TextStyle(fontSize: 14))),
                              DropdownMenuItem(value: 'meter', child: Text('/ meter', style: TextStyle(fontSize: 14))),
                            ],
                            onChanged: (val) => setModalState(() => satuanSelected = val ?? 'kg'),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(color: isPinned ? Colors.amber.shade50 : _DS.ground, borderRadius: BorderRadius.circular(12), border: Border.all(color: isPinned ? Colors.amber : Colors.transparent)),
                  child: CheckboxListTile(
                    title: Text('Pin ke Menu Kasir', style: TextStyle(fontWeight: FontWeight.w700, color: isPinned ? Colors.amber.shade800 : _DS.textSecondary, fontSize: 13)),
                    subtitle: Text('Tampil paling atas di layar pesanan', style: TextStyle(fontSize: 10, color: isPinned ? Colors.amber.shade700 : _DS.textHint)),
                    value: isPinned, activeColor: Colors.amber.shade700, checkColor: Colors.white,
                    onChanged: (val) => setModalState(() => isPinned = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0),
              onPressed: () async {
                if (namaCtrl.text.isEmpty || hargaCtrl.text.isEmpty) return;
                Navigator.pop(ctx); // Tutup dialog input
                setState(() => _isLoading = true); // Munculkan Loading Kaca Buram
                
                final payload = {
                  'nama': namaCtrl.text.trim(),
                  'harga_per_satuan': int.parse(hargaCtrl.text.trim()),
                  'satuan': satuanSelected,
                  'tipe': 'jasa',
                  'is_active': true,
                  'is_pinned': isPinned,
                };

                try {
                  if (isEdit) {
                    await _supabase.from('services').update(payload).eq('id', service['id']);
                  } else {
                    await _supabase.from('services').insert(payload);
                  }
                  await _loadServices();
                  if (mounted) _showCustomDialog(title: 'Tersimpan', message: isEdit ? 'Layanan berhasil diperbarui.' : 'Layanan baru berhasil ditambahkan.', isSuccess: true);
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    _showCustomDialog(title: 'Gagal Menyimpan', message: e.toString(), isSuccess: false);
                  }
                }
              },
              child: const Text('Simpan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          ],
        ),
      )
    );
  }

  String _formatRupiah(int amount) {
    final str = amount.toString(); final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) { if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.'); buffer.write(str[i]); }
    return 'Rp ${buffer.toString()}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [UPDATE UX] KUNCI ANTI-BOLONG: Background dasar Scaffold diset ke Navy!
      backgroundColor: _DS.navy,
      appBar: AppBar(title: const Text('Master Data Jasa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), backgroundColor: _DS.navy, foregroundColor: Colors.white, elevation: 0),
      body: Stack(
        children: [
          // Latar belakang utama (Ground) untuk konten
          Positioned.fill(child: Container(color: _DS.ground)),
          
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_DS.navy, _DS.blue], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari layanan jasa...', hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.5)),
                    filled: true, fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),
              
              Expanded(
                // [UPDATE UX] RefreshIndicator membungkus ListView
                child: RefreshIndicator(
                  color: _DS.blue,
                  backgroundColor: _DS.surface,
                  onRefresh: _loadServices,
                  child: _filteredServices.isEmpty && !_isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Text(_searchCtrl.text.isEmpty ? 'Belum ada data jasa' : 'Layanan tidak ditemukan', style: const TextStyle(color: _DS.textHint)),
                              ),
                            )
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          itemCount: _filteredServices.length,
                          itemBuilder: (ctx, i) {
                            final s = _filteredServices[i];
                            final isPinned = s['is_pinned'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: _DS.surface, 
                                borderRadius: BorderRadius.circular(16), 
                                border: Border.all(color: isPinned ? Colors.amber.shade400 : _DS.border, width: isPinned ? 2 : 1.5), 
                                boxShadow: _DS.cardShadow
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  title: Row(
                                    children: [
                                      if (isPinned) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.push_pin_rounded, size: 16, color: Colors.amber)),
                                      Expanded(child: Text(s['nama'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary))),
                                    ],
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text('${_formatRupiah((s['harga_per_satuan'] as num).toInt())} / ${s['satuan']}', style: const TextStyle(color: _DS.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: isPinned ? 'Lepas Pin' : 'Pin ke Layar Kasir',
                                        icon: Icon(isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined, color: isPinned ? Colors.amber.shade700 : _DS.textHint),
                                        onPressed: () => _togglePin(s['id'], isPinned),
                                      ),
                                      if (_isAdmin) PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, color: _DS.textHint),
                                        onSelected: (val) {
                                          if (val == 'edit') _showFormDialog(service: s);
                                          else if (val == 'hapus') _hapusJasa(s['id'], s['nama']);
                                        },
                                        itemBuilder: (context) => [
                                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_note_rounded, color: _DS.blue, size: 20), SizedBox(width: 8), Text('Edit Jasa')])),
                                          const PopupMenuItem(value: 'hapus', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                                        ],
                                      )
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),

          // [UPDATE UX] SCENE LOADING MODERN (Glassmorphism Blur)
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: _DS.navy.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      decoration: BoxDecoration(
                        color: _DS.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: _DS.navy.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: _DS.blue, strokeWidth: 3.5),
                          const SizedBox(height: 20),
                          const Text('Memuat Data...', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isAdmin ? Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: _DS.fabShadow),
        child: FloatingActionButton.extended(
          onPressed: () => _showFormDialog(),
          backgroundColor: _DS.blue, 
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text('Tambah Jasa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ) : null,
    );
  }
}