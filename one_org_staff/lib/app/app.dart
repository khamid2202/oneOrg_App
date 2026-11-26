import 'package:one_org_staff/features/me/data/http_my_repository.dart';
import 'package:one_org_staff/features/search/data/http_search_repository.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../features/MyClass/class_insights.dart';
import '../features/timetable/http_time_table_repository.dart';
import '../features/MyLessons/http_lesson_points_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/http_auth_repository.dart';
import '../features/auth/data/passkey_service.dart';
import '../features/auth/data/token_storage.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/branches/application/branch_controller.dart';
import '../features/branches/data/branch_http_client.dart';
import '../features/branches/data/http_branches_repository.dart';
import '../features/colleagues/data/http_colleagues_repository.dart';
import '../features/exams/data/http_exams_repository.dart';
import '../features/notifications/application/notifications_controller.dart';
import '../features/notifications/application/push_service.dart';
import '../features/notifications/data/http_notifications_repository.dart';
import '../features/lessons/application/lessons_outbox.dart';
import '../features/lessons/data/http_lessons_repository.dart';
import '../features/lessons/data/offline_cache.dart';
import '../features/point_report/data/http_point_report_repository.dart';
import '../features/tour/product_tour.dart';
import '../l10n/generated/app_localizations.dart';
import '../shared/api_client.dart';
import 'language_controller.dart';
import 'theme.dart';
import 'theme_controller.dart';

class OneOrgStaffApp extends StatefulWidget {
  const OneOrgStaffApp({super.key, this.controller, this.themeController});

  final AuthController? controller;

  /// Injected by tests so they can start from a known appearance without
  /// touching the platform's preference store.
  final ThemeController? themeController;

  @override
  State<OneOrgStaffApp> createState() => _OneOrgStaffAppState();
}

class _OneOrgStaffAppState extends State<OneOrgStaffApp> {
  late final bool _ownsController;
  late final AuthController _controller;
  late final bool _ownsThemeController;
  late final ThemeController _themeController;
  final LanguageController _languageController = LanguageController();
  final _tourStore = ProductTourStore();
  LessonsOutbox? _outbox;
  AppLifecycleListener? _lifecycle;
  http.Client? _client;

  /// Present only when this widget built the auth controller. A test that
  /// injects its own controller has no repositories to hang notifications off,
  /// so the shell renders without an inbox rather than with a broken one.
  NotificationsController? _notificationsController;
  PushService? _pushService;
  BranchController? _branchController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;

    if (_ownsController) {
      _client = BranchHttpClient(
        http.Client(),
        branchId: () => _branchController?.activeBranchId,
        onBranchRejected: () => _branchController?.handleBranchRejected(),
      );
      final tokenStorage = SecureTokenStorage();
      final offlineCache = OfflineCache();
      final lessons = HttpLessonsRepository(
        client: _client!,
        baseUrl: ApiConfig.baseUrl,
        readToken: tokenStorage.readToken,
        branchId: () => _branchController?.activeBranchId,
        cache: offlineCache,
      );
      _outbox = LessonsOutbox(upload: lessons.upload);
      _controller = AuthController(
        authRepository: HttpAuthRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
          cache: offlineCache,
        ),
        tokenStorage: tokenStorage,
        passkeys: PasskeyService(client: _client!, baseUrl: ApiConfig.baseUrl),
        timetableRepository: HttpTimetableRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        pointsRepository: HttpLessonPointsRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        colleaguesRepository: HttpColleaguesRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
          cache: offlineCache,
          branchId: () => _branchController?.activeBranchId,
        ),
        pointReportRepository: HttpPointReportRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        examsRepository: HttpExamsRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        notificationsRepository: HttpNotificationsRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        branchesRepository: HttpBranchesRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        lessons: lessons,
        outbox: _outbox,
        me: HttpMyRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
          readToken: tokenStorage.readToken,
          cache: offlineCache,
          branchId: () => _branchController?.activeBranchId,
        ),
        classInsights: HttpClassInsightsRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
          readToken: tokenStorage.readToken,
          cache: offlineCache,
          branchId: () => _branchController?.activeBranchId,
        ),
        search: HttpSearchRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
          readToken: tokenStorage.readToken,
        ),
        api: ApiClient(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
          readToken: tokenStorage.readToken,
        ),
      );
      _branchController = BranchController(
        loadBranches: _controller.loadMyBranches,
      );

      _setUpNotifications();
    } else {
      _controller = widget.controller!;
    }

    _controller.restoreSession();
    _outbox?.load();
    // Back in the app: saves waiting on the phone get another chance now.
    _lifecycle = AppLifecycleListener(onResume: () => _outbox?.retryAll());

    _ownsThemeController = widget.themeController == null;
    _themeController = widget.themeController ?? ThemeController();
    if (_ownsThemeController) {
      // Fire-and-forget: the defaults render immediately and the stored
      // preferences swap in a frame later, which beats holding a blank screen.
      _themeController.load();
    }
    _languageController.load();
  }

  /// Builds the inbox controller and the push service, and ties them to each
  /// other and to the session.
  void _setUpNotifications() {
    final notifications = NotificationsController(
      loadNotifications: _controller.loadNotifications,
      loadUnreadCount: _controller.loadUnreadNotificationCount,
      markRead: _controller.markNotificationRead,
      markAllRead: _controller.markAllNotificationsRead,
    );

    final push = PushService(
      registerDeviceToken: _controller.registerDeviceToken,
      unregisterDeviceToken: _controller.unregisterDeviceToken,
    );

    // A push landing while the app is open should move the badge now, not on
    // the next 60-second poll.
    push.onForegroundMessage = notifications.refreshUnreadCount;

    // The device token has to go before the session token does, or the DELETE
    // has nothing to authenticate with.
    _controller.onBeforeSignOut = push.unregisterDeviceToken;

    _notificationsController = notifications;
    _pushService = push;

    // Fire-and-forget: a missing Firebase config resolves to
    // `PushPermission.unavailable` inside the service rather than throwing,
    // and the REST inbox does not wait on any of it.
    unawaited(push.initialize());
  }

  @override
  void dispose() {
    _notificationsController?.dispose();
    _pushService?.dispose();
    _lifecycle?.dispose();
    _outbox?.dispose();
    _branchController?.dispose();
    _languageController.dispose();
    if (_ownsController) {
      _controller.dispose();
      _client?.close();
    }
    if (_ownsThemeController) {
      _themeController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuilds on every appearance change, so picking an accent or a dark
    // flavor recolours the running app immediately.
    return AnimatedBuilder(
      animation: Listenable.merge([_themeController, _languageController]),
      builder: (context, _) {
        return MaterialApp(
          title: 'Dombit School',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(
            accent: _themeController.accent,
            brightness: Brightness.light,
            darkVariant: _themeController.darkVariant,
          ),
          darkTheme: buildAppTheme(
            accent: _themeController.accent,
            brightness: Brightness.dark,
            darkVariant: _themeController.darkVariant,
          ),
          themeMode: _themeController.themeMode,
          locale: _languageController.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthGate(
            controller: _controller,
            themeController: _themeController,
            languageController: _languageController,
            notificationsController: _notificationsController,
            pushService: _pushService,
            branchController: _branchController,
            tourStore: _ownsController ? _tourStore : null,
          ),
        );
      },
    );
  }
}
