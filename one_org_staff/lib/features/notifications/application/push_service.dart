import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handles a push that arrives while the app is not running.
///
/// Runs on its own isolate with no access to anything the app has in memory,
/// which is why it re-initializes Firebase and the local-notification plugin
/// from scratch and must be a top-level function.
///
/// A message carrying a `notification` block is drawn by Android and iOS
/// themselves before Dart is ever consulted, so this returns immediately for
/// those — drawing another would show the user two of everything. It exists
/// for **data-only** messages, which the OS does not render at all: without
/// this they arrive silently and the user sees nothing until they next open
/// the app.
@pragma('vm:entry-point')
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  if (message.notification != null) return;

  final title = message.data['title'];
  final body = message.data['body'];
  if (title is! String && body is! String) return;

  try {
    await Firebase.initializeApp();

    final local = FlutterLocalNotificationsPlugin();
    await local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );

    // The channel is created by the running app too, but this isolate cannot
    // assume the app has ever been opened since install. Creating an existing
    // channel is a no-op.
    if (!kIsWeb && Platform.isAndroid) {
      await local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(PushService._androidChannel);
    }

    await local.show(
      id: message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch,
      title: title is String ? title : null,
      body: body is String ? body : null,
      notificationDetails: PushService._androidDetails,
    );
  } catch (error) {
    // Nothing may escape a background isolate — an uncaught error here is a
    // crash the user sees with no app on screen to explain it.
    debugPrint('Background push could not be shown: $error');
  }
}

/// Where the device stands on receiving push notifications.
enum PushPermission {
  /// Firebase never came up — no `google-services.json` /
  /// `GoogleService-Info.plist` in the build. The inbox still works; only push
  /// delivery is off.
  unavailable,

  /// The OS has never been asked. This is the only state where asking shows a
  /// system dialog — on iOS it is a one-shot, which is why the app puts its
  /// own explainer in front of it.
  notDetermined,

  granted,

  /// The user said no, in this app or in system settings. Asking again does
  /// nothing: only the OS settings screen can flip this back.
  denied,
}

/// Owns everything push: bringing Firebase up, asking for permission, keeping
/// this device's FCM token registered against the signed-in user, and drawing
/// a banner for messages that arrive while the app is in the foreground.
///
/// Every step is optional by design. If Firebase config is missing the service
/// degrades to [PushPermission.unavailable] and the rest of the app — the
/// notification inbox, which is plain REST — carries on unaffected.
class PushService extends ChangeNotifier {
  PushService({
    required Future<void> Function({
      required String deviceToken,
      required String platform,
    })
    registerDeviceToken,
    required Future<void> Function(String deviceToken) unregisterDeviceToken,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _registerDeviceToken = registerDeviceToken,
       _unregisterDeviceToken = unregisterDeviceToken,
       _local = localNotifications ?? FlutterLocalNotificationsPlugin();

  final Future<void> Function({
    required String deviceToken,
    required String platform,
  })
  _registerDeviceToken;
  final Future<void> Function(String deviceToken) _unregisterDeviceToken;
  final FlutterLocalNotificationsPlugin _local;

  /// Android needs a channel declared up front or notifications land silently.
  /// The id is duplicated in `AndroidManifest.xml` as
  /// `default_notification_channel_id` so background pushes — which the system
  /// draws without asking Dart — use this channel too.
  static const _androidChannel = AndroidNotificationChannel(
    'one_org_staff_high_importance',
    'School notifications',
    description: 'Announcements, points and payment alerts from the school.',
    importance: Importance.high,
  );

  /// Shared by the foreground path and [handleBackgroundMessage], so a push
  /// looks the same however it was drawn.
  static final _androidDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      _androidChannel.id,
      _androidChannel.name,
      channelDescription: _androidChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    ),
  );

  static const _promptSeenKey = 'one_org_staff.notifications.prompt_seen';

  PushPermission _permission = PushPermission.unavailable;
  PushPermission get permission => _permission;

  bool get isGranted => _permission == PushPermission.granted;

  /// True once the in-app explainer has been shown, so a teacher who declined
  /// is not re-asked on every launch. Enabling later goes through Profile.
  bool _promptSeen = false;
  bool get promptSeen => _promptSeen;

  Future<void>? _initialization;

  /// Completes when [initialize] has settled, however it settled. The shell
  /// waits on this before asking for permission — the ask has to know whether
  /// the OS already holds an answer, and firing it against a half-initialized
  /// service would spend the once-per-install prompt on a service that was
  /// about to report `unavailable` anyway.
  Future<void> get ready => _initialization ?? Future<void>.value();

  String? _deviceToken;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openedSub;

  /// Fired when a push is tapped, so the shell can open the inbox.
  VoidCallback? onNotificationOpened;

  /// Set alongside [onNotificationOpened]. A push that cold-starts the app is
  /// handled before any screen exists to listen, so the request is parked here
  /// for the shell to collect once it mounts.
  bool _openInboxRequested = false;

  bool consumeOpenInboxRequest() {
    final requested = _openInboxRequested;
    _openInboxRequested = false;
    return requested;
  }

  void _requestOpenInbox() {
    _openInboxRequested = true;
    onNotificationOpened?.call();
  }

  /// Fired when a push arrives while the app is open, so the badge can
  /// refresh without waiting for the next poll.
  VoidCallback? onForegroundMessage;

  /// Brings up Firebase and the local-notification plugin. Safe to call more
  /// than once, and safe to call with no Firebase config at all — a failure
  /// here leaves [permission] at [PushPermission.unavailable] instead of
  /// throwing into app startup.
  Future<void> initialize() => _initialization ??= _initialize();

