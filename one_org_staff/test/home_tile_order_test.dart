import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/landing/application/home_tile_order.dart';
import 'package:one_org_staff/features/landing/domain/app_items.dart';
import 'package:one_org_staff/features/landing/presentation/teacher_home.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _teacher = AppUserProfile(
  id: 1,
  fullName: 'Ali Valiyev',
  subtitle: '',
  email: '',
  phone: '',
  department: '',
  joinedDate: '',
  roles: ['teacher'],
);

Widget _home({required HomeTileOrder order, List<AppItem>? opened}) =>
    MaterialApp(
      theme: buildAppTheme(
        accent: kDefaultAccent,
        brightness: Brightness.light,
        darkVariant: kDefaultDarkVariant,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: TeacherHome(
            header: const SizedBox.shrink(),
            access: AppAccess(_teacher),
            onOpen: (item) => opened?.add(item),
            onOpenDay: (_) {},
            onOpenGradebook: (_) {},
            userId: 1,
            tileOrder: order,
          ),
        ),
      ),
    );

Finder _tile(AppItem item) => find.byKey(ValueKey('tile-${item.name}'));

/// Tiles in reading order: top to bottom, then left to right.
List<AppItem> _order(WidgetTester tester, List<AppItem> items) {
  final placed = [
    for (final item in items) (item, tester.getCenter(_tile(item))),
  ];
  placed.sort((a, b) {
    final row = (a.$2.dy - b.$2.dy).round();
    return row.abs() > 4 ? row : a.$2.dx.compareTo(b.$2.dx);
  });
  return [for (final p in placed) p.$1];
}

void main() {
  group('sortTiles', () {
    const tiles = [AppItem.behavior, AppItem.myPlan, AppItem.exams];

    test('keeps the default order until the user moves something', () {
      expect(sortTiles(tiles, null), tiles);
    });

    test('follows the saved order', () {
      expect(sortTiles(tiles, ['exams', 'behavior', 'myPlan']), [
        AppItem.exams,
        AppItem.behavior,
        AppItem.myPlan,
      ]);
    });

    test('a new tile slots in after its default neighbour', () {
      expect(sortTiles(tiles, ['exams', 'behavior']), [
        AppItem.exams,
        AppItem.behavior,
        AppItem.myPlan,
      ]);
    });
  });

  testWidgets('holding a tile and dragging it rearranges and saves', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final order = HomeTileOrder(prefs: prefs);
    final opened = <AppItem>[];
    await tester.pumpWidget(_home(order: order, opened: opened));
    await tester.pumpAndSettle();

    final tiles = AppAccess(_teacher).smallTiles;
    expect(_order(tester, tiles), tiles);
    final first = tiles.first;
    final third = tiles[2];

    // Hold the first tile, then drag it onto the third.
    final gesture = await tester.startGesture(tester.getCenter(_tile(first)));
    await tester.pump(const Duration(milliseconds: 500));
    final target = tester.getCenter(_tile(third));
    for (var i = 1; i <= 10; i++) {
      final from = tester.getCenter(_tile(first));
      await gesture.moveTo(Offset.lerp(from, target, i / 10)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump();

    expect(find.byKey(const ValueKey('tiles-done')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tiles-done')));
    await tester.pumpAndSettle();

    final moved = _order(tester, tiles);
    expect(moved.indexOf(first), 2);
    expect(await order.load(1), [for (final i in moved) i.name]);
    // Rearranging opened nothing.
    expect(opened, isEmpty);

    // A fresh Home reads the saved order back.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_home(order: order));
    await tester.pumpAndSettle();
    expect(_order(tester, tiles), moved);
  });

  testWidgets('Reset goes back to the default order', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final order = HomeTileOrder(prefs: prefs);
    final tiles = AppAccess(_teacher).smallTiles;
    await order.save(1, tiles.reversed.toList());

    await tester.pumpWidget(_home(order: order));
    await tester.pumpAndSettle();
    expect(_order(tester, tiles), tiles.reversed.toList());

    final gesture = await tester.startGesture(
      tester.getCenter(_tile(tiles.last)),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('tiles-reset')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tiles-done')));
    await tester.pumpAndSettle();

    expect(_order(tester, tiles), tiles);
    expect(await order.load(1), isNull);
  });
}
