import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/app.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';

import 'widget_test.dart' show FakeAuthRepository, InMemoryTokenStorage;

/// The header falls back to this while it has no profile. Seeing it again on
/// the way back to the dashboard is the blink this test guards against.
const _placeholderName = 'Staff Member';
const _realName = 'OneOrg Staff User';

void main() {
  testWidgets('swiping back to the dashboard does not blink the header', (
    tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();
    expect(find.text(_realName), findsOneWidget);

    // Into a page that has no navbar button, so leaving it is a swipe back to
    // the dashboard — the step that misbehaved.
    await tester.tap(find.text('Point report'));
    await tester.pumpAndSettle();
    expect(find.text(_realName), findsNothing);

    final frames = <String>[];
    void recordFrame() {
      final placeholder = find.text(_placeholderName).evaluate().isNotEmpty;
      final real = find.text(_realName).evaluate().isNotEmpty;
      // '-' is the dashboard not being on screen yet, which is fine; only the
      // placeholder standing in for a name we already have is a defect.
      frames.add(placeholder ? 'PLACEHOLDER' : (real ? 'name' : '-'));
    }

    // Recorded across the whole gesture: the dashboard mounts twice on the way
    // back — once as the page revealed under the drag, once as the page the
    // shell swaps in — and each mount is a chance to blink.
    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final gesture = await tester.startGesture(const Offset(5, 300));
    await tester.pump();
    recordFrame();
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(Offset(width * 0.09, 0));
      await tester.pump(const Duration(milliseconds: 16));
      recordFrame();
    }
    await gesture.up();

    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      recordFrame();
    }

    expect(frames.last, 'name');
    expect(
      frames.where((f) => f == 'PLACEHOLDER'),
      isEmpty,
      reason:
          'the header fell back to its placeholder mid-navigation — frames: '
          '${frames.join(' ')}',
    );
  });
}
