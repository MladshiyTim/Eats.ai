import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api_client.dart';

/// Background FCM handler. Notification messages are rendered by the system
/// tray automatically while the app is backgrounded/killed, so this is a no-op.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Manages Firebase Cloud Messaging: permission, the Android notification
/// channel, device-token registration with the backend, and showing pushes
/// while the app is in the foreground.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  final FlutterLocalNotificationsPlugin _fln = FlutterLocalNotificationsPlugin();

  // Must match the channel_id the backend sets in fcm_service.py.
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'eats_ai_reminders',
    'Eslatmalar',
    description: 'Suv va ovqat eslatmalari',
    importance: Importance.high,
  );

  bool _inited = false;

  /// Call once the user is authenticated (token registration needs the JWT).
  Future<void> init() async {
    if (_inited) return;
    _inited = true;

    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      await _fln.initialize(const InitializationSettings(android: androidInit));
      await _fln
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await FirebaseMessaging.instance.requestPermission();

      FirebaseMessaging.onMessage.listen(_showForeground);

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registerToken(token);
      FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);
    } catch (_) {
      // Never let push setup crash the app.
    }
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _fln.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  Future<void> _registerToken(String token) async {
    try {
      await ApiClient.instance.post('/devices/register/', {
        'token': token,
        'platform': 'android',
      });
    } catch (_) {
      // Ignore — retried on next token refresh / app start.
    }
  }
}
