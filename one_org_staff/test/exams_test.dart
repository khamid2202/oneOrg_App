import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';
import 'package:one_org_staff/features/exams/data/http_exams_repository.dart';
import 'package:one_org_staff/features/exams/domain/exams_repository.dart';
import 'package:one_org_staff/features/exams/presentation/exams_page.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';

const _profile = AppUserProfile(
  id: 11,
  fullName: 'Ahror Teacher',
  subtitle: 'Teacher',
  email: 'teacher@oneorg.uz',
  phone: '+998 90 123 45 67',
  department: 'Mathematics',
  joinedDate: '12 Sep 2024',
  username: 'ahror',
  status: 'active',
  roles: ['teacher'],
);

const _midterm = ExamPeriod(id: 3, name: 'Midterm 2026', date: '2026-03-25');
const _final = ExamPeriod(id: 4, name: 'Final 2026', date: '2026-05-30');

/// One exam of the signed-in teacher's, and one of somebody else's.
const _myExam = Exam(
  id: 12,
  examPeriodId: 3,
  subjectId: 7,
  maxScore: 100,
  groupIds: [5],
  createdBy: 11,
);
const _someoneElsesExam = Exam(
  id: 13,
  examPeriodId: 3,
  subjectId: 8,
  maxScore: 50,
  groupIds: [6],
  createdBy: 99,
);

/// The teacher takes Maths in 5-B and homeroom in 5-B; another teacher's
/// Physics lesson is in the same timetable and must not leak into the pickers.
final _timetable = [
  const TimetableLesson(
    title: 'Mathematics',
    timeLabel: '08:30',
    subjectId: 7,
    groupId: 5,
    groupLabel: '5-B',
    teacherId: 11,
  ),
  const TimetableLesson(
    title: 'Homeroom',
    timeLabel: '08:00',
    subjectId: 9,
    groupId: 5,
    groupLabel: '5-B',
    teacherId: 11,
  ),
  const TimetableLesson(
    title: 'Physics',
    timeLabel: '09:30',
    subjectId: 8,
    groupId: 6,
    groupLabel: '6-A',
    teacherId: 99,
  ),
];

final _students = [
  const StudentEntry(id: 101, personId: 201, fullName: 'Aziza Karimova'),
  const StudentEntry(id: 102, personId: 202, fullName: 'Bekzod Aliyev'),
  const StudentEntry(
    id: 103,
    personId: 203,
    fullName: 'Ketgan Talaba',
    status: 'left',
  ),
];

/// Records every write the page makes, so the tests can assert on the payloads
/// rather than only on what renders.
class _ExamsRecorder {
  final List<Map<String, Object?>> createdExams = [];
  final List<int> deletedExams = [];
  final List<ExamResultDraft> createdResults = [];
  final List<MapEntry<int, double>> updatedResults = [];
  final List<int> deletedResults = [];
  final List<int?> examQueries = [];
}

