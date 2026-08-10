import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart'; // Import config

class ForgotPasswordScreen extends StatefulWidget {
  final LoginConfig config;

  const ForgotPasswordScreen({super.key, required this.config});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final AuthService _authService = AuthService();
  
  // State control
  int _currentStep = 1; // 1 = Input HP & Email, 2 = Input OTP & Sandi Baru
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Form 1 Controllers (Minta OTP)
  final _formKey1 = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Form 2 Controllers (Verifikasi OTP)
  final _formKey2 = GlobalKey<FormState>();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // [UPDATE UX] Dialog Custom (Sama dengan LoginScreen)
  // ============================================================
  void _showCustomDialog({
    required String title,
    required String message,
    required bool isSuccess,
    VoidCallback? onSuccessOk,
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
                color: widget.config.primaryColor.withOpacity(0.15),
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
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F2557)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF6B7A99), fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSuccess ? widget.config.primaryColor : Colors.red.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    if (isSuccess && onSuccessOk != null) onSuccessOk();
                  },
                  child: const Text('Mengerti', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // TAHAP 1: MINTA OTP
  // ============================================================
  Future<void> _requestOTP() async {
    FocusScope.of(context).unfocus();
    if (!_formKey1.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.sendOtpLupaSandi(
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim(),
      );
      
      setState(() => _currentStep = 2);
      HapticFeedback.mediumImpact();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kode OTP berhasil dikirim ke email Anda.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      HapticFeedback.vibrate();
      _showCustomDialog(
        title: 'Gagal Kirim OTP',
        message: e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ============================================================
  // TAHAP 2: VERIFIKASI & RESET
  // ============================================================
  Future<void> _verifyAndReset() async {
    FocusScope.of(context).unfocus();
    if (!_formKey2.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await _authService.verifyOtpDanResetSandi(
        phone: _phoneController.text.trim(),
        otp: _otpController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );
      
      HapticFeedback.mediumImpact();
      _showCustomDialog(
        title: 'Sandi Berhasil Direset!',
        message: 'Kata sandi Anda berhasil diperbarui. Silakan login kembali menggunakan kata sandi yang baru.',
        isSuccess: true,
        onSuccessOk: () {
          Navigator.pop(context); // Kembali ke halaman login
        },
      );
    } catch (e) {
      HapticFeedback.vibrate();
      _showCustomDialog(
        title: 'Verifikasi Gagal',
        message: e.toString().replaceAll('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.config.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: widget.config.primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _currentStep == 1 ? _buildStep1Form() : _buildStep2Form(),
                ),
              ),

              // Loading Overlay
              // Loading Overlay (UI Diperbaiki)
              if (_isLoading)
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                    child: Container(
                      color: widget.config.primaryColor.withOpacity(0.15),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: widget.config.primaryColor.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36, height: 36,
                                child: CircularProgressIndicator(color: widget.config.primaryColor, strokeWidth: 3),
                              ),
                              const SizedBox(height: 16),
                              const Text('Memproses...', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F2557), fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UI: FORM 1 (Minta OTP)
  // ============================================================
  Widget _buildStep1Form() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: widget.config.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.lock_reset_rounded, size: 48, color: widget.config.primaryColor),
          ),
          const SizedBox(height: 24),
          Text('Lupa Kata Sandi?', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: widget.config.primaryColor)),
          const SizedBox(height: 12),
          Text(
            'Masukkan nomor HP dan Email yang terdaftar. Kami akan mengirimkan 6-digit kode OTP ke email Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          _buildInput(
            controller: _phoneController,
            label: 'Nomor WhatsApp',
            hint: 'Contoh: 081234567890',
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (val) => val == null || val.length < 10 ? 'Nomor HP minimal 10 digit' : null,
          ),
          const SizedBox(height: 16),
          
          _buildInput(
            controller: _emailController,
            label: 'Alamat Email',
            hint: 'email.anda@gmail.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (val) => val == null || !val.contains('@') ? 'Format email tidak valid' : null,
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _requestOTP,
              child: const Text('Kirim Kode OTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // UI: FORM 2 (Verifikasi & Sandi Baru)
  // ============================================================
  Widget _buildStep2Form() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.mark_email_read_rounded, size: 48, color: Colors.green),
          ),
          const SizedBox(height: 24),
          Text('Masukkan Kode OTP', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: widget.config.primaryColor)),
          const SizedBox(height: 12),
          Text(
            'Kode 6 digit telah dikirim ke:\n${_emailController.text}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 32),

          _buildInput(
            controller: _otpController,
            label: 'Kode OTP 6-Digit',
            hint: '123456',
            icon: Icons.password_rounded,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            validator: (val) => val == null || val.length != 6 ? 'Kode OTP harus 6 digit' : null,
          ),
          const SizedBox(height: 16),
          
          _buildInput(
            controller: _newPasswordController,
            label: 'Kata Sandi Baru',
            hint: 'Minimal 6 karakter',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (val) => val == null || val.length < 6 ? 'Minimal 6 karakter' : null,
          ),
          const SizedBox(height: 32),

          SizedBox(
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.config.primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _verifyAndReset,
              child: const Text('Simpan Sandi Baru', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => setState(() => _currentStep = 1),
            child: Text('Kembali / Ganti Email', style: TextStyle(color: Colors.grey.shade600)),
          )
        ],
      ),
    );
  }

  // Komponen Input (Copy persis dari LoginScreen)
  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(icon, color: widget.config.primaryColor.withOpacity(0.6), size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: widget.config.primaryColor, width: 1.8)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade300)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.red.shade400, width: 1.8)),
      ),
    );
  }
}