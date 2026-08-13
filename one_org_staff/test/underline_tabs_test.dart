import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/shared/underline_tabs.dart';

enum _Tab { profile, guardians, documents }

const _items = [
  UnderlineTabItem(
    value: _Tab.profile,
    label: 'Profile',
    icon: Icons.person_outline_rounded,
  ),
  UnderlineTabItem(
    value: _Tab.guardians,
    label: 'Guardians',
    icon: Icons.groups_outlined,
  ),
  UnderlineTabItem(
    value: _Tab.documents,
    label: 'Documents',
    icon: Icons.description_outlined,
  ),
];

Widget _wrap({
  _Tab selected = _Tab.profile,
  ValueChanged<_Tab>? onSelected,
  bool isDarkMode = false,
}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5E89)),
    ),
    home: Scaffold(
      body: UnderlineTabs<_Tab>(
        items: _items,
        selected: selected,
        isDarkMode: isDarkMode,
        onSelected: onSelected ?? (_) {},
      ),
    ),
  );
}

void main() {
  testWidgets('renders every tab', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Guardians'), findsOneWidget);
    expect(find.text('Documents'), findsOneWidget);
  });

  testWidgets('reports the tapped tab', (tester) async {
    _Tab? tapped;
    await tester.pumpWidget(_wrap(onSelected: (tab) => tapped = tab));

    await tester.tap(find.text('Documents'));
    await tester.pump();

    expect(tapped, _Tab.documents);
  });

  testWidgets('tints only the selected tab', (tester) async {
    await tester.pumpWidget(_wrap(selected: _Tab.guardians));

    Color colorOf(String label) =>
        tester.widget<Text>(find.text(label)).style!.color!;

    final accent = colorOf('Guardians');
    expect(colorOf('Profile'), isNot(accent));
    expect(colorOf('Documents'), isNot(accent));
  });

  testWidgets('fits a small phone without overflowing', (tester) async {
    // iPhone SE width — the tightest case for three icon+label tabs.
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    // A RenderFlex overflow would have been thrown by now.
    expect(tester.takeException(), isNull);
    expect(find.text('Documents'), findsOneWidget);
  });
}
