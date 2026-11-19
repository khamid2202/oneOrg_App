import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../app/language_controller.dart';
import '../../../app/theme_controller.dart';
import '../../branches/application/branch_controller.dart';
import '../../branches/presentation/branch_gate.dart';
import '../../landing/presentation/landing_page.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../notifications/application/push_service.dart';
import '../../tour/product_tour.dart';
import '../application/auth_controller.dart';
import 'login_page.dart';
import 'passkey_offer_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.controller,
    required this.themeController,
    this.languageController,
    this.notificationsController,
    this.pushService,
    this.branchController,
    this.tourStore,
  });

  final AuthController controller;
  final ThemeController themeController;
  final LanguageController? languageController;

  /// Null when the shell was handed a pre-built [AuthController] — a test
  /// harness — in which case the dashboard simply has no bell.
  final NotificationsController? notificationsController;
  final PushService? pushService;

  /// Null in a test harness, which then runs without selecting a branch.
  final BranchController? branchController;

  /// Null in a test harness, so the product tour never starts on its own.
  final ProductTourStore? tourStore;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        switch (controller.status) {
          case AuthStatus.checking:
            return const _StartupLoader();
          case AuthStatus.authenticated:
            if (controller.offerPasskey) {
              return PasskeyOfferPage(controller: controller);
            }
            final landing = LandingPage(
              controller: controller,
              themeController: themeController,
              languageController: languageController,
              notificationsController: notificationsController,
              pushService: pushService,
              branchController: branchController,
              tourStore: tourStore,
            );
            final branches = branchController;
            return branches == null
                ? landing
                : BranchGate(
                    controller: branches,
                    onSignOut: controller.signOut,
                    child: landing,
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
