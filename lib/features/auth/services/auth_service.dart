import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // ATURAN LOGIN PER ROLE:
  //
  // Kasir      → login pakai NOMOR HP
  // Pelanggan  → login pakai NOMOR HP
  // Super Admin → login pakai EMAIL
  //
  // Di balik layar, nomor HP diubah jadi format email palsu:
  // 081234567890 → 081234567890@laundry.local
  // ============================================================
  String _hpKeEmail(String phone) {
    final clean = phone
        .trim()
        .replaceAll(' ', '')
        .replaceAll('+62', '0')
        .replaceAll('+', '');
    return '$clean@laundry.local';
  }

  // ============================================================
  // LOGIN — verifikasi role sesuai aplikasi yang dibuka
  // ============================================================
  Future<Map<String, dynamic>> loginWithRole({
    required String identifier,
    required String password,
    required String expectedRole,
  }) async {
    try {
      String authEmail;

      if (expectedRole == 'super_admin') {
        if (!identifier.contains('@')) {
          throw Exception('Super Admin login menggunakan email, bukan nomor HP.');
        }
        authEmail = identifier.trim();
      } else {
        if (identifier.contains('@')) {
          throw Exception('Login menggunakan Nomor HP, bukan email.');
        }
        authEmail = _hpKeEmail(identifier);
      }

      final res = await _supabase.auth.signInWithPassword(
        email: authEmail,
        password: password,
      );

      if (res.user == null) throw Exception('Login gagal, coba lagi.');

      final profile = await _supabase
          .from('profiles')
          .select('role, nama_lengkap, nomor_hp, is_active')
          .eq('id', res.user!.id)
          .single();

      if (profile['is_active'] == false) {
        await _supabase.auth.signOut();
        throw Exception('Akun Anda dinonaktifkan. Hubungi admin.');
      }

      if (profile['role'] != expectedRole) {
        await _supabase.auth.signOut();
        throw Exception('Akses ditolak. Gunakan aplikasi yang sesuai.');
      }

      return profile;
    } on AuthException catch (e) {
      throw Exception(_translateError(e.message));
    } catch (e) {
      rethrow;
    }
  }

  // ============================================================
  // REGISTER KASIR
  // Auth email = nomor HP dalam format @laundry.local
  // ============================================================
  Future<void> registerKasir({
    required String phone,
    required String password,
    required String fullName,
    String? email,
  }) async {
    try {
      final authEmail = _hpKeEmail(phone);

      await _supabase.auth.signUp(
        email: authEmail,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': 'cashier',
          if (email != null && email.isNotEmpty) 'email_asli': email,
        },
      );
    } on AuthException catch (e) {
      throw Exception(_translateError(e.message));
    }
  }

  // ============================================================
  // REGISTER PELANGGAN
  //
  // Bisa dipanggil dari 2 tempat:
  // 1. Aplikasi KASIR — kasir daftarkan pelanggan baru dari POS
  //    → password default = nomor HP (pelanggan bisa ganti nanti)
  // 2. Aplikasi PELANGGAN — pelanggan daftar sendiri dari HP
  //    → password diisi sendiri oleh pelanggan
  //
  // Parameter password bersifat opsional:
  // - Kalau diisi → pakai password itu
  // - Kalau tidak diisi → pakai nomor HP sebagai password default
  // ============================================================
  Future<void> registerPelanggan({
    required String phone,
    required String fullName,
    String? password,       // opsional, default = nomor HP
    String? tanggalLahir,   // opsional, untuk notif ulang tahun
  }) async {
    try {
      final authEmail = _hpKeEmail(phone);
      // Kalau password tidak dikirim (kasir daftarkan), pakai nomor HP
      final authPassword = (password != null && password.isNotEmpty)
          ? password
          : phone.trim();

      await _supabase.auth.signUp(
        email: authEmail,
        password: authPassword,
        data: {
          'full_name': fullName,
          'phone': phone,
          'role': 'customer',
          if (tanggalLahir != null) 'tanggal_lahir': tanggalLahir,
        },
      );
    } on AuthException catch (e) {
      throw Exception(_translateError(e.message));
    }
  }

  // ============================================================
  // GET ROLE
  // ============================================================
  Future<String?> getMyRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();
      return profile['role'] as String?;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // GET PROFIL LENGKAP
  // ============================================================
  Future<Map<String, dynamic>?> getMyProfile() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;
      return await _supabase
          .from('profiles')
          .select('*')
          .eq('id', user.id)
          .single();
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // CEK SESSION
  // ============================================================
  bool isLoggedIn() => _supabase.auth.currentUser != null;

  // ============================================================
  // LOGOUT
  // ============================================================
  Future<void> logout() async => await _supabase.auth.signOut();

  // ============================================================
  // TRANSLATE ERROR
  // ============================================================
  String _translateError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'Nomor HP atau password salah.';
    }
    if (message.contains('User already registered')) {
      return 'Nomor HP ini sudah terdaftar.';
    }
    if (message.contains('Password should be at least')) {
      return 'Password minimal 6 karakter.';
    }
    if (message.contains('Database error')) {
      return 'Nomor HP ini sudah terdaftar.';
    }
    if (message.contains('Email rate limit')) {
      return 'Terlalu banyak percobaan. Tunggu beberapa menit.';
    }
    if (message.contains('Unable to validate email')) {
      return 'Format tidak valid.';
    }
    return message;
  }
}