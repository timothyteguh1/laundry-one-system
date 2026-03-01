import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/cashier/screens/invoice_screen.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';

class CreateOrderScreen extends StatefulWidget {
  const CreateOrderScreen({super.key});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final _supabase = Supabase.instance.client;
  int _step = 1;

  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _services = [];
  List<Map<String, dynamic>> _cart = [];
  
  List<Map<String, dynamic>> _allCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  final _searchCtrl = TextEditingController();

  String? _voucherCode;
  Map<String, dynamic>? _voucherData;
  double _diskonVoucher = 0;

  String _metodeBayar = 'cash'; 
  String _tipeBayar = 'lunas'; 

  final DateTime _tglMasuk = DateTime.now();
  DateTime? _estimasiSelesai;
  DateTime? _jatuhTempo;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _loadCustomers();
    _estimasiSelesai = _tglMasuk.add(const Duration(days: 2));
    _jatuhTempo = _tglMasuk.add(const Duration(days: 7));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final data = await _supabase.from('services').select('id, nama, harga_per_satuan, satuan, tipe, is_active, inventory_id, qty_per_unit').eq('is_active', true).order('nama');
    if (mounted) setState(() => _services = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _loadCustomers() async {
    final data = await _supabase.from('profiles').select('id, nama_lengkap, nomor_hp').eq('role', 'customer').order('nama_lengkap');
    if (mounted) {
      setState(() {
        _allCustomers = List<Map<String, dynamic>>.from(data);
        _filteredCustomers = _allCustomers;
      });
    }
  }

  void _searchCustomerLokal(String query) {
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

  void _tambahKeKeranjang(Map<String, dynamic> service, [int qty = 1]) {
    final idx = _cart.indexWhere((c) => c['service']['id'] == service['id']);
    setState(() {
      if (idx >= 0) {
        _cart[idx]['qty'] += qty;
        _cart[idx]['subtotal'] = _cart[idx]['qty'] * (service['harga_per_satuan'] as num).toDouble();
      } else {
        _cart.add({'service': service, 'qty': qty, 'subtotal': qty * (service['harga_per_satuan'] as num).toDouble()});
      }
    });
  }

  void _kurangiDariKeranjang(Map<String, dynamic> service) {
    final idx = _cart.indexWhere((c) => c['service']['id'] == service['id']);
    if (idx < 0) return;
    setState(() {
      if (_cart[idx]['qty'] <= 1) {
        _cart.removeAt(idx);
      } else {
        _cart[idx]['qty']--;
        _cart[idx]['subtotal'] = _cart[idx]['qty'] * (service['harga_per_satuan'] as num).toDouble();
      }
    });
  }

  void _setQtyManual(Map<String, dynamic> service, int newQty) {
    if (newQty <= 0) {
      setState(() => _cart.removeWhere((c) => c['service']['id'] == service['id']));
      return;
    }
    final idx = _cart.indexWhere((c) => c['service']['id'] == service['id']);
    setState(() {
      if (idx >= 0) {
        _cart[idx]['qty'] = newQty;
        _cart[idx]['subtotal'] = newQty * (service['harga_per_satuan'] as num).toDouble();
      } else {
        _cart.add({'service': service, 'qty': newQty, 'subtotal': newQty * (service['harga_per_satuan'] as num).toDouble()});
      }
    });
  }

  int _qtyDiKeranjang(String serviceId) {
    final item = _cart.firstWhere((c) => c['service']['id'] == serviceId, orElse: () => {});
    return item.isEmpty ? 0 : item['qty'];
  }

  double get _subtotal => _cart.fold(0, (sum, c) => sum + (c['subtotal'] as double));
  double get _total => (_subtotal - _diskonVoucher).clamp(0, double.infinity).toDouble();

  Future<void> _pakaiVoucher() async {
    if (_voucherCode == null || _voucherCode!.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    
    try {
      final data = await _supabase.from('reward_redemptions').select('*, rewards_catalog(*)').eq('kode_voucher', _voucherCode!).eq('status', 'aktif').maybeSingle();
      if (data == null) {
        _showSnackBar('Kode voucher tidak valid atau sudah dipakai', Colors.red);
        setState(() => _isLoading = false);
        return;
      }
      final reward = data['rewards_catalog'];
      final minBelanja = (reward['min_belanja'] ?? 0).toDouble();

      if (_subtotal < minBelanja) {
        _showSnackBar('Minimum belanja Rp ${_formatRupiah(minBelanja)} untuk voucher ini', Colors.orange);
        setState(() => _isLoading = false);
        return;
      }

      double diskon = 0;
      if (reward['tipe_diskon'] == 'persen') {
        diskon = _subtotal * (reward['nilai_diskon'] / 100);
        final maxDiskon = (reward['max_diskon'] ?? double.infinity).toDouble();
        diskon = diskon.clamp(0, maxDiskon).toDouble();
      } else {
        diskon = (reward['nilai_diskon'] as num).toDouble();
      }

      setState(() {
        _voucherData = data;
        _diskonVoucher = diskon;
        _isLoading = false;
      });
      _showSnackBar('Voucher berhasil! Diskon ${_formatRupiah(diskon)}', Colors.green);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal validasi voucher', Colors.red);
      }
    }
  }

  Future<void> _simpanOrder() async {
    setState(() => _isLoading = true);
    try {
      final kasirId = _supabase.auth.currentUser!.id;
      final kasirProfile = await _supabase.from('profiles').select('nama_lengkap').eq('id', kasirId).single();
      final namaKasir = kasirProfile['nama_lengkap'] ?? 'Kasir';

      String? customerId;
      if (_selectedCustomer != null) {
        final profileId = _selectedCustomer!['id'];
        final custData = await _supabase.from('customers').select('id').eq('profile_id', profileId).maybeSingle();
        customerId = custData?['id'];
      }

      final now = DateTime.now();
      final prefix = 'ORD-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final count = await _supabase.from('orders').select('id').like('nomor_order', '$prefix%');
      final nomorOrder = '$prefix-${(count.length + 1).toString().padLeft(4, '0')}';

      final int totalDibayar = _tipeBayar == 'piutang' ? 0 : _total.toInt();
      final String metodeBayarFinal = _tipeBayar == 'piutang' ? 'piutang' : _metodeBayar;

      final orderPayload = <String, dynamic>{
        'nomor_order': nomorOrder,
        'customer_id': customerId,
        'cashier_id': kasirId,
        'status': 'diproses',
        'total_harga': _total.toInt(),
        'total_dibayar': totalDibayar,
        'metode_bayar_awal': metodeBayarFinal,
        'is_piutang': _tipeBayar == 'piutang',
        'created_at': _tglMasuk.toIso8601String(),
        'estimasi_selesai': _estimasiSelesai?.toIso8601String(),
        'jatuh_tempo': _tipeBayar == 'piutang' ? _jatuhTempo?.toIso8601String() : null,
      };
      
      if (_diskonVoucher > 0) orderPayload['diskon_voucher'] = _diskonVoucher.toInt();
      if (_voucherData != null) orderPayload['redemption_id'] = _voucherData!['id'];

      final order = await _supabase.from('orders').insert(orderPayload).select().single();

      // ==========================================
      // FIX TAHAP 2: CATAT LANGSUNG KE ORDER PAYMENTS JIKA LUNAS
      // ==========================================
      if (_tipeBayar != 'piutang' && totalDibayar > 0) {
        await _supabase.from('order_payments').insert({
          'order_id': order['id'],
          'jumlah': totalDibayar,
          'metode': metodeBayarFinal,
          'diterima_oleh': kasirId,
        });
      }

      for (final item in _cart) {
        await _supabase.from('order_items').insert({
          'order_id': order['id'],
          'service_id': item['service']['id'],
          'jumlah': item['qty'],
          'harga_satuan': (item['service']['harga_per_satuan'] as num).toInt(),
          'subtotal': (item['subtotal'] as double).toInt(),
        });

        if (item['service']['tipe'] == 'produk' && item['service']['inventory_id'] != null) {
          final invId = item['service']['inventory_id'];
          final qtyPerUnit = (item['service']['qty_per_unit'] ?? 1).toDouble();
          final qtyKurang = item['qty'] * qtyPerUnit;

          final inv = await _supabase.from('inventory').select('stok_saat_ini').eq('id', invId).single();
          final stokBefore = (inv['stok_saat_ini'] as num).toDouble();
          final stokAfter = stokBefore - qtyKurang;

          await _supabase.from('inventory').update({'stok_saat_ini': stokAfter}).eq('id', invId);
          await _supabase.from('inventory_log').insert({
            'inventory_id': invId, 'tipe': 'keluar', 'qty': qtyKurang,
            'stok_sebelum': stokBefore, 'stok_sesudah': stokAfter,
            'keterangan': 'Order $nomorOrder', 'order_id': order['id'], 'created_by': kasirId,
          });
        }
      }

      if (_voucherData != null) {
        await _supabase.from('reward_redemptions').update({'status': 'dipakai', 'dipakai_di_order': order['id'], 'dipakai_at': now.toIso8601String()}).eq('id', _voucherData!['id']);
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceScreen(
              orderId: order['id'], nomorOrder: nomorOrder,
              namaPelanggan: _selectedCustomer?['nama_lengkap'] ?? 'Umum', nomorHp: _selectedCustomer?['nomor_hp'] ?? '-',
              namaKasir: namaKasir, items: _cart, subtotal: _subtotal, diskon: _diskonVoucher,
              total: _total, metodeBayar: metodeBayarFinal, isPiutang: _tipeBayar == 'piutang',
              created_at: _tglMasuk.toIso8601String(),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Gagal simpan order: $e', Colors.red);
      }
    }
  }

  void _showFormDaftarPelanggan({String nomorHpAwal = ''}) {
    final namaCtrl = TextEditingController();
    final hpCtrl = TextEditingController(text: nomorHpAwal);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom + 24, left: 24, right: 24, top: 16),
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20), const Text('Daftarkan Pelanggan Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4), Text('Password otomatis = nomor HP', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                const SizedBox(height: 20),
                TextFormField(
                  controller: namaCtrl, textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(labelText: 'Nama Lengkap', prefixIcon: const Icon(Icons.badge_outlined, color: Colors.grey, size: 20), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  validator: (v) => v == null || v.trim().length < 3 ? 'Nama minimal 3 huruf' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: hpCtrl, keyboardType: TextInputType.phone, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(labelText: 'Nomor WhatsApp', prefixIcon: const Icon(Icons.phone_android_outlined, color: Colors.grey, size: 20), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  validator: (v) => v == null || v.trim().length < 10 ? 'Nomor HP minimal 10 digit' : null,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                    onPressed: isSubmitting ? null : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        await AuthService().registerPelanggan(phone: hpCtrl.text.trim(), fullName: namaCtrl.text.trim());
                        await Future.delayed(const Duration(milliseconds: 800));
                        await _loadCustomers(); 
                        if (mounted) {
                          Navigator.pop(ctx);
                          final c = _allCustomers.firstWhere((e) => e['nomor_hp'] == hpCtrl.text.trim());
                          setState(() { _selectedCustomer = c; _step = 2; });
                          _showSnackBar('${namaCtrl.text.trim()} berhasil didaftarkan!', Colors.green);
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        _showSnackBar(e.toString().replaceAll('Exception: ', ''), Colors.red);
                      }
                    },
                    child: isSubmitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)) : const Text('Daftarkan & Pilih', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _pickDateOnly({required bool isEstimasi}) async {
    final initDate = isEstimasi ? _estimasiSelesai! : _jatuhTempo!;
    final date = await showDatePicker(
      context: context, initialDate: initDate, 
      firstDate: DateTime(2020), lastDate: DateTime(2030), 
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF1565C0))), child: child!)
    );
    if (date == null) return;
    
    final now = DateTime.now();
    setState(() {
      final dt = DateTime(date.year, date.month, date.day, now.hour, now.minute);
      if (isEstimasi) { _estimasiSelesai = dt; } else { _jatuhTempo = dt; }
    });
  }

