import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// DESIGN SYSTEM
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

class _CartItem {
  final String id;
  final String namaItem;
  final int stokSaatIni;
  final String satuan;
  final int hargaBeli;
  final TextEditingController qtyCtrl;

  _CartItem({required this.id, required this.namaItem, required this.stokSaatIni, required this.satuan, required this.hargaBeli, required this.qtyCtrl});
}

class _NotaItem {
  final String inventoryId;
  final String namaItem;
  final int qty;
  final int hargaBeli;
  final String satuan;

  _NotaItem({required this.inventoryId, required this.namaItem, required this.qty, required this.hargaBeli, required this.satuan});
  int get subtotal => qty * hargaBeli;
}

class _NotaData {
  final String id;
  final DateTime date;
  final String supplier;
  final String operatorName;
  final String paymentMethod;
  final List<_NotaItem> items;

  _NotaData({required this.id, required this.date, required this.supplier, required this.operatorName, required this.paymentMethod, required this.items});
  int get grandTotal => items.fold(0, (sum, item) => sum + item.subtotal);
}

String _formatRupiah(double amount) {
  final str = amount.toStringAsFixed(0);
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
    buffer.write(str[i]);
  }
  return str == '0' ? '0' : buffer.toString();
}

String _formatTanggal(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
  final jam = d.hour.toString().padLeft(2, '0');
  final mnt = d.minute.toString().padLeft(2, '0');
  return '${d.day} ${months[d.month - 1]} ${d.year} $jam:$mnt';
}

