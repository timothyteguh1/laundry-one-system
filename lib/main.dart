import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Koneksi Supabase dengan URL dan Anon Key milikmu
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
      title: 'Laundry One',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // 2. Ubah ini agar aplikasi langsung membuka LandingPage
    );
  }
}