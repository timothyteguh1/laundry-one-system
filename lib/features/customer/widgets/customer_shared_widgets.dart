import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';

// ============================================================
// [NEW UX] MODERN SPINNER (Gaya 21st Century)
// ============================================================
class ModernSpinner extends StatelessWidget {
  final Color color;
  final double size;
  const ModernSpinner({super.key, this.color = CustomerTheme.primary, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size, height: size,
      child: CircularProgressIndicator(
        strokeWidth: 4,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        backgroundColor: color.withOpacity(0.15),
        strokeCap: StrokeCap.round, // Ujung bulat memberikan kesan modern
      ),
    );
  }
}

// ============================================================
// [NEW UX] GLASSMORPHISM OVERLAY (Anti Double-Tap & Elegan)
// ============================================================
class GlassmorphismOverlay extends StatelessWidget {
  final String message;
  const GlassmorphismOverlay({super.key, this.message = 'Memproses...'});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          color: Colors.white.withOpacity(0.3),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: CustomerTheme.primary.withOpacity(0.15), blurRadius: 30, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ModernSpinner(size: 44),
                  const SizedBox(height: 20),
                  Text(message, style: const TextStyle(fontWeight: FontWeight.w800, color: CustomerTheme.textPrimary, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// [NEW UX] FADE-IN & SLIDE ANIMATION (Untuk Transisi Halus)
// ============================================================
class FadeInAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  const FadeInAnimation({super.key, required this.child, this.delay = 0});

  @override
  State<FadeInAnimation> createState() => _FadeInAnimationState();
}

class _FadeInAnimationState extends State<FadeInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _opacity = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _slide = Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

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
// WIDGET KARTU PESANAN MEWAH (DENGAN EFEK MEMBAL / BOUNCE)
// ============================================================
class PremiumOrderCard extends StatefulWidget {
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
  State<PremiumOrderCard> createState() => _PremiumOrderCardState();
}

class _PremiumOrderCardState extends State<PremiumOrderCard> with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.order['status'] ?? 'diproses';
    final cfg = _cfg(status);

    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.forward(),
      onTapUp: (_) {
        _scaleCtrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _scaleCtrl.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
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
                                  Text(widget.order['nomor_order'] ?? '-', style: const TextStyle(color: CustomerTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 14)), 
                                  const SizedBox(height: 2), 
                                  Text(_formatDate(widget.order['created_at']), style: const TextStyle(color: CustomerTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.w500))
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
                            Text(_fmt((widget.order['total_harga'] ?? 0).toDouble()), style: const TextStyle(color: CustomerTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.5)),
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
      ),
    );
  }

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