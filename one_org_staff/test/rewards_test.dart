import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/MyLessons/http_lesson_points_repository.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/rewards/presentation/rewards_page.dart';

const _tenA = GroupEntry(
  id: 5,
  grade: 10,
  className: 'A',
  academicYearId: 1,
  teacherIds: [],
);

const _elevenB = GroupEntry(
  id: 6,
  grade: 11,
  className: 'B',
  academicYearId: 1,
  teacherIds: [],
);

const _ada = StudentEntry(
  id: 1,
  personId: 100,
  fullName: 'Ada Lovelace',
  groupId: 5,
  classPair: '10-A',
);

const _grace = StudentEntry(
  id: 2,
  personId: 101,
  fullName: 'Grace Hopper',
  groupId: 5,
  classPair: '10-A',
);

const _katherine = StudentEntry(
  id: 3,
  personId: 102,
  fullName: 'Katherine Johnson',
  groupId: 6,
  classPair: '11-B',
);

/// Captures what the page would send, so a test can assert on the drafts
/// without a fake HTTP layer.
class _Recorder {
  final List<List<StudentPointDraft>> saves = [];
  final List<int?> studentScopes = [];

  Future<void> save(List<StudentPointDraft> drafts) async => saves.add(drafts);
}

Widget _wrap(
  _Recorder recorder, {
  List<StudentEntry> students = const [_ada, _grace, _katherine],
  Map<int, double> totals = const {100: 12, 101: -3},
  List<GroupEntry> groups = const [_tenA, _elevenB],
}) {
  // The page scrolls itself and pins a selection bar, so it takes a bounded
  // height — the same shape the landing shell gives it.
  return MaterialApp(
    home: Scaffold(
      body: RewardsPage(
        loadGroups: ({int? academicYearId}) async => groups,
        loadStudents: ({int? groupId}) async {
          recorder.studentScopes.add(groupId);
          return groupId == null
              ? students
              : students.where((s) => s.groupId == groupId).toList();
        },
        loadPointTotals: ({int? groupId}) async => totals,
        savePoints: recorder.save,
      ),
    ),
  );
}

