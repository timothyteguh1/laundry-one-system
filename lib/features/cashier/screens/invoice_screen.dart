import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:laundry_one/features/cashier/screens/printer_selection_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// [UPDATE DESAIN]: Menggunakan AppTokens terpusat, HAPUS class _DS
// Ganti path ini sesuai dengan lokasi AppTokens di project Anda
import 'package:laundry_one/core/tokens/app_tokens.dart';

class InvoiceScreen extends StatefulWidget {
  final String orderId;
  final String nomorOrder;
  final String namaPelanggan;
  final String nomorHp;
  final String namaKasir;
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double diskon;
  final double total;
  final String metodeBayar;
  final bool isPiutang;
  final String created_at;
  final bool isFromHome;
  final String? status;
  final bool isAdmin;

  const InvoiceScreen({
    super.key,
    required this.orderId,
    required this.nomorOrder,
    required this.namaPelanggan,
    required this.nomorHp,
    required this.namaKasir,
    required this.items,
    required this.subtotal,
    required this.diskon,
    required this.total,
    required this.metodeBayar,
    required this.isPiutang,
    this.created_at = '',
    this.isFromHome = false,
    this.status,
    this.isAdmin = false,
  });

  @override
  State<InvoiceScreen> createState() => _InvoiceScreenState();
}

class _InvoiceScreenState extends State<InvoiceScreen> {
  // BLUETOOTH PRINTER INSTANCE
  BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _connected = false;

