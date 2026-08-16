// lib/services/fcm_service.dart
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

import '../config/app_routes.dart';
import 'fcm_event_bus.dart';

class FcmService {
  static final GlobalKey<NavigatorState> navigatorKey =
  GlobalKey<NavigatorState>();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  @pragma('vm:entry-point')
  static Future<void> onBackgroundMessage(RemoteMessage message) async {
    print("📩 Background message: ${message.notification?.title}");
  }

  static Future<void> init() async {
    try {
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        print('❌ FCM permission denied');
        return;
      }

      FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);

      const AndroidInitializationSettings android =
      AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings ios = DarwinInitializationSettings();
      const InitializationSettings initSettings =
      InitializationSettings(android: android, iOS: ios);

      await _notifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _handleNotificationTapFromLocal,
      );

      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'fundi_channel',
        'FundiApp Notifications',
        description: 'Notifications from FundiApp',
        importance: Importance.max,
        showBadge: true,
        enableVibration: true,
        playSound: true,
      );

      await _notifications
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Set foreground presentation options for iOS
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);

      RemoteMessage? initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _handleNotificationTapFromRemote(initialMessage);
      }

      FirebaseMessaging.onMessageOpenedApp
          .listen(_handleNotificationTapFromRemote);

      print('✅ FCM initialized');
    } catch (e) {
      print('❌ FCM init error: $e');
    }
  }

  static void _showForegroundNotification(RemoteMessage message) {
    try {
      final title = message.notification?.title ?? 'FundiApp';
      final body =
          message.notification?.body ?? 'You have a new notification';

      final context = navigatorKey.currentContext;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$title: $body'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'View',
              onPressed: () {
                _handleNotificationTapFromRemote(message);
              },
            ),
          ),
        );
      }

      // System notification with badge support
      const AndroidNotificationDetails android = AndroidNotificationDetails(
        'fundi_channel',
        'FundiApp Notifications',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
        showWhen: true,
        playSound: true,
        enableVibration: true,
      );

      const NotificationDetails platform =
      NotificationDetails(android: android);

      _notifications.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platform,
        payload:
        message.data.isNotEmpty ? json.encode(message.data) : null,
      );

      // Live event bus so NotificationProvider can update the bell instantly
      FcmEventBus.instance.emit({
        'title': title,
        'body': body,
        'type': message.data['type'] ?? 'general',
        'data': message.data,
        'received_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      print('❌ Show foreground notification error: $e');
    }
  }

  static void _handleNotificationTapFromLocal(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = Map<String, dynamic>.from(
        json.decode(response.payload!) as Map<String, dynamic>,
      );
      _navigateBasedOnType(data);
    } catch (e) {
      _navigateToHome();
    }
  }

  static void _handleNotificationTapFromRemote(RemoteMessage message) {
    try {
      _navigateBasedOnType(message.data);
    } catch (e) {
      _navigateToHome();
    }
  }

  static void _navigateBasedOnType(Map<String, dynamic> data) {
    final type = data['type'] ?? '';
    final conversationId = data['conversation_id'];

    switch (type) {
      case 'chat_message':
        if (conversationId != null) {
          _navigateToChat(conversationId);
        } else {
          _navigateToHome();
        }
        break;
      case 'new_request':
      case 'request_accepted':
      case 'request_rejected':
        _navigateToRequests();
        break;
      case 'post_comment':
      case 'post_like':
        _navigateToBlog();
        break;
      case 'profile_update':
        _navigateToProfile();
        break;
      default:
        _navigateToHome();
    }
  }

  static void _navigateToChat(String conversationId) {
    navigatorKey.currentState?.pushNamed(
      AppRoutes.chat,
      arguments: {'conversationId': int.parse(conversationId)},
    );
  }

  static void _navigateToRequests() {
    navigatorKey.currentState?.pushNamed(AppRoutes.requests);
  }

  static void _navigateToBlog() {
    navigatorKey.currentState?.pushNamed(AppRoutes.blog);
  }

  static void _navigateToProfile() {
    navigatorKey.currentState?.pushNamed(AppRoutes.profile);
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
      print('❌ FCM getToken error: $e');
      return null;
    }
  }
}