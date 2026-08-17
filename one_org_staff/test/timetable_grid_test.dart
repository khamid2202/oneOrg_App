import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/timetable/domain/timetable_grid.dart';
import 'package:one_org_staff/features/timetable/presentation/timetable_page.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';

TimetableLesson _lesson({
  int? id,
  String title = 'Maths',
  int dayIndex = 1,
  int timeId = 2,
  int groupId = 5,
  String groupLabel = '10-A',
  int? teacherId = 12,
  String? teacherLabel = 'John Doe',
  String timeLabel = '2nd lesson',
  String? start = '08:30:00',
  String? end = '09:15:00',
  bool isText = false,
}) {
  return TimetableLesson(
    id: id,
    title: title,
    timeLabel: timeLabel,
    groupLabel: groupLabel,
    teacherLabel: teacherLabel,
    groupId: groupId,
    teacherId: teacherId,
    dayIndex: dayIndex,
    timeId: timeId,
    startTime: start,
    endTime: end,
    isTextLesson: isText,
  );
}

const _year = AcademicYearEntry(id: 1, name: '2025-2026', isActive: true);

const _profile = AppUserProfile(
  id: 12,
  fullName: 'John Doe',
  subtitle: 'Teacher',
  email: 'john@example.com',
  phone: '+1',
  department: 'Maths',
  joinedDate: '01 Jan 2026',
);

Widget _wrap(
  List<TimetableLesson> lessons, {
  AppUserProfile profile = _profile,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: TimetablePage(
          loadTimetable: ({int? academicYearId}) async => lessons,
          loadProfile: () async => profile,
          loadAcademicYears: () async => const [_year],
        ),
      ),
    ),
  );
}

