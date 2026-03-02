import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:laundry_one/features/cashier/screens/printer_selection_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    // --- PELINDUNG: Cegah eksekusi di Windows / Web ---
    if (kIsWeb || !Platform.isAndroid) {
      debugPrint('Bluetooth Printer dilewati (Bukan Android).');
      return; 
    }
    // --------------------------------------------------

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
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  String _formatDateTime(String isoString) {
    if (isoString.isEmpty) return '-';
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

  // ============================================================
  // FITUR SHARE KE WHATSAPP (TEKS RAPI)
  // ============================================================
  void _shareReceipt() {
    HapticFeedback.lightImpact();
    final statusText = widget.isPiutang ? 'BELUM LUNAS (PIUTANG)' : 'LUNAS (${widget.metodeBayar.toUpperCase()})';
    
    StringBuffer sb = StringBuffer();
    sb.writeln('🧾 *NOTA PESANAN - LAUNDRY ONE*');
    sb.writeln('-----------------------------------');
    sb.writeln('No Order : ${widget.nomorOrder}');
    sb.writeln('Tanggal  : ${_formatDateTime(widget.created_at)}');
    sb.writeln('Pelanggan: ${widget.namaPelanggan}');
    sb.writeln('Kasir    : ${widget.namaKasir}');
    sb.writeln('-----------------------------------');
    
    for (var item in widget.items) {
      final nama = item['service']?['nama'] ?? 'Item';
      final qty = item['qty'] ?? 0;
      final sub = item['subtotal'] ?? 0;
      sb.writeln('$qty x $nama');
      sb.writeln('   ${_formatRupiah(sub.toDouble())}');
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

    Share.share(sb.toString(), subject: 'Nota Pesanan ${widget.nomorOrder}');
  }

  // ============================================================
  // FITUR PRINT BLUETOOTH THERMAL
  // ============================================================
void _showPrinterDialog() async {
    HapticFeedback.lightImpact();

    // --- PELINDUNG: Cegah eksekusi di Windows / Web ---
    if (kIsWeb || !Platform.isAndroid) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Fitur cetak Bluetooth hanya tersedia di perangkat Android.'),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // --------------------------------------------------

    // BUKA LAYAR SELEKSI PRINTER YANG BARU DIBUAT
    final selectedDevice = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PrinterSelectionScreen()),
    );

    // JIKA KASIR MEMILIH PRINTER, LANGSUNG EKSEKUSI CETAK
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
      
      // LOGIKA CETAK KERTAS STRUK
      bluetooth.printCustom("LAUNDRY ONE", 3, 1); // Size 3, Align Center
      bluetooth.printNewLine();
      bluetooth.printCustom(widget.nomorOrder, 1, 1);
      bluetooth.printCustom(_formatDateTime(widget.created_at), 1, 1);
      bluetooth.printNewLine();
      
      bluetooth.printLeftRight("Pelanggan", widget.namaPelanggan, 1);
      bluetooth.printLeftRight("Kasir", widget.namaKasir, 1);
      bluetooth.printCustom("--------------------------------", 1, 1);
      
      for (var item in widget.items) {
        final nama = item['service']?['nama'] ?? 'Item';
        final qty = item['qty'] ?? 0;
        final sub = item['subtotal'] ?? 0;
        bluetooth.printCustom("$qty x $nama", 1, 0); // Align Left
        bluetooth.printLeftRight("", _formatRupiah(sub.toDouble()), 1);
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
      bluetooth.paperCut(); // Potong kertas otomatis (jika didukung)
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal mencetak: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.ground, 
      appBar: widget.isFromHome 
        ? AppBar(
            backgroundColor: _DS.navy, foregroundColor: Colors.white, elevation: 0,
            title: const Text('Detail Pesanan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ) 
        : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    
                    // CEKLIS HIJAU (Hanya jika order baru)
                    if (!widget.isFromHome) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.isPiutang ? 'Pesanan Disimpan!' : 'Pembayaran Berhasil!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _DS.textPrimary)),
                      const SizedBox(height: 24),
                    ],
                    
                    // KERTAS NOTA MENGAMBANG
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: _DS.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: _DS.border, width: 1.5), boxShadow: _DS.cardShadow),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                const Icon(Icons.receipt_long_rounded, color: _DS.blue, size: 36),
                                const SizedBox(height: 8),
                                const Text('NOTA PESANAN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1, color: _DS.textPrimary)),
                                const SizedBox(height: 4),
                                Text(widget.nomorOrder, style: const TextStyle(color: _DS.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: _DS.border, thickness: 1.5),
                          const SizedBox(height: 16),

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tanggal Transaksi', style: TextStyle(color: _DS.textSecondary, fontSize: 12)), Text(_formatDateTime(widget.created_at), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _DS.textPrimary))]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Kasir', style: TextStyle(color: _DS.textSecondary, fontSize: 12)), Text(widget.namaKasir, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _DS.textPrimary))]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Pelanggan', style: TextStyle(color: _DS.textSecondary, fontSize: 12)), Text(widget.namaPelanggan, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _DS.textPrimary))]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('No. HP', style: TextStyle(color: _DS.textSecondary, fontSize: 12)), Text(widget.nomorHp, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _DS.textPrimary))]),
                          
                          const SizedBox(height: 16),
                          const Divider(color: _DS.border, thickness: 1.5),
                          const SizedBox(height: 16),

                          const Text('Detail Layanan:', style: TextStyle(fontWeight: FontWeight.w700, color: _DS.textSecondary, fontSize: 12)),
                          const SizedBox(height: 12),
                          ...widget.items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['qty']}x ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _DS.textPrimary)),
                                Expanded(child: Text('${item['service']['nama']}', style: const TextStyle(fontSize: 13, color: _DS.textPrimary))), 
                                Text(_formatRupiah(item['subtotal']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _DS.textPrimary))
                              ]
                            )
                          )),
                          
                          const SizedBox(height: 16),
                          const Divider(color: _DS.border, thickness: 1.5),
                          const SizedBox(height: 12),

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(color: _DS.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)), Text(_formatRupiah(widget.subtotal), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _DS.textPrimary))]),
                          if (widget.diskon > 0) ...[
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Diskon Voucher', style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w600)), Text('- ${_formatRupiah(widget.diskon)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w700, fontSize: 13))]),
                          ],
                          const SizedBox(height: 16),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('TOTAL AKHIR', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _DS.textPrimary)), Text(_formatRupiah(widget.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: _DS.blue, letterSpacing: -0.5))]),
                          
                          const SizedBox(height: 24),
                          if (widget.isPiutang)
                            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)), child: Text('STATUS: PIUTANG (BELUM LUNAS)', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)))
                          else
                            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)), child: Text('STATUS: LUNAS (${widget.metodeBayar.toUpperCase()})', textAlign: TextAlign.center, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // ACTION BUTTONS (STICKY BAWAH) KONSISTEN DENGAN DS
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(color: _DS.surface, boxShadow: [BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))]),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareReceipt, icon: const Icon(Icons.share_rounded, size: 18), label: const Text('Share Nota', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(foregroundColor: _DS.blue, padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: _DS.border, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showPrinterDialog, icon: const Icon(Icons.print_rounded, size: 18), label: const Text('Cetak Struk', style: TextStyle(fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(foregroundColor: _DS.blue, padding: const EdgeInsets.symmetric(vertical: 14), side: const BorderSide(color: _DS.border, width: 1.5), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (widget.isFromHome) ...[
                    if (widget.status == 'diproses')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: double.infinity, height: 50,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.check_circle_outline), label: const Text('Tandai Cucian Selesai', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                            style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                            onPressed: () { Navigator.pop(context, 'selesai'); },
                          ),
                        ),
                      ),

                    if (widget.isPiutang)
                      SizedBox(
                        width: double.infinity, height: 50,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.payments_outlined), label: const Text('Lunasi Tagihan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                          onPressed: () { Navigator.pop(context, 'dibayar_lunas'); }, 
                        ),
                      )
                  ] 
                  else ...[
                    SizedBox(
                      width: double.infinity, height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: _DS.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kembali ke Beranda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      ),
                    ),
                  ]
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}