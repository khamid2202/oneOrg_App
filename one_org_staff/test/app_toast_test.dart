import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/shared/app_toast.dart';

void main() {
  Future<BuildContext> pumpHost(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return context;
  }

  testWidgets('each kind gets its own icon', (tester) async {
    final context = await pumpHost(tester);
    const icons = {
      ToastKind.success: Icons.check_rounded,
      ToastKind.info: Icons.info_rounded,
      ToastKind.warning: Icons.warning_rounded,
      ToastKind.error: Icons.error_rounded,
    };
    for (final entry in icons.entries) {
      showToast(context, 'Scores saved', kind: entry.key);
      await tester.pumpAndSettle();
      expect(find.text('Scores saved'), findsOneWidget);
      expect(find.byIcon(entry.value), findsOneWidget);
    }
  });

  testWidgets('a new toast replaces the old one, and ✕ closes it', (
    tester,
  ) async {
    final context = await pumpHost(tester);
    showToast(context, 'First');
    await tester.pumpAndSettle();
    showToast(context, 'Second', kind: ToastKind.success);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsNothing);
  });
}
