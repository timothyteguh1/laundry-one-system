import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> setupPushNotifications() async {
    // 1. Minta Izin Notifikasi ke HP Pelanggan
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      debugPrint('Izin notifikasi ditolak oleh pengguna.');
      return;
    }

    // 2. Persiapan "Jalur Khusus" Android
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initSettings = InitializationSettings(android: androidInit);
    
    // 👇 FIX FINAL: Tambahkan label "settings:" di depan initSettings
    await _localNotifications.initialize(
      settings: initSettings, // <--- Ini yang bikin error tadi
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

    // 3. LISTENER: Menangkap Notifikasi Saat Aplikasi Sedang Terbuka (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      
      // 👇 ALAT SADAP (LOGGER) DITAMBAHKAN DI SINI 👇
      debugPrint("====================================");
      debugPrint("🔥 HORE! NOTIFIKASI MASUK KE HP: ${message.notification?.title}");
      debugPrint("Isi Pesan: ${message.notification?.body}");
      debugPrint("====================================");

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
}