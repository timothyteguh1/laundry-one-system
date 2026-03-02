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

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('inventory').select().order('nama_item');
      if (mounted) setState(() { _inventory = List<Map<String, dynamic>>.from(data); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _modernInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _DS.textHint, fontSize: 13),
      filled: true,
      fillColor: _DS.ground,
      prefixIcon: icon != null ? Icon(icon, color: _DS.textHint, size: 20) : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _DS.blue, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // FITUR TAMBAH BARANG (DENGAN LOGIKA EXPENSES)
  void _showAddBarangDialog() {
    final namaCtrl = TextEditingController();
    final stokCtrl = TextEditingController();
    final modalCtrl = TextEditingController(); // Untuk Total Biaya Beli (Expenses)
    final hargaJualCtrl = TextEditingController();
    
    bool isSubmitting = false;
    bool isDijual = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Tambah Barang Fisik', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: namaCtrl, decoration: _modernInputDecoration('Nama Barang (Cth: Deterjen)')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: stokCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Stok Awal'))),
                    const SizedBox(width: 12),
                    Expanded(flex: 2, child: TextField(controller: modalCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Total Modal / Harga Beli (Rp)', icon: Icons.payments_outlined))),
                  ],
                ),
                const SizedBox(height: 6),
                const Text('*Modal akan tercatat otomatis di Pengeluaran Kasir', style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic)),
                const SizedBox(height: 16),
                
                // TOGGLE JUAL DI KASIR
                Container(
                  decoration: BoxDecoration(color: isDijual ? _DS.sky : _DS.ground, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDijual ? _DS.blue : Colors.transparent)),
                  child: CheckboxListTile(
                    title: Text('Jual di Kasir?', style: TextStyle(fontWeight: FontWeight.w700, color: isDijual ? _DS.blue : _DS.textSecondary, fontSize: 14)),
                    subtitle: Text(isDijual ? 'Barang akan muncul di layar pesanan' : 'Hanya pemakaian internal/gudang', style: TextStyle(fontSize: 11, color: isDijual ? _DS.blue.withOpacity(0.7) : _DS.textHint)),
                    value: isDijual,
                    activeColor: _DS.blue,
                    onChanged: (val) => setModalState(() => isDijual = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
                
                if (isDijual) ...[
                  const SizedBox(height: 12),
                  TextField(controller: hargaJualCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Harga Jual per Pcs (Rp)', icon: Icons.sell_outlined)),
                ]
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0),
              onPressed: isSubmitting ? null : () async {
                if (namaCtrl.text.isEmpty || stokCtrl.text.isEmpty || modalCtrl.text.isEmpty) return;
                if (isDijual && hargaJualCtrl.text.isEmpty) return; 
                
                setModalState(() => isSubmitting = true);
                try {
                  final qty = int.parse(stokCtrl.text.trim());
                  final totalModal = int.parse(modalCtrl.text.trim());
                  final hargaBeliPerSatuan = qty > 0 ? (totalModal / qty) : 0;
                  final kasirId = _supabase.auth.currentUser!.id;

                  // 1. Simpan ke Inventory (beserta harga beli)
                  final invRes = await _supabase.from('inventory').insert({
                    'nama_item': namaCtrl.text.trim(),
                    'stok_saat_ini': qty,
                    'satuan': 'pcs',
                    'harga_beli': hargaBeliPerSatuan,
                  }).select().single();

                  // 2. Jika dijual, simpan ke Services
                  if (isDijual) {
                    await _supabase.from('services').insert({
                      'nama': namaCtrl.text.trim(),
                      'harga_per_satuan': int.parse(hargaJualCtrl.text.trim()),
                      'satuan': 'pcs',
                      'tipe': 'produk',
                      'inventory_id': invRes['id'],
                      'is_active': true,
                    });
                  }

                  // 3. Catat Riwayat Masuk
                  await _supabase.from('inventory_log').insert({
                    'inventory_id': invRes['id'], 'tipe': 'masuk', 'qty': qty,
                    'stok_sebelum': 0, 'stok_sesudah': qty,
                    'keterangan': 'Stok Awal Sistem', 'created_by': kasirId
                  });

                  // 4. Catat Pengeluaran Modal ke EXPENSES jika totalModal > 0
                  if (totalModal > 0) {
                    await _supabase.from('expenses').insert({
                      'cashier_id': kasirId,
                      'nominal': totalModal,
                      'keterangan': 'Belanja Stok Awal: ${namaCtrl.text.trim()}',
                    });
                  }

                  if (mounted) { Navigator.pop(ctx); _loadInventory(); }
                } catch (e) {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
                }
              },
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          ],
        ),
      )
    );
  }

  void _showHistorySheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StockHistorySheet(
        item: item, 
        onUpdateFinished: () {
          _loadInventory(); 
        }
      ),
    ).then((_) => _loadInventory()); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground,
      appBar: AppBar(
        title: const Text('Stok Barang Fisik', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)), 
        backgroundColor: _DS.navy, 
        foregroundColor: Colors.white, 
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _DS.blue)) 
        : ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), 
            itemCount: _inventory.length,
            itemBuilder: (ctx, i) {
              final item = _inventory[i];
              final stok = (item['stok_saat_ini'] as num).toInt();
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    title: Text(item['nama_item'], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Sisa Stok: $stok ${item['satuan']}', style: TextStyle(color: stok <= 5 ? Colors.red.shade600 : _DS.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                    ),
                    trailing: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _DS.sky, 
                        foregroundColor: _DS.blue, 
                        elevation: 0, 
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                      ),
                      onPressed: () => _showHistorySheet(item),
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ),
                  ),
                ),
              );
            },
          ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: _DS.fabShadow),
        child: FloatingActionButton.extended(
          onPressed: _showAddBarangDialog,
          elevation: 0,
          backgroundColor: _DS.blue, 
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text('Barang Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        ),
      ),
    );
  }
}

