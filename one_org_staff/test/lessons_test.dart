import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/lessons/application/grading_sheet_controller.dart';
import 'package:one_org_staff/features/lessons/application/lessons_outbox.dart';
import 'package:one_org_staff/features/lessons/data/offline_cache.dart';
import 'package:one_org_staff/features/lessons/data/http_lessons_repository.dart';
import 'package:one_org_staff/features/lessons/domain/day_rows.dart';
import 'package:one_org_staff/features/lessons/domain/lesson_grading.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/features/lessons/presentation/grading_sheet_page.dart';
import 'package:one_org_staff/features/lessons/presentation/lessons_page.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lessons_repository.dart';

GradingSheet sheetOf(
  List<SheetStudent> students, {
  DateTime? date,
  String? status,
}) => GradingSheet(
  lesson: LessonDetail(
    id: 7,
    subject: 'Math',
    classLabel: '7-B',
    date: date ?? DateTime.now().add(const Duration(days: 1)),
    startTime: '08:30:00',
    endTime: '09:15:00',
    status: status,
  ),
  students: students,
);

const _p1 = BellPeriod(number: 1, start: 480, end: 525);
const _p2 = BellPeriod(number: 2, start: 530, end: 575);
const _p3 = BellPeriod(number: 3, start: 580, end: 625);

