import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../services/fcm_service.dart';
import '../services/fcm_event_bus.dart';
import '../services/api_service.dart';
import '../utils/badge_helper.dart';
import '../config/app_routes.dart';

class NotificationProvider extends ChangeNotifier {
  // ============================================
  // DEPENDENCIES
  // ============================================
  final FlutterLocalNotificationsPlugin _localNotifications =
  FlutterLocalNotificationsPlugin();
  final ApiService _apiService = ApiService();

  // ============================================
  // STATE
  // ============================================
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  StreamSubscription? _fcmSub;
  bool _pulseBadge = false;

  // ============================================
  // GETTERS
  // ============================================
  List<Map<String, dynamic>> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  bool get pulseBadge => _pulseBadge;

  int get unreadCount =>
      _notifications.where((n) => !_isRead(n)).length;

  bool get hasUnread => unreadCount > 0;
  bool get hasNotifications => _notifications.isNotEmpty;

  // ============================================
  // HELPERS (type-safe)
  // ============================================
  String _idToString(dynamic id) => id?.toString() ?? '';

  bool _isRead(Map<String, dynamic> n) {
    final value = n['is_read'];
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) {
      return value == '1' || value.toLowerCase() == 'true';
    }
    return false;
  }

  // ============================================
  // INITIALIZATION
  // ============================================
  NotificationProvider() {
    _init();
  }

  Future<void> _init() async {
    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings();
      const settings = InitializationSettings(android: android, iOS: ios);

      await _localNotifications.initialize(
        settings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      _isInitialized = true;
      await loadNotifications();

      _fcmSub = FcmEventBus.instance.stream.listen(_onFcmEvent);
    } catch (e) {
      debugPrint('❌ Notification init error: $e');
      _error = 'Failed to initialize notifications';
    }
  }

  void _onFcmEvent(Map<String, dynamic> event) {
    addLocalNotification({
      'id': 'local_${DateTime.now().millisecondsSinceEpoch}',
      'title': event['title'] ?? 'Notification',
      'body': event['body'] ?? '',
      'type': event['type'] ?? 'general',
      'is_read': false,
      'created_at': event['received_at'] ?? DateTime.now().toIso8601String(),
    });

    _pulseBadge = true;
    notifyListeners();
    _syncAppBadge();

    Future.delayed(const Duration(seconds: 2), loadNotifications);
  }

  void consumePulse() {
    _pulseBadge = false;
  }

  // ============================================
  // APP ICON BADGE
  // ============================================
  void _syncAppBadge() {
    BadgeHelper.updateBadge(unreadCount);
  }

  // ============================================
  // LOCAL NOTIFICATION TAP
  // ============================================
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;

    final context = FcmService.navigatorKey.currentContext;
    if (context == null) return;

    try {
      final data = Map<String, dynamic>.from(
        json.decode(payload) as Map,
      );
      _handleNavigation(context, data);
    } catch (e) {
      debugPrint('⚠️ Invalid notification payload: $e');
      FcmService.navigatorKey.currentState?.pushNamed(AppRoutes.home);
    }
  }

  void _handleNavigation(BuildContext context, Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final conversationId = data['conversation_id'];

    switch (type) {
      case 'chat_message':
        if (conversationId != null) {
          FcmService.navigatorKey.currentState?.pushNamed(
            AppRoutes.chat,
            arguments: {
              'conversationId': int.tryParse(conversationId.toString()) ?? 0,
            },
          );
        }
        break;
      case 'new_request':
      case 'request_accepted':
      case 'request_rejected':
        FcmService.navigatorKey.currentState?.pushNamed(AppRoutes.requests);
        break;
      case 'post_comment':
      case 'post_like':
        FcmService.navigatorKey.currentState?.pushNamed(AppRoutes.blog);
        break;
      case 'profile_update':
        FcmService.navigatorKey.currentState?.pushNamed(AppRoutes.profile);
        break;
      default:
        FcmService.navigatorKey.currentState?.pushNamed(AppRoutes.home);
    }
  }

  // ============================================
  // SHOW LOCAL NOTIFICATION
  // ============================================
  Future<void> showLocalNotification({
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    if (!_isInitialized) return;

    try {
      final androidDetails = AndroidNotificationDetails(
        channelId ?? 'fundi_channel',
        channelName ?? 'FundiApp Notifications',
        channelDescription: 'Notifications from FundiApp',
        importance: Importance.high,
        priority: Priority.high,
        channelShowBadge: true,
        showWhen: true,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        autoCancel: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final id = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      await _localNotifications.show(
        id,
        title,
        body,
        platformDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('❌ Failed to show notification: $e');
    }
  }

  Future<void> showSimpleNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    await showLocalNotification(title: title, body: body, payload: payload);
  }

  // ============================================
  // FCM
  // ============================================
  Future<void> initFcm() async {
    try {
      await FcmService.init();
    } catch (e) {
      debugPrint('❌ FCM init error: $e');
      _error = 'Failed to initialize FCM';
    }
  }

  Future<String?> getFcmToken() async {
    try {
      return await FcmService.getToken();
    } catch (e) {
      debugPrint('❌ FCM token error: $e');
      return null;
    }
  }

  // ============================================
  // API
  // ============================================
  Future<void> loadNotifications() async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.getNotifications();

      if (response.success && response.data != null) {
        _notifications = List<Map<String, dynamic>>.from(response.data);
      } else {
        _error = response.message ?? 'Failed to load notifications';
        _notifications = [];
      }
    } catch (e) {
      _error = 'Error loading notifications: $e';
      _notifications = [];
      debugPrint('❌ Load notifications error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
      _syncAppBadge();
    }
  }

  Future<void> refresh() async => loadNotifications();

  Future<bool> markAsRead(dynamic notificationId) async {
    final id = _idToString(notificationId);
    if (id.isEmpty) return false;

    try {
      final response = await _apiService.markNotificationAsRead(id);

      if (response.success) {
        final index = _notifications.indexWhere(
              (n) => _idToString(n['id']) == id,
        );
        if (index != -1) {
          _notifications[index]['is_read'] = true;
          notifyListeners();
          _syncAppBadge();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('❌ Mark as read error: $e');
      return false;
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await _apiService.markAllNotificationsAsRead();

      if (response.success) {
        for (final n in _notifications) {
          n['is_read'] = true;
        }
        notifyListeners();
        _syncAppBadge();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Mark all as read error: $e');
      return false;
    }
  }

  Future<bool> clearAll() async {
    try {
      final response = await _apiService.clearNotifications();

      if (response.success) {
        _notifications.clear();
        notifyListeners();
        _syncAppBadge();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Clear notifications error: $e');
      return false;
    }
  }

  Future<bool> deleteNotification(dynamic notificationId) async {
    final id = _idToString(notificationId);
    if (id.isEmpty) return false;

    try {
      final response = await _apiService.deleteNotification(id);

      if (response.success) {
        _notifications.removeWhere((n) => _idToString(n['id']) == id);
        notifyListeners();
        _syncAppBadge();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Delete notification error: $e');
      return false;
    }
  }

  // ============================================
  // LOCAL OPERATIONS
  // ============================================
  void addLocalNotification(Map<String, dynamic> notification) {
    final id = _idToString(notification['id']);
    final exists = _notifications.any((n) => _idToString(n['id']) == id);

    if (!exists) {
      _notifications.insert(0, notification);
      notifyListeners();
      _syncAppBadge();
    }
  }

  void addLocalNotifications(List<Map<String, dynamic>> list) {
    for (final n in list) {
      addLocalNotification(n);
    }
  }

  Map<String, dynamic>? getNotification(dynamic notificationId) {
    final id = _idToString(notificationId);
    try {
      return _notifications.firstWhere((n) => _idToString(n['id']) == id);
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>> getNotificationsByType(String type) {
    return _notifications.where((n) => n['type'] == type).toList();
  }

  // ============================================
  // UTILS
  // ============================================
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String getFormattedTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final parsed = DateTime.parse(timestamp);
      final diff = DateTime.now().difference(parsed);

      if (diff.inDays > 7) return '${diff.inDays}d ago';
      if (diff.inDays > 0) return '${diff.inDays}d ago';
      if (diff.inHours > 0) return '${diff.inHours}h ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
      return 'Just now';
    } catch (_) {
      return '';
    }
  }

  IconData getNotificationIcon(String type) {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'new_request':
        return Icons.request_page_outlined;
      case 'request_accepted':
        return Icons.check_circle_outline_rounded;
      case 'request_rejected':
        return Icons.cancel_outlined;
      case 'post_comment':
        return Icons.comment_outlined;
      case 'post_like':
        return Icons.favorite_border_rounded;
      case 'profile_update':
        return Icons.person_outline_rounded;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color getNotificationColor(String type) {
    switch (type) {
      case 'chat_message':
        return Colors.blue;
      case 'new_request':
        return Colors.orange;
      case 'request_accepted':
        return Colors.green;
      case 'request_rejected':
        return Colors.red;
      case 'post_comment':
        return Colors.purple;
      case 'post_like':
        return Colors.pink;
      case 'profile_update':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  @override
  void dispose() {
    _fcmSub?.cancel();
    _localNotifications.cancelAll();
    super.dispose();
  }
}