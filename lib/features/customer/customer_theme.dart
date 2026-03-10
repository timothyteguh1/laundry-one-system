import 'package:flutter/material.dart';

class CustomerTheme {
  static const primary = Color(0xFF00897B); // Hijau Teal
  static const primaryDark = Color(0xFF00695C); 
  static const primaryLight = Color(0xFFE0F2F1); 
  
  static const ground = Color(0xFFEEF2F5); 
  static const surface = Color(0xFFFAFAFA); 
  static const border = Color(0xFFD2DCE8);
  
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textHint = Color(0xFF94A3B8);

  // ==========================================
  // KONSISTENSI SHADOW (DIPERTEGAS AGAR MENGAMBANG)
  // Menggunakan 'primaryDark' agar bayangan lebih dalam
  // ==========================================
  
  static List<BoxShadow> cardShadow = [
    BoxShadow(color: primaryDark.withOpacity(0.12), blurRadius: 20, offset: const Offset(0, 8)),
    BoxShadow(color: primaryDark.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
  ];

  static List<BoxShadow> softShadow = [
    BoxShadow(color: primaryDark.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> headerShadow = [
    BoxShadow(color: primaryDark.withOpacity(0.10), blurRadius: 16, offset: const Offset(0, 6)),
  ];

  static List<BoxShadow> bottomNavShadow = [
    BoxShadow(color: primaryDark.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, -6)),
  ];

  // ==========================================
  // KONSISTENSI BENTUK KOTAK (BOX DECORATION)
  // ==========================================
  static BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    // Border ditipiskan dari 1.5 ke 1.0 agar shadow-nya yang mengambil alih dimensi
    border: Border.all(color: border, width: 1.0),
    boxShadow: cardShadow,
  );

  static BoxDecoration menuDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: border, width: 1.0),
    boxShadow: softShadow,
  );
}