void main() {
  group('TimetableSlot', () {
    test('drops the seconds the API sends', () {
      const slot = TimetableSlot(
        id: 1,
        label: '2nd lesson',
        start: '08:30:00',
        end: '09:15:00',
      );

      expect(slot.timeRange, '08:30 - 09:15');
      expect(slot.primaryLabel, '2nd lesson');
      expect(slot.secondaryLabel, '08:30 - 09:15');
    });

    test('falls back to the time range when the slot has no name', () {
      const slot = TimetableSlot(id: 1, start: '08:30:00', end: '09:15:00');

      expect(slot.primaryLabel, '08:30 - 09:15');
      // Nothing to add, so no second line.
      expect(slot.secondaryLabel, isNull);
    });

    test('a slot with no times at all still labels itself', () {
      const slot = TimetableSlot(id: 4);
      expect(slot.primaryLabel, 'Slot 4');
    });
  });

  group('teacher identity', () {
    test('prefers the id, since two teachers can share a name', () {
      expect(teacherKey(_lesson(teacherId: 12)), 'id:12');
    });

    test('falls back to the normalised name when there is no id', () {
      expect(
        teacherKey(_lesson(teacherId: null, teacherLabel: '  John Doe ')),
        'name:john doe',
      );
    });

    test('is null when the lesson names no teacher', () {
      expect(teacherKey(_lesson(teacherId: null, teacherLabel: null)), isNull);
    });
  });

  group('buildTimetableGrid, by teacher', () {
    test('keeps every school period as a column, even unused ones', () {
      // The teacher only works period 2, but the school also runs period 3.
      final grid = buildTimetableGrid(
        all: [
          _lesson(id: 1, timeId: 2, teacherId: 12),
          _lesson(id: 2, timeId: 3, teacherId: 99, teacherLabel: 'Other'),
        ],
        view: TimetableView.byTeacher,
        teacher: 'id:12',
      );

      // Their week keeps its shape rather than collapsing to one column.
      expect(grid.slots.map((s) => s.id), [2, 3]);
      expect(grid.at(1, 2), hasLength(1));
      expect(grid.at(1, 3), isEmpty);
    });

    test('orders columns by start time, not by id', () {
      final grid = buildTimetableGrid(
        all: [
          _lesson(id: 1, timeId: 9, start: '08:00:00', timeLabel: '1st'),
          _lesson(id: 2, timeId: 3, start: '10:00:00', timeLabel: '3rd'),
          _lesson(id: 3, timeId: 5, start: '09:00:00', timeLabel: '2nd'),
        ],
        view: TimetableView.byTeacher,
        teacher: 'id:12',
      );

      expect(grid.slots.map((s) => s.id), [9, 5, 3]);
    });

    test('shows only the chosen teacher’s lessons', () {
      final grid = buildTimetableGrid(
        all: [
          _lesson(id: 1, teacherId: 12),
          _lesson(id: 2, teacherId: 99, teacherLabel: 'Other', groupId: 6),
        ],
        view: TimetableView.byTeacher,
        teacher: 'id:12',
      );

      expect(grid.at(1, 2).single.id, 1);
    });

    test('stacks a clashing cell in class order', () {
      final grid = buildTimetableGrid(
        all: [
          _lesson(id: 1, groupId: 6, groupLabel: '10-B'),
          _lesson(id: 2, groupId: 5, groupLabel: '10-A'),
        ],
        view: TimetableView.byTeacher,
        teacher: 'id:12',
      );

      expect(grid.at(1, 2).map(classLabel), ['10-A', '10-B']);
    });
  });

  group('buildTimetableGrid, by class', () {
    test(
      'is the transpose of the teacher view: periods down, classes across',
      () {
        final grid = buildTimetableGrid(
          all: [_lesson(id: 1, timeId: 2, groupId: 5, dayIndex: 1)],
          view: TimetableView.byClass,
          dayIndex: 1,
        );

        // Row is the period, column is the class — not the other way round.
        expect(grid.at(2, 5), hasLength(1));
        expect(grid.at(5, 2), isEmpty);
      },
    );

    test('shows only the chosen day', () {
      final grid = buildTimetableGrid(
        all: [
          _lesson(id: 1, dayIndex: 1, timeId: 2, groupId: 5),
          _lesson(id: 2, dayIndex: 2, timeId: 2, groupId: 5),
        ],
        view: TimetableView.byClass,
        dayIndex: 1,
      );

      expect(grid.at(2, 5).single.id, 1);
    });

    test('every class gets a column, including one idle that period', () {
      final grid = buildTimetableGrid(
        all: [
          _lesson(id: 1, timeId: 2, groupId: 5),
          _lesson(id: 2, timeId: 2, groupId: 6, groupLabel: '10-B'),
          _lesson(id: 3, timeId: 3, groupId: 5),
        ],
        view: TimetableView.byClass,
        dayIndex: 1,
      );

      expect(grid.at(3, 5), hasLength(1));
      // 10-B has nothing in period 3; the cell is empty, not missing.
      expect(grid.at(3, 6), isEmpty);
    });
  });

  group('clash detection', () {
    test('flags a teacher booked twice in one period', () {
      final lessons = [_lesson(id: 1, groupId: 5), _lesson(id: 2, groupId: 6)];

      final clashes = findClashes(lessons);

      expect(clashes, {'id:1', 'id:2'});
    });

    test('the same period on another day is not a clash', () {
      final clashes = findClashes([
        _lesson(id: 1, dayIndex: 1),
        _lesson(id: 2, dayIndex: 2),
      ]);

      expect(clashes, isEmpty);
    });

    test('two different teachers in one period are not a clash', () {
      final clashes = findClashes([
        _lesson(id: 1, teacherId: 12),
        _lesson(id: 2, teacherId: 99, teacherLabel: 'Other'),
      ]);

      expect(clashes, isEmpty);
    });

    test('clashes are found across the whole school, not just one view', () {
      // The other half of the double-booking belongs to a different class, so
      // filtering first would hide it.
      final grid = buildTimetableGrid(
        all: [_lesson(id: 1, groupId: 5), _lesson(id: 2, groupId: 6)],
        view: TimetableView.byTeacher,
        teacher: 'id:12',
      );

      expect(grid.clashes(_lesson(id: 1, groupId: 5)), isTrue);
    });
  });

  group('option lists', () {
    test('teachers are listed once each, sorted by name', () {
      final teachers = teachersIn([
        _lesson(id: 1, teacherId: 12, teacherLabel: 'Zaynab'),
        _lesson(id: 2, teacherId: 12, teacherLabel: 'Zaynab'),
        _lesson(id: 3, teacherId: 9, teacherLabel: 'Anvar'),
      ]);

      expect(teachers.map((t) => t.label), ['Anvar', 'Zaynab']);
    });

    test('classes sort by grade numerically, so 9 comes before 10', () {
      final classes = classesIn([
        _lesson(id: 1, groupId: 1, groupLabel: '10-A'),
        _lesson(id: 2, groupId: 2, groupLabel: '9-B'),
      ]);

      expect(classes.map((c) => c.label), ['9-B', '10-A']);
    });

    test('days list only the weekdays that have lessons, in order', () {
      expect(
        daysIn([_lesson(id: 1, dayIndex: 3), _lesson(id: 2, dayIndex: 1)]),
        [1, 3],
      );
    });
  });

  group('TimetablePage', () {
    testWidgets('opens on the signed-in teacher’s own week', (tester) async {
      await tester.pumpWidget(
        _wrap([
          _lesson(id: 1, teacherId: 12, teacherLabel: 'John Doe'),
          _lesson(
            id: 2,
            teacherId: 99,
            teacherLabel: 'Aisha Karim',
            groupId: 6,
            groupLabel: '10-B',
            title: 'Biology',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maths'), findsOneWidget);
      // Another teacher's lesson stays out of your week.
      expect(find.text('Biology'), findsNothing);
    });

    testWidgets('there is no way to look at another teacher’s week', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([
          _lesson(id: 1, teacherId: 12, teacherLabel: 'John Doe'),
          _lesson(
            id: 2,
            teacherId: 99,
            teacherLabel: 'Aisha Karim',
            groupId: 6,
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(find.text('Aisha Karim'), findsNothing);
    });

    testWidgets(
      'someone who teaches nothing is told so, not shown a stranger',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_lesson(id: 1, teacherId: 99, teacherLabel: 'Aisha Karim')],
            profile: const AppUserProfile(
              id: 500,
              fullName: 'Head Teacher',
              subtitle: 'Admin',
              email: 'head@example.com',
              phone: '+1',
              department: 'Office',
              joinedDate: '01 Jan 2026',
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('You have no lessons in this timetable.'),
          findsOneWidget,
        );
        expect(find.text('Maths'), findsNothing);
      },
    );

    testWidgets('matches the signed-in teacher by name when ids are absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([
          _lesson(id: 1, teacherId: null, teacherLabel: 'john doe'),
          _lesson(
            id: 2,
            teacherId: null,
            teacherLabel: 'Aisha Karim',
            groupId: 6,
            title: 'Biology',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Maths'), findsOneWidget);
      expect(find.text('Biology'), findsNothing);
    });

    testWidgets('switching to by class shows one day across the classes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([
          _lesson(id: 1, groupId: 5, groupLabel: '10-A', title: 'Maths'),
          _lesson(
            id: 2,
            groupId: 6,
            groupLabel: '10-B',
            title: 'Biology',
            teacherId: 99,
            teacherLabel: 'Aisha',
          ),
        ]),
      );
      await tester.pumpAndSettle();

      // By teacher, the other teacher's class is not shown.
      expect(find.text('Biology'), findsNothing);

      await tester.tap(find.text('By class'));
      await tester.pumpAndSettle();

      // Both classes now appear, and the axes have swapped: classes head the
      // columns, periods label the rows.
      expect(find.text('Maths'), findsOneWidget);
      expect(find.text('Biology'), findsOneWidget);
      expect(find.text('Period'), findsOneWidget);
      expect(find.text('Weekday'), findsNothing);
      expect(find.text('2nd lesson'), findsWidgets);
      expect(find.text('10-A'), findsWidgets);
      expect(find.text('10-B'), findsWidgets);
    });

    testWidgets('the by-teacher view keeps days down and periods across', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap([_lesson(id: 1)]));
      await tester.pumpAndSettle();

      expect(find.text('Weekday'), findsOneWidget);
      expect(find.text('Period'), findsNothing);
      // Days label the rows.
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
    });

    testWidgets('by class opens on today', (tester) async {
      // Lessons on every weekday, so today is always among them.
      await tester.pumpWidget(
        _wrap([
          for (final day in kWeekdayIndexes)
            _lesson(id: day, dayIndex: day, title: 'Lesson $day'),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('By class'));
      await tester.pumpAndSettle();

      final today = DateTime.now().weekday;
      if (kWeekdayIndexes.contains(today)) {
        expect(find.text(kWeekdayLabels[today]!), findsWidgets);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Lesson $today'), findsOneWidget);
      } else {
        // At the weekend there is no "today" to show, so it falls back.
        expect(find.text('Today'), findsNothing);
        expect(find.text('Mon'), findsWidgets);
      }
    });

    testWidgets('falls back to the first teaching day when today has none', (
      tester,
    ) async {
      // Only Wednesday is taught, so today can never be the default.
      await tester.pumpWidget(
        _wrap([_lesson(id: 1, dayIndex: 3, title: 'Wednesday lesson')]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('By class'));
      await tester.pumpAndSettle();

      expect(find.text('Wed'), findsWidgets);
      expect(find.text('Wednesday lesson'), findsOneWidget);
    });

    testWidgets('the arrows step through the days and stop at each end', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap([
          _lesson(id: 1, dayIndex: 1, title: 'Monday lesson'),
          _lesson(id: 2, dayIndex: 2, title: 'Tuesday lesson'),
          _lesson(id: 3, dayIndex: 3, title: 'Wednesday lesson'),
        ]),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('By class'));
      await tester.pumpAndSettle();

      IconButton back() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
      );
      IconButton forward() => tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );

      // Walk to the first day, wherever today put us.
      while (back().onPressed != null) {
        await tester.tap(
          find.widgetWithIcon(IconButton, Icons.chevron_left_rounded),
        );
        await tester.pumpAndSettle();
      }

      expect(find.text('Monday lesson'), findsOneWidget);
      // Nowhere further back to go.
      expect(back().onPressed, isNull);

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tuesday lesson'), findsOneWidget);
      expect(find.text('Monday lesson'), findsNothing);

      await tester.tap(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wednesday lesson'), findsOneWidget);
      // Last taught day, so forward is spent.
      expect(forward().onPressed, isNull);
    });

    testWidgets('a text lesson renders as a note', (tester) async {
      await tester.pumpWidget(
        _wrap([_lesson(id: 1, title: 'Class meeting', isText: true)]),
      );
      await tester.pumpAndSettle();

      expect(find.text('NOTE'), findsOneWidget);
      expect(find.text('Class meeting'), findsOneWidget);
    });

    testWidgets('an empty timetable names the year it looked in', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const []));
      await tester.pumpAndSettle();

      expect(
        find.text('No timetable published for 2025-2026.'),
        findsOneWidget,
      );
    });

    testWidgets('an unresolved academic year says so, not "not published"', (
      tester,
    ) async {
      // The timetable is stored per year, so without one the request comes
      // back empty — reporting that as "nothing published" sends the reader
      // looking for the wrong problem.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetablePage(
                loadTimetable: ({int? academicYearId}) async => const [],
                loadProfile: () async => _profile,
                loadAcademicYears: () async =>
                    throw const AuthFailure('years down'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Could not work out the academic year'),
        findsOneWidget,
      );
    });

    testWidgets('the timetable is requested for the active year', (
      tester,
    ) async {
      int? requestedYear;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetablePage(
                loadTimetable: ({int? academicYearId}) async {
                  requestedYear = academicYearId;
                  return [_lesson(id: 1)];
                },
                loadProfile: () async => _profile,
                loadAcademicYears: () async => const [
                  AcademicYearEntry(id: 7, name: '2024-2025', isActive: false),
                  AcademicYearEntry(id: 8, name: '2025-2026', isActive: true),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The active year, not simply the first one listed.
      expect(requestedYear, 8);
    });

    testWidgets('a load failure shows the reason and offers a retry', (
      tester,
    ) async {
      var attempts = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetablePage(
                loadTimetable: ({int? academicYearId}) async {
                  attempts++;
                  if (attempts == 1) {
                    throw const AuthFailure('Forbidden');
                  }
                  return [_lesson(id: 1)];
                },
                loadProfile: () async => _profile,
                loadAcademicYears: () async => const [_year],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forbidden'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Maths'), findsOneWidget);
    });

    testWidgets('a profile failure says so, and by class still works', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimetablePage(
                loadTimetable: ({int? academicYearId}) async => [
                  _lesson(id: 1, teacherId: 99, teacherLabel: 'Aisha Karim'),
                ],
                loadProfile: () async => throw const AuthFailure('no profile'),
                loadAcademicYears: () async => const [_year],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Without a profile there is nobody to show a personal week for — and
      // guessing a teacher would show someone else's.
      expect(
        find.textContaining('Could not work out who is signed in'),
        findsOneWidget,
      );

      await tester.tap(find.text('By class'));
      await tester.pumpAndSettle();

      expect(find.text('Maths'), findsOneWidget);
    });
  });
}
