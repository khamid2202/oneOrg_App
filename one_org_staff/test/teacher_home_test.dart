import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/app/app.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';
import 'package:one_org_staff/features/auth/data/http_auth_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/landing/application/next_lesson_day.dart';
import 'package:one_org_staff/features/landing/domain/app_items.dart';
import 'package:one_org_staff/features/lessons/application/lessons_outbox.dart';
import 'package:one_org_staff/features/lessons/data/offline_cache.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/features/lessons/presentation/lessons_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lessons_repository.dart';
import 'widget_test.dart' show FakeAuthRepository, InMemoryTokenStorage;

AppUserProfile _profile({
  List<String> roles = const [],
  List<String>? permissions,
}) => AppUserProfile(
  id: 1,
  fullName: 'Ali Valiyev',
  subtitle: '',
  email: '',
  phone: '',
  department: '',
  joinedDate: '',
  roles: roles,
  permissions: permissions,
);

TeacherLesson _lesson(String start, String end, {String? status}) =>
    TeacherLesson(
      id: start.hashCode,
      subject: 'Math',
      classLabel: '9B',
      startTime: '$start:00',
      endTime: '$end:00',
      status: status,
    );

void main() {
  group('reading permissions', () {
    test(
      'a person\'s own records are open to everyone; tools need a class',
      () {
        final office = AppAccess(_profile(permissions: const []));
        expect(office.allows(AppItem.myPlan), isTrue);
        expect(office.allows(AppItem.myPoints), isTrue);
        expect(office.allows(AppItem.myFundings), isTrue);
        expect(office.allows(AppItem.teachingTools), isFalse);
        expect(
          AppAccess(_profile(roles: ['teacher'])).allows(AppItem.teachingTools),
          isTrue,
        );
      },
    );

    test('keeps null apart from holding none', () {
      expect(AppUserProfile.fromJson(const {'id': 1}).permissions, isNull);
      expect(
        AppUserProfile.fromJson(const {'id': 1, 'permissions': []}).permissions,
        isEmpty,
      );
    });

    test('admin is a wildcard', () {
      expect(_profile(roles: ['admin']).hasAnyPermission(['x.y']), isTrue);
      expect(_profile(permissions: ['a.b']).hasAnyPermission(['x.y']), isFalse);
      expect(_profile().hasAnyPermission(['x.y']), isFalse);
    });
  });

  group('who sees what', () {
    test('a regular teacher gets the web phone bar', () {
      final access = AppAccess(_profile(roles: ['teacher']));
      expect(access.phoneBar, [AppItem.lessons, AppItem.myClass]);
    });

    test('a teacher allowed to report gets Report in the middle', () {
      final access = AppAccess(
        _profile(roles: ['teacher'], permissions: ['behavior.read']),
      );
      expect(access.phoneBar, [
        AppItem.lessons,
        AppItem.behavior,
        AppItem.myClass,
      ]);
      expect(access.smallTiles.first, AppItem.behavior);
    });

    test('a teacher without the permission has no Report', () {
      final access = AppAccess(_profile(roles: ['teacher']));
      expect(access.allows(AppItem.behavior), isFalse);
    });

    test('an admin keeps the Timetable in the bar, not Report', () {
      final access = AppAccess(
        _profile(roles: ['teacher', 'admin'], permissions: ['behavior.read']),
      );
      expect(access.phoneBar.contains(AppItem.behavior), isFalse);
    });

    test('someone not teaching gets the timetable in the bar', () {
      final access = AppAccess(_profile(permissions: ['timetable.read']));
      expect(access.phoneBar, [AppItem.timetable]);
      expect(access.allows(AppItem.myClass), isFalse);
    });

    test('rewards are switched off, even with a points key', () {
      final access = AppAccess(
        _profile(roles: ['teacher', 'admin'], permissions: ['points.read']),
      );
      expect(access.allows(AppItem.rewards), isFalse);
      expect(access.smallTiles, isNot(contains(AppItem.rewards)));
    });

    test('whoever reads every grade loses the card unless they teach', () {
      const both = ['lesson_grades.read', 'lesson_grades.read_all'];
      expect(
        AppAccess(_profile(permissions: both)).allows(AppItem.grades),
        isFalse,
      );
      expect(
        AppAccess(
          _profile(roles: ['teacher'], permissions: both),
        ).allows(AppItem.grades),
        isTrue,
      );
    });

    test('an unknown profile is treated as a regular teacher', () {
      expect(const AppAccess(null).phoneBar, [
        AppItem.lessons,
        AppItem.myClass,
      ]);
    });
  });

  group('next lesson day', () {
    NextLessonDayLoader loader(
      Map<int, LessonDay> days,
      DateTime now, {
      Set<int> failing = const {},
    }) => NextLessonDayLoader(
      clock: () => now,
      getDay: (date) async {
        final offset = date
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;
        if (failing.contains(offset)) throw Exception('offline');
        return days[offset] ?? const LessonDay(lessons: []);
      },
    );

    test('today, sorted, with cancelled lessons left out', () async {
      final subject = loader({
        0: LessonDay(
          lessons: [
            _lesson('10:00', '10:45'),
            _lesson('08:00', '08:45'),
            _lesson('09:00', '09:45', status: 'cancelled'),
          ],
        ),
      }, DateTime(2026, 11, 11, 9));
      await subject.refreshIfStale();
      expect(subject.result!.items.map((i) => i.start), ['08:00', '10:00']);
    });

    test('a day off moves on to the next day with lessons', () async {
      final subject = loader({
        2: LessonDay(lessons: [_lesson('08:00', '08:45')]),
      }, DateTime(2026, 11, 14, 9));
      await subject.refreshIfStale();
      expect(subject.result!.day, DateTime(2026, 11, 16));
    });

    test('after 16:30 a finished day gives way to the next', () async {
      final subject = loader({
        0: LessonDay(lessons: [_lesson('08:00', '08:45')]),
        1: LessonDay(lessons: [_lesson('09:00', '09:45')]),
      }, DateTime(2026, 11, 11, 16, 31));
      await subject.refreshIfStale();
      expect(subject.result!.day, DateTime(2026, 11, 12));
    });

    test('after 16:30 a lesson still to come keeps today', () async {
      final subject = loader({
        0: LessonDay(lessons: [_lesson('17:00', '17:45')]),
        1: LessonDay(lessons: [_lesson('09:00', '09:45')]),
      }, DateTime(2026, 11, 11, 16, 31));
      await subject.refreshIfStale();
      expect(subject.result!.day, DateTime(2026, 11, 11));
    });

    test('offline, it stops at today rather than failing', () async {
      final subject = loader(
        {
          0: LessonDay(lessons: [_lesson('08:00', '08:45')]),
        },
        DateTime(2026, 11, 11, 17),
        failing: {1, 2, 3, 4, 5, 6},
      );
      await subject.refreshIfStale();
      expect(subject.result!.day, DateTime(2026, 11, 11));
    });

    test('searches once per day', () async {
      var calls = 0;
      final subject = NextLessonDayLoader(
        clock: () => DateTime(2026, 11, 11, 9),
        getDay: (_) async {
          calls += 1;
          return LessonDay(lessons: [_lesson('10:00', '10:45')]);
        },
      );
      await subject.refreshIfStale();
      await subject.refreshIfStale();
      expect(calls, 1);
    });
  });

  group('profile offline', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('the last profile answers when the server cannot', () async {
      var online = true;
      final repository = HttpAuthRepository(
        baseUrl: 'https://api.test',
        cache: OfflineCache(),
        client: MockClient((request) async {
          if (!online) throw http.ClientException('offline');
          return http.Response(
            jsonEncode({
              'id': 7,
              'full_name': 'Ali Valiyev',
              'roles': ['teacher'],
              'permissions': ['points.read'],
            }),
            200,
          );
        }),
      );

      await repository.getCurrentUser('token');
      online = false;
      final kept = await repository.getCurrentUser('token');
      expect(kept.fullName, 'Ali Valiyev');
      expect(kept.permissions, ['points.read']);
    });

    test('an expired session is not answered from the phone', () async {
      var status = 200;
      final repository = HttpAuthRepository(
        baseUrl: 'https://api.test',
        cache: OfflineCache(),
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({'id': 7, 'full_name': 'Ali Valiyev'}),
            status,
          ),
        ),
      );

      await repository.getCurrentUser('token');
      status = 401;
      expect(
        () => repository.getCurrentUser('token'),
        throwsA(isA<AuthFailure>()),
      );
    });
  });

  testWidgets('Home shows the day and opens Schedule on it', (tester) async {
    final lessons = FakeLessonsRepository(
      day: LessonDay(lessons: [_lesson('23:58', '23:59')]),
    );
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
      lessons: lessons,
      outbox: LessonsOutbox(upload: lessons.upload),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('My Schedule'), findsOneWidget);
    expect(find.text('23:58'), findsOneWidget);
    expect(find.text('9B'), findsOneWidget);
    expect(find.textContaining('/1'), findsOneWidget);

    await tester.tap(find.text('23:58'));
    await tester.pumpAndSettle();
    expect(find.byType(LessonsPage), findsOneWidget);
  });
}
