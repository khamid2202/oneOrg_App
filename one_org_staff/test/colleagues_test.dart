import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/colleagues/data/http_colleagues_repository.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';
import 'package:one_org_staff/features/colleagues/presentation/colleagues_page.dart';

const _ali = Colleague(
  id: 1,
  fullName: 'Ali Vali',
  username: 'ali',
  phoneNumber: '+998 90 111 22 33',
  email: 'ali@example.com',
  status: 'active',
);

const _bobur = Colleague(
  id: 2,
  fullName: 'Bobur Karimov',
  username: 'bobur',
  phoneNumber: null,
  email: 'bobur@example.com',
  status: 'active',
);

const _zulfiya = Colleague(
  id: 3,
  fullName: 'Zulfiya Rashidova',
  username: 'zulfiya',
  phoneNumber: '+998901234567',
  status: 'active',
);

const _formerStaff = Colleague(
  id: 4,
  fullName: 'Anvar Ketgan',
  username: 'anvar',
  status: 'inactive',
);

Widget _wrap(
  List<Colleague> colleagues, {
  Future<bool> Function(String uri)? launchDial,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ColleaguesPage(
          loadColleagues: () async => colleagues,
          launchDial: launchDial,
        ),
      ),
    ),
  );
}

void main() {
  group('Colleague', () {
    test('falls back to the username when full_name is missing', () {
      const colleague = Colleague(id: 1, fullName: '', username: 'ali');
      expect(colleague.displayName, 'ali');
      expect(colleague.initials, 'A');
    });

    test('takes at most two initials', () {
      expect(_zulfiya.initials, 'ZR');
      expect(
        const Colleague(id: 1, fullName: 'Abdul Aziz Karim').initials,
        'AA',
      );
    });

    test('strips formatting from the number for the dialer', () {
      // Dialers choke on spaces.
      expect(_ali.dialUri, 'tel:+998901112233');
      expect(_bobur.dialUri, isNull);
    });

    test('searches name, username, phone and email', () {
      expect(_ali.matches('vali'), isTrue);
      expect(_ali.matches('ALI@EXAMPLE'), isTrue);
      expect(_ali.matches('111 22'), isTrue);
      expect(_ali.matches('zulfiya'), isFalse);
      // An empty term matches everything, so the list shows in full.
      expect(_ali.matches('   '), isTrue);
    });

    test('reads picture_url, the field the API sends', () {
      final colleague = Colleague.fromJson(const {
        'id': 7,
        'full_name': 'Ali Vali',
        'picture_url': 'https://cdn.example.com/users/7/a.jpg',
        'roles': ['teacher'],
      });

      expect(colleague.pictureUrl, 'https://cdn.example.com/users/7/a.jpg');
      expect(colleague.roles, ['teacher']);
    });
  });

  group('HttpColleaguesRepository', () {
    test('reads the documented { ok, users: [...] } shape', () async {
      final repository = HttpColleaguesRepository(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/users');
          expect(request.headers['Authorization'], 'Bearer test-token');

          return http.Response(
            jsonEncode({
              'ok': true,
              'meta': {'total': 1},
              'users': [
                {
                  'id': 2,
                  'username': 'ali',
                  'full_name': 'Ali Vali',
                  'phone_number': '+998901112233',
                  'status': 'active',
                  'roles': ['teacher'],
                },
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz/',
      );

      final colleagues = await repository.getColleagues('test-token');

      expect(colleagues, hasLength(1));
      expect(colleagues.single.displayName, 'Ali Vali');
      expect(colleagues.single.isActive, isTrue);
    });

    test('surfaces the API message on failure', () async {
      final repository = HttpColleaguesRepository(
        client: MockClient(
          (request) async =>
              http.Response(jsonEncode({'message': 'Unauthorized'}), 401),
        ),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      expect(
        () => repository.getColleagues('bad-token'),
        throwsA(
          isA<AuthFailure>().having(
            (e) => e.message,
            'message',
            'Unauthorized',
          ),
        ),
      );
    });
  });

  group('ColleaguesPage', () {
    testWidgets('lists active staff sorted by name, under letter headings', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([_zulfiya, _ali, _bobur, _formerStaff]));
      await tester.pumpAndSettle();

      expect(find.text('Ali Vali'), findsOneWidget);
      expect(find.text('Bobur Karimov'), findsOneWidget);
      expect(find.text('Zulfiya Rashidova'), findsOneWidget);

      // Inactive staff are not in the directory.
      expect(find.text('Anvar Ketgan'), findsNothing);
      expect(find.text('3 active colleagues'), findsOneWidget);

      // A/B/Z headings, in that order.
      final headings = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .where((d) => d != null && d.length == 1)
          .toList();
      expect(headings, ['A', 'B', 'Z']);
    });

    testWidgets('the phone number is hidden until the row is tapped', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([_ali]));
      await tester.pumpAndSettle();

      expect(find.text('+998 90 111 22 33'), findsNothing);

      await tester.tap(find.text('Ali Vali'));
      await tester.pumpAndSettle();

      expect(find.text('+998 90 111 22 33'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Call'), findsOneWidget);
    });

    testWidgets('only one row is open at a time', (tester) async {
      await tester.pumpWidget(_wrap([_ali, _zulfiya]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali Vali'));
      await tester.pumpAndSettle();
      expect(find.text('+998 90 111 22 33'), findsOneWidget);

      await tester.tap(find.text('Zulfiya Rashidova'));
      await tester.pumpAndSettle();

      expect(find.text('+998901234567'), findsOneWidget);
      expect(find.text('+998 90 111 22 33'), findsNothing);
    });

    testWidgets('tapping the open row closes it', (tester) async {
      await tester.pumpWidget(_wrap([_ali]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali Vali'));
      await tester.pumpAndSettle();
      expect(find.text('+998 90 111 22 33'), findsOneWidget);

      await tester.tap(find.text('Ali Vali'));
      await tester.pumpAndSettle();
      expect(find.text('+998 90 111 22 33'), findsNothing);
    });

    testWidgets('a colleague with no number says so instead of offering Call', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([_bobur]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bobur Karimov'));
      await tester.pumpAndSettle();

      expect(find.text('No phone number'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Call'), findsNothing);
    });

    testWidgets('Call dials the number with the formatting stripped', (
      tester,
    ) async {
      final dialled = <String>[];

      await tester.pumpWidget(
        _wrap(
          [_ali],
          launchDial: (uri) async {
            dialled.add(uri);
            return true;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ali Vali'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Call'));
      await tester.pumpAndSettle();

      expect(dialled, ['tel:+998901112233']);
    });

    testWidgets('search filters the list and the count', (tester) async {
      await tester.pumpWidget(_wrap([_ali, _bobur, _zulfiya]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'bob');
      await tester.pumpAndSettle();

      expect(find.text('Bobur Karimov'), findsOneWidget);
      expect(find.text('Ali Vali'), findsNothing);
      expect(find.text('1 active colleague'), findsOneWidget);
    });

    testWidgets('an empty search result says so', (tester) async {
      await tester.pumpWidget(_wrap([_ali]));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nobody');
      await tester.pumpAndSettle();

      expect(
        find.text('No colleagues found matching your search.'),
        findsOneWidget,
      );
    });

    testWidgets('a load failure shows the reason and offers a retry', (
      tester,
    ) async {
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ColleaguesPage(
                loadColleagues: () async {
                  attempts++;
                  if (attempts == 1) {
                    throw const AuthFailure('Unauthorized');
                  }
                  return [_ali];
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unauthorized'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Ali Vali'), findsOneWidget);
    });
  });
}
