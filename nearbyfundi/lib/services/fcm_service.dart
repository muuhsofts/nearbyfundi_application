// lib/services/fcm_service.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class FcmService {
  // ============================================================
  // FIREBASE
  // ============================================================

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  // ============================================================
  // LOCAL NOTIFICATIONS
  // ============================================================

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
      // Firebase
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }

      // Notification permission
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // Android initialization
      const AndroidInitializationSettings androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS initialization
      const DarwinInitializationSettings iosSettings =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      // General initialization
      const InitializationSettings settings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Android channel
      await _createNotificationChannel();

      // Firebase listeners
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpened);

      // Background messages
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      // Save token
      await _saveToken();

      // Token refresh
      _fcm.onTokenRefresh.listen(_handleTokenRefresh);

      // Restore badge
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
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    );

    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);

    debugPrint('✅ Notification channel created');
  }

  // ============================================================
  // NOTIFICATION TAP
  // ============================================================

  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('👆 Notification tapped');
    debugPrint('Payload: ${response.payload}');
    // Navigation can be connected here later.
  }

  // ============================================================
  // FOREGROUND MESSAGE
  // ============================================================

  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📱 Foreground notification: ${message.notification?.title}');

    await _showNotification(message);
    await _incrementBadge();
  }

  // ============================================================
  // MESSAGE OPENED
  // ============================================================

  static Future<void> _handleMessageOpened(RemoteMessage message) async {
    debugPrint('📱 Notification opened: ${message.notification?.title}');
    debugPrint('Notification data: ${message.data}');
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
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
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
  // BADGE METHODS (Using SharedPreferences only)
  // ============================================================

  static Future<void> _incrementBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt(_badgeKey) ?? 0;
      final newCount = currentCount + 1;

      await prefs.setInt(_badgeKey, newCount);
      debugPrint('✅ Badge count updated: $newCount (in memory)');
    } catch (e) {
      debugPrint('❌ Failed to increment badge: $e');
    }
  }

  static Future<void> _loadSavedBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_badgeKey) ?? 0;
      debugPrint('✅ Restored badge count: $count');
    } catch (e) {
      debugPrint('❌ Failed to restore badge: $e');
    }
  }

  static Future<void> clearBadge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_badgeKey, 0);
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
      debugPrint('❌ Failed to get badge count: $e');
      return 0;
    }
  }

  // ============================================================
  // FCM TOKEN METHODS
  // ============================================================

  static Future<void> _saveToken() async {
    try {
      final token = await _fcm.getToken();

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
    // Firebase
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    debugPrint('📱 Background notification: ${message.notification?.title}');

    // Badge count (using SharedPreferences only)
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('badge_count') ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt('badge_count', newCount);

    // Local notification plugin
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

    // Notification details
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'fundi_channel',
      'NearbyFundi Notifications',
      channelDescription: 'Notifications from NearbyFundi',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
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

    // Notification ID
    final notificationId =
    DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

    // Show notification
    await notifications.show(
      notificationId,
      message.notification?.title ?? 'NearbyFundi',
      message.notification?.body ?? 'You have a new notification',
      notificationDetails,
      payload: message.data['type']?.toString() ?? 'notification',
    );

    debugPrint('✅ Background notification handled. Badge: $newCount');
  } catch (e, stackTrace) {
    debugPrint('❌ Background notification failed: $e');
    debugPrint('$stackTrace');
  }
}