TeacherLesson lessonAt(String start, String end, {String label = '7B'}) =>
    TeacherLesson(
      id: 1,
      instanceId: 7,
      subject: 'Math',
      classLabel: label,
      startTime: start,
      endTime: end,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('grading rules', () {
    test('being on time gives nothing, lateness takes points off', () {
      expect(lateDeduction(statusPresent, null), 0);
      expect(lateDeduction(statusLate, 9), -4);
      expect(lateDeduction(statusLate, 90), -20);
      expect(lateDeduction(statusAbsent, null), 0);
    });

    test('a late student loses points but never goes below 0', () {
      final draft = GradeDraft(status: statusLate, minutesLate: 9)..prefill();
      expect(draft.total, 96);
      final worst = GradeDraft(status: statusLate, minutesLate: 45)
        ..scores[materialsScore] = 5;
      expect(worst.total, 0);
    });

    test('the five categories add up to 100', () {
      expect(categoryMax.values.fold<int>(0, (a, b) => a + b), 100);
      expect(quickValuesFor(homeworkScore, gradingVersion).first, 30);
      expect(quickValuesFor(homeworkDoneScore, gradingVersion).first, 10);
    });

    test('a v1 row keeps the old math and has no "homework brought"', () {
      final draft = GradeDraft(version: 1)..prefill();
      expect(draft.scores[homeworkDoneScore], isNull);
      expect(draft.scores[homeworkScore], 20);
      expect(draft.total, 100);
    });

    test('a fresh sheet is present with full marks', () {
      final draft = GradeDraft()..prefill();
      expect(draft.status, statusPresent);
      expect(draft.total, 100);
      expect(draft.needsComment, isFalse);
    });

    test('a score under 40 needs a comment', () {
      final draft = GradeDraft(status: statusPresent)
        ..prefill()
        ..scores.updateAll((_, _) => 0);
      expect(draft.total, 0);
      expect(draft.needsComment, isTrue);
      draft.comment = 'Slept all lesson';
      expect(draft.needsComment, isFalse);
    });

    test('marking absent zeroes scores and undoing brings them back', () {
      final draft = GradeDraft(status: statusPresent)..prefill();
      draft.scores[homeworkScore] = 5;
      draft.mark(statusAbsent);
      expect(draft.scores[homeworkScore], 0);
      draft.mark(statusPresent);
      expect(draft.scores[homeworkScore], 5);
    });

    test('editing closes 3 days after the lesson, or Saturday 08:00', () {
      expect(
        editWindowClosesAt(DateTime(2026, 11, 9), '09:15:00'),
        DateTime(2026, 11, 12, 9, 15),
      );
      expect(
        editWindowClosesAt(DateTime(2026, 11, 12), '09:15:00'),
        DateTime(2026, 11, 14, 8),
      );
      // A Saturday lesson is past that Saturday's 08:00.
      expect(
        editWindowClosesAt(DateTime(2026, 11, 14), '10:00:00'),
        DateTime(2026, 11, 17, 10),
      );
    });
  });

  group('weekly graded count', () {
    TeacherLesson lesson(Map<String, dynamic> extra) => TeacherLesson.fromJson({
      'id': 1,
      'lesson_instance_id': 9,
      'subject': 'Math',
      'graded_lessons_this_week': 2,
      ...extra,
    });

    test('shows on your own gradable lesson', () {
      expect(lesson({}).showsWeeklyCount, isTrue);
      expect(lesson({}).gradedThisWeek, 2);
    });

    test('not on ungraded, cancelled, handed-over or unrecorded lessons', () {
      expect(lesson({'is_graded': false}).showsWeeklyCount, isFalse);
      expect(lesson({'status': 'cancelled'}).showsWeeklyCount, isFalse);
      expect(lesson({'substitution_type': 'cover'}).showsWeeklyCount, isFalse);
      expect(
        lesson({
          'substitution_type': 'cover',
          'is_substitution': true,
        }).showsWeeklyCount,
        isTrue,
      );
      expect(lesson({'lesson_instance_id': null}).showsWeeklyCount, isFalse);
      expect(
        lesson({'graded_lessons_this_week': null}).showsWeeklyCount,
        isFalse,
      );
    });
  });

  group('day layout', () {
    test('every bell period is kept and lessons sit on the time scale', () {
      final layout = layoutDay(const [
        _p1,
        _p2,
        _p3,
      ], LessonDay(lessons: [lessonAt('08:50', '09:35')]));
      expect(layout.periods, hasLength(3));
      expect(layout.start, 480);
      expect(layout.end, 625);
      expect(layout.taught(_p1), isFalse);
      expect(layout.taught(_p2), isTrue);
      expect(layout.items.single.item.lesson?.classLabel, '7B');
    });

    test('overlapping choice lessons share the width side by side', () {
      final layout = layoutDay(
        const [_p1],
        LessonDay(
          lessons: [
            lessonAt('08:00', '08:45'),
            lessonAt('08:00', '08:45', label: '8A'),
          ],
        ),
      );
      expect(layout.items.map((p) => p.column), [0, 1]);
      expect(layout.items.map((p) => p.columns), [2, 2]);
    });

    test('lessons that follow each other each take the full width', () {
      final layout = layoutDay(
        const [_p1, _p2],
        LessonDay(
          lessons: [lessonAt('08:00', '08:45'), lessonAt('08:50', '09:35')],
        ),
      );
      expect(layout.items.map((p) => p.columns), [1, 1]);
    });

    test('something outside the bells stretches the day', () {
      final layout = layoutDay(
        const [_p1],
        const LessonDay(
          lessons: [],
          meetings: [
            TeacherMeeting(
              title: 'Staff',
              startTime: '15:00',
              endTime: '16:00',
            ),
          ],
        ),
      );
      expect(layout.end, 16 * 60);
      expect(layout.items.single.item.meeting?.title, 'Staff');
    });

    test('no bell schedule falls back to the standard day', () {
      final layout = layoutDay(const [], const LessonDay(lessons: []));
      expect(layout.periods, hasLength(10));
      expect(layout.start, 8 * 60);
    });
  });

  group('sheet controller', () {
    late FakeLessonsRepository repository;
    late LessonsOutbox outbox;

    Future<GradingSheetController> open(
      List<SheetStudent> students, {
      DateTime? date,
      String? status,
      DateTime Function()? clock,
    }) async {
      repository = FakeLessonsRepository(
        sheet: sheetOf(students, date: date, status: status),
      );
      outbox = LessonsOutbox(upload: repository.upload);
      final sheet = GradingSheetController(
        repository: repository,
        outbox: outbox,
        lessonId: 7,
        clock: clock,
      );
      await sheet.load();
      return sheet;
    }

    SheetStudent graded(int id) => SheetStudent(
      studentId: id,
      fullName: 'Student $id',
      status: statusPresent,
      scores: {for (final field in teacherScoreFields) field: 10},
    );

    test('nothing is marked or scored when the sheet opens', () async {
      final sheet = await open([SheetStudent(studentId: 1, fullName: 'A')]);
      expect(sheet.draftOf(1)!.status, isNull);
      expect(sheet.draftOf(1)!.hasTeacherScores, isFalse);
      expect(sheet.unmarkedCount, 1);
      expect(sheet.attendanceDirty, isFalse);
      expect(sheet.scoresTouched, isFalse);
    });

    test(
      'the header checkbox marks everybody and unticking undoes it',
      () async {
        final sheet = await open([
          SheetStudent(studentId: 1, fullName: 'A'),
          SheetStudent(studentId: 2, fullName: 'B', status: statusAbsent),
        ]);
        sheet.markAll(statusPresent);
        expect(sheet.countMarked(statusPresent), 2);
        expect(sheet.attendanceDirty, isTrue);
        sheet.unmarkAll(statusPresent);
        // Back to what the server holds: unmarked, and the stored absence.
        expect(sheet.draftOf(1)!.status, isNull);
        expect(sheet.draftOf(2)!.status, statusAbsent);
        expect(sheet.attendanceDirty, isFalse);
      },
    );

    test('a category checkbox scores every present student', () async {
      final sheet = await open([
        SheetStudent(studentId: 1, fullName: 'A'),
        SheetStudent(studentId: 2, fullName: 'B'),
      ]);
      sheet.update(1, (row) => row.mark(statusPresent));
      sheet.update(2, (row) => row.mark(statusAbsent));
      sheet.fillAll(homeworkScore);
      expect(sheet.draftOf(1)!.scores[homeworkScore], 30);
      expect(sheet.draftOf(2)!.scores[homeworkScore], 0);
      expect(sheet.givenCount(homeworkScore), 1);
      expect(sheet.gradableCount(homeworkScore), 1);
      // Half graded saves as it is, and no comment is asked for yet.
      expect(sheet.problems, isEmpty);
      expect(sheet.dirtyCount, greaterThan(0));
      for (final field in teacherScoreFields) {
        sheet.fillAll(field);
      }
      expect(sheet.problems, isEmpty);
      expect(sheet.draftOf(1)!.total, 100);
      sheet.unfillAll(activityScore);
      expect(sheet.draftOf(1)!.scores[activityScore], isNull);
    });

    test('attendance saves alone and only the changed rows', () async {
      final sheet = await open([graded(1), graded(2)]);
      sheet.update(2, (row) => row.mark(statusAbsent));
      sheet.saveAttendance();
      await pumpEventQueue();
      expect(repository.attendanceSaves.single.single['student_id'], 2);
      expect(repository.attendanceSaves.single.single['status'], statusAbsent);
      expect(repository.gradeSaves, isEmpty);
      expect(sheet.attendanceDirty, isFalse);
      expect(sheet.hasUnsavedEdits, isFalse);
    });

    test('late without minutes is a problem until they are set', () async {
      final sheet = await open([graded(1)]);
      sheet.update(1, (row) => row.mark(statusLate));
      expect(sheet.problems[1], SheetProblem.minutesMissing);
      expect(sheet.lateMissingCount, 1);
      sheet.update(
        1,
        (row) => row.mark(statusLate, minutes: 9, keepMinutes: false),
      );
      expect(sheet.lateMissingCount, 0);
    });

    test('a low score without a comment is flagged', () async {
      final sheet = await open([graded(1)]);
      sheet.update(1, (row) => row.scores.updateAll((_, _) => 0));
      expect(sheet.problems[1], SheetProblem.commentRequired);
      sheet.update(1, (row) => row.comment = 'Unwell');
      expect(sheet.problems, isEmpty);
    });

    test('save sends only the fields that changed', () async {
      final sheet = await open([graded(1), graded(2)]);
      sheet.update(1, (row) => row.scores[homeworkScore] = 5);
      sheet.save();
      await pumpEventQueue();
      final grades = repository.gradeSaves.single;
      expect(grades, hasLength(1));
      expect(grades.single['student_id'], 1);
      expect(grades.single[homeworkScore], 5);
      expect(grades.single.containsKey(materialsScore), isFalse);
      expect(grades.single['client_saved_at'], isA<String>());
      expect(sheet.hasUnsavedEdits, isFalse);
    });

    test('an absent student sends no scores, only a comment', () async {
      final sheet = await open([
        SheetStudent(
          studentId: 1,
          fullName: 'A',
          status: statusAbsent,
          scores: {for (final field in teacherScoreFields) field: 0},
        ),
      ]);
      sheet.update(1, (row) => row.comment = 'Sick');
      sheet.save();
      await pumpEventQueue();
      final entry = repository.gradeSaves.single.single;
      expect(entry['comment'], 'Sick');
      expect(entry.containsKey(homeworkScore), isFalse);
    });

    test(
      'a closed window is read-only and shows only what is stored',
      () async {
        final sheet = await open(
          [SheetStudent(studentId: 1, fullName: 'A')],
          date: DateTime(2026, 11, 9),
          clock: () => DateTime(2026, 11, 13),
        );
        expect(sheet.windowClosed, isTrue);
        expect(sheet.readOnly, isTrue);
        expect(sheet.draftOf(1)!.status, isNull);
      },
    );

    test('a cancelled lesson is read-only', () async {
      final sheet = await open([graded(1)], status: 'cancelled');
      expect(sheet.readOnly, isTrue);
      expect(sheet.canGiveBehavior, isFalse);
    });

    test('a behavior mark saves at once and shows on the row', () async {
      final sheet = await open([graded(1)]);
      repository.reasons = const BehaviorReasons(
        positive: [BehaviorReason(id: 'r1', label: 'Helped')],
      );
      sheet.addBehaviorMark(
        studentId: 1,
        type: behaviorPositive,
        reasonIds: const ['r1'],
        comment: '',
      );
      await pumpEventQueue();
      expect(repository.behaviorSaves.single['lessonInstanceId'], 7);
      expect(sheet.marksOf(1), hasLength(1));
      expect(sheet.hasUnsavedEdits, isFalse);
    });
  });

  group('http repository', () {
    http.Response json(Object body) => http.Response(jsonEncode(body), 200);

    HttpLessonsRepository repositoryWith(MockClientHandler handler) =>
        HttpLessonsRepository(
          client: MockClient(handler),
          baseUrl: 'https://api.test/',
          readToken: () async => 'token',
        );

    test('the timetable is the list and records are laid over it', () async {
      final repository = repositoryWith((request) async {
        expect(request.url.queryParameters['date'], '2026-11-09');
        if (request.url.path == '/my-lessons') {
          return json({
            'lessons': [
              {
                'id': 1,
                'subject': 'Math',
                'class_pair_compact': '7B',
                'start_time': '09:00:00',
                'end_time': '09:45:00',
              },
              {
                'id': 2,
                'subject': 'Art',
                'class_pair_compact': '8A',
                'start_time': '08:00:00',
                'end_time': '08:45:00',
              },
            ],
          });
        }
        return json({
          'lessons': [
            {
              'id': 1,
              'lesson_instance_id': 70,
              'attendance_taken': true,
              'start_time': '09:00:00',
            },
            {
              'id': 9,
              'lesson_instance_id': 90,
              'subject': 'Bio',
              'is_substitution': true,
              'class_pair_compact': '9C',
              'start_time': '10:00:00',
              'end_time': '10:45:00',
            },
          ],
          'meetings': [
            {'title': 'Staff', 'start_time': '15:00', 'end_time': '16:00'},
          ],
        });
      });

      final day = await repository.getDay(DateTime(2026, 11, 9));
      expect(day.lessons.map((l) => l.classLabel), ['8A', '7B', '9C']);
      expect(day.lessons[0].instanceId, isNull);
      expect(day.lessons[1].instanceId, 70);
      expect(day.lessons[1].subject, 'Math');
      expect(day.lessons[1].attendanceTaken, isTrue);
      expect(day.lessons[2].isSubstitution, isTrue);
      expect(day.meetings.single.title, 'Staff');
    });

    test(
      'one source failing still lists the day; both failing throws',
      () async {
        final partial = repositoryWith((request) async {
          if (request.url.path == '/my-lessons') {
            return json({
              'lessons': [
                {'id': 1, 'subject': 'Math', 'start_time': '09:00'},
              ],
            });
          }
          return http.Response('{}', 500);
        });
        expect(
          (await partial.getDay(DateTime(2026, 11, 9))).lessons,
          hasLength(1),
        );

        final broken = repositoryWith(
          (request) async => http.Response('{}', 500),
        );
        // Another date: the day above is now kept on the phone.
        await expectLater(
          broken.getDay(DateTime(2026, 11, 10)),
          throwsA(anything),
        );
      },
    );

    test('bell periods follow the default schedule and the weekday', () async {
      final repository = repositoryWith((request) async {
        expect(request.url.queryParameters['academic_year_id'], '3');
        return json({
          'result': [
            {'is_default': false, 'periods': []},
            {
              'is_default': true,
              'periods': [
                {
                  'period_number': 2,
                  'start_time': '08:50:00',
                  'end_time': '09:35:00',
                  'day_of_week': 1,
                },
                {
                  'period_number': 1,
                  'start_time': '08:00:00',
                  'end_time': '08:45:00',
                  'day_of_week': null,
                },
                {
                  'period_number': 1,
                  'start_time': '09:00:00',
                  'end_time': '09:45:00',
                  'day_of_week': 6,
                },
              ],
            },
          ],
        });
      });
      final periods = await repository.getPeriods(
        academicYearId: 3,
        date: DateTime(2026, 11, 9), // A Monday.
      );
      expect(periods.map((p) => p.start), [480, 530]);
    });

    test('students marked as left drop off the sheet', () async {
      final repository = repositoryWith((request) async {
        switch (request.url.path) {
          case '/lesson-instances/7':
            return json({
              'result': {'id': 7, 'group_id': 4, 'date': '2026-11-09'},
            });
          case '/lesson-instances/7/grades':
            return json({
              'result': {
                'students': [
                  {'student_id': 1, 'full_name': 'Stays'},
                  {'student_id': 2, 'full_name': 'Left'},
                ],
              },
            });
          default:
            expect(request.url.queryParameters['status'], 'left');
            return json({
              'result': [
                {'id': 2},
              ],
            });
        }
      });
      final sheet = await repository.getSheet(7);
      expect(sheet.students.map((s) => s.fullName), ['Stays']);
    });

    test('each kind of save goes to its own endpoint', () async {
      final seen = <String>[];
      final repository = repositoryWith((request) async {
        seen.add('${request.method} ${request.url.path}');
        return json({});
      });
      await repository.upload(UploadKind.attendance, 7, {'marks': []});
      await repository.upload(UploadKind.grades, 7, {'grades': []});
      await repository.upload(UploadKind.behavior, 7, {'type': 'positive'});
      expect(seen, [
        'PUT /lesson-instances/7/attendance',
        'PUT /lesson-instances/7/grades',
        'POST /behavior/marks',
      ]);
    });

    test('a refusal carries the reason and is final', () async {
      final repository = repositoryWith(
        (request) async => http.Response(
          jsonEncode({'message': 'The edit window has closed'}),
          403,
        ),
      );
      await expectLater(
        repository.upload(UploadKind.grades, 7, {'grades': []}),
        throwsA(
          isA<UploadRefused>().having(
            (e) => e.message,
            'message',
            'The edit window has closed',
          ),
        ),
      );
    });

    test('no connection, a busy server or an expired session retry', () async {
      for (final handler in <MockClientHandler>[
        (request) async => throw const SocketException('offline'),
        (request) async => http.Response('{}', 503),
        (request) async => http.Response('{}', 401),
        (request) async => http.Response('{}', 429),
      ]) {
        await expectLater(
          repositoryWith(handler).upload(UploadKind.grades, 7, {'grades': []}),
          throwsA(isA<UploadRetryLater>()),
        );
      }
    });

    test('a day seen online still opens with no connection', () async {
      var online = true;
      final repository = repositoryWith((request) async {
        if (!online) throw const SocketException('offline');
        return json({
          'lessons': [
            {
              'id': 1,
              'lesson_instance_id': 70,
              'subject': 'Math',
              'start_time': '09:00',
            },
          ],
        });
      });
      await repository.getDay(DateTime(2026, 11, 9));

      online = false;
      final day = await repository.getDay(DateTime(2026, 11, 9));
      expect(day.lessons.single.instanceId, 70);
      await expectLater(
        repository.getDay(DateTime(2026, 11, 10)),
        throwsA(anything),
      );

      await repository.clearOffline();
      await expectLater(
        repository.getDay(DateTime(2026, 11, 9)),
        throwsA(anything),
      );
    });

    test('offline bells come from the last schedule kept', () async {
      var online = true;
      final repository = repositoryWith((request) async {
        if (!online) throw const SocketException('offline');
        return json({
          'result': [
            {
              'is_default': true,
              'periods': [
                {
                  'period_number': 1,
                  'start_time': '08:00:00',
                  'end_time': '08:45:00',
                },
              ],
            },
          ],
        });
      });
      expect(await repository.getPeriods(date: DateTime(2026, 11, 9)), isEmpty);
      await repository.getPeriods(
        academicYearId: 3,
        date: DateTime(2026, 11, 9),
      );
      online = false;
      final periods = await repository.getPeriods(date: DateTime(2026, 11, 9));
      expect(periods.single.start, 480);
    });
  });

  group('offline cache', () {
    test('keeps only the newest answers', () async {
      final cache = OfflineCache();
      for (var i = 0; i <= OfflineCache.maxEntries; i += 1) {
        await cache.remember('k$i', 'v$i');
      }
      expect(await cache.recall('k0'), isNull);
      expect(await cache.recall('k${OfflineCache.maxEntries}'), 'v60');
    });
  });

  group('outbox', () {
    late FakeLessonsRepository repository;
    late DateTime now;
    late LessonsOutbox outbox;

    Map<String, dynamic> marks(int id, String status) => {
      'marks': [
        {'student_id': id, 'status': status},
      ],
    };

    void add(UploadKind kind, Map<String, dynamic> body, {int lessonId = 7}) =>
        outbox.enqueue(kind: kind, lessonId: lessonId, body: body, label: 'L');

    setUp(() {
      repository = FakeLessonsRepository();
      now = DateTime(2026, 11, 11, 9);
      outbox = LessonsOutbox(upload: repository.upload, clock: () => now);
    });

    tearDown(() => outbox.dispose());

    test('uploads in the order saved and leaves nothing behind', () async {
      add(UploadKind.attendance, marks(1, 'present'));
      add(UploadKind.grades, {
        'grades': [
          {'student_id': 1, 'homework_score': 5},
        ],
      });
      await pumpEventQueue();
      expect(repository.uploadOrder, [
        UploadKind.attendance,
        UploadKind.grades,
      ]);
      expect(outbox.entries, isEmpty);
    });

    test('with no connection it waits, backs off, then sends', () async {
      repository.uploadError = const UploadRetryLater('offline');
      add(UploadKind.attendance, marks(1, 'present'));
      await pumpEventQueue();
      expect(outbox.waitingCount, 1);
      expect(outbox.entries.single.attempts, 1);

      repository.uploadError = null;
      await outbox.flush();
      expect(repository.attendanceSaves, isEmpty, reason: 'still backing off');

      now = now.add(LessonsOutbox.retryDelays.first);
      await outbox.flush();
      expect(repository.attendanceSaves, hasLength(1));
      expect(outbox.entries, isEmpty);
    });

    test('try now skips the wait', () async {
      repository.uploadError = const UploadRetryLater('offline');
      add(UploadKind.attendance, marks(1, 'present'));
      await pumpEventQueue();
      repository.uploadError = null;
      outbox.retryAll();
      await pumpEventQueue();
      expect(repository.attendanceSaves, hasLength(1));
    });

    test('a newer save of the same lesson merges while waiting', () async {
      repository.uploadError = const UploadRetryLater('offline');
      add(UploadKind.grades, {
        'grades': [
          {'student_id': 1, 'homework_score': 5},
          {'student_id': 2, 'homework_score': 7},
        ],
      });
      await pumpEventQueue();
      add(UploadKind.grades, {
        'grades': [
          {'student_id': 1, 'notes_score': 9},
        ],
      });
      await pumpEventQueue();
      expect(outbox.entries, hasLength(1));

      repository.uploadError = null;
      outbox.retryAll();
      await pumpEventQueue();
      expect(repository.gradeSaves.single, [
        {'student_id': 1, 'homework_score': 5, 'notes_score': 9},
        {'student_id': 2, 'homework_score': 7},
      ]);
    });

    test('behavior marks never merge', () async {
      repository.uploadError = const UploadRetryLater('offline');
      add(UploadKind.behavior, {'requestId': 'a'});
      await pumpEventQueue();
      add(UploadKind.behavior, {'requestId': 'b'});
      await pumpEventQueue();
      expect(outbox.entries, hasLength(2));
    });

    test('a refusal is kept with its reason and the rest continue', () async {
      repository.uploadError = const UploadRefused('Window closed');
      add(UploadKind.attendance, marks(1, 'present'));
      await pumpEventQueue();
      expect(outbox.waitingCount, 0);
      expect(outbox.entries.single.error, 'Window closed');

      repository.uploadError = null;
      add(UploadKind.attendance, marks(2, 'absent'), lessonId: 8);
      await pumpEventQueue();
      expect(repository.attendanceSaves, hasLength(1));
      expect(outbox.rejectedFor(7), 1);

      outbox.discard(outbox.entries.single.id);
      expect(outbox.entries, isEmpty);
    });

    test('saves survive closing the app', () async {
      repository.uploadError = const UploadRetryLater('offline');
      add(UploadKind.attendance, marks(1, 'late'));
      await pumpEventQueue();

      final reopened = LessonsOutbox(
        upload: repository.upload,
        clock: () => now,
      );
      await reopened.load();
      await pumpEventQueue();
      expect(reopened.entries.single.body, marks(1, 'late'));
      expect(reopened.entries.single.status, OutboxStatus.pending);
      reopened.dispose();
    });

    test('an upload cut off by closing the app goes back to waiting', () {
      final entry = OutboxEntry.fromJson({
        'id': 'a',
        'kind': 'grades',
        'lessonId': 7,
        'body': <String, dynamic>{},
        'label': 'L',
        'createdAt': '2026-11-11T09:00:00.000',
        'status': 'uploading',
      });
      expect(entry.status, OutboxStatus.pending);
    });

    test('sign-out clears the queue', () async {
      repository.uploadError = const UploadRetryLater('offline');
      add(UploadKind.attendance, marks(1, 'present'));
      await pumpEventQueue();
      outbox.clear();
      expect(outbox.entries, isEmpty);
    });
  });

  group('working offline', () {
    late FakeLessonsRepository repository;
    late LessonsOutbox outbox;

    SheetStudent present(int id) => SheetStudent(
      studentId: id,
      fullName: 'Student $id',
      status: statusPresent,
      scores: {for (final field in teacherScoreFields) field: 10},
    );

    Future<GradingSheetController> open() async {
      final sheet = GradingSheetController(
        repository: repository,
        outbox: outbox,
        lessonId: 7,
      );
      await sheet.load();
      return sheet;
    }

    setUp(() {
      repository = FakeLessonsRepository(sheet: sheetOf([present(1)]))
        ..uploadError = const UploadRetryLater('offline');
      outbox = LessonsOutbox(upload: repository.upload);
    });

    tearDown(() => outbox.dispose());

    test('a save counts as saved while it waits to upload', () async {
      final sheet = await open();
      sheet.update(1, (row) => row.scores[homeworkScore] = 5);
      sheet.save();
      await pumpEventQueue();

      expect(sheet.hasUnsavedEdits, isFalse);
      expect(sheet.dirtyCount, 0);
      expect(sheet.waitingCount, 1);
    });

    test('reopening a lesson shows what is still waiting', () async {
      final first = await open();
      first.update(1, (row) {
        row.mark(statusAbsent);
      });
      first.save();
      await pumpEventQueue();
      first.dispose();

      repository.sheet = sheetOf([present(1)]);
      final second = await open();
      expect(second.draftOf(1)!.status, statusAbsent);
      expect(second.draftOf(1)!.scores[homeworkScore], 0);
      expect(second.attendanceDirty, isFalse);
    });

    test('once uploaded the sheet takes the server copy', () async {
      final sheet = await open();
      sheet.update(1, (row) => row.scores[homeworkScore] = 5);
      sheet.save();
      await pumpEventQueue();

      repository.uploadError = null;
      repository.sheet = sheetOf([
        SheetStudent(
          studentId: 1,
          fullName: 'From server',
          status: statusPresent,
          scores: {for (final field in teacherScoreFields) field: 15},
        ),
      ]);
      outbox.retryAll();
      await pumpEventQueue();

      expect(sheet.waitingCount, 0);
      expect(sheet.students.single.fullName, 'From server');
    });

    test('new edits are not overwritten by an upload finishing', () async {
      final sheet = await open();
      sheet.update(1, (row) => row.scores[homeworkScore] = 5);
      sheet.save();
      await pumpEventQueue();
      sheet.update(1, (row) => row.scores[notesScore] = 1);

      repository.uploadError = null;
      outbox.retryAll();
      await pumpEventQueue();

      expect(sheet.draftOf(1)!.scores[notesScore], 1);
      expect(sheet.hasUnsavedEdits, isTrue);
    });

    test('a behavior mark shows at once with its reason', () async {
      repository.reasons = const BehaviorReasons(
        positive: [BehaviorReason(id: 'r1', label: 'Helped')],
      );
      final sheet = await open();
      sheet.addBehaviorMark(
        studentId: 1,
        type: behaviorPositive,
        reasonIds: const ['r1'],
        comment: '',
      );
      await pumpEventQueue();
      expect(sheet.marksOf(1).single.reasonLabel, 'Helped');
    });

    test('marks send minutes only for late students', () async {
      repository.uploadError = null;
      repository.sheet = sheetOf([present(1), present(2)]);
      final sheet = await open();
      sheet.update(
        1,
        (row) => row.mark(statusLate, minutes: 9, keepMinutes: false),
      );
      sheet.update(2, (row) => row.mark(statusAbsent));
      sheet.saveAttendance();
      await pumpEventQueue();
      expect(repository.attendanceSaves.single, [
        {'student_id': 1, 'status': 'late', 'minutes_late': 9},
        {'student_id': 2, 'status': 'absent'},
      ]);
    });

    testWidgets('the sheet says what is waiting and lists it', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildAppTheme(
            accent: kDefaultAccent,
            brightness: Brightness.light,
            darkVariant: kDefaultDarkVariant,
          ),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: GradingSheetPage(
            repository: repository,
            outbox: outbox,
            lessonId: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l.absentShort));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & next'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5)); // The toast leaves.
      await tester.pumpAndSettle();

      expect(find.text(l.waitingToUpload(1)), findsOneWidget);
      await tester.tap(find.text(l.waitingToUpload(1)));
      await tester.pumpAndSettle();
      expect(find.text(l.tryNow), findsOneWidget);
      expect(find.text('7-B · Math · ${l.attendance}'), findsOneWidget);

      repository.uploadError = null;
      await tester.tap(find.text(l.tryNow));
      await tester.pumpAndSettle();
      expect(repository.attendanceSaves, hasLength(1));
      expect(find.text(l.waitingToUpload(1)), findsNothing);
    });
  });

  group('screens', () {
    Widget app(Widget home, {Locale locale = const Locale('en')}) =>
        MaterialApp(
          theme: buildAppTheme(
            accent: kDefaultAccent,
            brightness: Brightness.light,
            darkVariant: kDefaultDarkVariant,
          ),
          locale: locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(body: home),
        );

    testWidgets('a lesson without a record says it can\'t be opened', (
      tester,
    ) async {
      final repository = FakeLessonsRepository(
        day: const LessonDay(
          lessons: [
            TeacherLesson(
              id: 1,
              subject: 'Math',
              classLabel: '7B',
              startTime: '08:00:00',
              endTime: '08:45:00',
            ),
          ],
        ),
      );
      await tester.pumpWidget(
        app(
          LessonsPage(
            repository: repository,
            outbox: LessonsOutbox(upload: repository.upload),
            loadAcademicYears: () async => const [],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('7B'), findsOneWidget);
      // Today's page scrolls to the current time; bring the lesson back.
      await tester.ensureVisible(find.text('Math'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Math'));
      await tester.pump();
      expect(find.byType(GradingSheetPage), findsNothing);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('coming back from a lesson reloads the day', (tester) async {
      final repository = FakeLessonsRepository(
        day: LessonDay(lessons: [lessonAt('08:00:00', '08:45:00')]),
        sheet: sheetOf([SheetStudent(studentId: 1, fullName: 'Ali')]),
      );
      await tester.pumpWidget(
        app(
          LessonsPage(
            repository: repository,
            outbox: LessonsOutbox(upload: repository.upload),
            loadAcademicYears: () async => const [],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repository.dayLoads, 1);

      // Today's page scrolls to the current time; bring the lesson back.
      await tester.ensureVisible(find.text('Math'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Math'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(GradingSheetPage), findsNothing);
      expect(repository.dayLoads, 2);
    });

    testWidgets('a closed lesson nobody graded shows no score', (tester) async {
      final repository = FakeLessonsRepository(
        sheet: sheetOf([
          SheetStudent(studentId: 1, fullName: 'Ali'),
        ], date: DateTime(2020, 1, 6)),
      );
      await tester.pumpWidget(
        app(
          GradingSheetPage(
            repository: repository,
            outbox: LessonsOutbox(upload: repository.upload),
            lessonId: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(repository.attendanceSaves, isEmpty);
      expect(find.text('0'), findsNothing);
      expect(find.text('Saved'), findsNothing);
    });

    testWidgets('header checkboxes mark everyone, then score everyone', (
      tester,
    ) async {
      final repository = FakeLessonsRepository(
        sheet: sheetOf([SheetStudent(studentId: 1, fullName: 'Ali Valiyev')]),
      );
      await tester.pumpWidget(
        app(
          GradingSheetPage(
            repository: repository,
            outbox: LessonsOutbox(upload: repository.upload),
            lessonId: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ali Valiyev'), findsOneWidget);
      // Nothing is marked when the sheet opens.
      expect(find.text('1 not marked'), findsOneWidget);
      await tester.tap(find.byType(Checkbox).first); // everyone present
      await tester.pumpAndSettle();
      expect(find.text('All marked'), findsOneWidget);
      await tester.tap(find.text('Save & next'));
      await tester.pumpAndSettle();
      expect(repository.attendanceSaves.single.single['status'], statusPresent);

      // Scores start empty; one checkbox per category fills them.
      expect(find.text('100'), findsNothing);
      expect(find.text('Skip'), findsOneWidget);
      final boxes = find.byType(Checkbox);
      expect(boxes, findsNWidgets(teacherScoreFields.length));
      for (var i = 0; i < teacherScoreFields.length; i++) {
        await tester.tap(boxes.at(i));
        await tester.pumpAndSettle();
      }
      expect(find.text('100'), findsOneWidget);
    });

    testWidgets('late blocks moving on until minutes are chosen', (
      tester,
    ) async {
      final repository = FakeLessonsRepository(
        sheet: sheetOf([SheetStudent(studentId: 1, fullName: 'Ali')]),
      );
      await tester.pumpWidget(
        app(
          GradingSheetPage(
            repository: repository,
            outbox: LessonsOutbox(upload: repository.upload),
            lessonId: 7,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text(l.lateShort));
      await tester.pumpAndSettle();
      expect(find.text(l.addMinutesForLate(1)), findsOneWidget);
      await tester.tap(find.text('Save & next'));
      await tester.pumpAndSettle();
      expect(repository.attendanceSaves, isEmpty);

      await tester.tap(find.text(l.minutesShort(10)));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save & next'));
      await tester.pumpAndSettle();
      expect(repository.attendanceSaves.single.single['minutes_late'], 10);
    });

    testWidgets('leaving with edits asks first, an untouched sheet does not', (
      tester,
    ) async {
      final repository = FakeLessonsRepository(
        sheet: sheetOf([SheetStudent(studentId: 1, fullName: 'Ali')]),
      );
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GradingSheetPage(
                    repository: repository,
                    outbox: LessonsOutbox(upload: repository.upload),
                    lessonId: 7,
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      final l = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.byType(GradingSheetPage), findsNothing);

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l.absentShort));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await tester.pumpAndSettle();
      expect(find.text(l.unsavedTitle), findsOneWidget);
    });

    testWidgets('the sheet follows the chosen language', (tester) async {
      final repository = FakeLessonsRepository(
        sheet: sheetOf([SheetStudent(studentId: 1, fullName: 'Ali')]),
      );
      await tester.pumpWidget(
        app(
          GradingSheetPage(
            repository: repository,
            outbox: LessonsOutbox(upload: repository.upload),
            lessonId: 7,
          ),
          locale: const Locale('ru'),
        ),
      );
      await tester.pumpAndSettle();
      final ru = await AppLocalizations.delegate.load(const Locale('ru'));
      expect(find.text(ru.attendance), findsOneWidget);
      expect(find.text(ru.scores), findsOneWidget);
    });
  });
}