ExamsApi _api(
  _ExamsRecorder recorder, {
  List<Exam> exams = const [_myExam, _someoneElsesExam],
  List<ExamPeriod> periods = const [_midterm, _final],
  List<ExamResult> results = const [],
}) {
  var examsNow = [...exams];
  var resultsNow = [...results];

  return ExamsApi(
    loadProfile: () async => _profile,
    loadAcademicYears: () async => const [
      AcademicYearEntry(id: 1, name: '2025-2026', isActive: true),
    ],
    loadExamPeriods: ({bool? isActive, int? academicYearId}) async => periods,
    loadExams: ({int? examPeriodId}) async {
      recorder.examQueries.add(examPeriodId);
      return examPeriodId == null
          ? examsNow
          : examsNow
                .where((exam) => exam.examPeriodId == examPeriodId)
                .toList();
    },
    createExam:
        ({
          required int examPeriodId,
          required int subjectId,
          required List<int> groupIds,
          required int maxScore,
        }) async {
          recorder.createdExams.add({
            'exam_period_id': examPeriodId,
            'subject_id': subjectId,
            'group_ids': groupIds,
            'max_score': maxScore,
          });
          final created = Exam(
            id: 99,
            examPeriodId: examPeriodId,
            subjectId: subjectId,
            maxScore: maxScore,
            groupIds: groupIds,
            createdBy: _profile.id,
          );
          examsNow = [...examsNow, created];
          return created;
        },
    deleteExam: (examId) async {
      recorder.deletedExams.add(examId);
      examsNow = examsNow.where((exam) => exam.id != examId).toList();
    },
    loadSubjects: () async => const [
      SubjectEntry(id: 7, name: 'Mathematics'),
      SubjectEntry(id: 8, name: 'Physics'),
      SubjectEntry(id: 9, name: 'Homeroom'),
    ],
    loadGroups: ({int? academicYearId}) async => const [
      GroupEntry(
        id: 5,
        grade: 5,
        className: 'B',
        academicYearId: 1,
        teacherIds: [11],
      ),
      GroupEntry(
        id: 6,
        grade: 6,
        className: 'A',
        academicYearId: 1,
        teacherIds: [99],
      ),
    ],
    loadColleagues: () async => const [
      Colleague(id: 11, fullName: 'Ahror Teacher'),
      Colleague(id: 99, fullName: 'Boshqa Ustoz'),
    ],
    loadTimetable: ({int? academicYearId}) async => _timetable,
    loadStudentsForGroup: (groupId, {bool includeContacts = false}) async =>
        _students,
    loadExamResults: (examId) async => resultsNow,
    createExamResultsBulk: (drafts) async {
      recorder.createdResults.addAll(drafts);
      var nextId = 500 + resultsNow.length;
      resultsNow = [
        ...resultsNow,
        for (final draft in drafts)
          ExamResult(
            id: nextId++,
            studentId: draft.studentId,
            examId: draft.examId,
            score: draft.score,
          ),
      ];
    },
    updateExamResult: ({required int resultId, required double score}) async {
      recorder.updatedResults.add(MapEntry(resultId, score));
      resultsNow = [
        for (final result in resultsNow)
          if (result.id == resultId)
            ExamResult(
              id: result.id,
              studentId: result.studentId,
              examId: result.examId,
              score: score,
            )
          else
            result,
      ];
    },
    deleteExamResult: (resultId) async {
      recorder.deletedResults.add(resultId);
      resultsNow = resultsNow.where((result) => result.id != resultId).toList();
    },
  );
}

/// The shape the landing shell gives the page: a scroll view, not a list.
Widget _wrap(ExamsApi api, {ExamsSection? section}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: ExamsPage(api: api, initialSection: section),
      ),
    ),
  );
}

