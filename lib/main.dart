import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'firebase_options.dart';
// Sesuaikan path import ini dengan struktur foldermu
import 'package:laundry_one/features/auth/services/notification_service.dart';

void main() async {
  // 1. Wajib baris pertama
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inisialisasi Firebase (Hanya di Android/iOS/Web)
  if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // 3. Inisialisasi Supabase
  await Supabase.initialize(
    url: 'https://wmmbzdcmewqtcuqyhatk.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndtbWJ6ZGNtZXdxdGN1cXloYXRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIwMTA5MDYsImV4cCI6MjA4NzU4NjkwNn0.xso6FyX2hnZWqhAosUluF_gow6NaSlgsWISgE0f7SqM',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Laundry One',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // Sesuaikan dengan screen awal kamu (misal LoginScreen atau MainScreen)
      home: const Scaffold(body: Center(child: Text("Loading..."))), 
    );
  }
}