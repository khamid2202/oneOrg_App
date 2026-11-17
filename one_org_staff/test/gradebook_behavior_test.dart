import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/behavior/presentation/behavior_page.dart';
import 'package:one_org_staff/features/grades/domain/gradebook.dart';
import 'package:one_org_staff/features/grades/presentation/gradebooks_page.dart';
import 'package:one_org_staff/features/lessons/application/lessons_outbox.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lessons_repository.dart';

const _pairs = [
  GradebookPair(groupId: 2, className: '8B', subjectId: 9, subject: 'Physics'),
  GradebookPair(
    groupId: 1,
    className: '7A',
    subjectId: 5,
    subject: 'Math',
    teaches: true,
  ),
  GradebookPair(
    groupId: 1,
    className: '7A',
    subjectId: 3,
    subject: 'Algebra',
    teaches: true,
  ),
  GradebookPair(groupId: 1, className: '7A', subjectId: 1, subject: 'Art'),
];

Gradebook _book() => Gradebook.fromJson({
  'students': [
    {'student_id': 1, 'person_id': 11, 'name': 'Karimov Aziz Olim'},
    {'student_id': 2, 'person_id': 12, 'name': 'Bekova Lola'},
    {'student_id': 3, 'person_id': 13, 'name': 'Solo'},
  ],
  'lessons': [
    {'lesson_id': 100, 'date': '2026-09-02', 'start_time': '08:30:00'},
    {'lesson_id': 101, 'date': '2026-10-05', 'start_time': '08:30:00'},
  ],
  'exams': [
    {
      'exam_id': 7,
      'period': 'September',
      'date': '2026-09-20',
      'max_score': 40,
    },
  ],
  'grades': {
    '1': {
      '100': {'score': 60, 'comment': ''},
      '101': {'score': 80, 'imported': true},
    },
    '2': {
      '100': {'score': '90.5', 'comment': 'Good'},
    },
  },
  'exam_results': {
    '11': {'7': 30},
  },
});

List<BehaviorStudent> _students(
  String cls,
  int count, {
  String name = 'Pupil',
}) => [
  for (var i = 0; i < count; i++)
    BehaviorStudent(
      id: '$cls-$i',
      fullName: '$name $cls ${i.toString().padLeft(2, '0')}',
      className: cls,
    ),
];

const _reasons = BehaviorReasons(
  positive: [BehaviorReason(id: 'respect', label: 'Respect')],
  negative: [BehaviorReason(id: 'rules', label: 'Broke the rules')],
);

Widget _app(Widget child) => MaterialApp(
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
  home: Scaffold(body: child),
);

