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

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF0F2557).withOpacity(0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static List<BoxShadow> fabShadow = [
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: const Color(0xFF1565C0).withOpacity(0.25),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
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
  List<Map<String, dynamic>> _filteredInventory = [];
  final _searchCtrl = TextEditingController();

  bool _isLoading = true;
  bool _isAdmin = false;

  // Menyimpan hubungan inventory_id -> data services (id, status pin, harga, dsb)
  // agar kita tahu barang mana yang punya entri aktif di layar kasir.
  Map<String, Map<String, dynamic>> _serviceLinks = {};

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
  // [UPDATE UX] CUSTOM DIALOG (sama seperti Services Management)
  // Menggantikan Snackbar agar pesan tidak tertumpuk
  // =========================================================
  void _showCustomDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
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
              BoxShadow(
                color: _DS.navy.withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
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
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: _DS.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: _DS.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
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
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _checkRoleAndLoad() async {
    try {
      final myId = _supabase.auth.currentUser!.id;
      final myProfile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', myId)
          .single();
      if (mounted)
        setState(() => _isAdmin = myProfile['role'] == 'super_admin');
    } catch (e) {
      debugPrint('Role check error: $e');
    }
    _loadInventory();
  }

  Future<void> _loadInventory() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('inventory')
          .select()
          .eq('is_active', true)
          .order('nama_item');
      final inventoryList = List<Map<String, dynamic>>.from(data);

      // Ambil data services terkait (untuk tahu status Pin, harga jual & apakah dijual di kasir)
      Map<String, Map<String, dynamic>> links = {};
      if (inventoryList.isNotEmpty) {
        final ids = inventoryList.map((e) => e['id']).toList();
        final svcData = await _supabase
            .from('services')
            .select(
              'id, inventory_id, is_pinned, nama, harga_per_satuan, satuan, is_active',
            )
            .inFilter('inventory_id', ids)
            .eq('is_active', true);
        for (final s in svcData) {
          if (s['inventory_id'] != null) {
            links[s['inventory_id'].toString()] = Map<String, dynamic>.from(s);
          }
        }
      }

      if (mounted) {
        setState(() {
          _inventory = inventoryList;
          _serviceLinks = links;
          _isLoading = false;
        });
        _applyFilterAndSort();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomDialog(
          title: 'Gagal Memuat',
          message: e.toString(),
          isSuccess: false,
        );
      }
    }
  }

  // =========================================================
  // [BARU] SEARCH & SORT (sama seperti Services Management)
  // =========================================================
  void _onSearchChanged(String query) {
    _applyFilterAndSort();
  }

  void _applyFilterAndSort() {
    setState(() {
      final query = _searchCtrl.text.toLowerCase();
      List<Map<String, dynamic>> temp = _inventory;

      if (query.isNotEmpty) {
        temp = temp
            .where(
              (s) => (s['nama_item'] ?? '').toString().toLowerCase().contains(
                query,
              ),
            )
            .toList();
      }

      temp.sort((a, b) {
        final linkA = _serviceLinks[a['id'].toString()];
        final linkB = _serviceLinks[b['id'].toString()];
        final pinA = (linkA != null && linkA['is_pinned'] == true) ? 1 : 0;
        final pinB = (linkB != null && linkB['is_pinned'] == true) ? 1 : 0;

        if (pinA != pinB) return pinB.compareTo(pinA);
        return (a['nama_item'] ?? '').toString().compareTo(
          (b['nama_item'] ?? '').toString(),
        );
      });

      _filteredInventory = temp;
    });
  }

  // Toggle status Pin barang di layar Kasir
  Future<void> _togglePin(String serviceId, bool current) async {
    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);
    try {
      await _supabase
          .from('services')
          .update({'is_pinned': !current})
          .eq('id', serviceId);
      await _loadInventory();
      if (mounted) {
        _showCustomDialog(
          title: !current ? 'Berhasil Di-Pin' : 'Pin Dilepas',
          message: !current
              ? 'Barang telah disematkan ke bagian atas Layar Kasir.'
              : 'Barang tidak lagi disematkan.',
          isSuccess: true,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showCustomDialog(
          title: 'Gagal Mengubah Pin',
          message: e.toString(),
          isSuccess: false,
        );
      }
    }
  }

  InputDecoration _modernInputDecoration(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _DS.textHint, fontSize: 13),
      filled: true,
      fillColor: _DS.ground,
      prefixIcon: icon != null
          ? Icon(icon, color: _DS.textHint, size: 20)
          : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _DS.blue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  // ====================================================================
  // FITUR HAPUS BARANG (KHUSUS ADMIN)
  // ====================================================================
  Future<void> _hapusBarang(String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(
              'Hapus Barang?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Yakin ingin menghapus $nama dari gudang? Barang ini akan otomatis disembunyikan dari layar penjualan Kasir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.heavyImpact();
      setState(() => _isLoading = true);
      try {
        // 1. Soft-Delete dari Gudang (Inventory)
        await _supabase
            .from('inventory')
            .update({'is_active': false})
            .eq('id', id);

        // 2. OTOMATIS Soft-Delete dari Etalase Kasir (Services) agar tak bisa dijual lagi
        await _supabase
            .from('services')
            .update({'is_active': false, 'is_pinned': false})
            .eq('inventory_id', id);

        await _loadInventory();
        if (mounted) {
          _showCustomDialog(
            title: 'Berhasil Dihapus',
            message: 'Barang & akses kasir berhasil ditutup dari sistem.',
            isSuccess: true,
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showCustomDialog(
            title: 'Gagal Menghapus',
            message: e.toString(),
            isSuccess: false,
          );
        }
      }
    }
  }

  // FITUR TAMBAH BARANG (DENGAN LOGIKA EXPENSES)
  void _showAddBarangDialog() {
    final namaCtrl = TextEditingController();
    final stokCtrl = TextEditingController();
    final modalCtrl = TextEditingController();
    final hargaJualCtrl = TextEditingController();

    bool isDijual = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Tambah Barang Fisik',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _DS.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: namaCtrl,
                  decoration: _modernInputDecoration(
                    'Nama Barang (Cth: Deterjen)',
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: stokCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _modernInputDecoration('Stok Awal'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modalCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _modernInputDecoration(
                    'Total Modal / Harga Beli (Rp)',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '*Modal akan tercatat otomatis di Pengeluaran Kasir',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: isDijual ? _DS.sky : _DS.ground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDijual ? _DS.blue : Colors.transparent,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      'Jual di Kasir?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDijual ? _DS.blue : _DS.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isDijual
                          ? 'Barang akan muncul di layar pesanan'
                          : 'Hanya pemakaian internal/gudang',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDijual
                            ? _DS.blue.withOpacity(0.7)
                            : _DS.textHint,
                      ),
                    ),
                    value: isDijual,
                    activeColor: _DS.blue,
                    onChanged: (val) =>
                        setModalState(() => isDijual = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
                if (isDijual) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: hargaJualCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _modernInputDecoration(
                      'Harga Jual per Pcs (Rp)',
                      icon: Icons.sell_outlined,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: _DS.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              onPressed: () async {
                if (namaCtrl.text.isEmpty ||
                    stokCtrl.text.isEmpty ||
                    modalCtrl.text.isEmpty)
                  return;
                if (isDijual && hargaJualCtrl.text.isEmpty) return;

                Navigator.pop(ctx); // Tutup dialog input
                setState(
                  () => _isLoading = true,
                ); // Munculkan Loading Kaca Buram

                try {
                  final qty = int.parse(stokCtrl.text.trim());
                  final totalModal = int.parse(modalCtrl.text.trim());
                  final hargaBeliPerSatuan = qty > 0 ? (totalModal / qty) : 0;
                  final kasirId = _supabase.auth.currentUser!.id;

                  // 1. Simpan ke Inventory
                  final invRes = await _supabase
                      .from('inventory')
                      .insert({
                        'nama_item': namaCtrl.text.trim(),
                        'stok_saat_ini': qty,
                        'satuan': 'pcs',
                        'harga_beli': hargaBeliPerSatuan,
                        'is_active': true,
                      })
                      .select()
                      .single();

                  // 2. Jika dijual, simpan ke Services
                  if (isDijual) {
                    await _supabase.from('services').insert({
                      'nama': namaCtrl.text.trim(),
                      'harga_per_satuan': int.parse(hargaJualCtrl.text.trim()),
                      'satuan': 'pcs',
                      'tipe': 'produk',
                      'inventory_id': invRes['id'],
                      'is_active': true,
                      'is_pinned': false,
                    });
                  }

                  // 3. Catat Riwayat Masuk
                  await _supabase.from('inventory_log').insert({
                    'inventory_id': invRes['id'],
                    'tipe': 'masuk',
                    'qty': qty,
                    'stok_sebelum': 0,
                    'stok_sesudah': qty,
                    'keterangan': 'Stok Awal Sistem',
                    'created_by': kasirId,
                  });

                  // 4. Catat Pengeluaran
                  if (totalModal > 0) {
                    await _supabase.from('expenses').insert({
                      'cashier_id': kasirId,
                      'nominal': totalModal,
                      'keterangan':
                          'Belanja Stok Awal: ${namaCtrl.text.trim()}',
                    });
                  }

                  await _loadInventory();
                  if (mounted) {
                    _showCustomDialog(
                      title: 'Tersimpan',
                      message: 'Barang baru berhasil ditambahkan.',
                      isSuccess: true,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    _showCustomDialog(
                      title: 'Gagal Menyimpan',
                      message: e.toString(),
                      isSuccess: false,
                    );
                  }
                }
              },
              child: const Text(
                'Simpan Data',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // [BARU] FITUR EDIT BARANG (KHUSUS ADMIN)
  // Semua field bisa diedit, termasuk toggle Jual di Kasir on/off.
  // ====================================================================
  void _showEditBarangDialog(Map<String, dynamic> item) {
    if (!_isAdmin) return; // Guard, hanya admin

    final existingLink = _serviceLinks[item['id'].toString()];

    final namaCtrl = TextEditingController(text: item['nama_item']);
    final stokCtrl = TextEditingController(
      text: (item['stok_saat_ini'] as num).toInt().toString(),
    );
    final hargaBeliCtrl = TextEditingController(
      text: item['harga_beli'] != null
          ? (item['harga_beli'] as num).toInt().toString()
          : '0',
    );
    final hargaJualCtrl = TextEditingController(
      text: existingLink != null
          ? (existingLink['harga_per_satuan'] as num).toInt().toString()
          : '',
    );

    bool isDijual = existingLink != null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Edit Barang Fisik',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _DS.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: namaCtrl,
                  decoration: _modernInputDecoration('Nama Barang'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: stokCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _modernInputDecoration('Stok Saat Ini'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hargaBeliCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _modernInputDecoration(
                    'Harga Beli per Pcs (Rp)',
                    icon: Icons.payments_outlined,
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(
                    color: isDijual ? _DS.sky : _DS.ground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDijual ? _DS.blue : Colors.transparent,
                    ),
                  ),
                  child: CheckboxListTile(
                    title: Text(
                      'Jual di Kasir?',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isDijual ? _DS.blue : _DS.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      isDijual
                          ? 'Barang akan muncul di layar pesanan'
                          : 'Barang tidak akan tampil di layar pesanan',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDijual
                            ? _DS.blue.withOpacity(0.7)
                            : _DS.textHint,
                      ),
                    ),
                    value: isDijual,
                    activeColor: _DS.blue,
                    onChanged: (val) =>
                        setModalState(() => isDijual = val ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                  ),
                ),
                if (isDijual) ...[
                  const SizedBox(height: 14),
                  TextField(
                    controller: hargaJualCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _modernInputDecoration(
                      'Harga Jual per Pcs (Rp)',
                      icon: Icons.sell_outlined,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: _DS.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                elevation: 0,
              ),
              onPressed: () async {
                if (namaCtrl.text.isEmpty || stokCtrl.text.isEmpty) return;
                if (isDijual && hargaJualCtrl.text.isEmpty) return;

                Navigator.pop(ctx);
                setState(() => _isLoading = true);

                try {
                  final namaBaru = namaCtrl.text.trim();
                  final stokBaru = int.parse(stokCtrl.text.trim());
                  final hargaBeliBaru = int.parse(hargaBeliCtrl.text.trim());

                  // 1. Update data Inventory
                  await _supabase
                      .from('inventory')
                      .update({
                        'nama_item': namaBaru,
                        'stok_saat_ini': stokBaru,
                        'harga_beli': hargaBeliBaru,
                      })
                      .eq('id', item['id']);

                  // 2. Cek apakah sudah ada baris services untuk barang ini (aktif ataupun tidak)
                  final svcRows = await _supabase
                      .from('services')
                      .select('id')
                      .eq('inventory_id', item['id']);
                  final svcList = List<Map<String, dynamic>>.from(svcRows);
                  final existingServiceId = svcList.isNotEmpty
                      ? svcList.first['id']
                      : null;

                  if (isDijual) {
                    final hargaJualBaru = int.parse(hargaJualCtrl.text.trim());
                    if (existingServiceId != null) {
                      // Sudah ada baris services -> update & aktifkan kembali
                      await _supabase
                          .from('services')
                          .update({
                            'nama': namaBaru,
                            'harga_per_satuan': hargaJualBaru,
                            'is_active': true,
                          })
                          .eq('id', existingServiceId);
                    } else {
                      // Belum pernah dijual sebelumnya -> buat baru
                      await _supabase.from('services').insert({
                        'nama': namaBaru,
                        'harga_per_satuan': hargaJualBaru,
                        'satuan': 'pcs',
                        'tipe': 'produk',
                        'inventory_id': item['id'],
                        'is_active': true,
                        'is_pinned': false,
                      });
                    }
                  } else {
                    // Toggle Jual di Kasir dimatikan -> nonaktifkan baris services agar hilang dari layar Kasir
                    if (existingServiceId != null) {
                      await _supabase
                          .from('services')
                          .update({'is_active': false, 'is_pinned': false})
                          .eq('id', existingServiceId);
                    }
                  }

                  await _loadInventory();
                  if (mounted) {
                    _showCustomDialog(
                      title: 'Tersimpan',
                      message: 'Data barang berhasil diperbarui.',
                      isSuccess: true,
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    _showCustomDialog(
                      title: 'Gagal Menyimpan',
                      message: e.toString(),
                      isSuccess: false,
                    );
                  }
                }
              },
              child: const Text(
                'Simpan Perubahan',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHistorySheet(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StockHistorySheet(
        item: item,
        isAdmin: _isAdmin,
        onUpdateFinished: () {
          _loadInventory();
        },
      ),
    ).then((_) => _loadInventory());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // [UPDATE UX] KUNCI ANTI-BOLONG: Background dasar Scaffold diset ke Navy!
      backgroundColor: _DS.navy,
      appBar: AppBar(
        title: const Text(
          'Stok Barang Fisik',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
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
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_DS.navy, _DS.blue],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari barang...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.white.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                  onChanged: _onSearchChanged,
                ),
              ),

              Expanded(
                child: RefreshIndicator(
                  color: _DS.blue,
                  backgroundColor: _DS.surface,
                  onRefresh: _loadInventory,
                  child: _filteredInventory.isEmpty && !_isLoading
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.5,
                              child: Center(
                                child: Text(
                                  _searchCtrl.text.isEmpty
                                      ? 'Belum ada data barang'
                                      : 'Barang tidak ditemukan',
                                  style: const TextStyle(color: _DS.textHint),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                          itemCount: _filteredInventory.length,
                          itemBuilder: (ctx, i) {
                            final item = _filteredInventory[i];
                            final stok = (item['stok_saat_ini'] as num).toInt();

                            final serviceLink =
                                _serviceLinks[item['id'].toString()];
                            final bool isPinned =
                                serviceLink != null &&
                                serviceLink['is_pinned'] == true;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              decoration: BoxDecoration(
                                color: _DS.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPinned
                                      ? Colors.amber.shade400
                                      : _DS.border,
                                  width: isPinned ? 2 : 1.5,
                                ),
                                boxShadow: _DS.cardShadow,
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 14,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          if (isPinned)
                                            const Padding(
                                              padding: EdgeInsets.only(
                                                right: 6,
                                              ),
                                              child: Icon(
                                                Icons.push_pin_rounded,
                                                size: 15,
                                                color: Colors.amber,
                                              ),
                                            ),
                                          Expanded(
                                            child: Text(
                                              item['nama_item'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: _DS.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (_isAdmin)
                                            PopupMenuButton<String>(
                                              icon: const Icon(
                                                Icons.more_vert_rounded,
                                                color: _DS.textHint,
                                              ),
                                              onSelected: (val) {
                                                if (val == 'edit')
                                                  _showEditBarangDialog(item);
                                                else if (val == 'hapus')
                                                  _hapusBarang(
                                                    item['id'],
                                                    item['nama_item'],
                                                  );
                                              },
                                              itemBuilder: (context) => [
                                                const PopupMenuItem(
                                                  value: 'edit',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.edit_note_rounded,
                                                        color: _DS.blue,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text('Edit Barang'),
                                                    ],
                                                  ),
                                                ),
                                                const PopupMenuItem(
                                                  value: 'hapus',
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons
                                                            .delete_outline_rounded,
                                                        color: Colors.red,
                                                        size: 20,
                                                      ),
                                                      SizedBox(width: 8),
                                                      Text(
                                                        'Hapus',
                                                        style: TextStyle(
                                                          color: Colors.red,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Sisa Stok: $stok ${item['satuan']}',
                                        style: TextStyle(
                                          color: stok <= 5
                                              ? Colors.red.shade600
                                              : _DS.textSecondary,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (serviceLink != null)
                                            IconButton(
                                              tooltip: isPinned
                                                  ? 'Lepas Pin'
                                                  : 'Pin ke Layar Kasir',
                                              icon: Icon(
                                                isPinned
                                                    ? Icons.push_pin_rounded
                                                    : Icons.push_pin_outlined,
                                                color: isPinned
                                                    ? Colors.amber.shade700
                                                    : _DS.textHint,
                                              ),
                                              onPressed: () => _togglePin(
                                                serviceLink['id'],
                                                isPinned,
                                              ),
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: _DS.sky,
                                                foregroundColor: _DS.blue,
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 10,
                                                    ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _showHistorySheet(item),
                                              icon: const Icon(
                                                Icons.history_rounded,
                                                size: 16,
                                              ),
                                              label: const Text(
                                                'Update & Riwayat',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
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

          // [UPDATE UX] SCENE LOADING MODERN (Glassmorphism Blur) - sama seperti Services Management
          if (_isLoading)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: _DS.navy.withOpacity(0.2),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 32,
                      ),
                      decoration: BoxDecoration(
                        color: _DS.surface,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: _DS.navy.withOpacity(0.15),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(
                            color: _DS.blue,
                            strokeWidth: 3.5,
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            'Memuat Data...',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _DS.textPrimary,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _isAdmin
          ? Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: _DS.fabShadow,
              ),
              child: FloatingActionButton.extended(
                onPressed: _showAddBarangDialog,
                elevation: 0,
                backgroundColor: _DS.blue,
                icon: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                label: const Text(
                  'Barang Baru',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

// ============================================================================
// KOMPONEN BOTTOM SHEET RIWAYAT & UPDATE STOK
// (TIDAK ADA PERUBAHAN LOGIKA DI BAWAH INI)
// ============================================================================
class _StockHistorySheet extends StatefulWidget {
  final Map<String, dynamic> item;
  final bool isAdmin;
  final VoidCallback onUpdateFinished;

  const _StockHistorySheet({
    required this.item,
    required this.isAdmin,
    required this.onUpdateFinished,
  });

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
      final data = await _supabase
          .from('inventory_log')
          .select()
          .eq('inventory_id', widget.item['id'])
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final d = DateTime.parse(isoString).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Ags',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _DS.blue, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  void _showUpdateStokDialog() {
    final qtyCtrl = TextEditingController();
    final ketCtrl = TextEditingController();
    final modalCtrl = TextEditingController();

    String tipe = 'masuk';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          backgroundColor: _DS.surface,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            widget.isAdmin ? 'Koreksi Stok Fisik' : 'Tambah Stok Masuk',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _DS.textPrimary,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.isAdmin) ...[
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.green,
                            ),
                          ),
                          value: 'masuk',
                          activeColor: Colors.green,
                          groupValue: tipe,
                          onChanged: (v) => setModalState(() => tipe = v!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text(
                            'Keluar / Rusak',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                          value: 'keluar',
                          activeColor: Colors.red,
                          groupValue: tipe,
                          onChanged: (v) => setModalState(() => tipe = v!),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _modernInputDecoration('Jumlah Barang (Qty)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: ketCtrl,
                  decoration: _modernInputDecoration('Keterangan (Wajib)'),
                ),
                if (tipe == 'masuk') ...[
                  const SizedBox(height: 16),
                  const Divider(color: _DS.border),
                  const SizedBox(height: 8),
                  TextField(
                    controller: modalCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: _modernInputDecoration(
                      'Total Biaya Beli (Opsional)',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '*Jika diisi, akan otomatis masuk ke tabel Pengeluaran.',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.orange,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text(
                'Batal',
                style: TextStyle(
                  color: _DS.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _DS.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 0,
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (qtyCtrl.text.isEmpty || ketCtrl.text.isEmpty) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        final qty = int.parse(qtyCtrl.text.trim());
                        final stokBaru = tipe == 'masuk'
                            ? _currentStock + qty
                            : _currentStock - qty;
                        final kasirId = _supabase.auth.currentUser!.id;

                        await _supabase
                            .from('inventory')
                            .update({'stok_saat_ini': stokBaru})
                            .eq('id', widget.item['id']);

                        await _supabase.from('inventory_log').insert({
                          'inventory_id': widget.item['id'],
                          'tipe': tipe,
                          'qty': qty,
                          'stok_sebelum': _currentStock,
                          'stok_sesudah': stokBaru,
                          'keterangan': ketCtrl.text.trim(),
                          'created_by': kasirId,
                        });

                        if (tipe == 'masuk' && modalCtrl.text.isNotEmpty) {
                          final totalBeli = int.parse(modalCtrl.text.trim());
                          if (totalBeli > 0) {
                            await _supabase.from('expenses').insert({
                              'cashier_id': kasirId,
                              'nominal': totalBeli,
                              'keterangan':
                                  'Restock Barang: ${widget.item['nama_item']} ($qty pcs)',
                            });
                          }
                        }

                        if (mounted) {
                          Navigator.pop(ctx);
                          setState(() => _currentStock = stokBaru);
                          _loadHistory();
                          widget.onUpdateFinished();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Stok berhasil diupdate!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Gagal: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Simpan',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: _DS.ground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              color: _DS.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: _DS.softShadow,
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
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.item['nama_item'],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _DS.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Riwayat Keluar Masuk Barang',
                            style: TextStyle(
                              color: _DS.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _DS.sky,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Sisa Stok',
                            style: TextStyle(
                              fontSize: 10,
                              color: _DS.blue,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '$_currentStock',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _DS.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _DS.blue),
                  )
                : _logs.isEmpty
                ? const Center(
                    child: Text(
                      'Belum ada riwayat stok',
                      style: TextStyle(color: _DS.textHint),
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    itemCount: _logs.length,
                    itemBuilder: (ctx, i) {
                      final log = _logs[i];
                      final isMasuk = log['tipe'] == 'masuk';
                      final color = isMasuk ? Colors.green : Colors.red;
                      final icon = isMasuk
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded;
                      final sign = isMasuk ? '+' : '-';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _DS.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _DS.border),
                          boxShadow: _DS.softShadow,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(
                            log['keterangan'] ?? 'Tanpa Keterangan',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: _DS.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            _formatDateTime(log['created_at']),
                            style: const TextStyle(
                              fontSize: 12,
                              color: _DS.textSecondary,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '$sign${log['qty']}',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${log['stok_sebelum']} ➔ ${log['stok_sesudah']}',
                                style: const TextStyle(
                                  color: _DS.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _DS.surface,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F2557).withOpacity(0.06),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: Icon(
                  widget.isAdmin
                      ? Icons.edit_note_rounded
                      : Icons.add_shopping_cart_rounded,
                ),
                label: Text(
                  widget.isAdmin
                      ? 'Update Stok Manual'
                      : 'Tambah Stok Baru (Restock)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _DS.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: _showUpdateStokDialog,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
