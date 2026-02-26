import 'package:flutter/material.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';

// ============================================================
// HOME ADMIN SCREEN — Dashboard Super Admin (Flutter Web)
// Ini placeholder dulu, akan dilengkapi di fase berikutnya
//
// Yang akan ada di sini nanti:
// - Ringkasan omset hari ini / minggu ini / bulan ini
// - Grafik transaksi
// - Daftar piutang aktif
// - Manajemen layanan & reward
// - Audit log poin
// - Manajemen akun kasir
// ============================================================

class HomeAdminScreen extends StatelessWidget {
  const HomeAdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Dashboard Super Admin',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Keluar',
            onPressed: () async {
              await AuthService().logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/',
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.admin_panel_settings_outlined,
                size: 80,
                color: Color(0xFF0D47A1),
              ),
              SizedBox(height: 20),
              Text(
                'Dashboard Admin',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Laporan, manajemen layanan, reward,\ndan audit log poin akan tampil di sini.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}