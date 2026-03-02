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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('services').select().eq('tipe', 'jasa').order('nama');
      if (mounted) setState(() { _services = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
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

  void _showAddJasaDialog() {
    final namaCtrl = TextEditingController();
    final hargaCtrl = TextEditingController();
    final satuanCtrl = TextEditingController(text: 'kg'); 
    final estimasiCtrl = TextEditingController(text: '2'); 
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Tambah Layanan Jasa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(controller: namaCtrl, decoration: _modernInputDecoration('Nama Jasa (Cth: Cuci Karpet)')),
                const SizedBox(height: 12),
                TextField(controller: hargaCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Harga (Rp)')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: satuanCtrl, decoration: _modernInputDecoration('Satuan (kg/m/pcs)'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: estimasiCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Estimasi (Hari)'))),
                  ],
                ),
                const SizedBox(height: 8),
                const Text('*Jasa otomatis aktif di menu Kasir', style: TextStyle(fontSize: 11, color: _DS.textHint, fontStyle: FontStyle.italic)),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0),
              onPressed: isSubmitting ? null : () async {
                if (namaCtrl.text.isEmpty || hargaCtrl.text.isEmpty || satuanCtrl.text.isEmpty) return;
                setModalState(() => isSubmitting = true);
                try {
                  await _supabase.from('services').insert({
                    'nama': namaCtrl.text.trim(),
                    'harga_per_satuan': int.parse(hargaCtrl.text.trim()),
                    'satuan': satuanCtrl.text.trim(),
                    'tipe': 'jasa',
                    'estimasi_hari': int.parse(estimasiCtrl.text.trim()),
                    'is_active': true,
                  });
                  if (mounted) { 
                    Navigator.pop(ctx); 
                    _loadServices(); 
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${namaCtrl.text} berhasil ditambahkan!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                }
              },
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Jasa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(title: const Text('Layanan Jasa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), backgroundColor: _DS.navy, foregroundColor: Colors.white, elevation: 0),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _DS.blue)) 
        : _services.isEmpty
            ? const Center(child: Text('Belum ada layanan jasa', style: TextStyle(color: _DS.textHint)))
            : ListView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                itemCount: _services.length,
                itemBuilder: (ctx, i) {
                  final srv = _services[i];
                  final harga = (srv['harga_per_satuan'] as num).toDouble();
                  final estimasi = srv['estimasi_hari'] ?? 0;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: _DS.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _DS.border, width: 1.5),
                      boxShadow: _DS.cardShadow,
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.local_laundry_service_rounded, color: Colors.purple),
                        ),
                        title: Text(srv['nama'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(6)), child: Text('Est: $estimasi Hari', style: const TextStyle(color: _DS.blue, fontSize: 11, fontWeight: FontWeight.w700))),
                            ],
                          ),
                        ),
                        trailing: Text('${_formatRupiah(harga)} / ${srv['satuan']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: _DS.blue)),
                      ),
                    ),
                  );
                },
              ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: _DS.fabShadow),
        child: FloatingActionButton.extended(
          onPressed: _showAddJasaDialog,
          backgroundColor: _DS.blue, 
          elevation: 0,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text('Tambah Jasa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    );
  }
}