void main() {
  group('gradebook', () {
    test('classes they teach come first and merge across subjects', () {
      final classes = gradebookClasses(_pairs);
      expect(classes.map((c) => c.name), ['7A', '8B']);
      expect(classes.first.teaches, isTrue);
    });

    test('subjects they teach come first, then by name', () {
      expect(gradebookSubjects(_pairs, 1).map((p) => p.subject), [
        'Algebra',
        'Math',
        'Art',
      ]);
    });

    test('short names keep the surname and an initial', () {
      final students = _book().students;
      expect(students[0].shortName, 'Karimov A.');
      expect(students[2].shortName, 'Solo');
    });

    test('parses strings and drops empty comments', () {
      final book = _book();
      expect(book.grades[2]![100]!.score, 90.5);
      expect(book.grades[2]![100]!.comment, 'Good');
      expect(book.grades[1]![100]!.comment, isNull);
      expect(book.grades[1]![101]!.imported, isTrue);
    });

    test('a broken payload is an empty gradebook', () {
      expect(Gradebook.fromJson(const {'grades': 'x'}).isEmpty, isTrue);
    });

    test('averages ignore students and lessons with no grade', () {
      final view = _book().view();
      expect(view.rows[0].dailyAverage, 70);
      expect(view.rows[2].dailyAverage, isNull);
      expect(view.classDaily, [75.3, 80]);
      expect(view.classDailyAverage, 80.3);
    });

    test('exams show as a percent of their maximum', () {
      final view = _book().view();
      expect(view.rows[0].exams.single!.percent, 75);
      expect(view.rows[0].exams.single!.score, 30);
      expect(view.rows[1].exams.single, isNull);
      expect(view.classExams, [75]);
    });

    test('a month narrows lessons, exams and the averages', () {
      final book = _book();
      expect(book.months, ['2026-09', '2026-10']);
      final view = book.view(month: '2026-10');
      expect(view.lessons.map((l) => l.lessonId), [101]);
      expect(view.exams, isEmpty);
      expect(view.rows[0].dailyAverage, 80);
      expect(view.rows[1].dailyAverage, isNull);
    });

    test('sorting puts the ungraded last', () {
      final names = _book()
          .view(sortByAverage: true)
          .rows
          .map((r) => r.student.name);
      expect(names, ['Bekova Lola', 'Karimov Aziz Olim', 'Solo']);
    });

    testWidgets('opens on the class and subject it was given', (tester) async {
      final loads = <(int, int)>[];
      await tester.pumpWidget(
        _app(
          GradebooksPage(
            loadPairs: () async => _pairs,
            loadGradebook: (group, subject) async {
              loads.add((group, subject));
              return _book();
            },
            initialGroupId: 2,
            initialSubjectId: 9,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(loads, [(2, 9)]);
      expect(find.text('Physics'), findsWidgets);
    });

    testWidgets('says so when nothing is assigned', (tester) async {
      await tester.pumpWidget(
        _app(
          GradebooksPage(
            loadPairs: () async => const [],
            loadGradebook: (_, _) async => const Gradebook(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No classes assigned to you yet.'), findsOneWidget);
    });
  });

  group('history and statistics payloads', () {
    test('statistics read the summary and the groups', () {
      final stats = BehaviorStatistics.fromJson(const {
        'summary': {'total': 5, 'positive': 3, 'negative': 2},
      });
      expect(stats.total, 5);
      expect(stats.positive, 3);
      expect(stats.negative, 2);
      expect(stats.byClass, isEmpty);
    });

    test('history keeps a missing reason empty', () {
      final entry = BehaviorHistoryEntry.fromJson(const {
        'id': 'a',
        'studentName': 'Lola',
        'className': '7A',
        'type': behaviorNegative,
        'createdAt': '2026-11-11T08:00:00Z',
      });
      expect(entry.reasonLabel, isNull);
      expect(entry.createdAt, isNotNull);
    });
  });

  group('Report Student', () {
    late FakeLessonsRepository repository;
    late LessonsOutbox outbox;

    Future<void> open(WidgetTester tester, BehaviorRoster roster) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      repository = FakeLessonsRepository(reasons: _reasons)..roster = roster;
      outbox = LessonsOutbox(upload: repository.upload);
      addTearDown(outbox.dispose);
      await tester.pumpWidget(
        _app(BehaviorPage(repository: repository, outbox: outbox)),
      );
      await tester.pumpAndSettle();
    }

    BehaviorRoster roster({int inHome = 3}) => BehaviorRoster(
      students: [..._students('7A', inHome), ..._students('8B', 2)],
      myClasses: const ['7A'],
      homeroomClass: '7A',
    );

    FilledButton action(WidgetTester tester) =>
        tester.widget<FilledButton>(find.byType(FilledButton));

    testWidgets('opens on the homeroom class', (tester) async {
      await open(tester, roster());
      expect(find.text('7A · mine'), findsOneWidget);
      expect(find.text('Pupil 7A 00'), findsOneWidget);
      expect(find.text('Pupil 8B 00'), findsNothing);
      expect(action(tester).onPressed, isNull);
    });

    testWidgets('searching reaches the whole school', (tester) async {
      await open(tester, roster());
      await tester.enterText(find.byType(TextField), '8b 01');
      await tester.pump();
      expect(find.text('Pupil 8B 01'), findsOneWidget);
      expect(find.text('8B'), findsOneWidget);
      expect(find.text('Pupil 7A 00'), findsNothing);
    });

    testWidgets('needs a reason or a comment before saving', (tester) async {
      await open(tester, roster());
      await tester.tap(find.text('Pupil 7A 00'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Positive'));
      await tester.pumpAndSettle();
      expect(action(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pump();
      expect(action(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField), 'Helped a friend');
      await tester.pump();
      expect(action(tester).onPressed, isNotNull);
      expect(find.text('Save for Pupil 7A 00'), findsOneWidget);
    });

    testWidgets('changing the type clears the reasons', (tester) async {
      await open(tester, roster());
      await tester.tap(find.text('Pupil 7A 00'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Positive'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Respect'));
      await tester.pump();
      expect(action(tester).onPressed, isNotNull);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs attention'));
      await tester.pumpAndSettle();
      expect(find.text('Broke the rules'), findsOneWidget);
      expect(action(tester).onPressed, isNull);
    });

    testWidgets('saves through the outbox in batches of 50', (tester) async {
      await open(tester, roster(inHome: 60));
      await tester.tap(find.text('Select all'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Needs attention'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Broke the rules'));
      await tester.pump();
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('Saved for 60 students'), findsOneWidget);
      expect(find.text('Mark more in 7A'), findsOneWidget);
      final saves = repository.behaviorSaves;
      expect(saves.map((b) => (b['studentIds'] as List).length), [50, 10]);
      expect(saves.first['type'], behaviorNegative);
      expect(saves.first['reasonIds'], ['rules']);
      expect(saves.first.containsKey('lessonInstanceId'), isFalse);
      expect(saves[0]['requestId'], isNot(saves[1]['requestId']));
      expect(repository.historyLoads, greaterThan(1));
    });

    testWidgets('a half-finished mark survives a look at History', (
      tester,
    ) async {
      await open(tester, roster());
      await tester.tap(find.text('Pupil 7A 00'));
      await tester.pump();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark'));
      await tester.pumpAndSettle();
      expect(find.text('Next · Pupil 7A 00'), findsOneWidget);
    });

    testWidgets('statistics bars have height', (tester) async {
      await open(tester, roster());
      repository.statistics = BehaviorStatistics.fromJson(const {
        'summary': {'total': 4, 'positive': 3, 'negative': 1},
        'byClass': [
          {'className': '7A', 'positive': 3, 'negative': 1, 'total': 4},
        ],
      });
      await tester.pumpWidget(
        _app(
          BehaviorPage(
            key: const ValueKey('again'),
            repository: repository,
            outbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stats'));
      await tester.pumpAndSettle();
      final bar = find.byWidgetPredicate(
        (w) => w is ColoredBox && w.color == const Color(0xFF10B981),
      );
      expect(tester.getSize(bar).height, 8);
    });

    testWidgets('history filters by type and class', (tester) async {
      await open(tester, roster());
      repository.history = const [
        BehaviorHistoryEntry(
          id: '1',
          studentName: 'Lola B',
          className: '7A',
          type: behaviorPositive,
          reasonLabel: 'Respect',
        ),
        BehaviorHistoryEntry(
          id: '2',
          studentName: 'Aziz K',
          className: '8B',
          type: behaviorNegative,
          comment: 'Late again',
        ),
      ];
      await tester.pumpWidget(
        _app(
          BehaviorPage(
            key: const ValueKey('again'),
            repository: repository,
            outbox: outbox,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Late again'), findsOneWidget);
      expect(find.text('Respect'), findsOneWidget);

      await tester.tap(find.text('Positive'));
      await tester.pump();
      expect(find.text('Late again'), findsNothing);

      await tester.tap(find.text('All'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '8b');
      await tester.pump();
      expect(find.text('Respect'), findsNothing);
      expect(find.text('Late again'), findsOneWidget);
    });
  });
}