// ============================================================================
// KOMPONEN BOTTOM SHEET RIWAYAT
// ============================================================================
class _StockHistorySheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onUpdateFinished;

  const _StockHistorySheet({required this.item, required this.onUpdateFinished});

  @override
  State<_StockHistorySheet> createState() => _StockHistorySheetState();
}

class _StockHistorySheetState extends State<_StockHistorySheet> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  late int _currentStock;

  @override
  void initState() {
    super.initState();
    _currentStock = (widget.item['stok_saat_ini'] as num).toInt();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('inventory_log').select().eq('inventory_id', widget.item['id']).order('created_at', ascending: false);
      if (mounted) {
        setState(() { _logs = List<Map<String, dynamic>>.from(data); _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final d = DateTime.parse(isoString).toLocal();
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
      final jam = d.hour.toString().padLeft(2, '0');
      final mnt = d.minute.toString().padLeft(2, '0');
      return '${d.day} ${months[d.month - 1]} ${d.year}, $jam:$mnt';
    } catch (e) {
      return '-';
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

  // UPDATE STOK (DENGAN LOGIKA EXPENSES)
  void _showUpdateStokDialog() {
    final qtyCtrl = TextEditingController();
    final ketCtrl = TextEditingController();
    final modalCtrl = TextEditingController(); // Khusus jika tipe = masuk
    String tipe = 'masuk'; 
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Update Stok Fisik', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: RadioListTile<String>(title: const Text('Masuk', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.green)), value: 'masuk', activeColor: Colors.green, groupValue: tipe, onChanged: (v) => setModalState(() => tipe = v!), contentPadding: EdgeInsets.zero)),
                    Expanded(child: RadioListTile<String>(title: const Text('Keluar / Rusak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.red)), value: 'keluar', activeColor: Colors.red, groupValue: tipe, onChanged: (v) => setModalState(() => tipe = v!), contentPadding: EdgeInsets.zero)),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Jumlah (Qty)')),
                const SizedBox(height: 12),
                TextField(controller: ketCtrl, decoration: _modernInputDecoration('Keterangan (Wajib)')),
                
                // MUNCULKAN INPUT MODAL JIKA BARANG MASUK
                if (tipe == 'masuk') ...[
                  const SizedBox(height: 16),
                  const Divider(color: _DS.border),
                  const SizedBox(height: 8),
                  TextField(controller: modalCtrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: _modernInputDecoration('Total Biaya Beli (Opsional)')),
                  const SizedBox(height: 4),
                  const Text('*Jika diisi, akan otomatis masuk ke tabel Pengeluaran.', style: TextStyle(fontSize: 10, color: Colors.orange, fontStyle: FontStyle.italic)),
                ]
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(onPressed: isSubmitting ? null : () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.w600))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), elevation: 0),
              onPressed: isSubmitting ? null : () async {
                if (qtyCtrl.text.isEmpty || ketCtrl.text.isEmpty) return;
                setModalState(() => isSubmitting = true);
                try {
                  final qty = int.parse(qtyCtrl.text.trim());
                  final stokBaru = tipe == 'masuk' ? _currentStock + qty : _currentStock - qty;
                  final kasirId = _supabase.auth.currentUser!.id;

                  // 1. Update Stok di DB
                  await _supabase.from('inventory').update({'stok_saat_ini': stokBaru}).eq('id', widget.item['id']);
                  
                  // 2. Catat Log Keluar Masuk
                  await _supabase.from('inventory_log').insert({
                    'inventory_id': widget.item['id'], 'tipe': tipe, 'qty': qty,
                    'stok_sebelum': _currentStock, 'stok_sesudah': stokBaru,
                    'keterangan': ketCtrl.text.trim(), 'created_by': kasirId
                  });

                  // 3. Jika Masuk & ada biayanya, catat di EXPENSES
                  if (tipe == 'masuk' && modalCtrl.text.isNotEmpty) {
                    final totalBeli = int.parse(modalCtrl.text.trim());
                    if (totalBeli > 0) {
                      await _supabase.from('expenses').insert({
                        'cashier_id': kasirId,
                        'nominal': totalBeli,
                        'keterangan': 'Restock Barang: ${widget.item['nama_item']} ($qty pcs)',
                      });
                    }
                  }

                  if (mounted) { 
                    Navigator.pop(ctx); 
                    setState(() => _currentStock = stokBaru); 
                    _loadHistory(); 
                    widget.onUpdateFinished(); 
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stok berhasil diupdate!'), backgroundColor: Colors.green));
                  }
                } catch (e) {
                  setModalState(() => isSubmitting = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
                }
              },
              child: isSubmitting ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Simpan Perubahan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          ],
        ),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(color: _DS.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), boxShadow: _DS.softShadow),
            child: Column(
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.item['nama_item'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _DS.textPrimary)),
                          const SizedBox(height: 4),
                          const Text('Riwayat Keluar Masuk Barang', style: TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        children: [
                          const Text('Sisa Stok', style: TextStyle(fontSize: 10, color: _DS.blue, fontWeight: FontWeight.w700)),
                          Text('$_currentStock', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _DS.blue)),
                        ],
                      ),
                    )
                  ],
                ),
              ],
            ),
          ),
          
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: _DS.blue))
              : _logs.isEmpty 
                  ? const Center(child: Text('Belum ada riwayat stok', style: TextStyle(color: _DS.textHint)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      itemCount: _logs.length,
                      itemBuilder: (ctx, i) {
                        final log = _logs[i];
                        final isMasuk = log['tipe'] == 'masuk';
                        final color = isMasuk ? Colors.green : Colors.red;
                        final icon = isMasuk ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
                        final sign = isMasuk ? '+' : '-';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border), boxShadow: _DS.softShadow),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 20)),
                            title: Text(log['keterangan'] ?? 'Tanpa Keterangan', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: _DS.textPrimary)),
                            subtitle: Text(_formatDateTime(log['created_at']), style: const TextStyle(fontSize: 12, color: _DS.textSecondary)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('$sign${log['qty']}', style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 16)),
                                Text('Sisa: ${log['stok_sesudah']}', style: const TextStyle(color: _DS.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _DS.surface, boxShadow: [BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))]),
            child: SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('Update Stok Manual', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                onPressed: _showUpdateStokDialog, 
              ),
            ),
          )
        ],
      ),
    );
  }
}