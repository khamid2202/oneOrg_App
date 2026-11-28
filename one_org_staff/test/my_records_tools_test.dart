import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/lessons/data/offline_cache.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/features/lessons/presentation/attendance_step.dart'
    show TeamMark, orderByTeam;
import 'package:one_org_staff/features/me/data/http_my_repository.dart';
import 'package:one_org_staff/features/me/domain/my_records.dart';
import 'package:one_org_staff/features/me/presentation/my_fundings_page.dart';
import 'package:one_org_staff/features/me/presentation/my_plan_page.dart';
import 'package:one_org_staff/features/me/presentation/my_points_page.dart';
import 'package:one_org_staff/features/teaching_tools/domain/team_shuffle.dart';
import 'package:one_org_staff/features/teaching_tools/presentation/teaching_tools_page.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lessons_repository.dart';

class _FakeMe implements MyRepository {
  List<UserPlan> plans = const [];
  List<PointRecord> points = const [];
  List<Funding> fundings = const [];
  List<FundingCategory> categories = const [];
  Future<void> Function()? statusResult;
  Object? pointsError;
  final List<int> asked = [];
  final List<PlanDraft> saved = [];
  final List<(int, String)> statuses = [];

  @override
  Future<List<UserPlan>> getPlans({
    required int userId,
    String? from,
    String? to,
  }) async {
    asked.add(userId);
    return plans;
  }

  @override
  Future<void> savePlan(
    PlanDraft draft, {
    int? id,
    List<PlanFile> files = const [],
    List<String> removeAttachmentKeys = const [],
  }) async => saved.add(draft);

  @override
  Future<void> setPlanStatus(int id, String status) async {
    statuses.add((id, status));
    await statusResult?.call();
  }

  @override
  Future<void> deletePlan(int id) async {}

  @override
  Future<List<PointRecord>> getPoints(int userId) async {
    asked.add(userId);
    if (pointsError != null) throw pointsError!;
    return points;
  }

  @override
  Future<List<Funding>> getFundings(int userId) async {
    asked.add(userId);
    return fundings;
  }

  @override
  Future<List<FundingCategory>> getFundingCategories() async => categories;

  @override
  Future<List<PointRecord>> getRecentPoints(
    int userId, {
    required String from,
  }) async => points;

  @override
  Future<List<Funding>> getRecentFundings(
    int userId, {
    required String from,
  }) async => fundings;

  @override
  Future<List<CalendarEntry>> getCalendar({
    required String from,
    required String to,
  }) async => const [];

  @override
  Future<List<CalendarEntry>> getFullCalendar({
    required String from,
    required String to,
  }) async => const [];

  @override
  Future<List<LessonObservation>> getMyObservations(int userId) async =>
      const [];

  @override
  Future<List<MyDepartmentEntry>> getMyDepartments() async => const [];

  @override
  Future<DepartmentStats> getDepartmentStats(
    int departmentId, {
    int? groupId,
  }) async => const DepartmentStats(
    summary: DepartmentFigures(id: 0, name: ''),
    subjectCount: 0,
    memberCount: 0,
  );
}

