import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../features/timetable/http_time_table_repository.dart';
import '../features/MyLessons/http_lesson_points_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/http_auth_repository.dart';
import '../features/auth/data/token_storage.dart';
import '../features/auth/presentation/auth_gate.dart';
import '../features/colleagues/data/http_colleagues_repository.dart';
import '../features/point_report/data/http_point_report_repository.dart';
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
  http.Client? _client;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;

    if (_ownsController) {
      _client = http.Client();
      _controller = AuthController(
        authRepository: HttpAuthRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
        tokenStorage: SecureTokenStorage(),
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
        ),
        pointReportRepository: HttpPointReportRepository(
          client: _client!,
          baseUrl: ApiConfig.baseUrl,
        ),
      );
    } else {
      _controller = widget.controller!;
    }

    _controller.restoreSession();

    _ownsThemeController = widget.themeController == null;
    _themeController = widget.themeController ?? ThemeController();
    if (_ownsThemeController) {
      // Fire-and-forget: the defaults render immediately and the stored
      // preferences swap in a frame later, which beats holding a blank screen.
      _themeController.load();
    }
  }

  @override
  void dispose() {
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
      animation: _themeController,
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
          home: AuthGate(
            controller: _controller,
            themeController: _themeController,
          ),
        );
      },
    );
  }
}
