// lib/providers/notification_provider.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../main.dart';
import '../services/api_service.dart';
import '../services/fcm_service.dart';

class NotificationProvider extends ChangeNotifier {
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();

  static const String _channelId = 'fundi_channel';
  static const String _channelName = 'NearbyFundi Notifications';

  List<Map<String, dynamic>> _notifications = [];

  bool _isLoading = false;
  String? _error;
  int _serverUnreadCount = 0;

  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _serverUnreadCount;

  int get localUnreadCount {
    return _notifications.where((notification) {
      return _isUnread(notification['is_read']);
    }).length;
  }

  NotificationProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
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

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
        onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationTap,
      );

      await _createNotificationChannel();
      await refreshUnreadCount();

      debugPrint('✅ NotificationProvider initialized');
    } catch (e, stackTrace) {
      debugPrint('❌ NotificationProvider initialization failed: $e');
      debugPrint('$stackTrace');
    }
  }

  @pragma('vm:entry-point')
  static void _onBackgroundNotificationTap(NotificationResponse response) {
    debugPrint('👆 Background notification tapped');
  }

  Future<void> _createNotificationChannel() async {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Notifications from NearbyFundi',
      importance: Importance.max,
      enableVibration: true,
      playSound: true,
      enableLights: true,
      showBadge: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
    _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(channel);
    debugPrint('✅ Notification channel created');
  }

  void _onNotificationTap(NotificationResponse response) {
    try {
      final String? payload = response.payload;
      debugPrint('👆 Notification tapped with payload: $payload');

      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('⚠️ Navigator context is not available');
        return;
      }

      navigatorKey.currentState?.pushNamed('/home');
    } catch (e) {
      debugPrint('❌ Notification navigation error: $e');
    }
  }

  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      const AndroidNotificationDetails androidDetails =
      AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Notifications from NearbyFundi',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        channelShowBadge: true,
      );

      const DarwinNotificationDetails iosDetails =
      DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails =
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final int notificationId =
      DateTime.now().millisecondsSinceEpoch.remainder(2147483647);

      await _localNotifications.show(
        notificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );

      debugPrint('✅ Local notification displayed');
    } catch (e) {
      debugPrint('❌ Failed to show local notification: $e');
    }
  }

  Future<void> initFcm() async {
    try {
      final token = await FcmService.getToken();
      debugPrint('✅ FCM Token retrieved in provider: $token');
    } catch (e) {
      debugPrint('❌ FCM token retrieval failed: $e');
    }
  }

  bool _isUnread(dynamic value) {
    if (value == null) return true;
    if (value is bool) return value == false;
    if (value is num) return value == 0;
    if (value is String) {
      final String normalized = value.toLowerCase().trim();
      return normalized == '0' || normalized == 'false' || normalized.isEmpty;
    }
    return false;
  }

  bool isRead(Map<String, dynamic> notification) {
    return !_isUnread(notification['is_read']);
  }

  Future<void> _updateAppBadge() async {
    try {
      debugPrint('ℹ️ Updating notification badge count: $_serverUnreadCount');
      if (await FlutterAppBadgeControl.isAppBadgeSupported()) {
        if (_serverUnreadCount > 0) {
          FlutterAppBadgeControl.updateBadgeCount(_serverUnreadCount);
        } else {
          FlutterAppBadgeControl.removeBadge();
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to update notification badge: $e');
    }
  }

  Future<void> loadNotifications() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final ApiService api = ApiService();
      final response = await api.getNotifications();

      if (response.success && response.data != null) {
        final dynamic data = response.data;

        if (data is List) {
          _notifications = data.map<Map<String, dynamic>>((item) {
            final Map<String, dynamic> notification =
            Map<String, dynamic>.from(item);
            final dynamic rawData = notification['data'];

            if (rawData is String && rawData.isNotEmpty) {
              try {
                notification['data'] = _safeJsonDecode(rawData);
              } catch (_) {}
            }
            return notification;
          }).toList();
        } else {
          _notifications = [];
        }
      } else {
        _error = response.message;
      }

      await refreshUnreadCount();
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  dynamic _safeJsonDecode(String value) {
    dynamic decoded = value;
    for (int i = 0; i < 2; i++) {
      final dynamic result = _tryDecode(decoded.toString());
      if (result is String) {
        decoded = result;
        continue;
      }
      return result;
    }
    return decoded;
  }

  dynamic _tryDecode(String value) {
    try {
      return jsonDecode(value);
    } catch (_) {
      return value;
    }
  }

  Future<void> refreshUnreadCount() async {
    try {
      final ApiService api = ApiService();
      final response = await api.getUnreadNotificationCount();

      if (response.success && response.data != null) {
        final dynamic count = response.data['count'];

        if (count is int) {
          _serverUnreadCount = count;
        } else {
          _serverUnreadCount =
              int.tryParse(count.toString()) ?? localUnreadCount;
        }
      } else {
        _serverUnreadCount = localUnreadCount;
      }
    } catch (e) {
      debugPrint('❌ Error refreshing unread count: $e');
      _serverUnreadCount = localUnreadCount;
    }

    await _updateAppBadge();
    notifyListeners();
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final ApiService api = ApiService();
      final response = await api.markNotificationAsRead(notificationId);

      if (!response.success) return;

      final int index = _notifications.indexWhere(
            (notification) =>
        notification['id'].toString() == notificationId.toString(),
      );

      if (index != -1) {
        _notifications[index]['is_read'] = true;
        _notifications[index]['read_at'] = DateTime.now().toIso8601String();
      }

      await refreshUnreadCount();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final ApiService api = ApiService();
      final response = await api.markAllNotificationsAsRead();

      if (!response.success) return;

      final String readAt = DateTime.now().toIso8601String();
      for (final notification in _notifications) {
        notification['is_read'] = true;
        notification['read_at'] = readAt;
      }

      _serverUnreadCount = 0;
      await _updateAppBadge();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error marking all notifications as read: $e');
    }
  }

  void addLocalNotification(Map<String, dynamic> notification) {
    notification['is_read'] ??= false;
    _notifications.insert(0, notification);
    _serverUnreadCount++;
    _updateAppBadge();
    notifyListeners();
  }

  Future<void> clearAll() async {
    try {
      final ApiService api = ApiService();
      final response = await api.clearNotifications();

      if (!response.success) return;

      _notifications.clear();
      _serverUnreadCount = 0;
      await _updateAppBadge();
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
    }
  }

  Future<void> clearBadge() async {
    try {
      await _localNotifications.cancelAll();
      FlutterAppBadgeControl.removeBadge();
      debugPrint('✅ Notifications and badge cleared');
    } catch (e) {
      debugPrint('❌ Failed to clear notifications: $e');
    }
  }

  @override
  void dispose() {
    _localNotifications.cancelAll();
    super.dispose();
  }
}