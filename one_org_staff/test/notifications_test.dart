import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/notifications/application/notifications_controller.dart';
import 'package:one_org_staff/features/notifications/application/push_service.dart';
import 'package:one_org_staff/features/notifications/data/http_notifications_repository.dart';
import 'package:one_org_staff/features/notifications/domain/notifications_repository.dart';
import 'package:one_org_staff/features/notifications/presentation/notification_bell.dart';
import 'package:one_org_staff/features/notifications/presentation/notification_permission_sheet.dart';
import 'package:one_org_staff/features/notifications/presentation/notifications_page.dart';

const _baseUrl = 'https://api.example.test';

HttpNotificationsRepository _repository(MockClient client) =>
    HttpNotificationsRepository(client: client, baseUrl: _baseUrl);

AppNotification _notification({
  int id = 1,
  String title = 'Staff meeting',
  bool isRead = false,
}) {
  return AppNotification(
    id: id,
    title: title,
    body: 'Please attend at 3 PM.',
    isRead: isRead,
    type: 'announcement',
    createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
  );
}

/// A controller wired to in-memory stubs, so the widget tests exercise the
/// real optimistic-update paths without any HTTP.
NotificationsController _controllerWith(
  List<AppNotification> items, {
  int unreadCount = 0,
  List<int>? markedRead,
  Object? failWith,
}) {
  var allRead = false;
  return NotificationsController(
    loadNotifications: ({int page = 1, int limit = 20, bool? isRead}) async {
      if (failWith != null) throw failWith;
      return NotificationPage(
        items: allRead
            ? items.map((item) => item.copyWith(isRead: true)).toList()
            : items,
        total: items.length,
        page: 1,
        pages: 1,
        unreadCount: allRead ? 0 : unreadCount,
      );
    },
    loadUnreadCount: () async => allRead ? 0 : unreadCount,
    markRead: (id) async => markedRead?.add(id),
    markAllRead: () async => allRead = true,
  );
}

PushService _pushService() => PushService(
  registerDeviceToken: ({required deviceToken, required platform}) async {},
  unregisterDeviceToken: (_) async {},
);

Widget _wrapPage(NotificationsController controller) {
  return MaterialApp(
    home: Scaffold(
      body: NotificationsPage(
        controller: controller,
        pushService: _pushService(),
      ),
    ),
  );
}

