import 'package:flutter/material.dart';

class DesignSystem {
  // Colors
  static const navy = Color(0xFF0F2557);
  static const blue = Color(0xFF1565C0);
  static const blueLight = Color(0xFF1976D2);
  static const sky = Color(0xFFE8F0FE);
  static const surface = Colors.white;
  static const ground = Color(0xFFF4F7FB);
  static const border = Color(0xFFE8EDF5);
  static const textPrimary = Color(0xFF0F2557);
  static const textSecondary = Color(0xFF6B7A99);
  static const textHint = Color(0xFFB0BAD1);

  // Status Colors (Disempurnakan kontrasnya)
  static const statusDiterima = Color(0xFF1565C0);
  static const statusDiproses = Color(0xFFE65100);
  static const statusSelesai = Color(0xFF00897B);
  static const statusSiap = Color(0xFF2E7D32);
  static const statusLunas = Color(0xFF757575);
  static const statusPiutang = Color(0xFFC62828);

  // Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.06), blurRadius: 20, offset: const Offset(0, 4)),
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 1)),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(color: const Color(0xFF0F2557).withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> fabShadow = [
    BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: const Color(0xFF1565C0).withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
  ];
}