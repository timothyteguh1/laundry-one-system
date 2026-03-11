import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/customer/screens/home_customer_screen.dart';
import 'package:laundry_one/features/customer/screens/register_customer_screen.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Firebase (Hanya di Android/iOS/Web)
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // 2. Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://wmmbzdcmewqtcuqyhatk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtbWJ6ZGNtZXdxdGN1cXloYXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMTA5MDYsImV4cCI6MjA4NzU4NjkwNn0.xso6FyX2hnZWqhAosUluF_gow6NaSlgsWISgE0f7SqM',
  );

  runApp(const CustomerApp());
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundry One',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
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
      if (role == 'customer') {
        // Ambil token notifikasi segera setelah sesi terdeteksi
        NotificationService.setupPushNotifications();
        
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeCustomerScreen()));
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
            roleName: 'Pelanggan',
            roleDatabase: 'customer',
            labelIdentifier: 'Nomor HP',
            hint: '081234567890',
            keyboardType: TextInputType.phone,
            primaryColor: CustomerTheme.primary,
            secondaryColor: CustomerTheme.primaryDark,
            backgroundColor: CustomerTheme.surface, 
            icon: Icons.local_laundry_service_rounded,
            tagline: 'Lacak cucian & kumpulkan poinnya', 
            homeScreen: const HomeCustomerScreen(),
            showRegister: true,
            registerScreen: const RegisterCustomerScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF00897B),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.local_laundry_service_rounded,
                  size: 56, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const Text('Laundry One',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
            ),
            const SizedBox(height: 48),
            const SizedBox(width: 24, height: 24,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}