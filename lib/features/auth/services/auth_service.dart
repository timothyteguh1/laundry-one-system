import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/core/services/app_state.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // ATURAN LOGIN PER ROLE:
  // Semua role (Super Admin, Kasir, Pelanggan) login pakai NOMOR HP
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
      // Sekarang semuanya menggunakan nomor HP
      String authEmail = _hpKeEmail(identifier);

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

      if (profile['role'] == 'customer') {
        final custData = await _supabase
            .from('customers')
            .select('branch_id')
            .eq('profile_id', res.user!.id)
            .limit(1) // <--- [SOLUSI]: Paksa ambil 1 saja agar tidak crash
            .maybeSingle();

        final branchId = custData != null && custData['branch_id'] != null
            ? custData['branch_id'] as String
            : null;

        await AppState.saveBranch(branchId: branchId);
        await AppState.saveRole('customer');
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
  // REGISTER PELANGGAN (VIA EDGE FUNCTION ANTI-LOGOUT)
  // ============================================================
  Future<void> registerPelanggan({
    required String phone,
    required String fullName,
    String? email,          // <--- [TAMBAHAN BARU]
    String? password,       
    String? tanggalLahir,   
    String? branchId,       
  }) async {
    try {
      final authEmail = _hpKeEmail(phone);
      final authPassword = (password != null && password.isNotEmpty)
          ? password
          : phone.trim();

      final currentRole = await AppState.getRole();
      String? branchIdToSend = branchId;
      if (branchIdToSend == null && currentRole != null) {
        branchIdToSend = await AppState.getBranchId();
      }

      final response = await _supabase.functions.invoke(
        'register-customer',
        body: {
          'email': authEmail,
          'email_asli': email, // <--- [TAMBAHAN BARU] Kirim ke fungsi server
          'password': authPassword,
          'full_name': fullName,
          'phone': phone,
          'tanggal_lahir': tanggalLahir,
          'branch_id': branchIdToSend,
        },
      );

      if (response.status != 200) {
         final errorMsg = response.data['error'] ?? 'Gagal mendaftarkan pelanggan';
         throw Exception(_translateError(errorMsg.toString()));
      }

    } on FunctionException catch (e) {
      // [UPDATE UI]: Ekstrak pesan error asli dari Edge Function
      String cleanError = 'Gagal mendaftar. Silakan coba lagi.';
      if (e.details != null && e.details is Map && e.details['error'] != null) {
        cleanError = e.details['error'].toString();
      }
      throw Exception(cleanError);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
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
  // [UPDATE] LOGIN UNIVERSAL UNTUK APP KASIR (ADMIN & KASIR)
  // ============================================================
  Future<Map<String, dynamic>> loginUniversal({
    required String identifier,
    required String password,
  }) async {
    try {
      // Karena Admin dan Kasir sekarang pakai Nomor HP, kita konversi
      final authEmail = _hpKeEmail(identifier); 
      
      final res = await _supabase.auth.signInWithPassword(
        email: authEmail,
        password: password,
      );

      if (res.user == null) throw Exception('Login gagal, coba lagi.');

      // Cek Role di database
      final profile = await _supabase
          .from('profiles')
          .select('role, nama_lengkap, nomor_hp, is_active')
          .eq('id', res.user!.id)
          .single();

      if (profile['is_active'] == false) {
        await _supabase.auth.signOut();
        throw Exception('Akun Anda dinonaktifkan. Hubungi admin.');
      }

      final role = profile['role'];
       
      // Izinkan masuk JIKA dia cashier ATAU super_admin
      if (role != 'cashier' && role != 'super_admin') {
        await _supabase.auth.signOut();
        throw Exception('Akses ditolak. Aplikasi ini hanya untuk Pegawai.');
      }

      // [MULTI-BRANCH]: Ambil branch_id dari tabel kasir untuk role cashier
      // Super Admin tetap fleksibel (branch_id = null, bisa ganti cabang nanti)
      if (role == 'cashier') {
        final kasirData = await _supabase
            .from('kasir')
            .select('branch_id')
            .eq('profile_id', res.user!.id)
            .maybeSingle();

        final branchId = kasirData != null && kasirData['branch_id'] != null
            ? kasirData['branch_id'] as String
            : null;

        await AppState.saveBranch(branchId: branchId);
      } else {
        await AppState.saveBranch(branchId: null);
      }

      await AppState.saveRole(role);
      return profile;
    } on AuthException catch (e) {
      throw Exception(_translateError(e.message));
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    try {
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
  // LOGOUT DENGAN PEMBERSIH JEJAK FCM
  // ============================================================
  Future<void> logout() async {
    final userId = _supabase.auth.currentUser?.id;

    if (userId != null) {
      try {
        // Hapus token FCM agar notifikasi orang lain tidak masuk ke HP ini
        await _supabase.from('profiles').update({'fcm_token': null}).eq('id', userId);
      } catch (_) {
        // Abaikan jika gagal (misal koneksi terputus), prioritas utama adalah logout
      }
    }
    
    // Baru kemudian hancurkan sesi login
    await _supabase.auth.signOut();
    await AppState.clearAll();
  }
  // // ============================================================
  // // LUPA SANDI VIA OTP (Memanggil Edge Function otp-self-reset)
  // // ============================================================
  // Future<void> resetPasswordViaOtp({
  //   required String phone,
  //   required String newPassword,
  // }) async {
  //   try {
  //     final response = await _supabase.functions.invoke(
  //       'otp-self-reset',
  //       body: {
  //         'phone': phone,
  //         'new_password': newPassword,
  //       },
  //     );

  //     if (response.status != 200) {
  //       final errorMsg = response.data['error'] ?? 'Gagal mereset sandi.';
  //       throw Exception(_translateError(errorMsg.toString()));
  //     }
  //   } on FunctionException catch (e) {
  //     throw Exception('Server Error: ${e.toString()}');
  //   } catch (e) {
  //     throw Exception(e.toString().replaceAll('Exception: ', ''));
  //   }
  // }

  // ============================================================
  // LUPA SANDI (TAHAP 1): MINTA OTP KE EMAIL
  // ============================================================
  Future<void> sendOtpLupaSandi({
    required String phone,
    required String email,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'send-otp',
        body: {
          'nomor_hp': phone,
          'email': email,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? 'Gagal mengirim OTP.';
        throw Exception(_translateError(errorMsg.toString()));
      }
    } on FunctionException catch (e) {
      // [UPDATE UI]: Kita ekstrak dan rapikan pesan aslinya agar cantik!
      String cleanError = 'Gagal memproses data.';
      if (e.details != null && e.details is Map && e.details['error'] != null) {
        cleanError = e.details['error'].toString();
      }
      throw Exception(cleanError);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ============================================================
  // LUPA SANDI (TAHAP 2): VERIFIKASI OTP & RESET SANDI
  // ============================================================
  Future<void> verifyOtpDanResetSandi({
    required String phone,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'verify-otp',
        body: {
          'nomor_hp': phone,
          'otp_input': otp,
          'new_password': newPassword,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data['error'] ?? 'Gagal verifikasi OTP.';
        throw Exception(_translateError(errorMsg.toString()));
      }
    } on FunctionException catch (e) {
      // [UPDATE UI]: Kita ekstrak dan rapikan pesan aslinya agar cantik!
      String cleanError = 'Gagal memproses data.';
      if (e.details != null && e.details is Map && e.details['error'] != null) {
        cleanError = e.details['error'].toString();
      }
      throw Exception(cleanError);
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  // ============================================================
  // VERIFIKASI OTP VOUCHER KHUSUS KASIR (BYPASS EDGE FUNCTION)
  // ============================================================
  Future<void> verifyVoucherOtpOnly({
    required String phone,
    required String otp,
  }) async {
    try {
      // Langsung ngebut baca dari database lokal Supabase
      final data = await _supabase
          .from('otp_verifications')
          .select('*')
          .eq('nomor_hp', phone)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) throw Exception('Kode OTP tidak ditemukan.');

      // Cek kedaluwarsa
      final expiresAt = DateTime.parse(data['expires_at']).toUtc();
      if (DateTime.now().toUtc().isAfter(expiresAt)) {
        throw Exception('Kode OTP sudah kedaluwarsa.');
      }

      // Cek kecocokan
      if (data['kode'] != otp) {
        throw Exception('Kode OTP salah!');
      }

      // Sukses? Langsung hapus OTP agar tidak bisa dipakai 2x
      await _supabase.from('otp_verifications').delete().eq('id', data['id']);
      
    } catch (e) {
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

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