  String _formatDateTime(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
    final jam = d.hour.toString().padLeft(2, '0');
    final mnt = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month - 1]} ${d.year}, $jam:$mnt';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, elevation: 0,
        title: Text(_step == 1 ? 'Pilih Pelanggan' : _step == 2 ? 'Pilih Layanan' : 'Detail & Pembayaran', style: const TextStyle(fontWeight: FontWeight.w700)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(4), child: LinearProgressIndicator(value: _step / 3, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation<Color>(Colors.white))),
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: IndexedStack(
                index: _step - 1, 
                children: [_buildStep1Pelanggan(), _buildStep2Layanan(), _buildStep3Bayar()]
              ),
            ),
          ),
          if (_isLoading) Positioned.fill(child: Container(color: Colors.black.withOpacity(0.4), child: const Center(child: CircularProgressIndicator(color: Colors.white)))),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800), child: _buildBottomBar())),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1Pelanggan() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari nama atau nomor HP...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  suffixIcon: _searchCtrl.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); _searchCustomerLokal(''); }) : null,
                ),
                onChanged: _searchCustomerLokal,
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() { _selectedCustomer = null; _step = 2; }),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
                  child: Row(
                    children: [
                      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.person_off_outlined, color: Colors.grey)),
                      const SizedBox(width: 12),
                      const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Tanpa Pelanggan (Umum)', style: TextStyle(fontWeight: FontWeight.w600)), Text('Order tidak terhubung ke akun', style: TextStyle(color: Colors.grey, fontSize: 12))])),
                      const Icon(Icons.chevron_right, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.person_search_outlined, size: 48, color: Colors.grey.shade300), const SizedBox(height: 8),
                      Text('Pelanggan tidak ditemukan', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add_outlined), label: const Text('Daftarkan Baru'),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () => _showFormDaftarPelanggan(nomorHpAwal: _searchCtrl.text),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (context, i) {
                    final c = _filteredCustomers[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: CircleAvatar(backgroundColor: const Color(0xFF1565C0).withOpacity(0.1), child: Text(c['nama_lengkap']?[0]?.toUpperCase() ?? '?', style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w700))),
                        title: Text(c['nama_lengkap'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(c['nomor_hp'] ?? '-'), trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                        onTap: () => setState(() { _selectedCustomer = c; _step = 2; }),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildStep2Layanan() {
    final jasa = _services.where((s) => s['tipe'] != 'produk').toList();
    final produk = _services.where((s) => s['tipe'] == 'produk').toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_selectedCustomer != null)
            Container(
              padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.06), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.2))),
              child: Row(children: [const Icon(Icons.person_outline, color: Color(0xFF1565C0), size: 18), const SizedBox(width: 8), Text(_selectedCustomer!['nama_lengkap'] ?? '-', style: const TextStyle(color: Color(0xFF1565C0), fontWeight: FontWeight.w600))]),
            ),
          if (jasa.isNotEmpty) ...[
            const Text('Layanan Jasa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 8),
            ...jasa.map((s) => _buildServiceTile(s)),
            const SizedBox(height: 16),
          ],
          if (produk.isNotEmpty) ...[
            const Text('Produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)), const SizedBox(height: 8),
            ...produk.map((s) => _buildServiceTile(s)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> s) {
    final qty = _qtyDiKeranjang(s['id']);
    return _ServiceTile(
      service: s, qty: qty, 
      onTambah: () => _tambahKeKeranjang(s), 
      onKurangi: () => _kurangiDariKeranjang(s),
      onEditQty: () {
        final ctrl = TextEditingController(text: qty > 0 ? qty.toString() : '');
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('Ubah Jumlah ${s['nama']}'),
            content: TextField(
              controller: ctrl, keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(hintText: 'Masukkan angka', border: OutlineInputBorder()), autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
              ElevatedButton(
                onPressed: () {
                  final newQty = int.tryParse(ctrl.text) ?? 0;
                  _setQtyManual(s, newQty);
                  Navigator.pop(ctx);
                }, 
                child: const Text('Simpan')
              )
            ],
          )
        );
      },
    );
  }

  Widget _buildStep3Bayar() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Waktu & Tanggal', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero, leading: const Icon(Icons.login_rounded, color: Colors.grey),
                  title: const Text('Tanggal Masuk', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  subtitle: Text(_formatDateTime(_tglMasuk), style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.black)),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF1565C0)),
                  title: const Text('Estimasi Selesai', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  subtitle: Text(_formatDateTime(_estimasiSelesai!), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
                  trailing: const Icon(Icons.edit_calendar_rounded, color: Color(0xFF1565C0), size: 20),
                  onTap: () => _pickDateOnly(isEstimasi: true),
                ),
                if (_tipeBayar == 'piutang') ...[
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero, leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    title: const Text('Batas Jatuh Tempo', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    subtitle: Text(_formatDateTime(_jatuhTempo!), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.orange.shade800)),
                    trailing: Icon(Icons.edit_calendar_rounded, color: Colors.orange.shade800, size: 20),
                    onTap: () => _pickDateOnly(isEstimasi: false),
                  ),
                ]
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text('Ringkasan Pesanan', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                ..._cart.map((item) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [Expanded(child: Text('${item['service']['nama']} × ${item['qty']}', style: const TextStyle(fontSize: 13))), Text(_formatRupiah(item['subtotal']), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]))),
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal'), Text(_formatRupiah(_subtotal), style: const TextStyle(fontWeight: FontWeight.w600))]),
                if (_diskonVoucher > 0) ...[const SizedBox(height: 4), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Diskon Voucher', style: TextStyle(color: Colors.green)), Text('- ${_formatRupiah(_diskonVoucher)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))])],
                const Divider(),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total', style: TextStyle(fontWeight: FontWeight.w700)), Text(_formatRupiah(_total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF1565C0)))]),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Status Pembayaran', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
          Row(
            children: [
              _PayOption(label: 'Lunas', icon: Icons.check_circle_outline, selected: _tipeBayar == 'lunas', color: Colors.green, onTap: () => setState(() => _tipeBayar = 'lunas')),
              const SizedBox(width: 10),
              _PayOption(label: 'Piutang', icon: Icons.schedule_outlined, selected: _tipeBayar == 'piutang', color: Colors.orange, onTap: () => setState(() => _tipeBayar = 'piutang')),
            ],
          ),
          const SizedBox(height: 20),

          if (_tipeBayar != 'piutang') ...[
            const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
            Row(
              children: [
                _PayOption(label: 'Cash', icon: Icons.payments_outlined, selected: _metodeBayar == 'cash', onTap: () => setState(() => _metodeBayar = 'cash')),
                const SizedBox(width: 8),
                _PayOption(label: 'Transfer', icon: Icons.account_balance_wallet_outlined, selected: _metodeBayar == 'transfer', onTap: () => setState(() => _metodeBayar = 'transfer')),
                const SizedBox(width: 8),
                _PayOption(label: 'QRIS', icon: Icons.qr_code_scanner_outlined, selected: _metodeBayar == 'qris', onTap: () => setState(() => _metodeBayar = 'qris')),
              ],
            ),
          ] else ...[
             Container(
               width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(12)),
               child: Row(children: [Icon(Icons.info_outline, color: Colors.orange.shade800, size: 20), const SizedBox(width: 8), Expanded(child: Text('Pastikan "Batas Jatuh Tempo" sudah diatur di bagian atas.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12)))]),
             )
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final itemCount = _cart.fold<int>(0, (s, c) => s + (c['qty'] as int));
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -3))]),
      child: Row(
        children: [
          if (_cart.isNotEmpty && _step == 2)
            Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$itemCount item', style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(_formatRupiah(_subtotal), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF1565C0), fontSize: 16))]))
          else const Spacer(),
          if (_step > 1) TextButton(onPressed: _isLoading ? null : () => setState(() => _step--), child: const Text('← Kembali')),
          const SizedBox(width: 8),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 24)),
              onPressed: _step == 1 ? null : _step == 2 ? (_cart.isEmpty ? null : () => setState(() => _step = 3)) : (_isLoading ? null : _simpanOrder),
              child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : Text(_step == 2 ? 'Lanjut →' : 'Buat Pesanan', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
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
}

