import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/lesson_plans/annual_plans.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/features/lessons/presentation/plan_week_badge.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';

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

LessonPlan _detail() => LessonPlan.fromJson({
  'id': 3,
  'title': 'STEM 4-5',
  'subject': 'STEM',
  'teacher_id': 15,
  'grades': [5, 4],
  'group_ids': [],
  'week_count': 2,
  'weeks': [
    {
      'week_no': 2,
      'start_date': '2026-09-07',
      'end_date': '2026-09-11',
      'unit': 'Carnival of Collisions',
      'topic': 'The Anchor',
      'objectives': 'Describe a collision.\n\nName the striker.',
      'homework': 'Lesson 2: Decorate the cover',
    },
    {
      'week_no': 1,
      'start_date': '2026-09-02',
      'end_date': '2026-09-04',
      'topic': 'Orientation week',
    },
  ],
});

void main() {
  group('plan week on lessons', () {
    test('lessons read their plan week, and lessons without one stay null', () {
      final lesson = TeacherLesson.fromJson({
        'id': 1,
        'subject': 'Maths',
        'class_pair_compact': '7B',
        'plan_week': {
          'plan_id': 3,
          'week_no': 6,
          'unit': 'Fractions',
          'topic': 'Adding fractions',
        },
      });
      expect(lesson.planWeek?.weekNo, 6);
      expect(lesson.planWeek?.topic, 'Adding fractions');
      expect(
        TeacherLesson.fromJson({
          'id': 2,
          'subject': 'Maths',
          'plan_week': null,
        }).planWeek,
        isNull,
      );
      expect(
        LessonDetail.fromJson({
          'id': 9,
          'plan_week': {'week_no': 2, 'topic': 'The Anchor'},
        }).planWeek?.topic,
        'The Anchor',
      );
    });

    testWidgets('the badge shows the week and topic, and the unit when asked', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          const PlanWeekBadge(
            week: PlanWeek(weekNo: 6, unit: 'Fractions', topic: 'Adding'),
            showUnit: true,
          ),
        ),
      );
      expect(find.text('W6'), findsOneWidget);
      expect(
        find.text('Adding · Fractions', findRichText: true),
        findsOneWidget,
      );
    });
  });

  group('annual plan', () {
    test('a plan sorts its weeks and splits objectives into lines', () {
      final plan = _detail();
      expect(plan.weeks.map((w) => w.weekNo), [1, 2]);
      expect(plan.grades, [4, 5]);
      expect(plan.weeks.last.objectives, [
        'Describe a collision.',
        'Name the striker.',
      ]);
      expect(plan.weeks.last.contains(DateTime(2026, 9, 11, 15)), isTrue);
      expect(plan.weeks.last.contains(DateTime(2026, 9, 12)), isFalse);
    });

    testWidgets('lists own and shared plans and opens on this week', (
      tester,
    ) async {
      final api = LessonPlansApi(
        list: () async => [
          LessonPlan.fromJson({
            'id': 3,
            'title': 'STEM 4-5',
            'subject': 'STEM',
            'teacher_id': 15,
            'grades': [4, 5],
            'week_count': 2,
          }),
          LessonPlan.fromJson({
            'id': 4,
            'title': 'STEM 6',
            'subject': 'STEM',
            'teacher_id': 20,
            'teacher': 'Karimov B.',
            'grades': [6],
            'shared': true,
            'week_count': 30,
          }),
        ],
        load: (id) async => _detail(),
      );
      await tester.pumpWidget(
        _app(
          AnnualPlansView(api: api, userId: 15, today: DateTime(2026, 9, 9)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('STEM · Grades 4, 5 · 2 weeks'), findsOneWidget);
      expect(find.text('Shared by Karimov B.'), findsOneWidget);

      await tester.tap(find.text('STEM 4-5'));
      await tester.pumpAndSettle();
      expect(find.text('The Anchor'), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('• Lesson 2: Decorate the cover'), findsOneWidget);
    });

    testWidgets('an empty list points to the web', (tester) async {
      await tester.pumpWidget(
        _app(
          AnnualPlansView(
            api: LessonPlansApi(
              list: () async => const [],
              load: (_) async => _detail(),
            ),
            userId: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('No annual plans yet'), findsOneWidget);
    });
  });
}
