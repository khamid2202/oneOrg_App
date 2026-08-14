import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/point_report/data/http_point_report_repository.dart';
import 'package:one_org_staff/features/point_report/domain/point_report_repository.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_page.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_table.dart';
import 'package:one_org_staff/features/TimeTable/time_table_repository.dart';
import 'package:one_org_staff/features/point_report/data/point_report_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

StudentPoint _point({
  int personId = 100,
  double points = 5,
  String? subject = 'Mathematics',
  String? reason = 'Homework check',
  required DateTime date,
}) {
  return StudentPoint(
    id: 1,
    personId: personId,
    points: points,
    subjectName: subject,
    reason: reason,
    date: date,
  );
}

const _year = AcademicYearEntry(id: 1, name: '2025-2026', isActive: true);

const _group = GroupEntry(
  id: 5,
  grade: 10,
  className: 'A',
  academicYearId: 1,
  teacherIds: [],
);

const _ali = StudentEntry(
  id: 900,
  personId: 100,
  fullName: 'Ali Valiyev',
  code: 'DIS260001',
  status: 'present',
);

const _laylo = StudentEntry(
  id: 901,
  personId: 101,
  fullName: 'Laylo Karimova',
  status: 'present',
);

const _left = StudentEntry(
  id: 902,
  personId: 102,
  fullName: 'Anvar Ketgan',
  status: 'left',
);

TimetableLesson _lesson(String subject, {int groupId = 5}) =>
    TimetableLesson(title: subject, timeLabel: '08:30-09:15', groupId: groupId);

Widget _wrap({
  List<StudentEntry> students = const [_ali],
  List<StudentPoint> points = const [],
  List<TimetableLesson> timetable = const [],
  Future<List<GroupEntry>> Function({int? academicYearId})? loadGroups,
  void Function(DateTime start, DateTime end)? onFetch,
  Future<void> Function(Uint8List png, String fileName)? shareImage,
  PointReportPreferences? preferences,
  Future<List<TimetableLesson>> Function()? loadTimetable,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PointReportPage(
          loadAcademicYears: () async => const [_year],
          loadGroups:
              loadGroups ?? ({int? academicYearId}) async => const [_group],
          loadStudentsForGroup:
              (groupId, {bool includeContacts = false}) async => students,
          loadPoints: ({required groupId, required start, required end}) async {
            onFetch?.call(start, end);
            return points;
          },
          loadTimetable: loadTimetable ?? () async => timetable,
          shareImage: shareImage,
          preferences: preferences,
        ),
      ),
    ),
  );
}

Future<void> _selectClass(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<GroupEntry>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('10-A').last);
  await tester.pumpAndSettle();
}

/// Seeds the stored filters so every column — including the name, which is
/// hidden by default — is showing.
void _showAllColumns() => SharedPreferences.setMockInitialValues({
  'flutter.point_report_hidden_columns': <String>[],
});

