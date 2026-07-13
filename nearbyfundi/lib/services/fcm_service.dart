import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class FcmService {
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    await _fcm.requestPermission();
    const AndroidInitializationSettings android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings();
    const InitializationSettings settings = InitializationSettings(android: android, iOS: ios);
    await _notifications.initialize(settings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showNotification(message);
    });
  }

  static void _showNotification(RemoteMessage message) {
    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'fundi_channel', 'NearbyFundi',
      importance: Importance.high, priority: Priority.high,
    );
    const NotificationDetails platform = NotificationDetails(android: android);
    _notifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      platform,
    );
  }

  static Future<String?> getToken() async => await _fcm.getToken();
}