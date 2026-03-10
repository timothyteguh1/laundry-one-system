import 'package:flutter/material.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';

// ============================================================
// WIDGET KETIKA DATA KOSONG (EMPTY STATE)
// ============================================================
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? sub;

  const EmptyState({super.key, required this.icon, required this.message, this.sub});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20), 
            decoration: const BoxDecoration(color: CustomerTheme.primaryLight, shape: BoxShape.circle), 
            child: Icon(icon, size: 36, color: CustomerTheme.primary)
          ),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: CustomerTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
          if (sub != null) ...[
            const SizedBox(height: 4), 
            Text(sub!, style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center)
          ]
        ]
      )
    );
  }
}

// ============================================================
// WIDGET KARTU PESANAN MEWAH (VERSI CUSTOMER - HIJAU)
// ============================================================
class PremiumOrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final bool isCustomerView;

  const PremiumOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    this.isCustomerView = true,
  });

  @override
  Widget build(BuildContext context) {
    final status = order['status'] ?? 'diproses';
    final cfg = _cfg(status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, 
          borderRadius: BorderRadius.circular(16), 
          border: Border.all(color: CustomerTheme.border, width: 1.5), 
          boxShadow: CustomerTheme.cardShadow
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, decoration: BoxDecoration(color: cfg['color'], borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)))),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38, height: 38, 
                            decoration: BoxDecoration(color: (cfg['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), 
                            child: Center(child: Icon(Icons.local_laundry_service_rounded, color: cfg['color'], size: 20))
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, 
                              children: [
                                Text(order['nomor_order'] ?? '-', style: const TextStyle(color: CustomerTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)), 
                                const SizedBox(height: 2), 
                                Text(_formatDate(order['created_at']), style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500))
                              ]
                            )
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                            decoration: BoxDecoration(color: (cfg['color'] as Color).withOpacity(0.1), borderRadius: BorderRadius.circular(8)), 
                            child: Text(cfg['label'], style: TextStyle(color: cfg['color'], fontSize: 11, fontWeight: FontWeight.w800))
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(_fmt((order['total_harga'] ?? 0).toDouble()), style: const TextStyle(color: CustomerTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5)),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, color: CustomerTheme.textHint),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pengaturan Warna Label Status
  Map<String, dynamic> _cfg(String s) {
    if (s == 'diproses') return {'label': 'Diproses', 'color': Colors.orange};
    if (s == 'selesai' || s == 'dibayar_lunas') return {'label': 'Selesai', 'color': CustomerTheme.primary};
    return {'label': s.toUpperCase(), 'color': Colors.grey};
  }
  
  String _fmt(double a) { final str = a.toStringAsFixed(0); final b = StringBuffer(); for (int i = 0; i < str.length; i++) { if (i > 0 && (str.length - i) % 3 == 0) b.write('.'); b.write(str[i]); } return 'Rp ${b.toString()}'; }
  
  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month}/${d.year}';
    } catch (e) { return '-'; }
  }
}