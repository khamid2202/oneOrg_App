import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../features/TimeTable/http_time_table_repository.dart';
import '../features/MyLessons/http_lesson_points_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/data/http_auth_repository.dart';
import '../features/auth/data/token_storage.dart';
import '../features/auth/presentation/auth_gate.dart';

class OneOrgStaffApp extends StatefulWidget {
  const OneOrgStaffApp({super.key, this.controller});

  final AuthController? controller;

  @override
  State<OneOrgStaffApp> createState() => _OneOrgStaffAppState();
}

class _OneOrgStaffAppState extends State<OneOrgStaffApp> {
  late final bool _ownsController;
  late final AuthController _controller;
  ThemeMode _themeMode = ThemeMode.light;
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
      );
    } else {
      _controller = widget.controller!;
    }

    _controller.restoreSession();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
      _client?.close();
    }
    super.dispose();
  }

  void _handleThemeModeChanged(ThemeMode themeMode) {
    if (_themeMode == themeMode) {
      return;
    }

    setState(() {
      _themeMode = themeMode;
    });
  }

  ThemeData _buildTheme(Brightness brightness) {
    const seedColor = Color(0xFF1F5E89);
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final isDarkMode = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: isDarkMode
          ? const Color(0xFF0E131A)
          : const Color(0xFFF3F6FB),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDarkMode ? const Color(0xFF19202A) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dombit School',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: _themeMode,
      home: AuthGate(
        controller: _controller,
        themeMode: _themeMode,
        onThemeModeChanged: _handleThemeModeChanged,
      ),
    );
  }
}
