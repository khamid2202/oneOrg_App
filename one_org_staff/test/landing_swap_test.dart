import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/app.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';

import 'widget_test.dart' show FakeAuthRepository, InMemoryTokenStorage;

/// Unique to the Rewards page — the dashboard's tile only says "Rewards".
const _previousPage = 'Tap students to select, then give or deduct points.';

/// Unique to the dashboard.
const _dashboard = 'Quick Access';

/// Where the page being left sits this frame, or null once it is off the tree.
///
/// While the swipe plays out it is translated to the right, on its way off
/// screen — that is the gesture working. Back at 0 it covers the screen again,
/// which is the state this test exists to rule out.
double? _outgoingOffset(WidgetTester tester) {
  final page = find.text(_previousPage);
  if (page.evaluate().isEmpty) {
    return null;
  }
  final transforms = tester.widgetList<Transform>(
    find.ancestor(of: page, matching: find.byType(Transform)),
  );
  var dx = 0.0;
  for (final transform in transforms) {
    dx += transform.transform.getTranslation().x;
  }
  return dx;
}

void main() {
  testWidgets('the page left behind never settles back over the dashboard', (
    tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rewards'));
    await tester.pumpAndSettle();
    expect(find.text(_previousPage), findsOneWidget);
    expect(find.text(_dashboard), findsNothing);

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final gesture = await tester.startGesture(const Offset(5, 300));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(width * 0.09, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();

    final frames = <String>[];
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      final offset = _outgoingOffset(tester);
      final home = find.text(_dashboard).evaluate().isNotEmpty;
      frames.add(
        offset == null
            ? (home ? 'home' : '-')
            : 'prev@${offset.round()}${home ? '+home' : ''}',
      );
    }

    expect(
      frames.last,
      'home',
      reason: 'never settled on the dashboard — frames: ${frames.join(' ')}',
    );

    // The defect: the page being left is painted at rest, full width, while
    // the dashboard is also up. The tabs draw no background of their own, so
    // one shows through the other and the old page appears to flash back.
    expect(
      frames.where((frame) => frame.startsWith('prev@0')),
      isEmpty,
      reason:
          'the previous page settled back over the dashboard — frames: '
          '${frames.join(' ')}',
    );
  });
}
