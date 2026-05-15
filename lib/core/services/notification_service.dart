/// @file notification_service.dart
/// @description Firebase Cloud Messaging integration for ARR DMRV mobile app.
///   Handles push notifications for:
///     - L1 approval decisions (field_executive receives result of their submission)
///     - L2 approval decisions (l1_supervisor receives escalation decisions)
///     - Programme-level alerts (sync failures, satellite anomalies)
///
/// Initialisation: call NotificationService.init() from main() after
///   WidgetsFlutterBinding.ensureInitialized() and Firebase.initializeApp().
///
/// Permissions: Android 13+ requires POST_NOTIFICATIONS permission;
///   handled by PermissionService.requestAppPermissions().
///
/// Uses: firebase_messaging, flutter_local_notifications
library;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Background message handler (top-level, required by FCM) ─────────────────

/// Must be a top-level function — FCM requirement for background isolate.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  // No UI interaction possible here — data is stored via shared_preferences
  // or processed when app comes to foreground.
}

// ─── Local notifications channel setup ───────────────────────────────────────

const _androidChannel = AndroidNotificationChannel(
  'arr_approvals',                         // channel id
  'ARR Approvals',                         // channel name
  description: 'L1/L2 tree measurement approval decisions and programme alerts',
  importance: Importance.high,
  playSound: true,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

// ─── Riverpod provider ────────────────────────────────────────────────────────

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService._internal();
});

// ─── Service ─────────────────────────────────────────────────────────────────

class NotificationService {
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  String? _fcmToken;

  /// Returns the device FCM token (null if not yet resolved or permission denied).
  String? get fcmToken => _fcmToken;

  /// Initialise FCM and local notifications.
  /// Call once from main() after Firebase.initializeApp().
  static Future<void> init() async {
    // Register background handler (must be top-level fn)
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundMessageHandler);

    // Android local notification channel
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // Initialise local notifications plugin
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS:     DarwinInitializationSettings(
        requestAlertPermission: false,   // handled by FCM requestPermission below
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Request FCM permission (iOS prompt; Android 13+ handled by PermissionService)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert:  true,
      badge:  true,
      sound:  true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      // Foreground message display on iOS
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Listen to foreground messages — show as local notification on Android
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // App opened from a terminated state via a notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) _handleMessageOpen(initial);

    // App brought to foreground via notification
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpen);

    debugPrint('[FCM] NotificationService initialised. Status: ${settings.authorizationStatus}');
  }

  /// Fetch the current FCM device token.
  /// Should be called after successful login to register the token with the API.
  Future<String?> getToken() async {
    _fcmToken = await _fcm.getToken();
    debugPrint('[FCM] Device token: $_fcmToken');
    return _fcmToken;
  }

  /// Subscribe to a topic (e.g. `programme_<id>` for programme-level alerts).
  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
    debugPrint('[FCM] Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic.
  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
    debugPrint('[FCM] Unsubscribed from topic: $topic');
  }

  // ─── Private handlers ───────────────────────────────────────────────────────

  /// Show a local notification when a push arrives while the app is in foreground.
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('[FCM] Foreground message: ${message.messageId}');
    final notification = message.notification;
    if (notification == null) return;

    await _localNotifications.show(
      message.hashCode,
      notification.title ?? 'ARR DMRV',
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority:   Priority.high,
          icon:       '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['type'] ?? '',
    );
  }

  /// Navigate or refresh on notification tap (app open / foregrounded).
  static void _handleMessageOpen(RemoteMessage message) {
    debugPrint('[FCM] Notification opened: ${message.data}');
    // Navigation is handled at the app level via a GlobalKey<NavigatorState>
    // or a riverpod-driven route redirect based on notification payload.
    // For now, payload type is logged; future implementation routes to the
    // relevant approval detail screen.
    final type = message.data['type'] as String? ?? '';
    debugPrint('[FCM] Notification type: $type');
  }

  /// Handle tap on a locally displayed notification.
  static void _onLocalNotificationTap(NotificationResponse response) {
    debugPrint('[FCM] Local notification tapped: ${response.payload}');
  }
}

// ─── Notification payload types (contract with backend) ─────────────────────

/// Payload `type` values sent by the API in FCM data payloads.
/// Match against `message.data['type']` in open handlers.
abstract final class NotificationTypes {
  /// L1 supervisor approved a field submission.
  static const String l1Approved = 'L1_APPROVED';

  /// L1 supervisor rejected a field submission.
  static const String l1Rejected = 'L1_REJECTED';

  /// L2 reviewer approved an L1-escalated submission.
  static const String l2Approved = 'L2_APPROVED';

  /// L2 reviewer rejected an L1-escalated submission.
  static const String l2Rejected = 'L2_REJECTED';

  /// Satellite NDVI anomaly detected in a programme stratum.
  static const String satelliteAnomaly = 'SATELLITE_ANOMALY';

  /// Sync queue has items that failed to upload after 3 retries.
  static const String syncFailed = 'SYNC_FAILED';
}
