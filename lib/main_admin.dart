import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/admin/screens/home_admin_screen.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://wmmbzdcmewqtcuqyhatk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtbWJ6ZGNtZXdxdGN1cXloYXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMTA5MDYsImV4cCI6MjA4NzU4NjkwNn0.xso6FyX2hnZWqhAosUluF_gow6NaSlgsWISgE0f7SqM',
  );
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundry One — Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
      ),
      home: const _SplashRouter(),
    );
  }
}

class _SplashRouter extends StatefulWidget {
  const _SplashRouter();

  @override
  State<_SplashRouter> createState() => _SplashRouterState();
}

class _SplashRouterState extends State<_SplashRouter> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final auth = AuthService();
    if (auth.isLoggedIn()) {
      final role = await auth.getMyRole();
      if (!mounted) return;
      if (role == 'super_admin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeAdminScreen()));
        return;
      }
      await auth.logout();
    }
    if (!mounted) return;
    _keLogin();
  }

  void _keLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(
          config: LoginConfig(
            roleName: 'Super Admin',
            roleDatabase: 'super_admin',
            labelIdentifier: 'Email',
            hint: 'admin@laundry.com',
            keyboardType: TextInputType.emailAddress,
            primaryColor: const Color(0xFF1A237E),
            secondaryColor: const Color(0xFF283593),
            backgroundColor: Colors.white,
            icon: Icons.shield_rounded,
            tagline: 'Panel kontrol penuh bisnis laundry kamu',
            homeScreen: const HomeAdminScreen(),
            showRegister: false,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A237E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15)),
              ),
              child: const Icon(Icons.shield_rounded,
                  size: 56, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Laundry One',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            Text('Admin Dashboard',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    letterSpacing: 1)),
            const SizedBox(height: 48),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}