/// Picks [classPair] (or "All classes") from the class dropdown.
Future<void> _chooseClass(WidgetTester tester, String label) async {
  await tester.tap(find.byType(DropdownButtonFormField<int?>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  group('Rewards page', () {
    testWidgets('lists nothing until a class or a search narrows it', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a class, or search by name, to list students.'),
        findsOneWidget,
      );
      // Nothing was fetched — a school-wide roster is not worth pulling before
      // the teacher has said what they are looking for.
      expect(recorder.studentScopes, isEmpty);
      expect(find.text('Ada Lovelace'), findsNothing);
    });

    testWidgets('choosing a class loads that roster with its balances', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      await _chooseClass(tester, '10-A');

      expect(recorder.studentScopes, [5]);
      expect(find.text('Ada Lovelace'), findsOneWidget);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Katherine Johnson'), findsNothing);
      // Balances net out, so a deducted student reads negative.
      expect(find.text('12'), findsOneWidget);
      expect(find.text('-3'), findsOneWidget);
    });

    testWidgets('a name search spans every class', (tester) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'kather');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(recorder.studentScopes, [null]);
      expect(find.text('Katherine Johnson'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
      // Away from a single class, the row says which one the student is in.
      expect(find.text('11-B'), findsOneWidget);
    });

    testWidgets('re-searching within a loaded roster does not refetch', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      await _chooseClass(tester, '10-A');
      expect(recorder.studentScopes, [5]);

      await tester.enterText(find.byType(TextField).first, 'grace');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(recorder.studentScopes, [5]);
      expect(find.text('Grace Hopper'), findsOneWidget);
      expect(find.text('Ada Lovelace'), findsNothing);
    });

    testWidgets('awards the same points to every selected student', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      await _chooseClass(tester, '10-A');

      await tester.tap(find.text('Ada Lovelace'));
      await tester.tap(find.text('Grace Hopper'));
      await tester.pumpAndSettle();

      expect(find.text('2 selected'), findsOneWidget);

      await tester.tap(find.text('Give points'));
      await tester.pumpAndSettle();

      // The preset is one tap instead of typing.
      await tester.tap(find.byKey(const ValueKey('reward-preset-5')));
      await tester.pumpAndSettle();
      expect(find.text('Adding 5 pts × 2 students'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Why the points were given or taken'), 'Quiz');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Give 5 pts'));
      await tester.pumpAndSettle();

      expect(recorder.saves, hasLength(1));
      final drafts = recorder.saves.single;
      expect(drafts.map((d) => d.personId), [100, 101]);
      // Every draft carries the student's own class — a point row is filed
      // against a group, not a person alone.
      expect(drafts.every((d) => d.groupId == 5), isTrue);
      expect(drafts.every((d) => d.points == 5), isTrue);
      expect(drafts.every((d) => d.reason == 'Quiz'), isTrue);

      // The new balance shows without a refetch, and the selection resets.
      expect(find.text('17'), findsOneWidget);
      expect(find.text('2 selected'), findsNothing);
    });

    testWidgets('a negative amount deducts, and defaults its reason', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      await _chooseClass(tester, '10-A');
      await tester.tap(find.text('Ada Lovelace'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Give points'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, '0'), '-4');
      await tester.pumpAndSettle();
      expect(find.text('Deducting 4 pts × 1 student'), findsOneWidget);

      await tester.tap(find.text('Deduct 4 pts'));
      await tester.pumpAndSettle();

      final draft = recorder.saves.single.single;
      expect(draft.points, -4);
      expect(draft.reason, 'Penalty');
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('select all covers only what the search left showing', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(_wrap(recorder));
      await tester.pumpAndSettle();

      await _chooseClass(tester, '10-A');
      await tester.enterText(find.byType(TextField).first, 'ada');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      await tester.tap(find.text('Select all (1)'));
      await tester.pumpAndSettle();

      expect(find.text('1 selected'), findsOneWidget);
    });

    testWidgets('a student with no class is reported, not guessed', (
      tester,
    ) async {
      final recorder = _Recorder();
      await tester.pumpWidget(
        _wrap(
          recorder,
          students: const [
            StudentEntry(id: 9, personId: 900, fullName: 'Unplaced Student'),
          ],
          totals: const {},
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, 'unplaced');
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      await tester.tap(find.text('Unplaced Student'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Give points'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('reward-preset-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Give 1 pts'));
      await tester.pumpAndSettle();

      expect(recorder.saves, isEmpty);
      expect(
        find.text('Selected students have no class assigned.'),
        findsOneWidget,
      );
    });
  });

  group('Rewards repository', () {
    test('pages through every student and keeps the class on each row', () async {
      final pages = <String>[];
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/students');
          final page = request.url.queryParameters['page']!;
          pages.add(page);
          expect(request.url.queryParameters['limit'], '100');
          // No class chosen means the whole school — no group filter at all.
          expect(
            request.url.queryParameters.containsKey('group_id'),
            isFalse,
          );

          return http.Response(
            jsonEncode({
              'ok': true,
              'meta': {'pages': 2},
              'result': [
                {
                  'id': page == '1' ? 1 : 2,
                  'person_id': page == '1' ? 100 : 101,
                  'group_id': 5,
                  'leave_date': null,
                  'full_name': page == '1' ? 'Ada Lovelace' : 'Grace Hopper',
                  'group': {'id': 5, 'grade': 10, 'class': 'A'},
                },
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      final students = await repository.getAllStudents('test-token');

      expect(pages, ['1', '2']);
      expect(students.map((s) => s.fullName), ['Ada Lovelace', 'Grace Hopper']);
      expect(students.every((s) => s.groupId == 5), isTrue);
      expect(students.every((s) => s.classPair == '10-A'), isTrue);
    });

    test('leavers are left off the roster', () async {
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'meta': {'pages': 1},
              'result': [
                {
                  'id': 1,
                  'person_id': 100,
                  'group_id': 5,
                  'leave_date': '2026-01-10',
                  'full_name': 'Gone Student',
                },
                {
                  'id': 2,
                  'person_id': 101,
                  'group_id': 5,
                  'leave_date': null,
                  'full_name': 'Present Student',
                },
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      final students = await repository.getAllStudents(
        'test-token',
        groupId: 5,
      );

      expect(students.map((s) => s.fullName), ['Present Student']);
    });

    test('reads net balances keyed by person id', () async {
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/student-points/statistics/by-student');
          expect(request.url.queryParameters['group_id'], '5');

          return http.Response(
            jsonEncode({
              'ok': true,
              'result': [
                {
                  'person_id': 100,
                  'student_name': 'Ada Lovelace',
                  'total_records': 4,
                  'total_points': 12,
                },
                {
                  'person_id': 101,
                  'student_name': 'Grace Hopper',
                  'total_records': 2,
                  'total_points': -3,
                },
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      final totals = await repository.getPointTotalsByStudent(
        'test-token',
        groupId: 5,
      );

      expect(totals, {100: 12.0, 101: -3.0});
    });
  });
}
