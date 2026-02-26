import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ============================================================
// INVOICE SCREEN
// Tampil setelah order berhasil dibuat
// - Detail pesanan lengkap
// - Tombol Print (Bluetooth thermal printer)
// - Tombol Selesai → kembali ke beranda
//
// Untuk print Bluetooth, tambahkan package:
// blue_thermal_printer: ^1.0.9 (di pubspec.yaml)
// ============================================================

class InvoiceScreen extends StatelessWidget {
  final String orderId;
  final String nomorOrder;
  final String namaPelanggan;
  final String nomorHp;
  final String namaKasir; // <-- TAMBAHAN BARU: Nama Kasir
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final double diskon;
  final double total;
  final String metodeBayar;
  final bool isPiutang;

  const InvoiceScreen({
    super.key,
    required this.orderId,
    required this.nomorOrder,
    required this.namaPelanggan,
    required this.nomorHp,
    required this.namaKasir, // <-- TAMBAHAN BARU
    required this.items,
    required this.subtotal,
    required this.diskon,
    required this.total,
    required this.metodeBayar,
    required this.isPiutang,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final tanggal =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Invoice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        leading: const SizedBox(), // sembunyikan back button
        actions: [
          TextButton(
            onPressed: () {
              // Kembali ke beranda kasir
              Navigator.popUntil(context, (route) => route.isFirst);
            },
            child: const Text('Selesai',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // =====================
            // KERTAS INVOICE
            // =====================
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header invoice
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_laundry_service_rounded,
                            color: Colors.white, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Laundry One',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              tanggal,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        // Badge status bayar
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isPiutang
                                ? Colors.orange.withOpacity(0.25)
                                : Colors.green.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isPiutang
                                  ? Colors.orange
                                  : Colors.green,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            isPiutang ? 'PIUTANG' : 'LUNAS',
                            style: TextStyle(
                              color: isPiutang
                                  ? Colors.orange.shade200
                                  : Colors.green.shade200,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nomor order
                        Center(
                          child: Text(
                            nomorOrder,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Garis putus-putus
                        _DashedDivider(),
                        const SizedBox(height: 12),

                        // Header tabel
                        Row(
                          children: [
                            Expanded(
                                child: Text('Item',
                                    style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            Text('Qty',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 60),
                            Text('Harga',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Item list
                        ...items.map((item) {
                          final nama = item['service']['nama'] ?? '-';
                          final qty = item['qty'];
                          final subtotalItem =
                              (item['subtotal'] as double);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(nama,
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500)),
                                ),
                                Text('$qty',
                                    style: const TextStyle(fontSize: 13)),
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    _formatRupiah(subtotalItem),
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 8),
                        _DashedDivider(),
                        const SizedBox(height: 12),

                        // Subtotal
                        _InvoiceRow(
                            label: 'Subtotal',
                            value: _formatRupiah(subtotal)),
                        if (diskon > 0)
                          _InvoiceRow(
                            label: 'Diskon Voucher',
                            value: '- ${_formatRupiah(diskon)}',
                            valueColor: Colors.green,
                          ),
                        const SizedBox(height: 8),

                        // Total
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF1565C0).withOpacity(0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15)),
                              Text(
                                _formatRupiah(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 20,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Metode bayar
                        _InvoiceRow(
                          label: 'Metode',
                          value: metodeBayar == 'cash' ? 'Cash' : 'Non-Cash',
                        ),
                        _InvoiceRow(
                          label: 'Status',
                          value: isPiutang ? 'Belum Lunas (Piutang)' : 'Lunas',
                          valueColor:
                              isPiutang ? Colors.orange : Colors.green,
                        ),

                        const SizedBox(height: 16),
                        _DashedDivider(),
                        const SizedBox(height: 12),

                        // --- INFORMASI KASIR & PELANGGAN ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kasir:', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                Text(namaKasir, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Pelanggan:', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                Text(namaPelanggan == 'Umum' ? 'Umum' : '$namaPelanggan\n$nomorHp', 
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                              ],
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),

                        Center(
                          child: Text(
                            'Terima kasih telah mempercayakan\ncucian Anda kepada kami 🙏',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // =====================
            // TOMBOL PRINT
            // =====================
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text(
                  'Print via Bluetooth',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: () => _printBluetooth(context, tanggal),
              ),
            ),
            const SizedBox(height: 12),

            // Tombol selesai
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side:
                      const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () =>
                    Navigator.popUntil(context, (route) => route.isFirst),
                child: const Text(
                  'Kembali ke Beranda',
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PRINT BLUETOOTH
  // ============================================================
  void _printBluetooth(BuildContext context, String tanggal) async {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Print Invoice',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Pastikan printer thermal Bluetooth sudah:\n'),
            const Text('• Menyala dan dalam jangkauan'),
            const Text('• Sudah di-pair di pengaturan Bluetooth HP'),
            const Text('• Kertas tersedia'),
            const SizedBox(height: 12),
            Text(
              'Paket yang dibutuhkan:\nblue_thermal_printer: ^1.0.9',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 12,
                  fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Tambahkan blue_thermal_printer di pubspec.yaml dulu'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text('Lanjut Print'),
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

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = (constraints.maxWidth / 8).floor();
        return Row(
          children: List.generate(count, (_) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 1,
              color: Colors.grey.shade300,
            ),
          )),
        );
      },
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InvoiceRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}