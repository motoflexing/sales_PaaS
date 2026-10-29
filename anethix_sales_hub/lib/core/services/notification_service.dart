import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_names.dart';

/// Handles a push that arrives while the app is terminated or backgrounded.
///
/// This must be a top-level function: Firebase spins up a separate isolate to
/// run it, so it cannot capture anything from the app's state. There is nothing
/// to do here beyond letting the message through — the navigation happens in
/// [NotificationService] when the user actually taps the notification.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

/// Firebase Cloud Messaging: permissions, foreground banners, and deep links
/// from a notification tap.
///
/// Payload contract — the sender sets `data.type` and, where relevant, an id:
///
/// ```json
/// { "type": "live_lead" }
/// { "type": "lead",       "leadId":     "<lead id>" }
/// { "type": "follow_up" }
/// { "type": "attendance" }
/// { "type": "leaderboard" }
/// ```
class NotificationService {
  NotificationService({
    required GlobalKey<NavigatorState> navigatorKey,
    required GlobalKey<ScaffoldMessengerState> messengerKey,
    FirebaseMessaging? messaging,
  })  :
        // Dart has no private named parameters, so an initializing formal is
        // not available for these two fields.
        // ignore: prefer_initializing_formals
        _navigatorKey = navigatorKey,
        // ignore: prefer_initializing_formals
        _messengerKey = messengerKey,
        _messaging = messaging ?? FirebaseMessaging.instance;

  final GlobalKey<NavigatorState> _navigatorKey;
  final GlobalKey<ScaffoldMessengerState> _messengerKey;
  final FirebaseMessaging _messaging;

  final List<StreamSubscription<dynamic>> _subscriptions = [];

  /// Asks for notification permission and wires up the three delivery paths:
  /// foreground, background-tap, and the tap that cold-started the app.
  Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      // iOS otherwise suppresses the system banner while the app is in front.
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      _subscriptions.add(FirebaseMessaging.onMessage.listen(_showInApp));
      _subscriptions
          .add(FirebaseMessaging.onMessageOpenedApp.listen(_navigateTo));

      // A notification that launched the app from terminated is delivered once,
      // here, rather than through onMessageOpenedApp.
      final initial = await _messaging.getInitialMessage();
      if (initial != null) {
        // Defer past the first frame so the router exists to navigate with.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _navigateTo(initial);
        });
      }
    } on Object catch (error) {
      // Push is an enhancement: a device that denies permission, or a build
      // without the platform config, must still run the app.
      debugPrint('FCM setup skipped: $error');
    }
  }

  /// The device token, for registering this install against a user server-side.
  Future<String?> token() async {
    try {
      return await _messaging.getToken();
    } on Object {
      return null;
    }
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// A push that lands while the app is in the foreground shows no system
  /// banner on Android, so it is surfaced as a SnackBar with an action that
  /// opens the same screen a tap would have.
  void _showInApp(RemoteMessage message) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;

    final notification = message.notification;
    final title = notification?.title?.trim();
    final body = notification?.body?.trim();
    final text = [
      if (title != null && title.isNotEmpty) title,
      if (body != null && body.isNotEmpty) body,
    ].join(' - ');
    if (text.isEmpty) return;

    final destination = _routeFor(message);

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(text),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        action: destination == null
            ? null
            : SnackBarAction(
                label: 'View',
                onPressed: () => _navigateTo(message),
              ),
      ),
    );
  }

  void _navigateTo(RemoteMessage message) {
    final route = _routeFor(message);
    if (route == null) return;

    final context = _navigatorKey.currentContext;
    if (context == null) return;

    // GoRouter is reached through the navigator's context so this service does
    // not need a Riverpod handle of its own.
    context.go(route);
  }

  /// Maps a payload to an in-app route. Returns null for a payload with no
  /// destination, which leaves the notification informational.
  static String? _routeFor(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] as String?;
    final leadId = data['leadId'] as String?;

    return switch (type) {
      'live_lead' => Routes.employeeLiveLeads,
      'lead' when leadId != null && leadId.isNotEmpty =>
        '${Routes.employeeMyLeads}/$leadId',
      'lead' => Routes.employeeMyLeads,
      'follow_up' => Routes.employeeFollowUps,
      'attendance' => Routes.employeeAttendance,
      'leaderboard' => Routes.employeeLeaderboard,
      _ => null,
    };
  }
}
