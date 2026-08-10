import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/customer/screens/home_customer_screen.dart';

// ============================================================
// IMPORT WAJIB UNTUK JURUS NINJA NOTIFIKASI FCM
// ============================================================
import 'package:laundry_one/features/auth/services/notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ============================================================
// REGISTER CUSTOMER SCREEN
// Pelanggan daftar sendiri dari aplikasi HP
//
// Field:
// - Nama Lengkap (wajib)
// - Nomor HP (wajib) → identifier untuk login
// - Password (wajib, min 6 karakter)
// - Konfirmasi Password (wajib)
// - Tanggal Lahir (opsional) → untuk notifikasi ulang tahun
//
// Setelah daftar → langsung masuk HomeCustomerScreen
// ============================================================

class RegisterCustomerScreen extends StatefulWidget {
  const RegisterCustomerScreen({super.key});

  @override
  State<RegisterCustomerScreen> createState() =>
      _RegisterCustomerScreenState();
}

class _RegisterCustomerScreenState extends State<RegisterCustomerScreen>
    with SingleTickerProviderStateMixin {
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _konfirmasiController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureKonfirmasi = true;
  bool _isLoading = false;
  DateTime? _tanggalLahir;

  final _formKey = GlobalKey<FormState>();
  final AuthService _authService = AuthService();

  // Animasi masuk
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim =
        CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _namaController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _konfirmasiController.dispose();
    super.dispose();
  }

  // ============================================================
  // PILIH TANGGAL LAHIR
  // ============================================================
  Future<void> _pilihTanggalLahir() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Pilih Tanggal Lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1976D2),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _tanggalLahir = picked);
    }
  }

  // ============================================================
  // [UPDATE UX] Dialog Custom pengganti SnackBar Merah
  // ============================================================
  void _showCustomDialog({
    required String title,
    required String message,
    required bool isSuccess,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1976D2).withOpacity(0.15),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: isSuccess ? Colors.green : Colors.red,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: Color(0xFF0F2557),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(
                  color: Color(0xFF6B7A99),
                  fontSize: 13,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess
                        ? const Color(0xFF1976D2)
                        : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTanggal(DateTime date) {
    final bulan = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${bulan[date.month]} ${date.year}';
  }

  // ============================================================
  // PROSES REGISTER
  // ============================================================
  Future<void> _prosesRegister() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      String? tanggalLahirStr;
      if (_tanggalLahir != null) {
        tanggalLahirStr =
            '${_tanggalLahir!.year}-${_tanggalLahir!.month.toString().padLeft(2, '0')}-${_tanggalLahir!.day.toString().padLeft(2, '0')}';
      }

      // 1. Daftar Akun
      await _authService.registerPelanggan(
        phone: _phoneController.text.trim(),
        fullName: _namaController.text.trim(),
        email: _emailController.text.trim(), 
        tanggalLahir: tanggalLahirStr,
        password: _passwordController.text.trim(),
      );

      // 2. Login Otomatis
      await _authService.loginWithRole(
        identifier: _phoneController.text.trim(),
        password: _passwordController.text.trim(),
        expectedRole: 'customer',
      );

      // 3. Pastikan email benar-benar tersimpan di tabel profiles
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        await Supabase.instance.client.from('profiles').update({
          'email': _emailController.text.trim()
        }).eq('id', userId);
      }

      // 4. Update FCM Token
      try {
        await NotificationService.saveTokenToSupabase();
      } catch (e) {
        debugPrint('Ninja Token Gagal: $e'); 
      }

      if (mounted) {
        HapticFeedback.mediumImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat datang, ${_namaController.text.trim().split(' ').first}! 👋'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );

        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const HomeCustomerScreen(),
            transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 400),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        
        final errorMsg = e.toString();
        String title = 'Pendaftaran Gagal';
        String message = errorMsg.replaceAll('Exception: ', '');

        if (errorMsg.contains('sudah terdaftar') || errorMsg.contains('already registered')) {
          title = 'Nomor Sudah Terdaftar';
          message = 'Nomor WhatsApp ini sudah pernah didaftarkan. Silakan langsung masuk (login) menggunakan nomor tersebut.';
        } else if (errorMsg.contains('SocketException') ||
            errorMsg.contains('Failed host lookup') ||
            errorMsg.contains('Network is unreachable') ||
            errorMsg.contains('Connection failed') ||
            errorMsg.contains('ClientException')) {
          title = 'Tidak Ada Koneksi';
          message = 'Periksa koneksi internet atau WiFi kamu, lalu coba lagi.';
        }

        _showCustomDialog(title: title, message: message, isSuccess: false);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F7FF),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),

                      // === TOMBOL KEMBALI ===
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: Color(0xFF1976D2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // === JUDUL ===
                      const Text(
                        'Daftar Akun',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Buat akun untuk mulai gunakan layanan kami.',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 28),

                      // === NAMA LENGKAP ===
                      _buildField(
                        controller: _namaController,
                        label: 'Nama Lengkap',
                        icon: Icons.person_outline_rounded,
                        keyboardType: TextInputType.name,
                        hint: 'Cth: Budi Santoso',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nama wajib diisi';
                          }
                          if (val.trim().length < 3) {
                            return 'Nama minimal 3 huruf';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // === EMAIL ===
                      _buildField(
                        controller: _emailController,
                        label: 'Alamat Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        hint: 'contoh@email.com',
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Email wajib diisi';
                          }
                          if (!val.contains('@') || !val.contains('.')) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // === NOMOR HP ===
                      _buildField(
                        controller: _phoneController,
                        label: 'Nomor WhatsApp',
                        icon: Icons.phone_android_outlined,
                        keyboardType: TextInputType.phone,
                        hint: 'Contoh: 081234567890',
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Nomor HP wajib diisi';
                          }
                          if (val.trim().length < 10) {
                            return 'Nomor HP minimal 10 digit';
                          }
                          if (val.trim().length > 15) {
                            return 'Nomor HP terlalu panjang';
                          }
                          return null;
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          '* Nomor ini digunakan untuk login',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue.shade400),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // === PASSWORD ===
                      _buildPasswordField(
                        controller: _passwordController,
                        label: 'Password',
                        obscure: _obscurePassword,
                        onToggle: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Password wajib diisi';
                          }
                          if (val.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // === KONFIRMASI PASSWORD ===
                      _buildPasswordField(
                        controller: _konfirmasiController,
                        label: 'Konfirmasi Password',
                        obscure: _obscureKonfirmasi,
                        inputAction: TextInputAction.done,
                        onToggle: () => setState(
                            () => _obscureKonfirmasi = !_obscureKonfirmasi),
                        onSubmitted: (_) => _prosesRegister(),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Konfirmasi password wajib diisi';
                          }
                          if (val != _passwordController.text) {
                            return 'Password tidak cocok';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // === TANGGAL LAHIR (OPSIONAL) ===
                      InkWell(
                        onTap: _pilihTanggalLahir,
                        borderRadius: BorderRadius.circular(15),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                                color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.cake_outlined,
                                  color: Colors.grey.shade500),
                              const SizedBox(width: 12),
                              Text(
                                _tanggalLahir != null
                                    ? _formatTanggal(_tanggalLahir!)
                                    : 'Tanggal Lahir (Opsional)',
                                style: TextStyle(
                                  color: _tanggalLahir != null
                                      ? Colors.black87
                                      : Colors.grey.shade500,
                                  fontSize: 16,
                                ),
                              ),
                              const Spacer(),
                              if (_tanggalLahir != null)
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _tanggalLahir = null),
                                  child: Icon(Icons.close,
                                      size: 18,
                                      color: Colors.grey.shade400),
                                )
                              else
                                Icon(Icons.chevron_right,
                                    color: Colors.grey.shade400),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 4),
                        child: Text(
                          '* Untuk notifikasi selamat ulang tahun 🎂',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // === TOMBOL DAFTAR ===
                      SizedBox(
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            disabledBackgroundColor:
                                const Color(0xFF1976D2).withOpacity(0.6),
                            elevation: _isLoading ? 0 : 2,
                            shadowColor:
                                const Color(0xFF1976D2).withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: _isLoading ? null : _prosesRegister,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isLoading
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    height: 22,
                                    width: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : const Text(
                                    key: ValueKey('text'),
                                    'DAFTAR & MASUK',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 1,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // === LINK KEMBALI KE LOGIN ===
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sudah punya akun? ',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2),
                              child: Text(
                                'Masuk di sini',
                                style: TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction inputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: inputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDeco(label: label, icon: icon, hint: hint),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    TextInputAction inputAction = TextInputAction.next,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: inputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      decoration: _inputDeco(label: label, icon: Icons.lock_outline).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: Colors.grey,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
      prefixIcon: Icon(icon, color: Colors.grey),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF1976D2), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}