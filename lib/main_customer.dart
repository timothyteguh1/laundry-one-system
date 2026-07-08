import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
import 'package:laundry_one/features/customer/customer_theme.dart';
import 'package:laundry_one/features/auth/screens/login_screen.dart';
import 'package:laundry_one/features/customer/screens/home_customer_screen.dart';
import 'package:laundry_one/features/customer/screens/register_customer_screen.dart';
import 'package:laundry_one/features/auth/services/auth_service.dart';
import 'package:laundry_one/features/auth/services/notification_service.dart';

// Handler ini WAJIB top-level function (di luar class), tidak boleh di dalam widget/class.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Isolate terpisah dari UI, jadi cukup log ringan di sini.
  // Jangan panggil setState/UI/Supabase auth di sini.
  debugPrint('📩 Notifikasi diterima saat app background/terminated: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Inisialisasi Firebase (Hanya di Android/iOS/Web)
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Jika sistem native Android sudah menyalakannya duluan, abaikan error duplikat ini
      if (!e.toString().contains('duplicate-app')) {
        rethrow; // Lemparkan error jika itu masalah lain, bukan masalah duplikat
      }
    }

    // [TAMBAHAN] Daftarkan background handler SEBELUM runApp
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
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
      if (role == 'customer') {
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