import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/screens/register_screen.dart'; // [TAMBAHAN] Import ini agar tombol daftar jalan

// ============================================================
// LOGIN SCREEN — Industry-standard design
// ============================================================

class LoginConfig {
  final String roleName;
  final String roleDatabase;
  final String labelIdentifier;
  final String? hint;
  final TextInputType keyboardType;
  final Color primaryColor;
  final Color? secondaryColor; 
  final Color backgroundColor;
  final IconData icon;
  final String? tagline;        
  final Widget homeScreen;
  final bool showRegister;
  final Widget? registerScreen;

  const LoginConfig({
    required this.roleName,
    required this.roleDatabase,
    required this.labelIdentifier,
    this.hint,
    this.keyboardType = TextInputType.phone, // Default ganti ke phone
    required this.primaryColor,
    this.secondaryColor,         
    required this.backgroundColor,
    required this.icon,
    this.tagline,                
    required this.homeScreen,
    required this.showRegister,
    this.registerScreen,
  });
}

class LoginScreen extends StatefulWidget {
  final LoginConfig config;
  const LoginScreen({super.key, required this.config});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading = false;

  late AnimationController _entranceController;
  late AnimationController _shakeController;
  late Animation<double> _headerAnim;
  late Animation<Offset> _formSlideAnim;
  late Animation<double> _formFadeAnim;
  late Animation<double> _shakeAnim;

  final AuthService _authService = AuthService();

  Color get _secondaryColor =>
      widget.config.secondaryColor ??
      Color.lerp(widget.config.primaryColor, Colors.black, 0.25)!;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _headerAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _formSlideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
    ));
    _formFadeAnim = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _shakeController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _prosesLogin() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _shakeController.forward(from: 0);
      return;
    }

    HapticFeedback.lightImpact();
    setState(() => _isLoading = true);

    try {
      // [UPDATE] Gunakan loginUniversal agar Admin/Kasir bisa pakai nomor HP
      await _authService.loginUniversal(
        identifier: _identifierController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (mounted) {
        HapticFeedback.mediumImpact();
        Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => widget.config.homeScreen,
            transitionsBuilder: (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.vibrate();
        _shakeController.forward(from: 0);
        _showError(e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // [UPDATE] Perbaikan fungsi tombol Daftar
  void _keRegister() {
    HapticFeedback.lightImpact();
    // Gunakan fallback otomatis jika registerScreen kosong
    Widget targetScreen = widget.config.registerScreen ?? const RegisterScreen();
    
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => targetScreen,
        transitionsBuilder: (_, animation, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          )),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: widget.config.backgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BgPainter(
                  primary: widget.config.primaryColor,
                  secondary: _secondaryColor,
                ),
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  FadeTransition(
                    opacity: _headerAnim,
                    child: SizedBox(
                      height: size.height * 0.36,
                      child: _Header(
                        config: widget.config,
                        secondaryColor: _secondaryColor,
                      ),
                    ),
                  ),

                  Expanded(
                    child: SlideTransition(
                      position: _formSlideAnim,
                      child: FadeTransition(
                        opacity: _formFadeAnim,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: widget.config.backgroundColor,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(32),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.10),
                                blurRadius: 24,
                                offset: const Offset(0, -4),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            padding:
                                const EdgeInsets.fromLTRB(28, 32, 28, 24),
                            child: AnimatedBuilder(
                              animation: _shakeAnim,
                              builder: (context, child) {
                                final shake =
                                    math.sin(_shakeAnim.value * math.pi * 6) *
                                        6 *
                                        (1 - _shakeAnim.value);
                                return Transform.translate(
                                  offset: Offset(shake, 0),
                                  child: child,
                                );
                              },
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      'Masuk',
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: widget.config.primaryColor,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Login dengan nomor HP kamu', // Teks diseragamkan
                                      style: TextStyle(
                                        color: Colors.grey.shade500,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 28),

                                    // Input identifier
                                    _buildInput(
                                      controller: _identifierController,
                                      label: 'Nomor HP', // Selalu minta Nomor HP
                                      hint: '081234567890',
                                      icon: Icons.phone_android_outlined,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return 'Wajib diisi';
                                        }
                                        if (val.trim().length < 9) {
                                          return 'Nomor HP tidak valid';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),

                                    // Input password
                                    _buildInput(
                                      controller: _passwordController,
                                      label: 'Password',
                                      hint: 'Masukkan password',
                                      icon: Icons.lock_outline_rounded,
                                      obscure: _obscurePassword,
                                      inputAction: TextInputAction.done,
                                      onSubmitted: (_) => _prosesLogin(),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off_outlined
                                              : Icons.visibility_outlined,
                                          color: Colors.grey.shade400,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                      validator: (val) {
                                        if (val == null || val.isEmpty) {
                                          return 'Password wajib diisi';
                                        }
                                        if (val.length < 6) {
                                          return 'Minimal 6 karakter';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 28),

                                    SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              widget.config.primaryColor,
                                          disabledBackgroundColor: widget
                                              .config.primaryColor
                                              .withOpacity(0.5),
                                          elevation: _isLoading ? 0 : 4,
                                          shadowColor: widget
                                              .config.primaryColor
                                              .withOpacity(0.35),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                        ),
                                        onPressed:
                                            _isLoading ? null : _prosesLogin,
                                        child: AnimatedSwitcher(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          child: _isLoading
                                              ? const SizedBox(
                                                  key: ValueKey('loading'),
                                                  height: 22,
                                                  width: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: Colors.white,
                                                    strokeWidth: 2.5,
                                                  ),
                                                )
                                              : const Text(
                                                  key: ValueKey('text'),
                                                  'Masuk',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 16,
                                                    letterSpacing: 0.3,
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 20),

                                    if (widget.config.showRegister)
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Belum punya akun? ',
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontSize: 14,
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: _keRegister, // Tombol ini sekarang aktif!
                                            child: Text(
                                              'Daftar',
                                              style: TextStyle(
                                                color: widget
                                                    .config.primaryColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscure = false,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction inputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textInputAction: inputAction,
      inputFormatters: inputFormatters,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        labelStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
        prefixIcon: Icon(
          icon,
          color: widget.config.primaryColor.withOpacity(0.6),
          size: 20,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: widget.config.primaryColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade300),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.red.shade400, width: 1.8),
        ),
      ),
    );
  }
}

// ============================================================
// HEADER — gradient + dekorasi lingkaran + logo + tagline
// ============================================================
class _Header extends StatelessWidget {
  final LoginConfig config;
  final Color secondaryColor;

  const _Header({required this.config, required this.secondaryColor});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [config.primaryColor, secondaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: -30,
          right: -30,
          child: Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 50,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Positioned(
          top: 50,
          left: -20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.05),
            ),
          ),
        ),
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
                    ),
                  ),
                  child: Icon(config.icon, size: 30, color: Colors.white),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Laundry One',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                if (config.tagline != null && config.tagline!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    config.tagline!,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    config.roleName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BACKGROUND PAINTER — dekorasi halus di area form
// ============================================================
class _BgPainter extends CustomPainter {
  final Color primary;
  final Color secondary;

  _BgPainter({required this.primary, required this.secondary});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primary.withOpacity(0.04)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width + 40, size.height * 0.75),
      110,
      paint,
    );

    paint.color = secondary.withOpacity(0.03);
    canvas.drawCircle(
      Offset(-20, size.height * 0.88),
      80,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}