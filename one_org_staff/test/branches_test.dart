import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/branches/application/branch_controller.dart';
import 'package:one_org_staff/features/branches/data/branch_http_client.dart';
import 'package:one_org_staff/features/branches/data/http_branches_repository.dart';
import 'package:one_org_staff/features/branches/domain/branches_repository.dart';
import 'package:one_org_staff/features/branches/presentation/branch_gate.dart';
import 'package:one_org_staff/features/branches/presentation/branch_switcher.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _main = Branch(id: 1, name: 'Main');
const _north = Branch(id: 2, name: 'North');
const _closed = Branch(id: 0, name: 'Closed', isActive: false);

final _base = Uri.parse('https://api.test');

BranchController _controller(
  SharedPreferences prefs, {
  required Future<List<Branch>?> Function() load,
  DateTime Function()? clock,
}) => BranchController(loadBranches: load, preferences: prefs, clock: clock);

Future<SharedPreferences> _prefs([Map<String, Object> values = const {}]) {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  group('BranchHttpClient', () {
    late List<http.Request> seen;

    BranchHttpClient client({int? branchId = 2, void Function()? onRejected}) {
      return BranchHttpClient(
        MockClient((request) async {
          seen.add(request);
          return http.Response('{}', 200);
        }),
        branchId: () => branchId,
        onBranchRejected: onRejected,
      );
    }

    setUp(() => seen = []);

    test('says which branch a staff request is for', () async {
      await client().get(_base.resolve('/students'));
      expect(seen.single.headers['X-Branch-Id'], '2');
    });

    test('sends no header until a branch is resolved', () async {
      await client(branchId: null).get(_base.resolve('/students'));
      expect(seen.single.headers.containsKey('X-Branch-Id'), isFalse);
    });

    for (final path in [
      '/users/me',
      '/branches/my',
      '/auth/validate',
      '/notifications',
      '/notifications/5/read',
    ]) {
      test('leaves the personal call $path alone', () async {
        await client().get(_base.resolve(path));
        expect(seen.single.headers.containsKey('X-Branch-Id'), isFalse);
      });
    }

    test('still scopes lookalikes of the personal calls', () async {
      await client().get(_base.resolve('/users'));
      await client().get(_base.resolve('/branches/2'));
      expect(seen.map((r) => r.headers['X-Branch-Id']), ['2', '2']);
    });

    test('acrossBranches reaches every branch, through awaits', () async {
      final c = client();
      await acrossBranches(() async {
        await Future<void>.delayed(Duration.zero);
        await c.post(_base.resolve('/student-points/bulk'));
      });
      expect(seen.single.headers.containsKey('X-Branch-Id'), isFalse);

      await c.get(_base.resolve('/students'));
      expect(seen.last.headers['X-Branch-Id'], '2');
    });

    BranchHttpClient refusing(String body, void Function() onRejected) {
      return BranchHttpClient(
        MockClient((_) async => http.Response(body, 403)),
        branchId: () => 2,
        onBranchRejected: onRejected,
      );
    }

    test('a lost branch is reported, and the body stays readable', () async {
      var rejected = 0;
      const body = '{"message":"You do not have access to this branch"}';
      final response = await refusing(
        body,
        () => rejected += 1,
      ).get(_base.resolve('/students'));

      expect(rejected, 1);
      expect(response.statusCode, 403);
      expect(response.body, body);
    });

    test('an ordinary 403 is not treated as a lost branch', () async {
      var rejected = 0;
      await refusing(
        '{"message":"Forbidden"}',
        () => rejected += 1,
      ).get(_base.resolve('/students'));
      expect(rejected, 0);
    });
  });

  group('HttpBranchesRepository', () {
    HttpBranchesRepository repo(http.Response response) =>
        HttpBranchesRepository(
          client: MockClient((_) async => response),
          baseUrl: 'https://api.test/',
        );

    test('reads the result list', () async {
      final branches = await repo(
        http.Response(
          jsonEncode({
            'ok': true,
            'result': [
              {'id': 2, 'name': 'North', 'is_active': false},
            ],
          }),
          200,
        ),
      ).getMyBranches('t');

      expect(branches!.single.id, 2);
      expect(branches.single.name, 'North');
      expect(branches.single.isActive, isFalse);
    });

    test('a 404 means the API predates branches', () async {
      expect(await repo(http.Response('', 404)).getMyBranches('t'), isNull);
    });

    test('a server error is a failure', () async {
      expect(
        repo(http.Response('', 500)).getMyBranches('t'),
        throwsA(anything),
      );
    });
  });

  group('BranchController', () {
    test('keeps the saved branch when it is still on offer', () async {
      final c = _controller(
        await _prefs({'active_branch_id': 2}),
        load: () async => [_main, _north],
      );
      await c.load();
      expect(c.status, BranchStatus.ready);
      expect(c.activeBranchId, 2);
    });

    test('falls back to the oldest active branch', () async {
      final prefs = await _prefs({'active_branch_id': 99});
      final c = _controller(prefs, load: () async => [_north, _closed, _main]);
      await c.load();
      await pumpEventQueue();
      expect(c.activeBranchId, 1);
      expect(prefs.getInt('active_branch_id'), 1);
    });

    test('a malformed saved branch does not block first sign-in', () async {
      final c = _controller(
        await _prefs({'active_branch_id': 'old-value'}),
        load: () async => [_main],
      );
      await c.load();
      expect(c.status, BranchStatus.ready);
      expect(c.activeBranchId, 1);
    });

    test('runs without a branch when the API predates them', () async {
      final c = _controller(await _prefs(), load: () async => null);
      await c.load();
      expect(c.status, BranchStatus.ready);
      expect(c.activeBranchId, isNull);
    });

    test('no assigned branch is its own state', () async {
      final c = _controller(await _prefs(), load: () async => const []);
      await c.load();
      expect(c.status, BranchStatus.none);
    });

    test('a failed load uses the saved branch if there is one', () async {
      final c = _controller(
        await _prefs({'active_branch_id': 2}),
        load: () async => throw Exception('offline'),
      );
      await c.load();
      expect(c.status, BranchStatus.ready);
      expect(c.activeBranchId, 2);
      expect(c.canSwitch, isFalse);
    });

    test('a failed load with nothing saved is an error', () async {
      final c = _controller(
        await _prefs(),
        load: () async => throw Exception('offline'),
      );
      await c.load();
      expect(c.status, BranchStatus.error);
      expect(c.activeBranchId, isNull);
    });

    test('switching saves the choice and ignores unknown ids', () async {
      final prefs = await _prefs();
      final c = _controller(prefs, load: () async => [_main, _north]);
      await c.load();

      c.switchTo(2);
      await pumpEventQueue();
      expect(c.activeBranchId, 2);
      expect(prefs.getInt('active_branch_id'), 2);

      c.switchTo(99);
      expect(c.activeBranchId, 2);
    });

    test('a refused branch is dropped and resolved again', () async {
      var offered = [_main, _north];
      final prefs = await _prefs({'active_branch_id': 2});
      final c = _controller(prefs, load: () async => offered);
      await c.load();
      expect(c.activeBranchId, 2);

      offered = [_main];
      c.handleBranchRejected();
      await pumpEventQueue();

      expect(c.status, BranchStatus.ready);
      expect(c.activeBranchId, 1);
    });

    test('repeated refusals do not become a reload loop', () async {
      var loads = 0;
      var now = DateTime(2026, 11, 11);
      final c = _controller(
        await _prefs(),
        clock: () => now,
        load: () async {
          loads += 1;
          return [_main, _north];
        },
      );
      await c.load();

      c.handleBranchRejected();
      c.handleBranchRejected();
      await pumpEventQueue();
      expect(loads, 2);

      now = now.add(const Duration(seconds: 11));
      c.handleBranchRejected();
      await pumpEventQueue();
      expect(loads, 3);
    });

    test('an answer arriving after sign-out is ignored', () async {
      final c = _controller(await _prefs(), load: () async => [_main]);
      final pending = c.load();
      c.reset();
      await pending;
      expect(c.activeBranchId, isNull);
      expect(c.status, BranchStatus.loading);
    });
  });

  group('screens', () {
    Widget app(Widget home) => MaterialApp(
      theme: buildAppTheme(
        accent: kDefaultAccent,
        brightness: Brightness.light,
        darkVariant: kDefaultDarkVariant,
      ),
      home: home,
    );

    testWidgets('the gate holds the app back until the branch is known', (
      tester,
    ) async {
      final c = _controller(await _prefs(), load: () async => [_main]);
      await tester.pumpWidget(
        app(
          BranchGate(
            controller: c,
            onSignOut: () {},
            child: const Text('dashboard'),
          ),
        ),
      );
      expect(find.text('dashboard'), findsNothing);

      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsOneWidget);
      expect(c.activeBranchId, 1);
    });

    testWidgets('a failed load offers retry and sign out', (tester) async {
      var fail = true;
      var signedOut = false;
      final c = _controller(
        await _prefs(),
        load: () async {
          if (fail) throw Exception('offline');
          return [_main];
        },
      );
      await tester.pumpWidget(
        app(
          BranchGate(
            controller: c,
            onSignOut: () => signedOut = true,
            child: const Text('dashboard'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsNothing);

      await tester.tap(find.text('Sign out'));
      expect(signedOut, isTrue);

      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('dashboard'), findsOneWidget);
    });

    testWidgets('a teacher at one branch sees no picker', (tester) async {
      final c = _controller(await _prefs(), load: () async => [_main]);
      await c.load();
      await tester.pumpWidget(
        app(Scaffold(body: BranchSwitcher(controller: c))),
      );
      expect(find.text('Main'), findsNothing);
    });

    testWidgets('picking from the sheet switches branch', (tester) async {
      final c = _controller(await _prefs(), load: () async => [_main, _north]);
      await c.load();
      await tester.pumpWidget(
        app(Scaffold(body: BranchSwitcher(controller: c))),
      );
      expect(find.text('Main'), findsOneWidget);

      await tester.tap(find.text('Main'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('North'));
      await tester.pumpAndSettle();

      expect(c.activeBranchId, 2);
      expect(find.text('North'), findsOneWidget);
      expect(find.text('Main'), findsNothing);
    });
  });
}
