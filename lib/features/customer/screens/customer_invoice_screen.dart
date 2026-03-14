import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';

class CustomerInvoiceScreen extends StatelessWidget {
  final Map<String, dynamic> order;

  const CustomerInvoiceScreen({super.key, required this.order});

  String _formatRupiah(num amount) {
    final str = amount.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return 'Rp ${buffer.toString()}';
  }

  // 👇 UPDATE: PERBAIKAN WAKTU WIB DI PELANGGAN
  String _formatDateTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '-';
    try {
      // 1. Cukup parse dan toLocal(). Jangan pakai pemaksaan 'Z' lagi.
      // Dart sudah sangat pintar mengenali mana yang UTC dan mana yang WIB.
      DateTime d = DateTime.parse(isoString).toLocal();

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

      return '${d.day} ${months[d.month - 1]} ${d.year}, $jam:$mnt WIB';
    } catch (e) {
      return '-';
    }
  }

  // ==========================================
  // PENGATURAN WARNA TEMA DINAMIS BERDASARKAN STATUS
  // ==========================================
  Color _getThemeColor(String status) {
    if (status == 'diproses') return Colors.orange.shade600;
    if (status == 'dibatalkan') return Colors.grey.shade600;
    return CustomerTheme.primary; // selesai / lunas
  }

  Color _getLightThemeColor(String status) {
    if (status == 'diproses') return Colors.orange.shade50;
    if (status == 'dibatalkan') return Colors.grey.shade100;
    return CustomerTheme.primaryLight;
  }

  void _shareReceipt() {
    HapticFeedback.lightImpact();
    final status = order['status'] ?? '';
    final isPiutang = order['is_piutang'] ?? false;
    final metodeBayar = order['metode_bayar_awal'] ?? 'cash';

    String statusText = '';
    if (status == 'dibatalkan') {
      statusText = 'DIBATALKAN';
    } else if (isPiutang) {
      statusText = 'BELUM LUNAS (PIUTANG)';
    } else {
      statusText = 'LUNAS (${metodeBayar.toString().toUpperCase()})';
    }

    final nomorOrder = order['nomor_order'] ?? '-';
    final namaPelanggan =
        order['customers']?['profiles']?['nama_lengkap'] ?? '-';
    final namaKasir = order['profiles']?['nama_lengkap'] ?? '-';
    final subtotal =
        (order['total_harga'] ?? 0) + (order['diskon_voucher'] ?? 0);
    final diskon = order['diskon_voucher'] ?? 0;
    final total = order['total_harga'] ?? 0;
    final items = order['order_items'] as List<dynamic>? ?? [];

    StringBuffer sb = StringBuffer();
    sb.writeln('🧾 *NOTA PESANAN - LAUNDRY ONE*');
    sb.writeln('-----------------------------------');
    sb.writeln('No Order : $nomorOrder');
    sb.writeln('Tanggal  : ${_formatDateTime(order['created_at'])}');
    sb.writeln('Pelanggan: $namaPelanggan');
    sb.writeln('Kasir    : $namaKasir');
    sb.writeln('-----------------------------------');

    for (var item in items) {
      final nama = item['services']?['nama'] ?? 'Item';
      final qty = item['jumlah'] ?? 0;
      final hargaSatuan = item['harga_satuan'] ?? 0;
      final sub = qty * hargaSatuan;
      sb.writeln('$qty x $nama');
      sb.writeln('   ${_formatRupiah(sub)}');
    }

    sb.writeln('-----------------------------------');
    sb.writeln('Subtotal : ${_formatRupiah(subtotal)}');
    if (diskon > 0) {
      sb.writeln('Diskon   : - ${_formatRupiah(diskon)}');
    }
    sb.writeln('TOTAL    : *${_formatRupiah(total)}*');
    sb.writeln('Status   : *$statusText*');
    sb.writeln('-----------------------------------');
    sb.writeln('Terima kasih telah menggunakan jasa kami! 🙏');

    Share.share(sb.toString(), subject: 'Nota Pesanan $nomorOrder');
  }

  @override
  Widget build(BuildContext context) {
    final items = order['order_items'] as List<dynamic>? ?? [];
    final nomorOrder = order['nomor_order'] ?? '-';
    final namaPelanggan =
        order['customers']?['profiles']?['nama_lengkap'] ?? '-';
    final nomorHp = order['customers']?['profiles']?['nomor_hp'] ?? '-';
    final namaKasir = order['profiles']?['nama_lengkap'] ?? 'Admin Kasir';
    final subtotal =
        (order['total_harga'] ?? 0) + (order['diskon_voucher'] ?? 0);
    final diskon = order['diskon_voucher'] ?? 0;
    final total = order['total_harga'] ?? 0;
    final isPiutang = order['is_piutang'] ?? false;
    final metodeBayar = order['metode_bayar_awal'] ?? 'cash';
    final status = order['status'] ?? 'draft';

    // Ambil warna tema sesuai status!
    final themeColor = _getThemeColor(status);
    final lightThemeColor = _getLightThemeColor(status);

    return Scaffold(
      backgroundColor: CustomerTheme.ground,
      appBar: AppBar(
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Detail Pesanan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
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

                    // KERTAS NOTA MENGAMBANG
                    Container(
                      decoration: BoxDecoration(
                        color: CustomerTheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: CustomerTheme.border,
                          width: 1.5,
                        ),
                        boxShadow: CustomerTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // HEADER WARNA DINAMIS
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: lightThemeColor,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(18),
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: themeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.receipt_long_rounded,
                                    color: Colors.white,
                                    size: 36,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'NOTA PESANAN',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 18,
                                    letterSpacing: 1,
                                    color: themeColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  nomorOrder,
                                  style: const TextStyle(
                                    color: CustomerTheme.textSecondary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Tanggal Transaksi',
                                      style: TextStyle(
                                        color: CustomerTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _formatDateTime(order['created_at']),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: CustomerTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Kasir',
                                      style: TextStyle(
                                        color: CustomerTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      namaKasir,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: CustomerTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Pelanggan',
                                      style: TextStyle(
                                        color: CustomerTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      namaPelanggan,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: CustomerTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'No. HP',
                                      style: TextStyle(
                                        color: CustomerTheme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      nomorHp,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: CustomerTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 16),
                                const Divider(
                                  color: CustomerTheme.border,
                                  thickness: 1.5,
                                ),
                                const SizedBox(height: 16),

                                const Text(
                                  'Detail Layanan:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: CustomerTheme.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ...items.map((item) {
                                  final nama =
                                      item['services']?['nama'] ?? 'Item';
                                  final qty = item['jumlah'] ?? 0;
                                  final hargaSatuan = item['harga_satuan'] ?? 0;
                                  final sub = qty * hargaSatuan;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${qty}x ',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: CustomerTheme.textPrimary,
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            nama,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: CustomerTheme.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          _formatRupiah(sub),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: CustomerTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                                const SizedBox(height: 16),
                                const Divider(
                                  color: CustomerTheme.border,
                                  thickness: 1.5,
                                ),
                                const SizedBox(height: 12),

                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Subtotal',
                                      style: TextStyle(
                                        color: CustomerTheme.textSecondary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      _formatRupiah(subtotal),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: CustomerTheme.textPrimary,
                                      ),
                                    ),
                                  ],
                                ),
                                if (diskon > 0) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Diskon Voucher',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        '- ${_formatRupiah(diskon)}',
                                        style: const TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'TOTAL AKHIR',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: CustomerTheme.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      _formatRupiah(total),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 24,
                                        color: themeColor,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 24),

                                // WIDGET STATUS PEMBAYARAN DIBAWAH
                                _buildPaymentBadge(
                                  status,
                                  isPiutang,
                                  metodeBayar,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ACTION BUTTONS (STICKY BAWAH)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              decoration: BoxDecoration(
                color: CustomerTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F2557).withOpacity(0.06),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _shareReceipt,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text(
                        'Share Nota ke WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor:
                            themeColor, // Warna tombol ikut dinamis
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: themeColor.withOpacity(0.5),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // LOGIKA BADGE BAWAH AGAR AKURAT
  Widget _buildPaymentBadge(
    String status,
    bool isPiutang,
    dynamic metodeBayar,
  ) {
    if (status == 'dibatalkan') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          'STATUS: DIBATALKAN',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else if (isPiutang) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Text(
          'STATUS: BELUM BAYAR (PIUTANG)',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.red.shade700,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
    } else {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Text(
          'STATUS: LUNAS (${metodeBayar.toString().toUpperCase()})',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      );
    }
  }
}
