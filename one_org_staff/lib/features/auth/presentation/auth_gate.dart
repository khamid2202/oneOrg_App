import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/theme_controller.dart';
import '../../landing/presentation/landing_page.dart';
import '../application/auth_controller.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AuthController controller;
  final ThemeController themeController;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        switch (controller.status) {
          case AuthStatus.checking:
            return const _StartupLoader();
          case AuthStatus.authenticated:
            return LandingPage(
              controller: controller,
              themeController: themeController,
            );
          case AuthStatus.unauthenticated:
            return LoginPage(controller: controller);
        }
      },
    );
  }
}

class _StartupLoader extends StatelessWidget {
  const _StartupLoader();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                appColorsOf(context).accent.solid.withValues(alpha: 0.10),
                Theme.of(context).scaffoldBackgroundColor,
              ),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              SizedBox(height: 16),
              Text('Checking your session...'),
            ],
          ),
        ),
      ),
    );
  }
}