  Future<void> _initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _promptSeen = prefs.getBool(_promptSeenKey) ?? false;
    } catch (_) {
      // Nothing here may throw: [ready] is awaited by the shell before it
      // asks for permission, and a rejected future there would take the
      // dashboard's first frame with it.
    }

    try {
      await Firebase.initializeApp();
      await _initializeLocalNotifications();

      // Registering stores a callback handle the OS uses to spin up a Dart
      // isolate for a push that lands with the app closed. It has to be set
      // on a normal run for a later background delivery to find it.
      FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);

      // iOS draws foreground pushes itself once these are on; Android never
      // does, which is what [_handleForeground] is for.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );

      _foregroundSub = FirebaseMessaging.onMessage.listen(_handleForeground);
      _openedSub = FirebaseMessaging.onMessageOpenedApp.listen(
        (_) => _requestOpenInbox(),
      );

      // A push that cold-started the app is not delivered through the stream
      // above, so it has to be collected separately.
      final launchMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (launchMessage != null) {
        _requestOpenInbox();
      }
    } catch (error) {
      // Usually no google-services.json / GoogleService-Info.plist in this
      // build. Push is off; the REST inbox is untouched.
      debugPrint('Push disabled — Firebase did not initialize: $error');
      _permission = PushPermission.unavailable;
      notifyListeners();
      return;
    }

    await refreshPermission();
    notifyListeners();
  }

  Future<void> _initializeLocalNotifications() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/launcher_icon'),
        // The Darwin permission prompt is driven explicitly through
        // [requestPermission] so the app's own explainer comes first; asking
        // here would fire the system dialog the moment the app launches.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _requestOpenInbox(),
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);
    }
  }

  /// Reads the current OS-level setting without prompting.
  Future<void> refreshPermission() async {
    if (Firebase.apps.isEmpty) {
      _permission = PushPermission.unavailable;
      notifyListeners();
      return;
    }

    try {
      final settings = await FirebaseMessaging.instance
          .getNotificationSettings();
      _permission = _mapStatus(settings.authorizationStatus);
    } catch (_) {
      _permission = PushPermission.unavailable;
    }

    if (_permission == PushPermission.granted) {
      // Registration is idempotent server-side, so re-syncing on every launch
      // keeps a rotated token from silently going stale.
      unawaited(syncDeviceToken());
    }
    notifyListeners();
  }

  /// Shows the OS permission dialog and, on a yes, registers this device.
  ///
  /// Returns true when push is live afterwards. Records that the ask happened
  /// either way, so the in-app explainer is a once-per-install thing.
  Future<bool> requestPermission() async {
    await markPromptSeen();

    if (Firebase.apps.isEmpty) {
      return false;
    }

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      _permission = _mapStatus(settings.authorizationStatus);
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      _permission = PushPermission.unavailable;
    }

    notifyListeners();

    if (_permission != PushPermission.granted) {
      return false;
    }

    await syncDeviceToken();
    return true;
  }

  /// Pushes this device's FCM token to `POST /notifications/device-token` and
  /// keeps watching for rotations.
  Future<void> syncDeviceToken() async {
    if (_permission != PushPermission.granted) return;

    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _sendToken(token);
    } catch (error) {
      // A device that fails to register still gets its in-app inbox; nothing
      // here is worth interrupting the user over.
      debugPrint('Device token registration failed: $error');
    }

    _tokenRefreshSub ??= FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      unawaited(_sendToken(token).catchError((_) {}));
    });
  }

  Future<void> _sendToken(String token) async {
    await _registerDeviceToken(deviceToken: token, platform: _platformName);
    _deviceToken = token;
  }

  /// Drops this device's registration. Called on the way out of a session —
  /// the next person to sign in on this phone must not inherit the last
  /// user's pushes.
  Future<void> unregisterDeviceToken() async {
    final token = _deviceToken;
    if (token == null || token.isEmpty) return;

    try {
      await _unregisterDeviceToken(token);
    } finally {
      _deviceToken = null;
    }
  }

  /// Forces the permission state. Tests use this to reach the branches that
  /// otherwise need a real Firebase app and a real OS answer behind them.
  @visibleForTesting
  void debugSetPermission(PushPermission value) {
    _permission = value;
    notifyListeners();
  }

  Future<void> markPromptSeen() async {
    if (_promptSeen) return;
    _promptSeen = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_promptSeenKey, true);
    } catch (_) {
      // Worst case the explainer reappears on the next launch — not worth
      // throwing out of a UI callback over.
    }
  }

  /// Android shows nothing for a push that lands while the app is open, so it
  /// gets a local notification built from the same payload. iOS already drew
  /// one via the foreground presentation options above.
  Future<void> _handleForeground(RemoteMessage message) async {
    onForegroundMessage?.call();

    if (kIsWeb || !Platform.isAndroid) return;

    final notification = message.notification;
    if (notification == null) return;

    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: _androidDetails,
    );
  }

  static PushPermission _mapStatus(AuthorizationStatus status) {
    switch (status) {
      case AuthorizationStatus.authorized:
      case AuthorizationStatus.provisional:
        return PushPermission.granted;
      case AuthorizationStatus.denied:
        return PushPermission.denied;
      case AuthorizationStatus.notDetermined:
        return PushPermission.notDetermined;
    }
  }

  /// What the API records alongside the token. `docs/staff/notifications.md`
  /// shows `web`; this app is only ever one of the two mobile platforms.
  static String get _platformName {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    return Platform.operatingSystem;
  }

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    _foregroundSub?.cancel();
    _openedSub?.cancel();
    super.dispose();
  }
}
