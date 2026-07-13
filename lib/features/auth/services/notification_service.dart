import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static final _supabase = Supabase.instance.client;

  static Future<void> setupPushNotifications() async {
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true, badge: true, sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('Izin notifikasi ditolak oleh pengguna.');
      return;
    }

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notifikasi di-klik: ${response.payload}');
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'Notifikasi Penting',
      description: 'Channel khusus untuk memunculkan pop-up notifikasi saat aplikasi dibuka.',
      importance: Importance.max,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Simpan token pertama kali & pantau kalau berubah
    await saveTokenToSupabase();
    _fcm.onTokenRefresh.listen((newToken) => _updateToken(newToken));

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.max,
              priority: Priority.high,
              color: const Color(0xFF1565C0),
            ),
          ),
        );
      }
    });
  }

  /// Ambil FCM token dari device lalu simpan ke kolom fcm_token di profiles
  static Future<void> saveTokenToSupabase() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final token = await _fcm.getToken();
    if (token == null) return;

    await _updateToken(token, userId: user.id);
  }

  static Future<void> _updateToken(String token, {String? userId}) async {
    final id = userId ?? _supabase.auth.currentUser?.id;
    if (id == null) return;

    try {
      await _supabase.from('profiles').update({'fcm_token': token}).eq('id', id);
      debugPrint('FCM token tersimpan untuk user $id');
    } catch (e) {
      debugPrint('Gagal simpan FCM token: $e');
    }
  }
}