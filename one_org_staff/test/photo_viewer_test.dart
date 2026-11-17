import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/shared/photo_viewer.dart';

void main() {
  Widget row({required String? url, required VoidCallback onRowTap}) {
    return MaterialApp(
      home: Scaffold(
        body: InkWell(
          key: const ValueKey('row'),
          onTap: onRowTap,
          child: Row(
            children: [
              ZoomableAvatar(
                url: url,
                name: 'Ali Valiyev',
                child: const SizedBox(
                  key: ValueKey('avatar'),
                  width: 36,
                  height: 36,
                ),
              ),
              const Expanded(child: Text('Ali Valiyev')),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('tapping the photo enlarges it without opening the row', (
    tester,
  ) async {
    var rowTaps = 0;
    await tester.pumpWidget(
      row(url: 'https://cdn.example.com/a.jpg', onRowTap: () => rowTaps++),
    );

    await tester.tap(find.byKey(const ValueKey('avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(rowTaps, 0);

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);

    // The rest of the row still opens it.
    await tester.tap(find.text('Ali Valiyev'));
    expect(rowTaps, 1);
  });

  testWidgets('without a photo the tap goes to the row', (tester) async {
    var rowTaps = 0;
    await tester.pumpWidget(row(url: null, onRowTap: () => rowTaps++));

    await tester.tap(find.byKey(const ValueKey('avatar')));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsNothing);
    expect(rowTaps, 1);
  });
}
