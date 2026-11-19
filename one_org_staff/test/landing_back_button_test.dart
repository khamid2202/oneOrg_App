import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/app.dart';
import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';

import 'widget_test.dart' show FakeAuthRepository, InMemoryTokenStorage;

const _greeting = 'Hi, OneOrg';

/// Android's system back button, as the engine delivers it.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Android back steps back through pages instead of closing', (
    tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );
    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text(_greeting), findsOneWidget);

    // Home → Point Report (tile) → Profile (bottom bar).
    await tester.tap(find.text('Point Report'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    // Back to Point Report, not out of the app.
    await _pressBack(tester);
    expect(find.text('Account'), findsNothing);
    expect(find.text(_greeting), findsNothing);

    // Back again lands on Home.
    await _pressBack(tester);
    expect(find.text(_greeting), findsOneWidget);
  });

  testWidgets('a Profile sub-screen closes first, then the tab history', (
    tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );
    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await _pressBack(tester);
    expect(find.text('Account'), findsOneWidget);

    await _pressBack(tester);
    expect(find.text(_greeting), findsOneWidget);
  });
}