  final _supabase = Supabase.instance.client;
  String? _branchName;
  String? _branchAddress;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
    _loadBranchInfo();
  }

  // [MULTI-BRANCH]: Fetch branch name & address dynamically from branches table
  Future<void> _loadBranchInfo() async {
    try {
      final order = await _supabase
          .from('orders')
          .select('branch_id')
          .eq('id', widget.orderId)
          .maybeSingle();

      final branchId = order?['branch_id'] as String?;
      if (branchId != null) {
        final branch = await _supabase
            .from('branches')
            .select('nama_cabang, alamat')
            .eq('id', branchId)
            .maybeSingle();
        if (branch != null && mounted) {
          setState(() {
            _branchName = branch['nama_cabang'] as String?;
            _branchAddress = branch['alamat'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading branch info: $e');
    }
  }

  // ============================================================
  // [PERBAIKAN BUG]: LOGIKA HAPUS NOTA YANG LEBIH AKURAT
  // ============================================================
  Future<void> _hapusNota() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radius16)),
        title: const Row(children: [Icon(Icons.warning_amber_rounded, color: Colors.red), SizedBox(width: 8), Text('Hapus Permanen?', style: TextStyle(fontWeight: FontWeight.bold))]),
        content: const Text('Yakin ingin menghapus nota ini secara permanen? Data pembayaran, nota, dan audit akan terhapus. (Poin & Voucher akan dikembalikan ke pelanggan otomatis jika ada).'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      HapticFeedback.heavyImpact();
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator(color: Colors.white)));

      try {
        final orderId = widget.orderId;
        final currentKasirId = _supabase.auth.currentUser!.id;

        // Ambil data order lengkap beserta branch_id nya
        final ord = await _supabase.from('orders').select().eq('id', orderId).single();
        final custId = ord['customer_id'];
        final int poin = ord['poin_didapat'] ?? 0;
        final bool poinDiberikan = ord['poin_sudah_diberikan'] == true;
        final branchId = ord['branch_id']; // <--- KUNCI PERBAIKAN: Ambil ID Cabang

        // 1. TARIK KEMBALI POIN EARNED (JIKA ADA)
        if (custId != null && poinDiberikan && poin > 0) {
          final custData = await _supabase.from('customers').select('poin_saldo').eq('id', custId).single();
          final int saldoSaatIni = custData['poin_saldo'] ?? 0;
          final int saldoBaru = (saldoSaatIni - poin < 0) ? 0 : saldoSaatIni - poin;
          
          await _supabase.from('customers').update({'poin_saldo': saldoBaru}).eq('id', custId);
          
          await _supabase.from('points_ledger').insert({
            'customer_id': custId,
            'branch_id': branchId, // <--- PASTIKAN MASUK KE CABANG YANG TEPAT
            'tipe': 'reversed',
            'jumlah': -poin,
            'saldo_sebelum': saldoSaatIni,
            'saldo_sesudah': saldoBaru,
            'dilakukan_oleh': currentKasirId,
            'catatan': 'Pembatalan Poin (Nota Dihapus)',
          });
        }

        // 2. REFUND POIN VOUCHER (TANPA SYARAT DISKON)
        if (custId != null) {
          List<dynamic> redemptions = [];
          
          try {
            // Tarik semua voucher yang terikat ke nota ini (baik diskon maupun barang fisik)
            final res = await _supabase.from('reward_redemptions').select().eq('dipakai_di_order', orderId);
            if (res.isNotEmpty) redemptions.addAll(res);
          } catch (_) {}

          for (var red in redemptions) {
            final int poinDigunakan = red['poin_digunakan'] ?? 0;
            final String? redCustId = red['customer_id'];

            if (redCustId != null && poinDigunakan > 0) {
              final custData = await _supabase.from('customers').select('poin_saldo').eq('id', redCustId).single();
              final int saldoSaatIni = custData['poin_saldo'] ?? 0;
              final int saldoBaru = saldoSaatIni + poinDigunakan;

              await _supabase.from('customers').update({'poin_saldo': saldoBaru}).eq('id', redCustId);

              // KEMBALIKAN POIN KE PELANGGAN
              await _supabase.from('points_ledger').insert({
                'customer_id': redCustId,
                'branch_id': branchId, // <--- PASTIKAN MASUK KE CABANG YANG TEPAT
                'tipe': 'reversed',
                'jumlah': poinDigunakan, // Angka Positif = Saldo Bertambah
                'saldo_sebelum': saldoSaatIni,
                'saldo_sesudah': saldoBaru,
                'dilakukan_oleh': currentKasirId,
                'catatan': 'Pengembalian Poin (Voucher Dibatalkan)',
              });
            }

            try {
               await _supabase.from('notifications').delete().eq('redemption_id', red['id']);
            } catch (_) {}

            // Hapus rekam jejak voucher
            await _supabase.from('reward_redemptions').delete().eq('id', red['id']);
          }
        }

        // 3. Eksekusi Hapus Nota Utama
        await _supabase.from('orders').delete().eq('id', orderId);

        if (mounted) {
          Navigator.pop(context); // Tutup Loading
          Navigator.pop(context, 'dihapus'); // Tutup Invoice
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Nota batal & Poin/Voucher telah dikembalikan!'), backgroundColor: Colors.green));
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); 
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red));
        }
      }
    }
  }

  Future<void> _initBluetooth() async {
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Bluetooth Printer dilewati (Bukan Android).');
      return;
    }

    try {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      if (mounted) setState(() => _devices = devices);
    } on PlatformException {
      // Handle permission or BT off errors here silently
    }
    bluetooth.onStateChanged().listen((state) {
      switch (state) {
        case BlueThermalPrinter.CONNECTED:
          setState(() => _connected = true);
          break;
        case BlueThermalPrinter.DISCONNECTED:
        case BlueThermalPrinter.DISCONNECT_REQUESTED:
          setState(() => _connected = false);
          break;
        default:
          break;
      }
    });
  }

  String _formatRupiah(double amount) {
    return AppTokens.formatRupiah(amount);
  }

  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      DateTime d = DateTime.parse(isoString).toLocal();

      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Ags', 'Sep', 'Okt', 'Nov', 'Des'];
      final jam = d.hour.toString().padLeft(2, '0');
      final mnt = d.minute.toString().padLeft(2, '0');

      return '${d.day} ${months[d.month - 1]} ${d.year}, $jam:$mnt WIB';
    } catch (e) {
      return '-';
    }
  }

  Future<void> _shareReceipt() async {
    HapticFeedback.lightImpact();
    final statusText = widget.isPiutang
        ? 'BELUM LUNAS (PIUTANG)'
        : 'LUNAS (${widget.metodeBayar.toUpperCase()})';

    // Gunakan nama cabang dinamis, fallback ke "LAUNDRY" jika kosong
    final namaCabang = _branchName?.toUpperCase() ?? 'LAUNDRY';

    StringBuffer sb = StringBuffer();
    sb.writeln('🧾 *NOTA PESANAN - $namaCabang*');
    sb.writeln('-----------------------------------');
    sb.writeln('No Order : ${widget.nomorOrder}');
    sb.writeln('Tanggal  : ${_formatDateTime(widget.created_at)}');
    sb.writeln('Pelanggan: ${widget.namaPelanggan}');
    sb.writeln('Kasir    : ${widget.namaKasir}');
    sb.writeln('-----------------------------------');

    for (var item in widget.items) {
      String nama = item['service']?['nama'] ?? 'Item';
      final int qty = item['qty'] ?? 0;
      final double sub = (item['subtotal'] as num).toDouble();
      final int hargaNormal = item['service']?['harga_per_satuan'] ?? 0;
      
      if (sub < (hargaNormal * qty)) {
        nama = "$nama (Grosir)";
      }

      sb.writeln('$qty x $nama');
      sb.writeln('   ${_formatRupiah(sub)}');
    }

    sb.writeln('-----------------------------------');
    sb.writeln('Subtotal : ${_formatRupiah(widget.subtotal)}');
    if (widget.diskon > 0) {
      sb.writeln('Diskon   : - ${_formatRupiah(widget.diskon)}');
    }
    sb.writeln('TOTAL    : *${_formatRupiah(widget.total)}*');
    sb.writeln('Status   : *$statusText*');
    sb.writeln('-----------------------------------');
    sb.writeln('Terima kasih telah menggunakan jasa kami! 🙏');
    String formattedNumber = widget.nomorHp;
    if (formattedNumber.startsWith('0')) {
      formattedNumber = '62${formattedNumber.substring(1)}';
    } else if (formattedNumber.startsWith('+62')) {
      formattedNumber = formattedNumber.replaceAll('+', '');
    } else if (formattedNumber.startsWith('8')) {
      formattedNumber = '62$formattedNumber';
    }

    // 2. Encode teks nota agar aman masuk URL
    String encodedPesan = Uri.encodeComponent(sb.toString());

    // 3. Buat URL WhatsApp
    final Uri waUrl = Uri.parse('https://wa.me/$formattedNumber?text=$encodedPesan');

    // 4. Eksekusi Buka WhatsApp
    try {
      await launchUrl(waUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal membuka WhatsApp. Pastikan aplikasi terinstal di perangkat ini.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  void _showPrinterDialog() async {
    HapticFeedback.lightImpact();

    if (kIsWeb || !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fitur cetak Bluetooth hanya tersedia di perangkat Android.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final selectedDevice = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
    );

    if (selectedDevice != null && selectedDevice is BluetoothDevice) {
      _connectAndPrint(selectedDevice);
    }
  }

  Future<void> _connectAndPrint(BluetoothDevice device) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == false) {
        await bluetooth.connect(device);
      }

      final namaCabang = _branchName?.toUpperCase() ?? 'LAUNDRY';
      bluetooth.printCustom(namaCabang, 3, 1); 
      bluetooth.printNewLine();
      bluetooth.printCustom(widget.nomorOrder, 1, 1);
      bluetooth.printCustom(_formatDateTime(widget.created_at), 1, 1);
      bluetooth.printNewLine();

      bluetooth.printLeftRight("Pelanggan", widget.namaPelanggan, 1);
      bluetooth.printLeftRight("Kasir", widget.namaKasir, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);

      for (var item in widget.items) {
        String nama = item['service']?['nama'] ?? 'Item';
        final int qty = item['qty'] ?? 0;
        final double sub = (item['subtotal'] as num).toDouble();
        final int hargaNormal = item['service']?['harga_per_satuan'] ?? 0;
        
        if (sub < (hargaNormal * qty)) {
          nama = "$nama (Grosir)";
        }

        bluetooth.printCustom("$qty x $nama", 1, 0); 
        bluetooth.printLeftRight("", _formatRupiah(sub), 1);
      }

      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("Subtotal", _formatRupiah(widget.subtotal), 1);
      if (widget.diskon > 0) {
        bluetooth.printLeftRight("Diskon", "- ${_formatRupiah(widget.diskon)}", 1);
      }
      bluetooth.printCustom("--------------------------------", 1, 1);
      bluetooth.printLeftRight("TOTAL", _formatRupiah(widget.total), 2);

      bluetooth.printNewLine();
      if (widget.isPiutang) {
        bluetooth.printCustom("STATUS: BELUM LUNAS (PIUTANG)", 1, 1);
      } else {
        bluetooth.printCustom("STATUS: LUNAS (${widget.metodeBayar.toUpperCase()})", 1, 1);
      }

      bluetooth.printNewLine();
      bluetooth.printCustom("Terima Kasih!", 1, 1);
      bluetooth.printNewLine();
      bluetooth.printNewLine();
      bluetooth.paperCut(); 
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencetak: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.ground,
      appBar: widget.isFromHome
          ? AppBar(
              backgroundColor: AppTokens.navy,
              foregroundColor: Colors.white,
              elevation: 0,
              title: const Text(
                'Detail Pesanan',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            )
          : null,
      body: SafeArea(
        child: Center( 
          child: ConstrainedBox( 
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(AppTokens.space24),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        if (!widget.isFromHome) ...[
                          Container(
                            padding: const EdgeInsets.all(AppTokens.space16),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Colors.green,
                              size: 56,
                            ),
                          ),
                          const SizedBox(height: AppTokens.space16),
                          Text(
                            widget.isPiutang
                                ? 'Pesanan Disimpan!'
                                : 'Pembayaran Berhasil!',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppTokens.textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppTokens.space24),
                        ],

                        Container(
                          padding: const EdgeInsets.all(AppTokens.space24),
                          decoration: BoxDecoration(
                            color: AppTokens.surface,
                            borderRadius: BorderRadius.circular(AppTokens.radius20),
                            border: Border.all(color: AppTokens.border, width: 1.5),
                            boxShadow: AppTokens.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.receipt_long_rounded,
                                      color: AppTokens.blue,
                                      size: 36,
                                    ),
                                    const SizedBox(height: AppTokens.space8),
                                    const Text(
                                      'NOTA PESANAN',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 18,
                                        letterSpacing: 1,
                                        color: AppTokens.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: AppTokens.space4),
                                     Text(
                                       widget.nomorOrder,
                                       style: const TextStyle(
                                         color: AppTokens.textSecondary,
                                         fontSize: 13,
                                         fontWeight: FontWeight.w600,
                                       ),
                                     ),
                                     const SizedBox(height: AppTokens.space4),

                                     // [MULTI-BRANCH]: Nama & alamat cabang secara dinamis
                                     if (_branchName != null)
                                       Text(
                                         _branchName!,
                                         style: const TextStyle(
                                           color: AppTokens.textPrimary,
                                           fontSize: 13,
                                           fontWeight: FontWeight.w700,
                                         ),
                                       ),
                                     if (_branchAddress != null)
                                       Text(
                                         _branchAddress!,
                                         style: const TextStyle(
                                           color: AppTokens.textSecondary,
                                           fontSize: 11,
                                         ),
                                         textAlign: TextAlign.center,
                                       ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppTokens.space20),
                              const Divider(color: AppTokens.border, thickness: 1.5),
                              const SizedBox(height: AppTokens.space16),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tanggal Transaksi',
                                    style: TextStyle(color: AppTokens.textSecondary, fontSize: 12),
                                  ),
                                  Text(
                                    _formatDateTime(widget.created_at),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTokens.textPrimary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppTokens.space8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Kasir', style: TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
                                  Text(widget.namaKasir, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTokens.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: AppTokens.space8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Pelanggan', style: TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
                                  Text(widget.namaPelanggan, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTokens.textPrimary)),
                                ],
                              ),
                              const SizedBox(height: AppTokens.space8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('No. HP', style: TextStyle(color: AppTokens.textSecondary, fontSize: 12)),
                                  Text(widget.nomorHp, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppTokens.textPrimary)),
                                ],
                              ),

                              const SizedBox(height: AppTokens.space16),
                              const Divider(color: AppTokens.border, thickness: 1.5),
                              const SizedBox(height: AppTokens.space16),

                              const Text('Detail Layanan:', style: TextStyle(fontWeight: FontWeight.w700, color: AppTokens.textSecondary, fontSize: 12)),
                              const SizedBox(height: AppTokens.space12),
                              ...widget.items.map(
                                (item) {
                                  String itemName = item['service']['nama'] ?? 'Item';
                                  final int qty = item['qty'] ?? 0;
                                  final double sub = (item['subtotal'] as num).toDouble();
                                  final int hargaNormal = item['service']['harga_per_satuan'] ?? 0;
                                  
                                  if (sub < (hargaNormal * qty)) {
                                    itemName = "$itemName (Grosir)";
                                  }

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${item['qty']}x ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTokens.textPrimary)),
                                        Expanded(child: Text(itemName, style: const TextStyle(fontSize: 13, color: AppTokens.textPrimary))),
                                        Text(_formatRupiah(item['subtotal']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTokens.textPrimary)),
                                      ],
                                    ),
                                  );
                                }
                              ),

                              const SizedBox(height: AppTokens.space16),
                              const Divider(color: AppTokens.border, thickness: 1.5),
                              const SizedBox(height: AppTokens.space12),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Subtotal', style: TextStyle(color: AppTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(_formatRupiah(widget.subtotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTokens.textPrimary)),
                                ],
                              ),
                              if (widget.diskon > 0) ...[
                                const SizedBox(height: AppTokens.space8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Diskon Voucher', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)),
                                    Text('- ${_formatRupiah(widget.diskon)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: AppTokens.space16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('TOTAL AKHIR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTokens.textPrimary)),
                                  Text(_formatRupiah(widget.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppTokens.blue, letterSpacing: -0.5)),
                                ],
                              ),

                              const SizedBox(height: AppTokens.space24),
                              if (widget.isPiutang)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    'STATUS: PIUTANG (BELUM LUNAS)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Text(
                                    'STATUS: LUNAS (${widget.metodeBayar.toUpperCase()})',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  decoration: BoxDecoration(
                    color: AppTokens.surface,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareReceipt,
                              icon: const Icon(Icons.share_rounded, size: 18),
                              label: const Text('Share Nota', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTokens.blue,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppTokens.border, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTokens.space12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showPrinterDialog,
                              icon: const Icon(Icons.print_rounded, size: 18),
                              label: const Text('Cetak Struk', style: TextStyle(fontWeight: FontWeight.w700)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTokens.blue,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                side: const BorderSide(color: AppTokens.border, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space12),

                      if (widget.isFromHome) ...[
                        if (widget.status == 'diproses')
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline),
                                label: const Text('Tandai Cucian Selesai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTokens.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                onPressed: () { Navigator.pop(context, 'selesai'); },
                              ),
                            ),
                          ),

                        if (widget.isPiutang)
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Lunasi Tagihan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green.shade600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: () { Navigator.pop(context, 'dibayar_lunas'); },
                            ),
                          ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTokens.blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 0,
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Kembali ke Beranda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          ),
                        ),
                      ],

                      if (widget.isAdmin) ...[
                        const SizedBox(height: AppTokens.space12),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                            label: const Text('Hapus Nota (Permanen)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 15)),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.red.shade50,
                              side: BorderSide(color: Colors.red.shade200, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: _hapusNota,
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}