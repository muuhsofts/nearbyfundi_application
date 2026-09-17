import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_navigator.dart';
import '../config/app_routes.dart';
import '../main.dart';
import 'fcm_event_bus.dart';

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  /// Use the shared key from app_navigator.dart
  static GlobalKey<NavigatorState> get navKey => navigatorKey;

  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    debugPrint('📩 Background message: ${message.notification?.title}');
  }

  static Future<void> init() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        debugPrint('❌ FCM permission denied');
        return;
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      const initSettings = InitializationSettings(android: android, iOS: ios);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTapFromLocal,
      );

      const channel = AndroidNotificationChannel(
        'fundi_channel',
        'NearbyFundi Notifications',
        description: 'Notifications from NearbyFundi',
        importance: Importance.max,
        showBadge: true,
        enableVibration: true,
        playSound: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTapFromRemote(initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp
          .listen(_handleNotificationTapFromRemote);

      debugPrint('✅ FCM initialized');
    } catch (e) {
      debugPrint('❌ FCM init error: $e');
    }
  }

  static String _sanitize(String? value, String fallback) {
    final text = (value ?? '').trim();
    if (text.isEmpty || int.tryParse(text) != null) return fallback;
    return text;
  }

  static void _showForegroundNotification(RemoteMessage message) {
    try {
      final type = message.data['type']?.toString() ?? 'general';

      // Chat: silent – no system tray banner
      if (type == 'chat_message') {
        FcmEventBus.instance.emit({
          'title': message.notification?.title ?? '',
          'body': message.notification?.body ?? '',
          'type': type,
          'data': message.data,
          'received_at': DateTime.now().toIso8601String(),
        });
        return;
      }

      final title = _sanitize(
        message.notification?.title ?? message.data['title']?.toString(),
        'NearbyFundi',
      );
      final body = _sanitize(
        message.notification?.body ?? message.data['body']?.toString(),
        'You have a new update',
      );

      const android = AndroidNotificationDetails(
        'fundi_channel',
        'NearbyFundi Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const platform = NotificationDetails(android: android);

      _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platform,
        payload: message.data.isNotEmpty ? json.encode(message.data) : null,
      );

      FcmEventBus.instance.emit({
        'title': title,
        'body': body,
        'type': type,
        'data': message.data,
        'received_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('❌ Show foreground notification error: $e');
    }
  }

  static void _handleNotificationTapFromLocal(NotificationResponse response) {
    if (response.payload == null) return;
    try {
      final data = Map<String, dynamic>.from(
        json.decode(response.payload!) as Map<String, dynamic>,
      );
      _navigateBasedOnType(data);
    } catch (_) {
      _navigateToHome();
    }
  }

  static void _handleNotificationTapFromRemote(RemoteMessage message) {
    try {
      _navigateBasedOnType(message.data);
    } catch (_) {
      _navigateToHome();
    }
  }

  static void _navigateBasedOnType(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final conversationId = data['conversation_id'];

    switch (type) {
      case 'chat_message':
        if (conversationId != null) {
          navigatorKey.currentState?.pushNamed(
            AppRoutes.chat,
            arguments: {
              'conversationId': int.tryParse(conversationId.toString()) ?? 0,
            },
          );
        } else {
          _navigateToHome();
        }
        break;
      case 'new_request':
      case 'request_accepted':
      case 'request_rejected':
      case 'request_in_progress':
      case 'request_completed':
      case 'request_on_the_way':
      case 'request_arrived':
      case 'request_cancelled':
        navigatorKey.currentState?.pushNamed(AppRoutes.requests);
        break;
      case 'post_comment':
      case 'post_like':
      case 'new_post':
        navigatorKey.currentState?.pushNamed(AppRoutes.blog);
        break;
      case 'profile_update':
        navigatorKey.currentState?.pushNamed(AppRoutes.profile);
        break;
      default:
        navigatorKey.currentState?.pushNamed(AppRoutes.notifications);
    }
  }

  static void _navigateToHome() {
    navigatorKey.currentState?.pushNamedAndRemoveUntil(
      AppRoutes.home,
          (_) => false,
    );
  }

  static Future<String?> getToken() async {
    try {
      return await _fcm.getToken();
    } catch (e) {
      debugPrint('❌ FCM getToken error: $e');
      return null;
    }
  }
}