void main() {
  group('HttpExamsRepository', () {
    test('reads the documented { ok, result: [...] } exam list', () async {
      late Uri requested;
      final repository = HttpExamsRepository(
        baseUrl: 'https://api.test/',
        client: MockClient((request) async {
          requested = request.url;
          return http.Response(jsonEncode({
              'ok': true,
              'result': [
                {
                  'id': 12,
                  'exam_period_id': 3,
                  'subject_id': 7,
                  'group_ids': [5, 6],
                  'max_score': 100,
                  'created_at': '2026-03-19T10:11:12.000Z',
                  'created_by': 1,
                },
              ],
            }),
            200,
          );
        }),
      );

      final exams = await repository.getExams('token', examPeriodId: 3);

      expect(requested.path, '/exams');
      expect(requested.queryParameters['exam_period_id'], '3');
      expect(exams, hasLength(1));
      expect(exams.single.groupIds, [5, 6]);
      expect(exams.single.maxScore, 100);
      expect(exams.single.createdBy, 1);
    });

    test('reads the bare array /subjects returns', () async {
      final repository = HttpExamsRepository(
        baseUrl: 'https://api.test',
        client: MockClient(
          (request) async => http.Response(jsonEncode([
              {'id': 44, 'name': 'Mathematics'},
              {'id': 45, 'name': 'Physics'},
            ]),
            200,
          ),
        ),
      );

      final subjects = await repository.getSubjects('token');

      expect(subjects.map((subject) => subject.name), [
        'Mathematics',
        'Physics',
      ]);
    });

    test('posts the create body the API documents', () async {
      late String body;
      final repository = HttpExamsRepository(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          body = request.body;
          return http.Response(jsonEncode({
              'ok': true,
              'result': {
                'id': 12,
                'exam_period_id': 3,
                'subject_id': 7,
                'group_ids': [5],
                'max_score': 80,
              },
            }),
            201,
          );
        }),
      );

      final exam = await repository.createExam(
        'token',
        examPeriodId: 3,
        subjectId: 7,
        groupIds: [5],
        maxScore: 80,
      );

      expect(jsonDecode(body), {
        'exam_period_id': 3,
        'subject_id': 7,
        'group_ids': [5],
        'max_score': 80,
      });
      expect(exam.id, 12);
    });

    test('patches one result at a time, not the rejected bulk route', () async {
      late Uri requested;
      late String method;
      final repository = HttpExamsRepository(
        baseUrl: 'https://api.test',
        client: MockClient((request) async {
          requested = request.url;
          method = request.method;
          return http.Response(jsonEncode({'ok': true}), 200);
        }),
      );

      await repository.updateExamResult('token', resultId: 55, score: 88);

      expect(method, 'PATCH');
      expect(requested.path, '/exam-results/55');
    });

    test('surfaces the API message on failure', () async {
      final repository = HttpExamsRepository(
        baseUrl: 'https://api.test',
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({'message': 'Exam already exists'}),
            409,
          ),
        ),
      );

      expect(
        () => repository.createExam(
          'token',
          examPeriodId: 3,
          subjectId: 7,
          groupIds: [5],
          maxScore: 100,
        ),
        throwsA(
          isA<AuthFailure>().having(
            (failure) => failure.message,
            'message',
            'Exam already exists',
          ),
        ),
      );
    });
  });

  group('ExamsPage hub', () {
    testWidgets('offers the two workflows the web hub offers', (tester) async {
      await tester.pumpWidget(_wrap(_api(_ExamsRecorder())));
      await tester.pumpAndSettle();

      expect(find.text('Create a new exam'), findsOneWidget);
      expect(find.text('Score the exam'), findsOneWidget);
    });

    testWidgets('opens the create form from its card', (tester) async {
      await tester.pumpWidget(_wrap(_api(_ExamsRecorder())));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create a new exam'));
      await tester.pumpAndSettle();

      expect(find.text('My Exams'), findsOneWidget);
      expect(find.text('Create exam'), findsWidgets);
    });
  });

  group('Create exam', () {
    testWidgets('offers only the teacher-taught subjects, minus Homeroom', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_api(_ExamsRecorder()), section: ExamsSection.create),
      );
      await tester.pumpAndSettle();

      // The exams list below already names subjects, so the menu's own entries
      // are what changed once it opened.
      final mathsBefore = find.text('Mathematics').evaluate().length;
      final physicsBefore = find.text('Physics').evaluate().length;

      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();

      // Mathematics is on the teacher's timetable; Homeroom is filtered out and
      // Physics belongs to another teacher.
      expect(
        find.text('Mathematics').evaluate().length,
        greaterThan(mathsBefore),
      );
      expect(find.text('Homeroom'), findsNothing);
      expect(find.text('Physics').evaluate().length, physicsBefore);
    });

    testWidgets('lists only the teacher-taught classes', (tester) async {
      await tester.pumpWidget(
        _wrap(_api(_ExamsRecorder()), section: ExamsSection.create),
      );
      await tester.pumpAndSettle();

      expect(find.widgetWithText(CheckboxListTile, '5-B'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, '6-A'), findsNothing);
    });

    testWidgets('posts a single class and the entered max score', (
      tester,
    ) async {
      final recorder = _ExamsRecorder();
      await tester.pumpWidget(
        _wrap(_api(recorder), section: ExamsSection.create),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Midterm 2026 (2026-03-25)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mathematics').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(CheckboxListTile, '5-B'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '80');
      await tester.tap(find.text('Create exam').last);
      await tester.pumpAndSettle();

      expect(recorder.createdExams, [
        {
          'exam_period_id': 3,
          'subject_id': 7,
          'group_ids': [5],
          'max_score': 80,
        },
      ]);
    });

    testWidgets('refuses to submit without a class', (tester) async {
      final recorder = _ExamsRecorder();
      await tester.pumpWidget(
        _wrap(_api(recorder), section: ExamsSection.create),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Midterm 2026 (2026-03-25)').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Create exam').last);
      await tester.pumpAndSettle();

      expect(recorder.createdExams, isEmpty);
      expect(find.text('Select a subject'), findsOneWidget);
    });

    testWidgets('shows who created each exam in the list', (tester) async {
      await tester.pumpWidget(
        _wrap(_api(_ExamsRecorder()), section: ExamsSection.create),
      );
      await tester.pumpAndSettle();

      expect(find.text('Created by Ahror Teacher'), findsOneWidget);
      expect(find.text('Created by Boshqa Ustoz'), findsOneWidget);
    });

    testWidgets('filtering by period re-queries the endpoint', (tester) async {
      final recorder = _ExamsRecorder();
      await tester.pumpWidget(
        _wrap(_api(recorder), section: ExamsSection.create),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Final 2026').last);
      await tester.pumpAndSettle();

      expect(recorder.examQueries, [null, 4]);
    });
  });

  group('Score the exam', () {
    Future<void> openGrading(WidgetTester tester, ExamsApi api) async {
      await tester.pumpWidget(_wrap(api, section: ExamsSection.score));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Midterm 2026'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mathematics'));
      await tester.pumpAndSettle();
    }

    testWidgets('lists every exam period', (tester) async {
      await tester.pumpWidget(
        _wrap(_api(_ExamsRecorder()), section: ExamsSection.score),
      );
      await tester.pumpAndSettle();

      expect(find.text('Midterm 2026'), findsOneWidget);
      expect(find.text('Final 2026'), findsOneWidget);
    });

    testWidgets("hides another teacher's exams", (tester) async {
      await tester.pumpWidget(
        _wrap(_api(_ExamsRecorder()), section: ExamsSection.score),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Midterm 2026'));
      await tester.pumpAndSettle();

      expect(find.text('1 exam in this period'), findsOneWidget);
      expect(find.text('Mathematics'), findsOneWidget);
      expect(find.text('Physics'), findsNothing);
    });

    testWidgets('grades only the enrolled students', (tester) async {
      await openGrading(tester, _api(_ExamsRecorder()));

      expect(find.text('Aziza Karimova'), findsOneWidget);
      expect(find.text('Bekzod Aliyev'), findsOneWidget);
      // The student who left the class is not on the sheet.
      expect(find.text('Ketgan Talaba'), findsNothing);
      expect(find.text('5-B — Mathematics'), findsOneWidget);
      expect(find.text('2/2 graded'), findsOneWidget);
    });

    testWidgets('creates the untouched students at zero on first save', (
      tester,
    ) async {
      final recorder = _ExamsRecorder();
      await openGrading(tester, _api(recorder));

      await tester.enterText(find.byType(TextField).first, '86');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(
        recorder.createdResults
            .map((draft) => '${draft.studentId}:${draft.score}')
            .toList(),
        ['101:86.0', '102:0.0'],
      );
      expect(recorder.updatedResults, isEmpty);
    });

    testWidgets('patches a score that already exists', (tester) async {
      final recorder = _ExamsRecorder();
      await openGrading(
        tester,
        _api(
          recorder,
          results: const [
            ExamResult(id: 55, studentId: 101, examId: 12, score: 60),
            ExamResult(id: 56, studentId: 102, examId: 12, score: 70),
          ],
        ),
      );

      await tester.enterText(find.byType(TextField).first, '90');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(recorder.updatedResults.single.key, 55);
      expect(recorder.updatedResults.single.value, 90);
      expect(recorder.createdResults, isEmpty);
      expect(recorder.deletedResults, isEmpty);
    });

    testWidgets('deletes a score that was cleared', (tester) async {
      final recorder = _ExamsRecorder();
      await openGrading(
        tester,
        _api(
          recorder,
          results: const [
            ExamResult(id: 55, studentId: 101, examId: 12, score: 60),
            ExamResult(id: 56, studentId: 102, examId: 12, score: 70),
          ],
        ),
      );

      await tester.enterText(find.byType(TextField).first, '');
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(recorder.deletedResults, [55]);
      expect(recorder.updatedResults, isEmpty);
    });

    testWidgets('rejects a score above the exam maximum', (tester) async {
      final recorder = _ExamsRecorder();
      await openGrading(tester, _api(recorder));

      await tester.enterText(find.byType(TextField).first, '150');
      await tester.pump();

      // Blur is where an out-of-range entry is rejected, as on the web.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();

      expect(find.text('Score must be between 0 and 100'), findsOneWidget);
      expect(find.widgetWithText(TextField, '150'), findsNothing);
    });

    testWidgets('warns before leaving with unsaved edits', (tester) async {
      await openGrading(tester, _api(_ExamsRecorder()));

      await tester.enterText(find.byType(TextField).first, '75');
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Back to exams'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsOneWidget);

      await tester.tap(find.text('Keep editing'));
      await tester.pumpAndSettle();

      // Still on the sheet, edit intact.
      expect(find.text('Aziza Karimova'), findsOneWidget);
    });

    testWidgets('leaves without a prompt when nothing changed', (tester) async {
      await openGrading(tester, _api(_ExamsRecorder()));

      await tester.tap(find.byTooltip('Back to exams'));
      await tester.pumpAndSettle();

      expect(find.text('Discard changes?'), findsNothing);
      expect(find.text('Created Exams'), findsOneWidget);
    });
  });
}
