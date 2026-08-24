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
    return _notifications.where((notification) {
      return notification['is_read'] == false ||
          notification['is_read'] == 0 ||
          notification['is_read'] == null;
    }).length;
  }

  NotificationProvider() {
    _init();
  }

  // ================================================================
  // INITIALIZE LOCAL NOTIFICATIONS
  // ================================================================

  Future<void> _init() async {
    const AndroidInitializationSettings android =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings ios =
    DarwinInitializationSettings();

    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
  }

  // ================================================================
  // HANDLE NOTIFICATION TAP
  // ================================================================

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null) {
      return;
    }

    final context = navigatorKey.currentContext;

    if (context != null) {
      try {
        navigatorKey.currentState?.pushNamed('/home');
      } catch (e) {
        debugPrint('Notification navigation error: $e');
      }
    }
  }

  // ================================================================
  // SHOW LOCAL NOTIFICATION
  // ================================================================

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails android =
    AndroidNotificationDetails(
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

    const NotificationDetails platform = NotificationDetails(
      android: android,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      platform,
      payload: payload,
    );
  }

  // ================================================================
  // INITIALIZE FCM
  // ================================================================

  Future<void> initFcm() async {
    await FcmService.init();
  }

  // ================================================================
  // LOAD NOTIFICATIONS FROM SERVER
  // ================================================================

  Future<void> loadNotifications() async {
    _isLoading = true;
    _error = null;

    notifyListeners();

    try {
      final api = ApiService();
      final response = await api.getNotifications();

      if (response.success && response.data != null) {
        final data = response.data;

        if (data is List) {
          _notifications = data
              .map<Map<String, dynamic>>(
                (item) => Map<String, dynamic>.from(item),
          )
              .toList();
        } else {
          _notifications = [];
        }
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();

      debugPrint(
        'Error loading notifications: $e',
      );
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  // ================================================================
  // MARK SINGLE NOTIFICATION AS READ
  // ================================================================

  Future<void> markAsRead(String notificationId) async {
    try {
      final api = ApiService();

      final response =
      await api.markNotificationAsRead(notificationId);

      if (response.success) {
        final index = _notifications.indexWhere(
              (notification) =>
          notification['id'].toString() ==
              notificationId.toString(),
        );

        if (index != -1) {
          _notifications[index]['is_read'] = true;
          _notifications[index]['read_at'] =
              DateTime.now().toIso8601String();

          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint(
        'Error marking notification as read: $e',
      );
    }
  }

  // ================================================================
  // MARK ALL AS READ
  // ================================================================

  Future<void> markAllAsRead() async {
    try {
      final api = ApiService();

      final response =
      await api.markAllNotificationsAsRead();

      if (response.success) {
        for (final notification in _notifications) {
          notification['is_read'] = true;
          notification['read_at'] =
              DateTime.now().toIso8601String();
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'Error marking all notifications as read: $e',
      );
    }
  }

  // ================================================================
  // ADD LOCAL NOTIFICATION
  // ================================================================

  void addLocalNotification(
      Map<String, dynamic> notification,
      ) {
    _notifications.insert(
      0,
      notification,
    );

    notifyListeners();
  }

  // ================================================================
  // CLEAR ALL NOTIFICATIONS
  // ================================================================

  Future<void> clearAll() async {
    try {
      final api = ApiService();

      final response =
      await api.clearNotifications();

      if (response.success) {
        _notifications.clear();

        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'Error clearing notifications: $e',
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}