// lib/providers/notification_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart';
import '../services/fcm_service.dart';
import '../services/api_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get unreadCount {
    return _notifications.where((n) => n['is_read'] == false).length;
  }

  NotificationProvider() {
    _init();
  }

  void _init() async {
    const AndroidInitializationSettings android =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    const InitializationSettings settings =
    InitializationSettings(android: android, iOS: ios);

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // Handle notification tap
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null) {
      // Use navigatorKey from main.dart
      final context = navigatorKey.currentContext;
      if (context != null) {
        try {
          // Parse payload and navigate
          // For now, navigate to home
          navigatorKey.currentState?.pushNamed('/home');
        } catch (e) {
          // If payload is not JSON, navigate to home
          navigatorKey.currentState?.pushNamed('/home');
        }
      }
    }
  }

  // Show local notification
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'fundi_channel',
      'NearbyFundi Notifications',
      channelDescription: 'Notifications from NearbyFundi',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails platform = NotificationDetails(android: android);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platform,
      payload: payload,
    );
  }

  // Initialize FCM
  Future<void> initFcm() async {
    await FcmService.init();
  }

  // Load notifications from server
  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getNotifications();

      if (response.success && response.data != null) {
        _notifications = List<Map<String, dynamic>>.from(response.data);
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      final api = ApiService();
      final response = await api.markNotificationAsRead(notificationId);

      if (response.success) {
        final index = _notifications.indexWhere((n) => n['id'] == notificationId);
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
    }
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    try {
      final api = ApiService();
      final response = await api.markAllNotificationsAsRead();

      if (response.success) {
        for (var notification in _notifications) {
          notification['is_read'] = true;
        }
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
    }
  }

  // Add notification locally (for testing or when receiving FCM)
  void addLocalNotification(Map<String, dynamic> notification) {
    _notifications.insert(0, notification);
    notifyListeners();
  }

  // Clear all notifications
  Future<void> clearAll() async {
    try {
      final api = ApiService();
      final response = await api.clearNotifications();

      if (response.success) {
        _notifications.clear();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error clearing notifications: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}