class _ServiceTile extends StatelessWidget {
  final Map<String, dynamic> service;
  final int qty;
  final VoidCallback onTambah;
  final VoidCallback onKurangi;
  final VoidCallback onEditQty; 

  const _ServiceTile({required this.service, required this.qty, required this.onTambah, required this.onKurangi, required this.onEditQty});

  @override
  Widget build(BuildContext context) {
    final harga = (service['harga_per_satuan'] as num).toDouble();
    final satuan = service['satuan'] ?? 'pcs';
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: qty > 0 ? Border.all(color: const Color(0xFF1565C0), width: 1.5) : Border.all(color: Colors.grey.shade200)),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(service['nama'] ?? '-', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), Text('${_formatRupiah(harga)} / $satuan', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))])),
          if (qty == 0)
            GestureDetector(onTap: onTambah, child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(8)), child: const Text('+ Tambah', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12))))
          else
            Row(children: [
              GestureDetector(onTap: onKurangi, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.remove, size: 20))),
              GestureDetector(
                onTap: onEditQty,
                child: Container(
                  width: 44, color: Colors.transparent,
                  child: Text('$qty', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1565C0), decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted)),
                ),
              ),
              GestureDetector(onTap: onTambah, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: const Color(0xFF1565C0), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.add, color: Colors.white, size: 20))),
            ]),
        ],
      ),
    );
  }
  
  String _formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0); final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) { if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.'); buffer.write(str[i]); }
    return 'Rp ${buffer.toString()}';
  }
}

class _PayOption extends StatelessWidget {
  final String label; final IconData icon; final bool selected; final Color color; final VoidCallback onTap;
  const _PayOption({required this.label, required this.icon, required this.selected, required this.onTap, this.color = const Color(0xFF1565C0)});
  @override Widget build(BuildContext context) { return Expanded(child: GestureDetector(onTap: onTap, child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: selected ? color.withOpacity(0.08) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? color : Colors.grey.shade200, width: selected ? 1.8 : 1)), child: Column(children: [Icon(icon, color: selected ? color : Colors.grey, size: 22), const SizedBox(height: 4), Text(label, style: TextStyle(color: selected ? color : Colors.grey, fontWeight: selected ? FontWeight.w800 : FontWeight.normal, fontSize: 13))])))); }
}