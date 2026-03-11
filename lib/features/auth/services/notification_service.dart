import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static Future<void> setupPushNotifications() async {
    // 1. Lewati jika di platform yang tidak didukung Firebase Messaging
    if (kIsWeb || (!kIsWeb && Platform.isWindows)) {
      print('ℹ️ NotificationService: Skip platform Desktop/Web');
      return; 
    }

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;

      // Minta izin
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        // Ambil Token unik HP
        String? fcmToken = await messaging.getToken();
        
        if (fcmToken != null) {
          print('🚀 FCM TOKEN HP INI: $fcmToken');
          await _saveTokenToSupabase(fcmToken);
        }

        // Listener jika token berubah di masa depan
        messaging.onTokenRefresh.listen((newToken) {
          _saveTokenToSupabase(newToken);
        });
      }
    } catch (e) {
      print('⚠️ Firebase Messaging Error: $e');
    }
  }

  static Future<void> _saveTokenToSupabase(String token) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token})
            .eq('id', currentUser.id);
        print('✅ Token berhasil sinkron ke Supabase');
      }
    } catch (e) {
      print('❌ Gagal simpan token ke Supabase: $e');
    }
  }
}