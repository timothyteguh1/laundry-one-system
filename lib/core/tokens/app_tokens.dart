import 'package:flutter/material.dart';

class AppTokens {
  // 1. Brand Colors
  static const Color primarySeed = Color(0xFF1565C0);
  static const Color navy = Color(0xFF0F2557);
  static const Color blue = Color(0xFF1565C0);
  static const Color blueLight = Color(0xFF1976D2);
  static const Color sky = Color(0xFFE8F0FE);
  
  // 2. Background & Surface Colors
  static const Color ground = Color(0xFFEAF0F6);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFD2DCE8);
  
  // 3. Text Colors
  static const Color textPrimary = Color(0xFF0F2557);
  static const Color textSecondary = Color(0xFF6B7A99);
  static const Color textHint = Color(0xFFB0BAD1);

  // 4. Status Colors (Wajib ada untuk label order)
  static const Color statusDiterima = Color(0xFF1565C0);
  static const Color statusDiproses = Color(0xFFE65100);
  static const Color statusSelesai = Color(0xFF00897B);
  static const Color statusSiap = Color(0xFF2E7D32);
  static const Color statusLunas = Color(0xFF757575);
  static const Color statusPiutang = Color(0xFFC62828);

  // 5. 4pt Grid Spacing System
  static const double space4 = 4.0;
  static const double space8 = 8.0;
  static const double space12 = 12.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space32 = 32.0;
  static const double space48 = 48.0;

  // 6. Border Radii
  static const double radius8 = 8.0;
  static const double radius12 = 12.0;
  static const double radius16 = 16.0;
  static const double radius20 = 20.0;
  static const double radius24 = 24.0;
  static const double radius28 = 28.0; // Dipakai khusus untuk BottomSheet

  // 7. Global Shadows
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: navy.withOpacity(0.09), blurRadius: 16, offset: const Offset(0, 4)),
    BoxShadow(color: navy.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(color: navy.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> fabShadow = [
    BoxShadow(color: blue.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: blue.withOpacity(0.2), blurRadius: 6, offset: const Offset(0, 2)),
  ];

  // 8. Helper Methods
  static String formatRupiah(double amount) {
    final str = amount.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write('.');
      buffer.write(str[i]);
    }
    return str == '0' ? '0' : buffer.toString();
  }
}