void main() {
  // PushService persists its once-per-install prompt flag. Without a mock
  // store the real plugin call never completes and the tests that touch it
  // hang rather than fail.
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('HttpNotificationsRepository', () {
    test('parses the inbox page and its unread count', () async {
      late Uri seen;
      final repository = _repository(
        MockClient((request) async {
          seen = request.url;
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'id': 10,
                  'title': 'New Payment Received',
                  'body': 'Payment of 500,000 UZS was processed.',
                  'data': {'invoice_id': 12},
                  'type': 'payment',
                  'is_read': false,
                  'read_at': null,
                  'created_at': '2026-08-12T08:30:00.000Z',
                },
              ],
              'total': 1,
              'page': 1,
              'limit': 20,
              'pages': 1,
              'unread_count': 1,
            }),
            200,
          );
        }),
      );

      final page = await repository.getNotifications('tok', page: 1, limit: 20);

      expect(seen.path, '/notifications');
      expect(seen.queryParameters['page'], '1');
      expect(seen.queryParameters['limit'], '20');
      // Omitted rather than sent as null — the API treats the key's presence
      // as a filter.
      expect(seen.queryParameters.containsKey('is_read'), isFalse);

      expect(page.unreadCount, 1);
      expect(page.items.single.id, 10);
      expect(page.items.single.type, 'payment');
      expect(page.items.single.data['invoice_id'], 12);
      expect(page.items.single.isRead, isFalse);
    });

    test('passes the is_read filter through when one is given', () async {
      late Uri seen;
      final repository = _repository(
        MockClient((request) async {
          seen = request.url;
          return http.Response(jsonEncode({'items': []}), 200);
        }),
      );

      await repository.getNotifications('tok', isRead: false);

      expect(seen.queryParameters['is_read'], 'false');
    });

    test('reads the unread count', () async {
      final repository = _repository(
        MockClient(
          (_) async => http.Response(jsonEncode({'unread_count': 7}), 200),
        ),
      );

      expect(await repository.getUnreadCount('tok'), 7);
    });

    test('marks one notification read with a PATCH', () async {
      late http.Request seen;
      final repository = _repository(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'id': 10, 'is_read': true}), 200);
        }),
      );

      await repository.markAsRead('tok', id: 10);

      expect(seen.method, 'PATCH');
      expect(seen.url.path, '/notifications/10/read');
      expect(seen.headers['Authorization'], 'Bearer tok');
    });

    test('registers the device token with its platform', () async {
      late http.Request seen;
      final repository = _repository(
        MockClient((request) async {
          seen = request;
          return http.Response(jsonEncode({'id': 1}), 201);
        }),
      );

      await repository.registerDeviceToken(
        'tok',
        deviceToken: 'fcm-abc',
        platform: 'android',
      );

      expect(seen.method, 'POST');
      expect(seen.url.path, '/notifications/device-token');
      expect(jsonDecode(seen.body), {
        'token': 'fcm-abc',
        'platform': 'android',
      });
    });

    test('unregisters the device token with a DELETE carrying a body', () async {
      late http.Request seen;
      final repository = _repository(
        MockClient((request) async {
          seen = request;
          return http.Response('', 204);
        }),
      );

      await repository.unregisterDeviceToken('tok', deviceToken: 'fcm-abc');

      expect(seen.method, 'DELETE');
      expect(jsonDecode(seen.body), {'token': 'fcm-abc'});
    });

    test('surfaces the server message on a failure', () async {
      final repository = _repository(
        MockClient(
          (_) async =>
              http.Response(jsonEncode({'message': 'Session expired'}), 401),
        ),
      );

      expect(
        () => repository.getUnreadCount('tok'),
        throwsA(
          isA<AuthFailure>().having((e) => e.message, 'message', 'Session expired'),
        ),
      );
    });
  });

  group('NotificationsController', () {
    test('marking one read drops the badge immediately', () async {
      final marked = <int>[];
      final controller = _controllerWith(
        [_notification(id: 1), _notification(id: 2, isRead: true)],
        unreadCount: 1,
        markedRead: marked,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      expect(controller.unreadCount, 1);

      await controller.markAsRead(1);

      expect(controller.unreadCount, 0);
      expect(controller.items.first.isRead, isTrue);
      expect(marked, [1]);
    });

    test('marking an already-read row does nothing', () async {
      final marked = <int>[];
      final controller = _controllerWith(
        [_notification(id: 1, isRead: true)],
        markedRead: marked,
      );
      addTearDown(controller.dispose);

      await controller.refresh();
      await controller.markAsRead(1);

      expect(marked, isEmpty);
    });

    test('mark-all clears every row and the badge', () async {
      final controller = _controllerWith([
        _notification(id: 1),
        _notification(id: 2),
      ], unreadCount: 2);
      addTearDown(controller.dispose);

      await controller.refresh();
      await controller.markAllAsRead();

      expect(controller.unreadCount, 0);
      expect(controller.items.every((item) => item.isRead), isTrue);
    });

    test('a failed load shows the server message, not a stack string', () async {
      final controller = _controllerWith(
        const [],
        failWith: const AuthFailure('Session expired'),
      );
      addTearDown(controller.dispose);

      await controller.refresh();

      expect(controller.error, 'Session expired');
      expect(controller.items, isEmpty);
    });
  });

  group('NotificationBell', () {
    testWidgets('shows the unread count and caps it at 99+', (tester) async {
      final controller = _controllerWith(const [], unreadCount: 130);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBell(controller: controller, onTap: () {}),
          ),
        ),
      );

      // Nothing loaded yet, so no badge.
      expect(find.text('99+'), findsNothing);

      await controller.refreshUnreadCount();
      await tester.pump();

      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('stays bare when there is nothing unread', (tester) async {
      final controller = _controllerWith(const []);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NotificationBell(controller: controller, onTap: () {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('0'), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    });
  });

  group('NotificationsPage', () {
    testWidgets('lists the inbox and marks a row read on tap', (tester) async {
      final marked = <int>[];
      final controller = _controllerWith([
        _notification(id: 1, title: 'Staff meeting'),
      ], unreadCount: 1, markedRead: marked);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrapPage(controller));
      await tester.pumpAndSettle();

      expect(find.text('Staff meeting'), findsOneWidget);
      expect(find.text('1 unread'), findsOneWidget);

      await tester.tap(find.text('Staff meeting'));
      await tester.pumpAndSettle();

      expect(marked, [1]);
      expect(find.text('You are all caught up'), findsOneWidget);
    });

    testWidgets('mark-all-read only shows while something is unread', (
      tester,
    ) async {
      final controller = _controllerWith([
        _notification(id: 1),
        _notification(id: 2),
      ], unreadCount: 2);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrapPage(controller));
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsOneWidget);

      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(find.text('Mark all read'), findsNothing);
      expect(find.text('You are all caught up'), findsOneWidget);
    });

    testWidgets('shows an empty state on a fresh account', (tester) async {
      final controller = _controllerWith(const []);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrapPage(controller));
      await tester.pumpAndSettle();

      expect(find.text('Nothing yet'), findsOneWidget);
    });

    testWidgets('offers a retry when the load fails', (tester) async {
      final controller = _controllerWith(
        const [],
        failWith: const AuthFailure('Session expired'),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(_wrapPage(controller));
      await tester.pumpAndSettle();

      expect(find.text('Could not load notifications'), findsOneWidget);
      expect(find.text('Session expired'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('notification permission sheet', () {
    /// Pumps a button that opens the sheet and records what it resolves to.
    Future<List<bool?>> open(WidgetTester tester) async {
      final answers = <bool?>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  answers.add(await showNotificationPermissionSheet(context));
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return answers;
    }

    testWidgets('explains what the notifications are before asking', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('Turn on notifications?'), findsOneWidget);
      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Points and rewards'), findsOneWidget);
      expect(find.text('Schedule changes'), findsOneWidget);
      expect(find.text('Allow notifications'), findsOneWidget);
      expect(find.text('Not now'), findsOneWidget);
    });

    testWidgets('Allow resolves true, which is what triggers the OS prompt', (
      tester,
    ) async {
      final answers = await open(tester);

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();

      expect(answers, [true]);
    });

    testWidgets('Not now resolves false', (tester) async {
      final answers = await open(tester);

      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(answers, [false]);
    });

    testWidgets('a tap outside cannot count as a decline', (tester) async {
      final answers = await open(tester);

      // The barrier is the top-left corner, well clear of the sheet.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(answers, isEmpty);
      expect(find.text('Turn on notifications?'), findsOneWidget);
    });
  });

  group('maybeAskForNotificationPermission', () {
    /// Pumps a screen that runs the gate once mounted, and reports whether the
    /// explainer ended up on screen.
    Future<void> run(WidgetTester tester, PushService push) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  maybeAskForNotificationPermission(context, push);
                });
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('does not burn the once-per-install flag when Firebase is '
        'missing', (tester) async {
      final push = _pushService();
      addTearDown(push.dispose);
      push.debugSetPermission(PushPermission.unavailable);

      await run(tester, push);

      expect(find.text('Turn on notifications?'), findsNothing);
      // The regression: marking it seen here would leave the prompt spent, so
      // adding google-services.json later could never surface the sheet.
      expect(push.promptSeen, isFalse);
    });

    testWidgets('asks when the OS has no answer yet', (tester) async {
      final push = _pushService();
      addTearDown(push.dispose);
      push.debugSetPermission(PushPermission.notDetermined);

      await run(tester, push);

      expect(find.text('Turn on notifications?'), findsOneWidget);
    });

    testWidgets('stays quiet, and spends the flag, once the OS has said no', (
      tester,
    ) async {
      final push = _pushService();
      addTearDown(push.dispose);
      push.debugSetPermission(PushPermission.denied);

      await run(tester, push);

      expect(find.text('Turn on notifications?'), findsNothing);
      expect(push.promptSeen, isTrue);
    });

    testWidgets('never asks twice', (tester) async {
      final push = _pushService();
      addTearDown(push.dispose);
      push.debugSetPermission(PushPermission.notDetermined);
      await push.markPromptSeen();

      await run(tester, push);

      expect(find.text('Turn on notifications?'), findsNothing);
    });
  });
}
