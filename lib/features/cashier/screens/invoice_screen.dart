import 'package:flutter/material.dart';

class InvoiceScreen extends StatelessWidget {
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
  });

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB), 
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // ICON SUCCESS
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 56),
                    ),
                    const SizedBox(height: 16),
                    Text(isPiutang ? 'Pesanan Disimpan!' : 'Pembayaran Berhasil!', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF0F2557))),
                    const SizedBox(height: 24),
                    
                    // CARD KERTAS NOTA
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                const Text('NOTA PESANAN', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: 1)),
                                const SizedBox(height: 4),
                                Text(nomorOrder, style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Divider(color: Colors.black12, thickness: 1),
                          const SizedBox(height: 16),

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tanggal Transaksi', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(_formatDateTime(created_at), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Kasir', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(namaKasir, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]),
                          const SizedBox(height: 8),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Pelanggan', style: TextStyle(color: Colors.grey, fontSize: 12)), Text(namaPelanggan, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12))]),
                          
                          const SizedBox(height: 16),
                          const Divider(color: Colors.black12, thickness: 1),
                          const SizedBox(height: 16),

                          const Text('Detail Layanan:', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey, fontSize: 12)),
                          const SizedBox(height: 8),
                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item['qty']}x ', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                                Expanded(child: Text('${item['service']['nama']}', style: const TextStyle(fontSize: 13))), 
                                Text(_formatRupiah(item['subtotal']), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))
                              ]
                            )
                          )),
                          
                          const SizedBox(height: 16),
                          const Divider(color: Colors.black12, thickness: 1),
                          const SizedBox(height: 12),

                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal', style: TextStyle(color: Colors.grey, fontSize: 13)), Text(_formatRupiah(subtotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))]),
                          if (diskon > 0) ...[
                            const SizedBox(height: 8),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Diskon Voucher', style: TextStyle(color: Colors.green, fontSize: 13)), Text('- ${_formatRupiah(diskon)}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600, fontSize: 13))]),
                          ],
                          const SizedBox(height: 12),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Total Akhir', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)), Text(_formatRupiah(total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: Color(0xFF1565C0)))]),
                          
                          const SizedBox(height: 16),
                          if (isPiutang)
                            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade200)), child: Text('STATUS: PIUTANG / BELUM LUNAS', textAlign: TextAlign.center, style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1)))
                          else
                            Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.shade200)), child: Text('STATUS: LUNAS ($metodeBayar)', textAlign: TextAlign.center, style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // ACTION BUTTONS DI BAWAH (STICKY)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, -4))]),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {}, icon: const Icon(Icons.share, size: 18), label: const Text('Share Nota'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {}, icon: const Icon(Icons.print, size: 18), label: const Text('Cetak Struk'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF1565C0), padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity, height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1565C0), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Kembali ke Beranda', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}