Widget _app(Widget child) => MaterialApp(
  theme: buildAppTheme(
    accent: kDefaultAccent,
    brightness: Brightness.light,
    darkVariant: kDefaultDarkVariant,
  ),
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

UserPlan _plan(int id, String status, String start, String end) => UserPlan(
  id: id,
  agenda: 'Milestone $id',
  status: status,
  start: DateTime.parse(start),
  end: DateTime.parse(end),
);

Funding _funding(
  int id,
  String date,
  int amount, {
  String type = 'deposit',
  int? category = 1,
  String currency = currencyUzs,
}) => Funding(
  id: id,
  type: type,
  amount: amount,
  date: date,
  categoryId: category,
  categoryName: 'Bonus',
  currency: currency,
);

const _students = [
  ToolStudent(id: 'a', name: 'A'),
  ToolStudent(id: 'b', name: 'B'),
  ToolStudent(id: 'c', name: 'C'),
  ToolStudent(id: 'd', name: 'D'),
  ToolStudent(id: 'e', name: 'E'),
  ToolStudent(id: 'f', name: 'F'),
  ToolStudent(id: 'g', name: 'G'),
  ToolStudent(id: 'h', name: 'H'),
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('plan', () {
    test('in progress is half, cancelled is not counted', () {
      expect(
        planProgress([
          _plan(1, planCompleted, '2026-09-01', '2026-09-30'),
          _plan(2, planInProgress, '2026-10-01', '2026-10-31'),
          _plan(3, planCancelled, '2026-11-01', '2026-11-30'),
        ]),
        75,
      );
      expect(planProgress(const []), 0);
    });

    test('only open work can be overdue, and not on its last day', () {
      final now = DateTime(2026, 10, 2, 15);
      expect(
        isOverdue(_plan(1, planPending, '2026-09-01', '2026-10-01'), now),
        isTrue,
      );
      expect(
        isOverdue(_plan(1, planPending, '2026-09-01', '2026-10-02'), now),
        isFalse,
      );
      for (final status in [planCompleted, planCancelled, planPostponed]) {
        expect(
          isOverdue(_plan(1, status, '2026-09-01', '2026-10-01'), now),
          isFalse,
        );
      }
    });

    test('current is what is in progress, else the first open one', () {
      final done = _plan(1, planCompleted, '2026-09-01', '2026-09-30');
      final open = _plan(2, planPending, '2026-10-01', '2026-10-31');
      final going = _plan(3, planInProgress, '2026-11-01', '2026-11-30');
      expect(currentPlanIndex([done, open, going]), 2);
      expect(currentPlanIndex([done, open]), 1);
      expect(currentPlanIndex([done]), -1);
    });

    test('a month later stays inside the shorter month', () {
      expect(addMonths(DateTime(2027, 1, 31), 1), DateTime(2027, 2, 28));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });

    test('the next milestone follows the latest one', () {
      final now = DateTime(2026, 11, 11);
      expect(
        nextMilestoneStart(
          [
            _plan(1, planPending, '2026-11-01', '2026-11-30'),
            _plan(2, planPending, '2026-09-01', '2026-09-30'),
          ],
          yearStart: DateTime(2026, 9, 1),
          now: now,
        ),
        DateTime(2026, 12, 1),
      );
      expect(
        nextMilestoneStart(const [], yearStart: DateTime(2026, 9, 1), now: now),
        DateTime(2026, 9, 1),
      );
      expect(nextMilestoneStart(const [], now: now), now);
    });

    test('period windows', () {
      final now = DateTime(2026, 11, 11);
      expect(windowOf(PeriodPreset.all, now), isNull);
      final month = windowOf(PeriodPreset.month, now)!;
      expect((month.from, month.to), ('2026-11-01', '2026-11-30'));
      final recent = windowOf(PeriodPreset.last30, now)!;
      expect((recent.from, recent.to), ('2026-10-13', '2026-11-11'));
      expect(recent.contains('2026-10-12'), isFalse);
      expect(recent.contains('2026-10-13'), isTrue);
    });
  });

  group('fundings', () {
    test('each row carries the balance of its own pocket', () {
      final rows = withRunningBalance([
        _funding(2, '2026-10-02', 300, type: fundingWithdrawal),
        _funding(1, '2026-10-01', 1000),
        _funding(3, '2026-10-03', 50, currency: 'USD'),
      ]);
      expect(rows.map((r) => r.id), [3, 2, 1]);
      expect(rows.map((r) => r.balanceAfter), [50, 700, 1000]);
    });

    test('pockets never mix categories or currencies', () {
      final pockets = pocketsOf(
        [
          _funding(1, '2026-10-01', 1000),
          _funding(2, '2026-10-02', 300, type: fundingWithdrawal),
          _funding(3, '2026-10-03', 50, currency: 'USD'),
        ],
        const [
          FundingCategory(id: 1, name: 'Bonus'),
          FundingCategory(id: 2, name: 'Empty'),
        ],
      );
      expect(pockets.map((p) => (p.name, p.currency, p.balance)), [
        ('Bonus', currencyUzs, 700),
        ('Bonus', 'USD', 50),
        ('Empty', currencyUzs, 0),
      ]);
    });

    test('net is per currency, UZS first', () {
      expect(
        netByCurrency([
          _funding(3, '2026-10-03', 50, currency: 'USD'),
          _funding(1, '2026-10-01', 1000),
          _funding(2, '2026-10-02', 300, type: fundingWithdrawal),
        ]).entries.map((e) => (e.key, e.value)),
        [(currencyUzs, 700), ('USD', 50)],
      );
    });
  });

  group('team shuffle', () {
    test('teams differ in size by at most one and lose nobody', () {
      final teams = makeTeams(
        _students.sublist(0, 7),
        3,
        const TeamHistory(),
        random: Random(1),
      );
      expect(teams.map((t) => t.members.length).toList()..sort(), [2, 2, 3]);
      expect(teams.expand((t) => t.members).toSet().length, 7);
    });

    test('avoids last time\'s pairs when it can', () {
      final random = Random(2);
      final first = makeTeams(
        _students,
        2,
        const TeamHistory(),
        random: random,
      );
      final history = afterShuffle(
        const TeamHistory(),
        first,
        rolesShown: true,
      );
      final next = makeTeams(_students, 4, history, random: random);
      final repeats = next.where(
        (t) => history.pairs.contains(
          ([t.members[0].id, t.members[1].id]..sort()).join('|'),
        ),
      );
      expect(repeats, isEmpty);
    });

    test('nobody keeps last time\'s role when there is a choice', () {
      final random = Random(3);
      const pair = [
        ToolStudent(id: 'a', name: 'A'),
        ToolStudent(id: 'b', name: 'B'),
      ];
      var history = const TeamHistory();
      var last = <String, String>{};
      for (var round = 0; round < 6; round++) {
        final team = makeTeams(pair, 1, history, random: random).single;
        if (last.isNotEmpty) {
          expect(team.roles['a'], isNot(last['a']));
        }
        last = team.roles;
        history = afterShuffle(history, [team], rolesShown: true);
      }
    });

    test('roles that were hidden do not count', () {
      final teams = makeTeams(_students, 2, const TeamHistory());
      final history = afterShuffle(
        const TeamHistory(),
        teams,
        rolesShown: false,
      );
      expect(history.lastRole, isEmpty);
      expect(history.pairs, isNotEmpty);
    });

    test('history survives a round trip, and broken history is none', () {
      final teams = makeTeams(_students, 2, const TeamHistory());
      final history = afterShuffle(
        const TeamHistory(),
        teams,
        rolesShown: true,
      );
      final back = TeamHistory.decode(history.encode());
      expect(back.pairs, history.pairs);
      expect(back.lastRole, history.lastRole);
      expect(back.roleCounts, history.roleCounts);
      expect(TeamHistory.decode('{nope').pairs, isEmpty);
      expect(TeamHistory.decode('{"pairs":3}').pairs, isEmpty);
      expect(TeamHistory.decode(null).pairs, isEmpty);
    });

    test('a round gives everyone one turn, then starts again', () {
      var picked = <String>[];
      final students = _students.sublist(0, 3);
      for (var i = 0; i < 3; i++) {
        picked = pickNext(students, picked, random: Random(i))!.$2;
      }
      expect(picked.toSet().length, 3);
      final next = pickNext(students, picked, random: Random(9))!;
      expect(next.$2, hasLength(1));
      expect(pickNext(const [], const []), isNull);
    });
  });

  group('http', () {
    HttpMyRepository repo(MockClient client) => HttpMyRepository(
      client: client,
      baseUrl: 'https://api.test/',
      readToken: () async => 'token',
    );

    test('always names the person, and reads every page', () async {
      final seen = <Uri>[];
      final client = MockClient((request) async {
        seen.add(request.url);
        return http.Response(
          jsonEncode({
            'result': [
              {
                'id': int.parse(request.url.queryParameters['page']!),
                'points': 2,
              },
            ],
            'meta': {'total': 150},
          }),
          200,
        );
      });
      final points = await repo(client).getPoints(42);
      expect(points, hasLength(2));
      expect(pointsTotal(points), 4);
      expect(seen.map((u) => u.queryParameters['user_id']), ['42', '42']);
      expect(seen.map((u) => u.queryParameters['page']), ['1', '2']);
    });

    test('the offline copy is kept per branch', () async {
      SharedPreferences.setMockInitialValues({});
      var branch = 1;
      var online = true;
      final client = MockClient((request) async {
        if (!online) throw http.ClientException('offline');
        return http.Response(
          jsonEncode({
            'result': [
              {'id': branch, 'points': branch * 10},
            ],
          }),
          200,
        );
      });
      final repo = HttpMyRepository(
        client: client,
        baseUrl: 'https://api.test',
        readToken: () async => 'token',
        cache: OfflineCache(),
        branchId: () => branch,
      );
      await repo.getPoints(42);
      branch = 2;
      await repo.getPoints(42);

      online = false;
      branch = 1;
      expect(pointsTotal(await repo.getPoints(42)), 10);
      branch = 2;
      expect(pointsTotal(await repo.getPoints(42)), 20);
      branch = 3;
      await expectLater(repo.getPoints(42), throwsA(anything));
    });

    test('backdated and edited points are told apart', () {
      final record = PointRecord.fromJson({
        'id': 1,
        'points': 5,
        'date': '2026-10-01',
        'created_at': '2026-10-03T10:00:00.000',
        'updated_at': '2026-10-04T10:00:00.000',
        'updated_by': 7,
      });
      expect(record.backdated, isTrue);
      expect(record.edited, isTrue);
      final plain = PointRecord.fromJson({
        'id': 2,
        'points': 5,
        'date': '2026-10-03',
        'created_at': '2026-10-03T10:00:00.000',
        'updated_at': '2026-10-03T10:00:00.000',
        'updated_by': null,
      });
      expect(plain.backdated, isFalse);
      expect(plain.edited, isFalse);
    });

    test('plans are scoped to the year', () async {
      late Uri seen;
      final client = MockClient((request) async {
        seen = request.url;
        return http.Response('{"result":[]}', 200);
      });
      await repo(
        client,
      ).getPlans(userId: 42, from: '2026-09-01', to: '2027-06-30');
      expect(seen.path, '/user-plans');
      expect(seen.queryParameters['user_id'], '42');
      expect(seen.queryParameters['date_from'], '2026-09-01');
      expect(seen.queryParameters['date_to'], '2027-06-30');
    });

    test('a status change sends only the status', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response('{}', 200);
      });
      await repo(client).setPlanStatus(7, planCompleted);
      expect(sent.method, 'PATCH');
      expect(sent.url.path, '/user-plans/7');
      expect(jsonDecode(sent.body), {'status': planCompleted});
    });

    test('the server\'s refusal is what the app reports', () async {
      final client = MockClient(
        (_) async => http.Response('{"message":"Not allowed"}', 403),
      );
      await expectLater(
        repo(client).deletePlan(1),
        throwsA(predicate((e) => '$e'.contains('Not allowed'))),
      );
    });
  });

  group('pages', () {
    Widget plan(_FakeMe me) => _app(
      MyPlanPage(
        repository: me,
        userId: 42,
        loadYear: () async => const AcademicYearEntry(
          id: 1,
          name: '2026-2027',
          isActive: true,
          startDate: '2026-09-01',
          endDate: '2027-06-30',
        ),
      ),
    );

    testWidgets('a status change shows at once and reverts if refused', (
      tester,
    ) async {
      _phone(tester);
      final gate = Completer<void>();
      final me = _FakeMe()
        ..plans = [_plan(1, planPending, '2030-09-01', '2030-09-30')]
        ..statusResult = () => gate.future;
      await tester.pumpWidget(plan(me));
      await tester.pumpAndSettle();
      expect(me.asked, [42]);
      expect(find.text('Not started'), findsNWidgets(2));

      await tester.tap(find.text('Not started').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Done'));
      await tester.pumpAndSettle();
      expect(me.statuses, [(1, planCompleted)]);
      expect(find.text('Not started'), findsOneWidget);

      gate.completeError(Exception('offline'));
      await tester.pumpAndSettle();
      expect(find.text('Not started'), findsNWidgets(2));
      expect(find.text("Couldn't update the status"), findsOneWidget);
    });

    testWidgets('a milestone needs a title and follows the last one', (
      tester,
    ) async {
      _phone(tester);
      final me = _FakeMe()
        ..plans = [_plan(1, planPending, '2026-09-01', '2026-11-30')];
      await tester.pumpWidget(plan(me));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add milestone'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Add milestone'));
      await tester.pump();
      expect(find.text('Give the milestone a title'), findsOneWidget);
      expect(me.saved, isEmpty);

      await tester.enterText(find.byType(TextField).first, '  Term 2  ');
      await tester.tap(find.widgetWithText(FilledButton, 'Add milestone'));
      await tester.pumpAndSettle();
      expect(me.saved.single.toJson()['agenda'], 'Term 2');
      expect(me.saved.single.start, DateTime(2026, 12, 1));
      expect(me.saved.single.end, DateTime(2027, 1, 1));
      expect(me.saved.single.category, 'curriculum');
      expect(find.text('Milestone added'), findsOneWidget);
    });

    testWidgets('points add up all time; the period only narrows the list', (
      tester,
    ) async {
      _phone(tester);
      final me = _FakeMe()
        ..points = const [
          PointRecord(id: 1, points: 5, date: '2020-01-01', note: 'Old'),
          PointRecord(id: 2, points: -2, date: '2020-02-01', note: 'Late'),
        ];
      await tester.pumpWidget(_app(MyPointsPage(repository: me, userId: 42)));
      await tester.pumpAndSettle();
      expect(me.asked, [42]);
      expect(find.text('3'), findsOneWidget);
      // The row, and February's net.
      expect(find.text('−2'), findsNWidgets(2));

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('Old'), findsNothing);
      expect(find.text('Nothing in this period.'), findsOneWidget);
    });

    testWidgets('history is grouped by month, newest first, each with a net', (
      tester,
    ) async {
      _phone(tester);
      final me = _FakeMe()
        ..points = [
          const PointRecord(id: 1, points: 5, date: '2026-09-10', note: 'Sep'),
          const PointRecord(id: 2, points: -2, date: '2026-10-02', note: 'A'),
          const PointRecord(id: 3, points: 7, date: '2026-10-20', note: 'B'),
          PointRecord(
            id: 4,
            points: 1,
            date: '2026-10-01',
            note: 'Late entry',
            createdAt: DateTime(2026, 10, 5, 9),
            createdBy: 9,
            updatedAt: DateTime(2026, 10, 6, 9),
            updatedBy: 9,
          ),
        ];
      await tester.pumpWidget(
        _app(
          MyPointsPage(
            repository: me,
            userId: 42,
            loadNames: () async => {9: 'Akmal'},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('OCTOBER 2026'), findsOneWidget);
      expect(find.text('SEPTEMBER 2026'), findsOneWidget);
      expect(find.text('+6'), findsOneWidget);
      final october = tester.getTopLeft(find.text('OCTOBER 2026')).dy;
      final b = tester.getTopLeft(find.text('B')).dy;
      final a = tester.getTopLeft(find.text('A')).dy;
      final sep = tester.getTopLeft(find.text('SEPTEMBER 2026')).dy;
      expect(october < b && b < a && a < sep, isTrue);
      expect(
        find.text('For 1 Oct · 5 Oct, 09:00 · Akmal · edited'),
        findsOneWidget,
      );
    });

    testWidgets('a failed refresh keeps the list and says so', (tester) async {
      _phone(tester);
      final me = _FakeMe()
        ..points = const [
          PointRecord(id: 1, points: 5, date: '2026-09-10', note: 'Kept'),
        ];
      await tester.pumpWidget(_app(MyPointsPage(repository: me, userId: 42)));
      await tester.pumpAndSettle();
      me.pointsError = Exception('offline');
      await tester.fling(find.text('Kept'), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(me.asked, [42, 42]);
      expect(find.text('Kept'), findsOneWidget);
      expect(find.text("Couldn't refresh your points."), findsOneWidget);
    });

    testWidgets('reset clears the period and the category', (tester) async {
      _phone(tester);
      final me = _FakeMe()
        ..points = const [
          PointRecord(
            id: 1,
            points: 5,
            date: '2020-01-01',
            note: 'Old',
            categoryId: 1,
            categoryName: 'Bonus',
          ),
          PointRecord(id: 2, points: 1, date: '2020-01-02', note: 'Other'),
        ];
      await tester.pumpWidget(_app(MyPointsPage(repository: me, userId: 42)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('More filters'));
      await tester.pumpAndSettle();
      expect(find.text('Reset filters'), findsNothing);
      await tester.tap(find.text('Bonus'));
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsNothing);
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text('Other'), findsOneWidget);
      expect(find.text('Old'), findsOneWidget);
      expect(find.text('Reset filters'), findsNothing);
    });

    testWidgets('the eye hides every amount and is remembered', (tester) async {
      _phone(tester);
      final me = _FakeMe()
        ..categories = const [FundingCategory(id: 1, name: 'Bonus')]
        ..fundings = [_funding(1, '2026-10-01', 1000000)];
      await tester.pumpWidget(_app(MyFundingsPage(repository: me, userId: 42)));
      await tester.pumpAndSettle();
      expect(me.asked, [42]);
      expect(find.text('1 000 000 UZS'), findsWidgets);

      await tester.tap(find.byTooltip('Hide amounts'));
      await tester.pumpAndSettle();
      expect(find.textContaining('000'), findsNothing);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('my_fundings_hidden'), isTrue);
    });

    Widget tools(FakeLessonsRepository lessons, {DateTime Function()? clock}) =>
        _app(
          TeachingToolsPage(
            repository: lessons,
            random: Random(5),
            clock: clock ?? DateTime.now,
          ),
        );

    FakeLessonsRepository classroom() =>
        FakeLessonsRepository()
          ..roster = BehaviorRoster(
            myClasses: const ['7A'],
            students: [
              for (final s in _students)
                BehaviorStudent(id: s.id, fullName: s.name, className: '7A'),
              const BehaviorStudent(id: 'z', fullName: 'Z', className: '10B'),
            ],
          );

    testWidgets('shuffle makes coloured teams and remembers them', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(tools(classroom()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team Shuffle'));
      await tester.pumpAndSettle();
      expect(find.text('8/8'), findsOneWidget);

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();
      expect(find.text('Red'), findsOneWidget);
      expect(find.text('Yellow'), findsOneWidget);
      expect(find.text('Purple'), findsNothing);
      expect(find.text('Leader'), findsNWidgets(4));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('teaching-tools:teams:7A'), isNotNull);
    });

    testWidgets('an absent student is left out of the teams', (tester) async {
      _phone(tester);
      await tester.pumpWidget(tools(classroom()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team Shuffle'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('H'));
      await tester.pump();
      expect(find.text('7/8'), findsOneWidget);
      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();
      expect(find.text('H'), findsNothing);
    });

    testWidgets('the class on now comes first and its teams go to grading', (
      tester,
    ) async {
      _phone(tester);
      final lessons =
          FakeLessonsRepository(
              day: const LessonDay(
                lessons: [
                  TeacherLesson(
                    id: 1,
                    instanceId: 55,
                    subject: 'Physics',
                    classLabel: '10B',
                    startTime: '10:00:00',
                    endTime: '10:45:00',
                  ),
                ],
              ),
            )
            ..roster = const BehaviorRoster(
              myClasses: ['7A'],
              students: [
                BehaviorStudent(id: '1', fullName: 'A', className: '7A'),
                BehaviorStudent(id: '11', fullName: 'P', className: '10B'),
                BehaviorStudent(id: '12', fullName: 'Q', className: '10B'),
                BehaviorStudent(id: '13', fullName: 'R', className: '10B'),
                BehaviorStudent(id: '14', fullName: 'S', className: '10B'),
              ],
            );
      TeacherLesson? graded;
      Map<int, TeamMark>? sent;
      await tester.pumpWidget(
        _app(
          TeachingToolsPage(
            repository: lessons,
            random: Random(5),
            clock: () => DateTime(2026, 11, 27, 10, 15),
            gradeWithTeams: (lesson, teams) {
              graded = lesson;
              sent = teams;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Team Shuffle'));
      await tester.pumpAndSettle();

      // 10B is on now: listed first and picked over the teacher's own 7A.
      expect(
        tester.getTopLeft(find.text('10B')).dx,
        lessThan(tester.getTopLeft(find.text('7A')).dx),
      );
      expect(find.text('4/4'), findsOneWidget);
      expect(find.textContaining('Grade 10B'), findsNothing);

      await tester.tap(find.text('Shuffle'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.textContaining('Grade 10B'),
        200,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .first,
      );
      await tester.tap(find.textContaining('Grade 10B'));
      expect(graded?.instanceId, 55);
      expect(sent!.keys.toSet(), {11, 12, 13, 14});
      expect(sent!.values.map((t) => t.order).toSet(), {0, 1, 2, 3});

      // Another class has no grading button.
      await tester.tap(find.text('7A'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Grade 10B'), findsNothing);
    });

    test('the grading sheet groups students by team, the rest last', () {
      SheetStudent s(int id) => SheetStudent(studentId: id, fullName: '$id');
      final ordered = orderByTeam(
        [s(1), s(2), s(3), s(4)],
        {
          3: (color: const Color(0xFFEF4444), order: 0),
          1: (color: const Color(0xFF3B82F6), order: 1),
          4: (color: const Color(0xFFEF4444), order: 0),
        },
      );
      expect(ordered.map((e) => e.studentId), [3, 4, 1, 2]);
    });

    testWidgets('the picker lands on a name and counts down the round', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(tools(classroom()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Name Picker'));
      await tester.pumpAndSettle();
      expect(find.text('8/8'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.casino_rounded));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(find.text('7/8'), findsOneWidget);
    });

    testWidgets('the timer follows the clock and stops at zero', (
      tester,
    ) async {
      _phone(tester);
      var now = DateTime(2026, 11, 11, 9);
      await tester.pumpWidget(tools(classroom(), clock: () => now));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timer'));
      await tester.pumpAndSettle();
      expect(find.text('05:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Start'));
      await tester.pump();
      now = now.add(const Duration(seconds: 90));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('03:30'), findsOneWidget);

      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('00:00'), findsOneWidget);
      expect(find.byTooltip('Start'), findsOneWidget);
    });
  });
}