// ============================================================
// SCREEN 1: DASBOR RIWAYAT
// ============================================================
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key});

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isAdmin = false;
  List<_NotaData> _notaHistory = [];

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    try {
      final myId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('role').eq('id', myId).maybeSingle();
      if (profile != null) _isAdmin = profile['role'] == 'super_admin';

      final startIso = DateTime(_startDate.year, _startDate.month, _startDate.day, 0, 0, 0).toUtc().toIso8601String();
      final endIso = DateTime(_endDate.year, _endDate.month, _endDate.day, 23, 59, 59).toUtc().toIso8601String();

      final data = await _supabase
          .from('inventory_log')
          .select('inventory_id, created_at, qty, keterangan, inventory(nama_item, harga_beli, satuan)')
          .eq('tipe', 'masuk')
          .like('keterangan', '%[ID: BLJ-%')
          .gte('created_at', startIso)
          .lte('created_at', endIso)
          .order('created_at', ascending: false);

      final Map<String, _NotaData> grouped = {};

      for (var row in data) {
        final ket = row['keterangan'] as String;
        final idMatch = RegExp(r'\[ID: (.*?)\]').firstMatch(ket);
        if (idMatch == null) continue;
        final notaId = idMatch.group(1)!;

        final payMatch = RegExp(r'\[PAY: (.*?)\]').firstMatch(ket);
        final paymentMethod = payMatch != null ? payMatch.group(1)! : 'CASH';

        final opMatch = RegExp(r'\[OP: (.*?)\]').firstMatch(ket);
        final operatorName = opMatch != null ? opMatch.group(1)! : 'Admin';

        final supplier = ket.split('[ID:')[0].trim();
        final date = DateTime.parse(row['created_at']).toLocal();

        final inv = row['inventory'] ?? {};
        final namaItem = inv['nama_item'] ?? 'Barang Dihapus';
        final hargaBeli = (inv['harga_beli'] as num?)?.toInt() ?? 0;
        final qty = (row['qty'] as num).toInt();

        if (!grouped.containsKey(notaId)) {
          grouped[notaId] = _NotaData(id: notaId, date: date, supplier: supplier, operatorName: operatorName, paymentMethod: paymentMethod, items: []);
        }

        grouped[notaId]!.items.add(_NotaItem(inventoryId: row['inventory_id'], namaItem: namaItem, qty: qty, hargaBeli: hargaBeli, satuan: inv['satuan'] ?? 'pcs'));
      }

      final list = grouped.values.toList();
      list.sort((a, b) => b.date.compareTo(a.date));

      if (mounted) {
        setState(() {
          _notaHistory = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _hapusNota(_NotaData nota) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Hapus Nota?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))]),
        content: Text('Yakin ingin membatalkan nota ${nota.id}? Stok barang yang masuk dari nota ini akan dikurangi kembali (Reverse).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan Nota', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final adminId = _supabase.auth.currentUser!.id;
        
        // 1. Kembalikan stok & tambah log keluar (Reverse)
        for (var item in nota.items) {
          final inv = await _supabase.from('inventory').select('stok_saat_ini').eq('id', item.inventoryId).single();
          int currentStok = inv['stok_saat_ini'];
          int newStok = currentStok - item.qty;
          
          await _supabase.from('inventory').update({'stok_saat_ini': newStok}).eq('id', item.inventoryId);
          await _supabase.from('inventory_log').insert({
            'inventory_id': item.inventoryId,
            'tipe': 'keluar',
            'qty': item.qty,
            'stok_sebelum': currentStok,
            'stok_sesudah': newStok,
            'keterangan': 'Pembatalan Nota ${nota.id}',
            'created_by': adminId,
          });
        }

        // 2. Ubah tag ID agar tersembunyi dari dashboard ini
        final oldLogs = await _supabase.from('inventory_log').select('id, keterangan').like('keterangan', '%[ID: ${nota.id}]%');
        for (var oLog in oldLogs) {
          String oldKet = oLog['keterangan'];
          String newKet = oldKet.replaceAll('[ID:', '[BATAL:');
          await _supabase.from('inventory_log').update({'keterangan': newKet}).eq('id', oLog['id']);
        }

        // 3. Hapus pengeluaran kas
        await _supabase.from('expenses').delete().like('keterangan', '%[ID: ${nota.id}]%');

        await _loadHistory();
      } catch (e) {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickDateRange() async {
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
            onSurface: _DS.textPrimary
          )
        ), 
        child: child!
      ),
    );

    if (picked != null) {
      // Validasi Gaya M-Banking: Selisih maksimal 31 Hari
      final difference = picked.end.difference(picked.start).inDays;
      
      if (difference > 31) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Rentang waktu maksimal adalah 31 hari untuk menjaga performa aplikasi.')),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          ),
        );
        return; // Hentikan proses, biarkan tanggal tetap di rentang yang lama
      }

      // Jika valid (<= 31 hari), jalankan penarikan data
      setState(() { 
        _startDate = picked.start; 
        _endDate = picked.end; 
      });
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.navy,
      appBar: AppBar(
        title: const Text('Riwayat Pembelian', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Container(color: _DS.ground)),
          Column(
            children: [
              Container(
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_DS.navy, _DS.blue], begin: Alignment.topLeft, end: Alignment.bottomRight)),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(child: Text('Rekapitulasi nota belanja dan restock barang ke gudang.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4))),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: _pickDateRange,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.2))),
                        child: const Row(children: [Icon(Icons.calendar_month_rounded, color: Colors.white, size: 16), SizedBox(width: 6), Text('Jadwal', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  color: _DS.blue,
                  backgroundColor: _DS.surface,
                  onRefresh: _loadHistory,
                  child: _notaHistory.isEmpty && !_isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.receipt_long_rounded, size: 60, color: _DS.textHint.withOpacity(0.5)),
                                    const SizedBox(height: 16),
                                    const Text('Belum ada nota di rentang waktu ini.', style: TextStyle(color: _DS.textHint, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            )
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          itemCount: _notaHistory.length,
                          itemBuilder: (ctx, i) {
                            final nota = _notaHistory[i];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border), boxShadow: _DS.softShadow),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () async {
                                    HapticFeedback.lightImpact();
                                    final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => _ReceiptScreen(nota: nota)));
                                    if (res == true) _loadHistory();
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(color: _DS.sky, borderRadius: BorderRadius.circular(12)),
                                          child: const Icon(Icons.receipt_rounded, color: _DS.blue, size: 24),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(nota.id, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)),
                                              const SizedBox(height: 4),
                                              Text('${_formatTanggal(nota.date)} • ${nota.items.length} Barang', style: const TextStyle(color: _DS.textSecondary, fontSize: 12)),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Total Beli', style: TextStyle(fontSize: 10, color: _DS.textHint, fontWeight: FontWeight.bold)),
                                            const SizedBox(height: 2),
                                            Text(_formatRupiah(nota.grandTotal.toDouble()), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.green)),
                                          ],
                                        ),
                                        if (_isAdmin) ...[
                                          const SizedBox(width: 8),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                                            onPressed: () => _hapusNota(nota),
                                            visualDensity: VisualDensity.compact,
                                          )
                                        ]
                                      ],
                                    ),
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
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: _DS.navy.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
                      decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: _DS.navy.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))]),
                      child: const Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(color: _DS.blue, strokeWidth: 3.5), SizedBox(height: 20), Text('Memuat Data...', style: TextStyle(fontWeight: FontWeight.w800, color: _DS.textPrimary, fontSize: 15))]),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const _CreatePurchaseScreen()));
          if (result == true) _loadHistory();
        },
        backgroundColor: _DS.blue,
        elevation: 0,
        icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
        label: const Text('Buat Nota Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ============================================================
// SCREEN 2: PEMBUATAN NOTA (KERANJANG BELANJA)
// ============================================================
class _CreatePurchaseScreen extends StatefulWidget {
  const _CreatePurchaseScreen();

  @override
  State<_CreatePurchaseScreen> createState() => _CreatePurchaseScreenState();
}

class _CreatePurchaseScreenState extends State<_CreatePurchaseScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _inventoryList = [];
  final List<_CartItem> _cart = [];
  
  final _supplierCtrl = TextEditingController();
  String _paymentMethod = 'CASH'; 
  String _operatorName = 'Kasir'; 

  bool _isLoading = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _supplierCtrl.dispose();
    for (var item in _cart) item.qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final myId = _supabase.auth.currentUser!.id;
      final profile = await _supabase.from('profiles').select('nama_lengkap').eq('id', myId).maybeSingle();
      if (profile != null && profile['nama_lengkap'] != null) {
        _operatorName = profile['nama_lengkap'];
      }

      final data = await _supabase.from('inventory').select().eq('is_active', true).order('nama_item');
      if (mounted) {
        setState(() {
          _inventoryList = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showItemPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.8,
          decoration: const BoxDecoration(color: _DS.ground, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: const BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 16),
                    const Text('Pilih Barang Restock', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: _DS.textPrimary)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _inventoryList.length,
                  itemBuilder: (ctx, i) {
                    final item = _inventoryList[i];
                    final isAlreadyInCart = _cart.any((c) => c.id == item['id']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isAlreadyInCart ? _DS.ground : _DS.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isAlreadyInCart ? Colors.transparent : _DS.border),
                      ),
                      child: ListTile(
                        onTap: isAlreadyInCart ? null : () {
                          Navigator.pop(ctx);
                          _addToCart(item);
                        },
                        title: Text(item['nama_item'], style: TextStyle(fontWeight: FontWeight.w700, color: isAlreadyInCart ? _DS.textHint : _DS.textPrimary)),
                        subtitle: Text('Stok: ${item['stok_saat_ini']} ${item['satuan']}', style: TextStyle(color: isAlreadyInCart ? _DS.textHint : _DS.textSecondary)),
                        trailing: isAlreadyInCart ? const Icon(Icons.check_circle_rounded, color: Colors.green) : const Icon(Icons.add_circle_outline_rounded, color: _DS.blue),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    final newItem = _CartItem(
      id: item['id'],
      namaItem: item['nama_item'],
      stokSaatIni: (item['stok_saat_ini'] as num).toInt(),
      satuan: item['satuan'] ?? 'pcs',
      hargaBeli: (item['harga_beli'] as num?)?.toInt() ?? 0,
      qtyCtrl: TextEditingController(),
    );

    newItem.qtyCtrl.addListener(() => setState(() {}));
    setState(() => _cart.add(newItem));
  }

  Future<void> _simpanNotaPembelian() async {
    HapticFeedback.heavyImpact();
    if (_cart.isEmpty) return;

    for (var item in _cart) {
      final qtyText = item.qtyCtrl.text.trim();
      if (qtyText.isEmpty || int.tryParse(qtyText) == null || int.parse(qtyText) <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ada Qty barang yang belum diisi dengan benar!'), backgroundColor: Colors.red));
        return;
      }
    }

    if (_supplierCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama Supplier wajib diisi!'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final adminId = _supabase.auth.currentUser!.id;
      final totalPengeluaran = _cart.fold(0, (sum, item) => sum + ((int.tryParse(item.qtyCtrl.text) ?? 0) * item.hargaBeli));
      
      final supplierName = _supplierCtrl.text.trim();
      final notaId = 'BLJ-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'; 
      final noteText = '$supplierName [ID: $notaId] [PAY: $_paymentMethod] [OP: $_operatorName]'; 
      
      Future? expenseFuture;
      if (totalPengeluaran > 0) {
        expenseFuture = _supabase.from('expenses').insert({
          'cashier_id': adminId,
          'nominal': totalPengeluaran,
          'keterangan': 'Restock Grosir - $supplierName [ID: $notaId]', 
        });
      }

      final List<Map<String, dynamic>> logsToInsert = [];
      final List<Future> inventoryUpdateFutures = [];
      final List<_NotaItem> itemsForReceipt = [];

      for (var item in _cart) {
        final qtyMasuk = int.parse(item.qtyCtrl.text);
        final stokBaru = item.stokSaatIni + qtyMasuk;

        logsToInsert.add({
          'inventory_id': item.id,
          'tipe': 'masuk',
          'qty': qtyMasuk,
          'stok_sebelum': item.stokSaatIni,
          'stok_sesudah': stokBaru,
          'keterangan': noteText,
          'created_by': adminId,
        });

        inventoryUpdateFutures.add(_supabase.from('inventory').update({'stok_saat_ini': stokBaru}).eq('id', item.id));
        itemsForReceipt.add(_NotaItem(inventoryId: item.id, namaItem: item.namaItem, qty: qtyMasuk, hargaBeli: item.hargaBeli, satuan: item.satuan));
      }

      await Future.wait([
        if (expenseFuture != null) expenseFuture,
        _supabase.from('inventory_log').insert(logsToInsert),
        ...inventoryUpdateFutures,
      ]);

      if (mounted) {
        final completedNota = _NotaData(id: notaId, date: DateTime.now(), supplier: supplierName, operatorName: _operatorName, paymentMethod: _paymentMethod, items: itemsForReceipt);
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => _ReceiptScreen(nota: completedNota)));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPengeluaran = _cart.fold(0, (sum, item) => sum + ((int.tryParse(item.qtyCtrl.text) ?? 0) * item.hargaBeli));

    return Scaffold(
      backgroundColor: _DS.navy,
      appBar: AppBar(
        title: const Text('Catat Nota Pembelian', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: _DS.navy,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [_DS.navy, _DS.blue], begin: Alignment.topLeft, end: Alignment.bottomRight)),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
            child: const Text('Masukkan barang-barang yang dibeli dalam 1 nota ke dalam daftar di bawah ini untuk restock massal.', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
          ),
          
          Expanded(
            child: Container(
              color: _DS.ground,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: _DS.blue))
                  : RefreshIndicator(
                      color: _DS.blue,
                      backgroundColor: _DS.surface,
                      onRefresh: _loadInitialData,
                      child: _cart.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                SizedBox(
                                  height: MediaQuery.of(context).size.height * 0.4,
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.shopping_cart_checkout_rounded, size: 60, color: _DS.textHint.withOpacity(0.5)),
                                        const SizedBox(height: 16),
                                        const Text('Keranjang kosong.', style: TextStyle(color: _DS.textHint, fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 24),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                                          onPressed: _showItemPicker,
                                          icon: const Icon(Icons.add, color: Colors.white),
                                          label: const Text('Pilih Barang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        )
                                      ],
                                    ),
                                  ),
                                )
                              ],
                            )
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                              padding: const EdgeInsets.all(20),
                              itemCount: _cart.length + 1, // +1 Untuk tombol tambah barang di paling bawah
                              itemBuilder: (ctx, i) {
                                if (i == _cart.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8, bottom: 20),
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(backgroundColor: _DS.surface, foregroundColor: _DS.blue, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: _DS.border)), elevation: 0),
                                      onPressed: _showItemPicker,
                                      icon: const Icon(Icons.add_circle_outline_rounded),
                                      label: const Text('Tambah Barang Lain', style: TextStyle(fontWeight: FontWeight.w800)),
                                    ),
                                  );
                                }

                                final item = _cart[i];
                                final inputQty = int.tryParse(item.qtyCtrl.text) ?? 0;
                                final subtotal = inputQty * item.hargaBeli;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: _DS.border), boxShadow: _DS.softShadow),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(item.namaItem, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _DS.textPrimary))),
                                            IconButton(icon: const Icon(Icons.delete_outline_rounded, color: Colors.red), onPressed: () => setState(() => _cart.removeAt(i)), padding: EdgeInsets.zero, constraints: const BoxConstraints())
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text('Stok saat ini: ${item.stokSaatIni} ${item.satuan}', style: const TextStyle(color: _DS.textSecondary, fontSize: 12)),
                                        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: _DS.border, height: 1)),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: TextField(
                                                controller: item.qtyCtrl,
                                                keyboardType: TextInputType.number,
                                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                                decoration: InputDecoration(
                                                  labelText: 'Qty Masuk', labelStyle: const TextStyle(color: _DS.textHint, fontSize: 12),
                                                  filled: true, fillColor: _DS.ground,
                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              flex: 3,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                decoration: BoxDecoration(color: _DS.sky.withOpacity(0.5), borderRadius: BorderRadius.circular(10), border: Border.all(color: _DS.blue.withOpacity(0.1))),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    const Text('Total Beli (Auto)', style: TextStyle(color: _DS.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 2),
                                                    Text('$inputQty x ${_formatRupiah(item.hargaBeli.toDouble())}', style: const TextStyle(color: _DS.textSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
                                                    Text(_formatRupiah(subtotal.toDouble()), style: const TextStyle(color: _DS.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
            ),
          ),

          // [PERBAIKAN UX GAMBAR 1] - Bottom Sheet diletakkan paten agar tidak tertimpa List
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: BoxDecoration(color: _DS.surface, boxShadow: [BoxShadow(color: _DS.navy.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _supplierCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cth: Toko Makmur Jaya', labelText: 'Nama Supplier', labelStyle: const TextStyle(color: _DS.textSecondary),
                      filled: true, fillColor: _DS.ground,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), isDense: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Metode Pembayaran', style: TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['CASH', 'TRANSFER', 'QRIS'].map((method) {
                        final isSelected = _paymentMethod == method;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(method, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? Colors.white : _DS.textSecondary)),
                            selected: isSelected,
                            selectedColor: _DS.blue,
                            backgroundColor: _DS.ground,
                            side: BorderSide.none,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onSelected: (val) => setState(() => _paymentMethod = method),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(color: _DS.border, height: 1)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Pengeluaran', style: TextStyle(color: _DS.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(
                            _formatRupiah(totalPengeluaran.toDouble()),
                            style: const TextStyle(color: Colors.orange, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                        onPressed: _cart.isEmpty || _isSubmitting ? null : _simpanNotaPembelian,
                        child: const Text('Simpan Nota', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SCREEN 3: TAMPILAN SETRUK NOTA
// ============================================================
class _ReceiptScreen extends StatelessWidget {
  final _NotaData nota;
  const _ReceiptScreen({required this.nota});

  @override
  Widget build(BuildContext context) {
    // PopScope menggantikan WillPopScope (di Flutter modern) untuk menangkap tombol back bawaan HP
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        Navigator.pop(context, true); // Selalu kembalikan true agar Dasbor merefresh
      },
      child: Scaffold(
        backgroundColor: _DS.ground,
        appBar: AppBar(
          title: const Text('Detail Nota', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          backgroundColor: _DS.navy,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context, true), 
          ),
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: _DS.cardShadow),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 32),
                Center(child: Text('ID: ${nota.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87, letterSpacing: 0.5))),
                const SizedBox(height: 32),
                const Divider(color: _DS.border, height: 1, thickness: 1),
                
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildInfoRow('Tanggal', _formatTanggal(nota.date)),
                      const SizedBox(height: 12),
                      _buildInfoRow('Operator', nota.operatorName), 
                      const SizedBox(height: 12),
                      _buildInfoRow('Supplier', nota.supplier),
                      const SizedBox(height: 12),
                      _buildInfoRow('Pembayaran', nota.paymentMethod, valueColor: Colors.black87),
                      const SizedBox(height: 12),
                      _buildInfoRow('Status', 'PAID', valueColor: Colors.green, isBold: true),
                    ],
                  ),
                ),
                
                Container(color: _DS.ground, height: 8),
  
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Row(
                    children: [
                      const Text('Product List', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: Colors.lightBlue, borderRadius: BorderRadius.circular(6)),
                        child: Text('${nota.items.length}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                ),
  
                const Divider(color: _DS.border, height: 1, thickness: 1),
  
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: nota.items.length,
                  separatorBuilder: (ctx, i) => const Divider(color: _DS.border, height: 1),
                  itemBuilder: (ctx, i) {
                    final item = nota.items[i];
                    return Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.namaItem, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.black87)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${item.qty}x ${_formatRupiah(item.hargaBeli.toDouble())}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                              Text(_formatRupiah(item.subtotal.toDouble()), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                            ],
                          )
                        ],
                      ),
                    );
                  },
                ),
  
                Container(color: _DS.ground, height: 8),
  
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Subtotal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(_formatRupiah(nota.grandTotal.toDouble()), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grand Total', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.lightBlue, borderRadius: BorderRadius.circular(6)),
                            child: Text(_formatRupiah(nota.grandTotal.toDouble()), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
  
                const Divider(color: _DS.border, height: 1, thickness: 1),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text('Powered by Laundry One', style: TextStyle(color: _DS.textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color valueColor = _DS.textSecondary, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.black87)),
        Text(value, style: TextStyle(fontWeight: isBold ? FontWeight.w900 : FontWeight.w700, fontSize: 14, color: valueColor)),
      ],
    );
  }
}