void main() {
  // Every page test starts from an empty preference store, so a choice made in
  // one test can't leak into the next.
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('StudentPoint', () {
    test('reads homework and performance out of free-text reasons', () {
      expect(
        _point(reason: 'Homework check', date: DateTime(2026, 8, 12)).category,
        PointCategory.homework,
      );
      expect(
        _point(
          reason: 'Class performance',
          date: DateTime(2026, 8, 12),
        ).category,
        PointCategory.performance,
      );
      expect(
        _point(reason: 'Quiz', date: DateTime(2026, 8, 12)).category,
        isNull,
      );
    });

    test('recognises both spellings of the attendance penalties', () {
      DateTime d = DateTime(2026, 8, 12);
      expect(
        _point(reason: 'lateness', date: d).penalty,
        AttendancePenalty.late,
      );
      expect(_point(reason: 'Late', date: d).penalty, AttendancePenalty.late);
      expect(
        _point(reason: 'absence', date: d).penalty,
        AttendancePenalty.absent,
      );
      expect(
        _point(reason: 'excused', date: d).penalty,
        AttendancePenalty.excused,
      );
      expect(_point(reason: 'Quiz', date: d).penalty, isNull);
    });

    test('a non-numeric point value counts as zero rather than throwing', () {
      final parsed = StudentPoint.fromJson(const {
        'id': 1,
        'person_id': 100,
        'points': 'not a number',
        'date': '2026-08-12',
      });

      expect(parsed.points, 0);
    });
  });

  group('DateRange', () {
    test('a week runs Monday to Sunday, as on the web', () {
      // 2026-08-12 is a Wednesday.
      final week = DateRange.weekOf(DateTime(2026, 8, 12));

      expect(week.start, DateTime(2026, 8, 10));
      expect(week.end, DateTime(2026, 8, 16));
    });

    test('a Sunday belongs to the week that started the Monday before', () {
      final week = DateRange.weekOf(DateTime(2026, 8, 16));
      expect(week.start, DateTime(2026, 8, 10));
    });

    test('previousWeek is the seven days before the range starts', () {
      final previous = DateRange.weekOf(DateTime(2026, 8, 12)).previousWeek;

      expect(previous.start, DateTime(2026, 8, 3));
      expect(previous.end, DateTime(2026, 8, 9));
    });

    test('contains ignores the time of day', () {
      final range = DateRange.singleDay(DateTime(2026, 8, 12));
      expect(range.contains(DateTime(2026, 8, 12, 23, 59)), isTrue);
      expect(range.contains(DateTime(2026, 8, 13)), isFalse);
    });
  });

  group('PointReport.aggregate', () {
    final week = DateRange.weekOf(DateTime(2026, 8, 12));

    test('buckets homework and performance within a subject', () {
      final report = PointReport.aggregate(
        points: [
          _point(reason: 'Homework', points: 5, date: DateTime(2026, 8, 10)),
          _point(reason: 'Performance', points: 3, date: DateTime(2026, 8, 11)),
        ],
        range: week,
      );

      final maths = report.totalsFor(100).subjects['Mathematics']!;
      expect(maths.homework, 5);
      expect(maths.performance, 3);
      expect(maths.total, 8);
    });

    test('an uncategorised point counts toward the total but no bucket', () {
      final report = PointReport.aggregate(
        points: [
          _point(reason: 'Quiz', points: 4, date: DateTime(2026, 8, 11)),
        ],
        range: week,
      );

      final maths = report.totalsFor(100).subjects['Mathematics']!;
      expect(maths.homework, 0);
      expect(maths.performance, 0);
      expect(maths.total, 4);
    });

    test('attendance penalties sit outside any subject', () {
      final report = PointReport.aggregate(
        points: [
          _point(reason: 'Homework', points: 5, date: DateTime(2026, 8, 11)),
          _point(
            reason: 'lateness',
            points: -2,
            subject: 'Mathematics',
            date: DateTime(2026, 8, 11),
          ),
        ],
        range: week,
      );

      final totals = report.totalsFor(100);
      expect(totals.subjects['Mathematics']!.total, 5);
      expect(totals.penalties[AttendancePenalty.late], -2);
      // The total nets the penalty off the subject points.
      expect(totals.total, 3);
    });

    test('points outside the period are ignored', () {
      final report = PointReport.aggregate(
        points: [
          _point(points: 5, date: DateTime(2026, 8, 11)),
          _point(points: 99, date: DateTime(2026, 8, 20)),
        ],
        range: week,
      );

      expect(report.totalsFor(100).total, 5);
    });

    test('the previous week is counted separately from the period', () {
      final report = PointReport.aggregate(
        points: [
          _point(points: 5, date: DateTime(2026, 8, 11)),
          // Inside the previous Mon–Sun window.
          _point(points: 7, date: DateTime(2026, 8, 5)),
        ],
        range: week,
      );

      final totals = report.totalsFor(100);
      expect(totals.total, 5);
      expect(totals.previousWeekTotal, 7);
    });

    test('keeps students apart and lists subjects sorted', () {
      final report = PointReport.aggregate(
        points: [
          _point(personId: 100, points: 5, date: DateTime(2026, 8, 11)),
          _point(
            personId: 101,
            points: 2,
            subject: 'Biology',
            date: DateTime(2026, 8, 11),
          ),
        ],
        range: week,
      );

      expect(report.totalsFor(100).total, 5);
      expect(report.totalsFor(101).total, 2);
      expect(report.subjects, ['Biology', 'Mathematics']);
    });

    test('a student with no points reports empty totals, not an error', () {
      final report = PointReport.aggregate(points: const [], range: week);

      final totals = report.totalsFor(100);
      expect(totals.isEmpty, isTrue);
      expect(totals.total, 0);
      expect(totals.previousWeekTotal, 0);
    });

    test('a point with no date is skipped', () {
      final report = PointReport.aggregate(
        points: [
          StudentPoint(id: 1, personId: 100, points: 9, subjectName: 'Maths'),
        ],
        range: week,
      );

      expect(report.totalsFor(100).total, 0);
    });
  });

  test('formatSubjectLabel title-cases and applies the web override', () {
    expect(formatSubjectLabel('m_tongue'), 'M.Toungue');
    expect(formatSubjectLabel('mother_tongue'), 'M.Toungue');
    expect(formatSubjectLabel('computer science'), 'Computer Science');
    // Acronyms are left alone.
    expect(formatSubjectLabel('ICT'), 'ICT');
  });

  group('HttpPointReportRepository', () {
    test('sends the group and date span, and follows pagination', () async {
      final pagesRequested = <String>[];

      final repository = HttpPointReportRepository(
        client: MockClient((request) async {
          pagesRequested.add(request.url.queryParameters['page']!);
          expect(request.url.path, '/student-points');
          expect(request.url.queryParameters['group_id'], '5');
          expect(request.url.queryParameters['start_date'], '2026-08-03');
          expect(request.url.queryParameters['end_date'], '2026-08-16');

          final page = int.parse(request.url.queryParameters['page']!);
          return http.Response(
            jsonEncode({
              'ok': true,
              'meta': {'total': 3, 'page': page, 'limit': 2},
              'points': page == 1
                  ? [
                      {
                        'id': 1,
                        'person_id': 100,
                        'points': 5,
                        'subject_name': 'Mathematics',
                        'reason': 'Homework',
                        'date': '2026-08-11',
                      },
                      {
                        'id': 2,
                        'person_id': 100,
                        'points': 3,
                        'subject_name': 'Biology',
                        'reason': 'Performance',
                        'date': '2026-08-12',
                      },
                    ]
                  : [
                      {
                        'id': 3,
                        'person_id': 101,
                        'points': 2,
                        'subject_name': 'Biology',
                        'reason': 'Quiz',
                        'date': '2026-08-12',
                      },
                    ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz/',
        pageSize: 2,
      );

      final points = await repository.getPoints(
        'test-token',
        groupId: 5,
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 16),
      );

      expect(pagesRequested, ['1', '2']);
      expect(points, hasLength(3));
      expect(points.first.subjectName, 'Mathematics');
    });

    test('a single short page does not trigger a second request', () async {
      var requests = 0;

      final repository = HttpPointReportRepository(
        client: MockClient((request) async {
          requests++;
          return http.Response(
            jsonEncode({
              'ok': true,
              'points': [
                {'id': 1, 'person_id': 100, 'points': 5, 'date': '2026-08-11'},
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
        pageSize: 100,
      );

      await repository.getPoints(
        'test-token',
        groupId: 5,
        start: DateTime(2026, 8, 3),
        end: DateTime(2026, 8, 16),
      );

      expect(requests, 1);
    });

    test('surfaces the API message on failure', () async {
      final repository = HttpPointReportRepository(
        client: MockClient(
          (request) async =>
              http.Response(jsonEncode({'message': 'Forbidden'}), 403),
        ),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      expect(
        () => repository.getPoints(
          'test-token',
          groupId: 5,
          start: DateTime(2026, 8, 3),
          end: DateTime(2026, 8, 16),
        ),
        throwsA(
          isA<AuthFailure>().having((e) => e.message, 'message', 'Forbidden'),
        ),
      );
    });
  });

  group('PointReportPage', () {
    testWidgets('asks for a class before showing anything', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(
        find.text('Choose a class to view the point report.'),
        findsOneWidget,
      );
    });

    testWidgets('lists students once a class is chosen', (tester) async {
      _showAllColumns();
      await tester.pumpWidget(
        _wrap(
          students: const [_laylo, _ali, _left],
          points: [_point(personId: 100, points: 5, date: DateTime.now())],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      // Sorted by name, and the student who left is not in the report.
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.text('Laylo Karimova'), findsOneWidget);
      expect(find.text('Anvar Ketgan'), findsNothing);
    });

    testWidgets('the fetch spans the previous week through the period end', (
      tester,
    ) async {
      DateTime? fetchedStart;
      DateTime? fetchedEnd;

      await tester.pumpWidget(
        _wrap(
          onFetch: (start, end) {
            fetchedStart = start;
            fetchedEnd = end;
          },
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      final thisWeek = DateRange.weekOf(DateTime.now());
      expect(fetchedStart, thisWeek.previousWeek.start);
      expect(fetchedEnd, thisWeek.end);
    });

    testWidgets('renders the web table\'s columns', (tester) async {
      _showAllColumns();
      final today = DateTime.now();

      await tester.pumpWidget(
        _wrap(
          points: [
            _point(reason: 'Homework', points: 5, date: today),
            _point(
              reason: 'Performance',
              points: 3,
              subject: 'Biology',
              date: today,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      // The web's header row, including the Uzbek name column.
      expect(find.text('No.'), findsOneWidget);
      expect(find.text('ID'), findsOneWidget);
      expect(find.text('Ism/Familya'), findsOneWidget);
      expect(find.text('Pr-week'), findsOneWidget);
      expect(find.text('Late'), findsOneWidget);
      expect(find.text('Absent'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);

      // One column per subject, in sorted order.
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);

      // The row: number, person code, name, then the per-subject cells.
      expect(find.text('1'), findsOneWidget);
      expect(find.text('DIS260001'), findsOneWidget);
      expect(find.text('Ali Valiyev'), findsOneWidget);
      expect(find.text('+5'), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      // The total, and a clean attendance record reading as "Good" twice.
      expect(find.text('+8'), findsOneWidget);
      expect(find.text('Good'), findsNWidgets(2));
    });

    testWidgets('every cell draws a gridline', (tester) async {
      // Regression: the border lived on a parent DecoratedBox while the fill
      // lived on the child Container, so the child painted straight over the
      // line and the table rendered with no grid at all.
      await tester.pumpWidget(
        _wrap(points: [_point(points: 5, date: DateTime.now())]),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      final cells = tester
          .widgetList<Container>(find.byType(Container))
          .where((c) => c.decoration is BoxDecoration)
          .map((c) => c.decoration as BoxDecoration)
          .where((d) => d.color != null && d.border != null)
          .toList();

      // Header + body cells, all of them bordered.
      expect(cells, isNotEmpty);
      for (final decoration in cells) {
        final border = decoration.border! as Border;
        expect(border.right.color, isNot(Colors.transparent));
        expect(border.right.width, greaterThan(0));
        expect(border.bottom.width, greaterThan(0));
      }
    });

    testWidgets('the ID column is wide enough for the whole code', (
      tester,
    ) async {
      // Regression: the column was pinned to 64px and codes like DIS250383
      // rendered as "DIS25…". The code is what a parent uses to identify their
      // child, so truncating it is the one thing this cell must not do.
      await tester.pumpWidget(
        _wrap(points: [_point(points: 5, date: DateTime.now())]),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      final codeFinder = find.text('DIS260001');
      expect(codeFinder, findsOneWidget);

      // The laid-out text must fit inside its cell with no overflow.
      final textWidget = tester.widget<Text>(codeFinder);
      final painter = TextPainter(
        text: TextSpan(text: textWidget.data, style: textWidget.style),
        textDirection: TextDirection.ltr,
      )..layout();

      final cellWidth = tester.getSize(codeFinder).width;
      expect(
        painter.width,
        lessThanOrEqualTo(cellWidth + 0.5),
        reason: 'code is clipped: needs ${painter.width}, has $cellWidth',
      );
      expect(painter.didExceedMaxLines, isFalse);
    });

    testWidgets('a longer code still fits', (tester) async {
      // The column measures its content, so a format change does not silently
      // start truncating.
      await tester.pumpWidget(
        _wrap(
          students: const [
            StudentEntry(
              id: 900,
              personId: 100,
              fullName: 'Ali Valiyev',
              code: 'DIS2600001234',
              status: 'present',
            ),
          ],
          points: [_point(points: 5, date: DateTime.now())],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      final codeFinder = find.text('DIS2600001234');
      final textWidget = tester.widget<Text>(codeFinder);
      final painter = TextPainter(
        text: TextSpan(text: textWidget.data, style: textWidget.style),
        textDirection: TextDirection.ltr,
      )..layout();

      expect(
        painter.width,
        lessThanOrEqualTo(tester.getSize(codeFinder).width + 0.5),
      );
    });

    testWidgets('the name column is hidden by default', (tester) async {
      // Teachers share this table with parents, so names are off unless asked
      // for — matching the web's default.
      await tester.pumpWidget(
        _wrap(points: [_point(points: 5, date: DateTime.now())]),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      expect(find.text('Ism/Familya'), findsNothing);
      expect(find.text('Ali Valiyev'), findsNothing);
      // The rest of the grid is intact.
      expect(find.text('No.'), findsOneWidget);
      expect(find.text('DIS260001'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('the column picker toggles a column off and on', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(points: [_point(points: 5, date: DateTime.now())]),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      expect(find.text('Pr-week'), findsOneWidget);

      await tester.tap(find.byTooltip('Choose columns'));
      await tester.pumpAndSettle();

      // The count reflects the hidden name column: 6 of 7 on.
      expect(find.text('6/7'), findsOneWidget);

      await tester.tap(find.widgetWithText(CheckboxListTile, 'Pr-week'));
      await tester.pumpAndSettle();
      expect(find.text('5/7'), findsOneWidget);

      await tester.tap(find.text('Clear all'));
      await tester.pumpAndSettle();
      expect(find.text('0/7'), findsOneWidget);

      await tester.tap(find.text('Select all'));
      await tester.pumpAndSettle();
      expect(find.text('7/7'), findsOneWidget);

      // Closing the sheet leaves every column showing, name included.
      Navigator.of(tester.element(find.text('Select all'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Ism/Familya'), findsOneWidget);
    });

    testWidgets('the column choice survives leaving and returning', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(points: [_point(points: 5, date: DateTime.now())]),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      await tester.tap(find.byTooltip('Choose columns'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Total'));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.text('Select all'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsNothing);

      // Rebuild the page from scratch, as navigating away and back would.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _wrap(points: [_point(points: 5, date: DateTime.now())]),
      );
      await tester.pumpAndSettle();

      // The class comes back too, so the report is where it was left.
      expect(find.text('DIS260001'), findsOneWidget);
      expect(find.text('Total'), findsNothing);
      expect(find.text('Pr-week'), findsOneWidget);
    });

    testWidgets('every timetabled subject gets a column, even with no points', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          timetable: [_lesson('Mathematics'), _lesson('Art')],
          // Only Maths was scored this week.
          points: [_point(points: 5, date: DateTime.now())],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      // Art is on the timetable, so it gets an (empty) column rather than
      // vanishing — the empty cell is the information that nothing was given.
      expect(find.text('Art'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
    });

    testWidgets('a subject from another class is not given a column', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          timetable: [
            _lesson('Mathematics'),
            _lesson('Chemistry', groupId: 99),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Chemistry'), findsNothing);
    });

    testWidgets('a subject with points but no timetable slot still shows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          timetable: [_lesson('Art')],
          points: [_point(points: 5, date: DateTime.now())],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      // Data is never hidden just because the timetable disagrees.
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Art'), findsOneWidget);
    });

    testWidgets('a timetable failure still renders the report', (tester) async {
      await tester.pumpWidget(
        _wrap(
          loadTimetable: () async => throw const AuthFailure('nope'),
          points: [_point(points: 5, date: DateTime.now())],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('+5'), findsWidgets);
    });

    testWidgets('a subject with no points for a student leaves the cell blank', (
      tester,
    ) async {
      final today = DateTime.now();

      await tester.pumpWidget(
        _wrap(
          students: const [_ali, _laylo],
          points: [
            _point(personId: 100, points: 5, date: today),
            _point(personId: 101, points: 4, subject: 'Biology', date: today),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      // Both subjects are columns, but each student only scored in one, so the
      // grid still has a cell for the other — empty, not a misleading 0.
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('+5'), findsNWidgets(2));
      expect(find.text('+4'), findsNWidgets(2));
    });

    testWidgets('rows sort by total descending, and Name toggles', (
      tester,
    ) async {
      _showAllColumns();
      final today = DateTime.now();

      await tester.pumpWidget(
        _wrap(
          students: const [_ali, _laylo],
          points: [
            _point(personId: 100, points: 2, date: today),
            _point(personId: 101, points: 9, date: today),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      List<String> names() => tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .whereType<String>()
          .where((d) => d == 'Ali Valiyev' || d == 'Laylo Karimova')
          .toList();

      // Highest total first by default.
      expect(names(), ['Laylo Karimova', 'Ali Valiyev']);

      await tester.tap(find.text('Ism/Familya'));
      await tester.pumpAndSettle();
      expect(names(), ['Ali Valiyev', 'Laylo Karimova']);

      // Tapping the active column flips it.
      await tester.tap(find.text('Ism/Familya'));
      await tester.pumpAndSettle();
      expect(names(), ['Laylo Karimova', 'Ali Valiyev']);
    });

    testWidgets('negative attendance shows the penalty instead of Good', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          points: [
            _point(
              reason: 'lateness',
              points: -2,
              subject: 'Mathematics',
              date: DateTime.now(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      expect(find.text('-2'), findsNWidgets(2));
      // Absent is still clean.
      expect(find.text('Good'), findsOneWidget);
    });

    testWidgets('sharing captures the table as a PNG with a named file', (
      tester,
    ) async {
      final shared = <(int, String)>[];

      await tester.pumpWidget(
        _wrap(
          points: [_point(points: 5, date: DateTime.now())],
          shareImage: (png, fileName) async {
            shared.add((png.length, fileName));
          },
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      // toImage() is real engine work, so it has to run outside fake-async;
      // and the button's spinner animates forever, so pumpAndSettle would
      // never return while the capture is in flight.
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(FilledButton, 'Share'));
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(shared, hasLength(1));
      // A real PNG, not an empty buffer.
      expect(shared.single.$1, greaterThan(1000));
      expect(shared.single.$2, startsWith('point-report-10-a-'));
      expect(shared.single.$2, endsWith('.png'));
    });

    testWidgets('sharing is disabled until a table has loaded', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      FilledButton shareButton() => tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Share'),
      );

      // The button sits with the title from the start, but there is nothing to
      // capture until a class is chosen.
      expect(shareButton().onPressed, isNull);

      await _selectClass(tester);

      expect(shareButton().onPressed, isNotNull);
    });

    testWidgets('the exported table drops the sort arrows', (tester) async {
      // The image is a static artifact — an arrow in it would imply the reader
      // can re-sort.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: PointReportTable(
                students: const [_ali],
                report: PointReport.aggregate(
                  points: [_point(points: 5, date: DateTime(2026, 8, 12))],
                  range: DateRange.weekOf(DateTime(2026, 8, 12)),
                ),
                subjects: const ['Mathematics'],
                columns: PointReportColumns.defaults(const ['Mathematics']),
                classLabel: 'Students in 10-A',
                periodLabel: 'Aug 10, 2026 – Aug 16, 2026',
                sort: PointReportSort.total,
                descending: true,
                forExport: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('↓'), findsNothing);
      expect(find.text('↑'), findsNothing);
      // The caption travels with the image.
      expect(find.text('Students in 10-A'), findsOneWidget);
      expect(find.text('Aug 10, 2026 – Aug 16, 2026'), findsWidgets);
    });

    testWidgets('a load failure shows the reason and offers a retry', (
      tester,
    ) async {
      _showAllColumns();
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PointReportPage(
                loadAcademicYears: () async => const [_year],
                loadGroups: ({int? academicYearId}) async => const [_group],
                loadStudentsForGroup:
                    (groupId, {bool includeContacts = false}) async {
                      attempts++;
                      if (attempts == 1) {
                        throw const AuthFailure('Forbidden');
                      }
                      return const [_ali];
                    },
                loadPoints:
                    ({required groupId, required start, required end}) async =>
                        const [],
                loadTimetable: () async => const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _selectClass(tester);

      expect(find.text('Forbidden'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Ali Valiyev'), findsOneWidget);
    });
  });
}
