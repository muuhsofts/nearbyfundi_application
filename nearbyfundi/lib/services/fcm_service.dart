import 'dart:io';
import 'package:app_badge_control_flutter/app_badge_control_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static const String _tokenKey = 'fcm_token';
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) {
      debugPrint('ℹ️ FCM Service already initialized');
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      await _saveToken();
      _fcm.onTokenRefresh.listen(_handleTokenRefresh);

      _initialized = true;
      debugPrint('✅ FCM Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ FCM Service initialization failed: $e');
      debugPrint('$stackTrace');
    }
  }

  static Future<void> _handleTokenRefresh(String token) async {
    try {
      if (token.isEmpty) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      debugPrint('✅ FCM token refreshed and saved');
    } catch (e) {
      debugPrint('❌ Failed to save refreshed FCM token: $e');
    }
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 Foreground FCM received: ${message.notification?.title}');
    // Delegate handling to NotificationProvider via main listener
  }

  static void _handleMessageOpened(RemoteMessage message) {
    debugPrint('📱 FCM Notification opened: ${message.notification?.title}');
  }

  static Future<void> _saveToken() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      debugPrint('✅ FCM token saved');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      if (Platform.isIOS) {
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _fcm.getAPNSToken();
        }
        if (apnsToken == null) {
          debugPrint('⚠️ APNS Token is null. Cannot retrieve FCM Token yet.');
          return null;
        }
      }
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('❌ Failed to get FCM token: $e');
      return null;
    }
  }
}

// ============================================================
// BACKGROUND FIREBASE MESSAGE HANDLER
// ============================================================

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final currentCount = (prefs.getInt('badge_count') ?? 0) + 1;
    await prefs.setInt('badge_count', currentCount);

    await AppBadgeControlFlutter.updateBadgeCount(currentCount);

    if (message.notification == null) {
      final notifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await notifications.initialize(
        const InitializationSettings(android: androidSettings, iOS: iosSettings),
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fundi_channel',
        'NearbyFundi Notifications',
        description: 'Notifications from NearbyFundi',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
      );

      final androidPlugin = notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(channel);

      final AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        'fundi_channel',
        'NearbyFundi Notifications',
        channelDescription: 'Notifications from NearbyFundi',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
        channelShowBadge: true,
        number: currentCount,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await notifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
        message.data['title']?.toString() ?? 'NearbyFundi',
        message.data['body']?.toString() ?? 'You have a new notification',
        notificationDetails,
        payload: message.data['type']?.toString() ?? 'notification',
      );
    }
  } catch (e, stackTrace) {
    debugPrint('❌ Background notification failed: $e');
    debugPrint('$stackTrace');
  }
}