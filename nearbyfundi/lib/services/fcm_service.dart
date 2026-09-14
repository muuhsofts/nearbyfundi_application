// lib/services/fcm_service.dart

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class FcmService {
  // ============================================================
  // FIREBASE & NOTIFICATIONS
  // ============================================================

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const String _channelId = 'fundi_channel';
  static const String _channelName = 'NearbyFundi Notifications';
  static const String _badgeKey = 'badge_count';
  static const String _tokenKey = 'fcm_token';

  static bool _initialized = false;

  // ============================================================
  // INITIALIZE
  // ============================================================

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

      // Request notification permissions
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Platform Settings
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      await _createNotificationChannel();

      // Listeners
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Save FCM Token cleanly with APNS safety
      await _saveToken();

      _fcm.onTokenRefresh.listen(_handleTokenRefresh);
      await _loadSavedBadge();

      _initialized = true;
      debugPrint('✅ FCM Service initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ FCM Service initialization failed: $e');
      debugPrint('$stackTrace');
    }
  }

  // ============================================================
  // TOKEN REFRESH
  // ============================================================

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

  // ============================================================
  // ANDROID NOTIFICATION CHANNEL
  // ============================================================

  static Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications from NearbyFundi',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      showBadge: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
    debugPrint('✅ Notification channel created');
  }

  // ============================================================
  // NOTIFICATION TAP & FOREGROUND
  // ============================================================

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 Notification tapped');
    debugPrint('Payload: ${response.payload}');
  }

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Foreground notification: ${message.notification?.title}');
    await _showNotification(message);
    await _incrementBadge();
  }

  static Future<void> _handleMessageOpened(RemoteMessage message) async {
    debugPrint('📱 Notification opened: ${message.notification?.title}');
  }

  // ============================================================
  // SHOW LOCAL NOTIFICATION
  // ============================================================

  static Future<void> _showNotification(RemoteMessage message) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Notifications from NearbyFundi',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
      channelShowBadge: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    final title = message.notification?.title ?? 'NearbyFundi';
    final body = message.notification?.body ?? 'You have a new notification';
    final payload = message.data['type']?.toString() ?? 'notification';

    await _notifications.show(
      notificationId,
      title,
      body,
      notificationDetails,
      payload: payload,
    );

    debugPrint('✅ Local notification displayed');
  }

  // ============================================================
  // HARDWARE APP BADGE LOGIC
  // ============================================================

  static Future<void> _incrementBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_badgeKey) ?? 0;
      final newCount = currentCount + 1;

      await prefs.setInt(_badgeKey, newCount);
      await _updateNativeBadge(newCount);
    } catch (e) {
      debugPrint('❌ Failed to increment badge: $e');
    }
  }

  static Future<void> _loadSavedBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_badgeKey) ?? 0;
      await _updateNativeBadge(count);
      debugPrint('✅ Restored badge count: $count');
    } catch (e) {
      debugPrint('❌ Failed to restore badge: $e');
    }
  }

  static Future<void> _updateNativeBadge(int count) async {
    if (await FlutterAppBadgeControl.isAppBadgeSupported()) {
      if (count > 0) {
        FlutterAppBadgeControl.updateBadgeCount(count);
      } else {
        FlutterAppBadgeControl.removeBadge();
      }
    }
  }

  static Future<void> clearBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_badgeKey, 0);
      if (await FlutterAppBadgeControl.isAppBadgeSupported()) {
        FlutterAppBadgeControl.removeBadge();
      }
      debugPrint('✅ Notification badge cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear badge: $e');
    }
  }

  static Future<int> getBadgeCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_badgeKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  // ============================================================
  // APNS-SAFE FCM TOKEN RETRIEVAL
  // ============================================================

  static Future<void> _saveToken() async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ FCM token is null or empty');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);
      debugPrint('✅ FCM token saved');
    } catch (e) {
      debugPrint('❌ Failed to save FCM token: $e');
    }
  }

  static Future<String?> getToken() async {
    try {
      // Safe APNS Check on iOS to prevent apns-token-not-set exception
      if (Platform.isIOS) {
        String? apnsToken = await _fcm.getAPNSToken();
        if (apnsToken == null) {
          await Future.delayed(const Duration(seconds: 2));
          apnsToken = await _fcm.getAPNSToken();
        }
        if (apnsToken == null) {
          debugPrint('⚠️ APNS Token is still null. Cannot get FCM Token yet.');
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
    final currentCount = prefs.getInt('badge_count') ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt('badge_count', newCount);

    if (await FlutterAppBadgeControl.isAppBadgeSupported()) {
      FlutterAppBadgeControl.updateBadgeCount(newCount);
    }

    final notifications = FlutterLocalNotificationsPlugin();
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await notifications.initialize(settings);

    const AndroidNotificationDetails androidDetails =
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
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    await notifications.show(
      notificationId,
      message.notification?.title ?? 'NearbyFundi',
      message.notification?.body ?? 'You have a new notification',
      notificationDetails,
      payload: message.data['type']?.toString() ?? 'notification',
    );
  } catch (e, stackTrace) {
    debugPrint('❌ Background notification failed: $e');
    debugPrint('$stackTrace');
  }
}