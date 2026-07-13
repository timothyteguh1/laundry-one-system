import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Kunci opsi Firebase khusus kasir
import 'firebase_options_cashier.dart' as cashierFirebase;

import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/auth/screens/register_screen.dart';
import 'package:laundry_one/features/cashier/screens/home_cashier_screen.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 Notif background: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Jalankan Firebase untuk semua platform (Web & Android)
    await Firebase.initializeApp(
      options: cashierFirebase.DefaultFirebaseOptions.currentPlatform,
    );
    
    // Cegah crash di Chrome: Background handler HANYA dinyalakan jika BUKAN Web
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    }
  } catch (e) {
    if (!e.toString().contains('duplicate-app')) {
      debugPrint("Error Firebase: $e");
    }
  }

  await Supabase.initialize(
    url: 'https://wmmbzdcmewqtcuqyhatk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtbWJ6ZGNtZXdxdGN1cXloYXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMTA5MDYsImV4cCI6MjA4NzU4NjkwNn0.xso6FyX2hnZWqhAosUluF_gow6NaSlgsWISgE0f7SqM',
  );
  
  runApp(const CashierApp());
}

class CashierApp extends StatelessWidget {
  const CashierApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Laundry One — Kasir',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      navigatorKey: GlobalKey<NavigatorState>(),
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
    _setupAuthListener();
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        if (mounted) _keLogin();
      }
    });
  }

  Future<void> _checkSession() async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final auth = AuthService();
    
    if (auth.isLoggedIn()) {
      final role = await auth.getMyRole();
      if (!mounted) return;
      if (role == 'cashier' || role == 'super_admin') {
        NotificationService.setupPushNotifications();
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const HomeCashierScreen()));
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
            roleName: 'Staf Kasir',
            roleDatabase: 'cashier',
            labelIdentifier: 'Nomor HP',
            hint: '081234567890',
            keyboardType: TextInputType.phone,
            primaryColor: const Color(0xFF1565C0),
            secondaryColor: const Color(0xFF0D47A1),
            backgroundColor: Colors.white,
            icon: Icons.point_of_sale_rounded,
            tagline: 'Kelola pesanan dengan cepat & mudah',
            homeScreen: const HomeCashierScreen(),
            showRegister: true,
            registerScreen: const RegisterScreen(),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
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
            const Text(
              'Laundry One',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5),
            ),
            const SizedBox(height: 6),
            Text('POS Kasir',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.7), fontSize: 14)),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}