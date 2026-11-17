// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_org_staff/app/app.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';
import 'package:one_org_staff/features/auth/data/token_storage.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/features/MyClass/my_class.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';
import 'package:one_org_staff/features/exams/presentation/exams_page.dart';
import 'package:one_org_staff/features/lessons/application/lessons_outbox.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/features/point_report/domain/point_report_repository.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_page.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_lessons_repository.dart';

void main() {
  test('no connection at start keeps the session', () async {
    final storage = InMemoryTokenStorage(initialToken: 'saved-token');
    final controller = AuthController(
      authRepository: _UnreachableAuthRepository(),
      tokenStorage: storage,
    );
    await controller.restoreSession();
    expect(controller.status, AuthStatus.authenticated);
    expect(await storage.readToken(), 'saved-token');
  });

  test('a token the server rejects still signs out', () async {
    final storage = InMemoryTokenStorage(initialToken: 'expired');
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'other'}),
      tokenStorage: storage,
    );
    await controller.restoreSession();
    expect(controller.status, AuthStatus.unauthenticated);
    expect(await storage.readToken(), isNull);
  });

  testWidgets('shows the login screen when no saved token exists', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(),
      tokenStorage: InMemoryTokenStorage(),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Hi, OneOrg'), findsNothing);
  });

  testWidgets('restores a valid saved token into the landing page', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Hi, OneOrg'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    // The phone bar, like the web's for a regular teacher.
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('Class'), findsOneWidget);
    // Small tiles only.
    expect(find.text('Colleagues'), findsOneWidget);
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('Point Report'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Sign Out'), findsNothing);
  });

  testWidgets('Profile matches the web: card, Account and App rows', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository(
      validTokens: const {'saved-token'},
      currentUser: const AppUserProfile(
        id: 11,
        fullName: 'Ahror Teacher',
        subtitle: 'Teacher • Academic Department',
        email: 'teacher@oneorg.uz',
        phone: '+998 90 123 45 67',
        department: 'Mathematics',
        joinedDate: '12 Sep 2024',
        username: 'ahror',
        status: 'active',
        roles: ['teacher'],
      ),
    )..contact = const ProfileContact(email: 'ahror@school.uz');
    final controller = AuthController(
      authRepository: repository,
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();
    await openProfile(tester);

    // The card: name, @username and roles.
    expect(find.text('Ahror Teacher'), findsOneWidget);
    expect(find.text('@ahror'), findsOneWidget);
    expect(find.text('teacher'), findsOneWidget);

    // Contact comes from /settings/profile; an empty phone reads "Not set".
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('ahror@school.uz'), findsOneWidget);
    expect(find.text('Not set'), findsOneWidget);
    expect(find.text('App'), findsOneWidget);
    expect(find.text('Language, color, dark mode'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);

    // Password opens its own screen, and back returns to the list.
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.text('Update password'), findsWidgets);
    expect(find.text('Account'), findsNothing);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    // Dark mode lives under System.
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();
    final switchFinder = find.byType(Switch);
    await tester.ensureVisible(switchFinder);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('editing the phone saves through /settings/profile', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository(validTokens: const {'saved-token'});
    final controller = AuthController(
      authRepository: repository,
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.tap(find.text('Phone'));
    await tester.pumpAndSettle();
    expect(find.text('Contact details'), findsOneWidget);

    final phoneField = find.widgetWithText(TextField, 'Phone');
    await tester.enterText(phoneField, 'abc');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid phone number'), findsOneWidget);

    await tester.enterText(phoneField, '+998 99 111 22 33');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(repository.contact.phone, '+998 99 111 22 33');
    expect(repository.contact.email, 'staff@oneorg.uz');
    expect(find.text('+998 99 111 22 33'), findsOneWidget);
    expect(find.text('Contact details updated'), findsOneWidget);
  });

  testWidgets('Suggestions sends once three letters are typed', (
    WidgetTester tester,
  ) async {
    final repository = FakeAuthRepository(validTokens: const {'saved-token'});
    final controller = AuthController(
      authRepository: repository,
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();
    await openProfile(tester);

    await tester.tap(find.text('Suggestions'));
    await tester.pumpAndSettle();

    FilledButton send() => tester.widget<FilledButton>(
      find.ancestor(of: find.text('Send'), matching: find.byType(FilledButton)),
    );
    await tester.enterText(find.byType(TextField), 'hi');
    await tester.pump();
    expect(send().onPressed, isNull);

    await tester.enterText(find.byType(TextField), '  Add a dark map  ');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pumpAndSettle();

    expect(repository.suggestions.single.message, 'Add a dark map');
    expect(repository.suggestions.single.anonymous, isTrue);
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('picking an accent in System recolours the whole app', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final themeController = ThemeController();
    await themeController.load();

    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(
      OneOrgStaffApp(controller: controller, themeController: themeController),
    );
    await tester.pumpAndSettle();

    ThemeData currentTheme() =>
        Theme.of(tester.element(find.byType(BottomMenu)));

    expect(currentTheme().colorScheme.primary, accentForKey('purple').solid);

    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    // The swatches are in palette order, so Cyan is the sixth.
    final cyanSwatch = find.byWidgetPredicate(
      (widget) => widget is Semantics && widget.properties.label == 'Cyan',
    );
    await tester.ensureVisible(cyanSwatch);
    await tester.tap(cyanSwatch);
    await tester.pumpAndSettle();

    expect(themeController.accent.key, 'cyan');
    // The change reaches the app-wide theme, not just the settings page.
    expect(currentTheme().colorScheme.primary, accentForKey('cyan').solid);
  });

  testWidgets('the Colleagues navbar button opens the directory', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
      colleaguesRepository: _FakeColleaguesRepository(),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Colleagues'));
    await tester.pumpAndSettle();

    expect(find.text('Ali Vali'), findsOneWidget);
    expect(find.text('1 active colleague'), findsOneWidget);
  });

  testWidgets('Profile and My Class still open after the tab renumbering', (
    WidgetTester tester,
  ) async {
    // Inserting Colleagues shifted Profile to 4 and My Class to 5; this pins
    // both so a future insert can't silently point a button at the wrong page.
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Account'), findsOneWidget);

    // Back to the dashboard, then into My Class from its row.
    await tester.tap(
      find.descendant(of: find.byType(BottomMenu), matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Class'));
    await tester.pumpAndSettle();

    expect(find.byType(MyClassPage), findsOneWidget);
  });

  testWidgets('the dashboard Point report row opens the report', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
      pointReportRepository: _FakePointReportRepository(),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    // No navbar button by design — the report opens from the dashboard.
    expect(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Point Report'),
      ),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Point Report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point Report'));
    await tester.pumpAndSettle();

    expect(find.byType(PointReportPage), findsOneWidget);
    expect(
      find.text('Choose a class to view the point report.'),
      findsOneWidget,
    );
  });

  testWidgets('the dashboard Exams row opens the exams hub', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    // No navbar button by design — exams open from the dashboard.
    expect(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Exams'),
      ),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Exams'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exams'));
    await tester.pumpAndSettle();

    expect(find.byType(ExamsPage), findsOneWidget);
    expect(find.text('Create a new exam'), findsOneWidget);
    expect(find.text('Score the exam'), findsOneWidget);
  });

  testWidgets('lessons tab shows scheduled lessons for the selected day', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
      timetableRepository: FakeTimetableRepository(),
      outbox: LessonsOutbox(upload: FakeLessonsRepository().upload),
      lessons: FakeLessonsRepository(
        day: const LessonDay(
          lessons: [
            TeacherLesson(
              id: 1,
              instanceId: 7,
              subject: 'Mathematics',
              classLabel: '6B',
              startTime: '08:00:00',
              endTime: '08:45:00',
              room: '201',
            ),
          ],
        ),
      ),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Schedule'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    expect(find.text('6B'), findsOneWidget);
    expect(find.text('201'), findsOneWidget);
  });

  testWidgets('the timetable opens on the by-teacher grid', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(validTokens: const {'saved-token'}),
      tokenStorage: InMemoryTokenStorage(initialToken: 'saved-token'),
      timetableRepository: FakeTimetableRepository(),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    // Timetable has no navbar button — it opens from its dashboard row, which
    // sits below the fold at this window size.
    await tester.ensureVisible(find.text('Timetable'));
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Timetable'));
    await tester.pumpAndSettle();

    // My week is the default view.
    expect(find.text('My week'), findsOneWidget);
    expect(find.text('By class'), findsOneWidget);

    // The signed-in user is not in this timetable, so they are told so.
    expect(find.text('You have no lessons in this timetable.'), findsOneWidget);
  });

  testWidgets('navigates to landing after a successful login', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(),
      tokenStorage: InMemoryTokenStorage(),
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'staffuser');
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Hi, OneOrg'), findsOneWidget);
  });
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.signInToken = 'session-token',
    this.validTokens = const {'session-token'},
    this.currentUser = const AppUserProfile(
      id: 11,
      fullName: 'OneOrg Staff User',
      subtitle: 'Teacher • Academic Department',
      email: 'staff@oneorg.uz',
      phone: '+998 90 123 45 67',
      department: 'Mathematics',
      joinedDate: '12 Sep 2024',
      roles: ['teacher'],
      permissions: ['points.read'],
    ),
  });

  final String signInToken;
  final Set<String> validTokens;
  final AppUserProfile currentUser;

  /// Avatar uploads recorded by [uploadProfilePicture], newest last.
  final List<({int userId, int byteCount, String filename})> pictureUploads =
      [];
  final List<int> pictureRemovals = [];

  @override
  Future<String?> uploadProfilePicture(
    String token, {
    required int userId,
    required List<int> bytes,
    required String filename,
  }) async {
    if (!validTokens.contains(token)) {
      throw const AuthFailure('Invalid or expired token');
    }
    pictureUploads.add((
      userId: userId,
      byteCount: bytes.length,
      filename: filename,
    ));
    return 'https://cdn.example.com/users/$userId/avatar.jpg';
  }

  @override
  Future<String?> removeProfilePicture(
    String token, {
    required int userId,
  }) async {
    if (!validTokens.contains(token)) {
      throw const AuthFailure('Invalid or expired token');
    }
    pictureRemovals.add(userId);
    return null;
  }

  @override
  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      throw const AuthFailure('Invalid username or password');
    }

    return signInToken;
  }

  @override
  Future<String> updatePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    if (!validTokens.contains(token)) {
      throw const AuthFailure('Invalid or expired token');
    }
    if (currentPassword.isEmpty || newPassword.length < 6) {
      throw const AuthFailure('Unable to update password');
    }
    return 'Password updated successfully';
  }

  @override
  Future<void> validate(String token) async {
    if (!validTokens.contains(token)) {
      throw const AuthFailure('Invalid or expired token');
    }
  }

  @override
  Future<void> revoke(String token) async {}

  ProfileContact contact = const ProfileContact(
    email: 'staff@oneorg.uz',
    phone: '+998901234567',
  );
  final List<({String message, bool anonymous})> suggestions = [];

  @override
  Future<ProfileContact> loadContact(String token) async => contact;

  @override
  Future<ProfileContact> updateContact(
    String token, {
    required String email,
    required String phone,
  }) async => contact = ProfileContact(email: email, phone: phone);

  @override
  Future<void> sendSuggestion(
    String token, {
    required String message,
    required bool anonymous,
  }) async => suggestions.add((message: message, anonymous: anonymous));

  @override
  Future<AppUserProfile> getCurrentUser(String token) async {
    if (!validTokens.contains(token)) {
      throw const AuthFailure('Invalid or expired token');
    }

    return currentUser;
  }
}

class InMemoryTokenStorage implements TokenStorage {
  InMemoryTokenStorage({this.initialToken});

  String? initialToken;

  @override
  Future<void> clearToken() async {
    initialToken = null;
  }

  @override
  Future<String?> readToken() async {
    return initialToken;
  }

  @override
  Future<void> writeToken(String token) async {
    initialToken = token;
  }
}

class _UnreachableAuthRepository extends FakeAuthRepository {
  _UnreachableAuthRepository() : super(validTokens: const {});

  @override
  Future<void> validate(String token) async {
    throw const SocketException('offline');
  }
}

class FakeTimetableRepository implements TimetableRepository {
  @override
  Future<TimetableDaySchedule> getMyLessons(
    String token, {
    required DateTime date,
  }) async {
    return TimetableDaySchedule(
      date: DateTime(date.year, date.month, date.day),
      lessons: const [
        TimetableLesson(
          id: 1,
          title: 'Mathematics',
          timeLabel: '08:30-09:15',
          groupLabel: '6-B',
          teacherLabel: 'John Doe',
          groupId: 12,
          room: 'A-12',
          dayLabel: 'Monday',
        ),
      ],
    );
  }

  @override
  Future<List<TimetableLesson>> getTimetable(
    String token, {
    int? academicYearId,
  }) async {
    return const [
      TimetableLesson(
        id: 11,
        title: 'Mathematics',
        timeLabel: 'Slot 2',
        subtitle: 'Group #7 • John Doe',
        groupLabel: 'Group #7',
        teacherLabel: 'John Doe',
        groupId: 7,
        room: 'A-12',
        dayLabel: 'Monday',
        dayIndex: 1,
        timeId: 2,
      ),
      TimetableLesson(
        id: 12,
        title: 'English',
        timeLabel: 'Slot 3',
        subtitle: 'Group #5 • Jane Smith',
        groupLabel: 'Group #5',
        teacherLabel: 'Jane Smith',
        groupId: 5,
        room: 'B-04',
        dayLabel: 'Tuesday',
        dayIndex: 2,
        timeId: 3,
      ),
    ];
  }
}

class _FakeColleaguesRepository implements ColleaguesRepository {
  @override
  Future<List<Colleague>> getColleagues(String token) async => const [
    Colleague(
      id: 1,
      fullName: 'Ali Vali',
      username: 'ali',
      phoneNumber: '+998901112233',
      status: 'active',
    ),
  ];
}

class _FakePointReportRepository implements PointReportRepository {
  @override
  Future<List<StudentPoint>> getPoints(
    String token, {
    required int groupId,
    required DateTime start,
    required DateTime end,
  }) async => const [];
}

Future<void> openProfile(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomMenu),
      matching: find.text('Profile'),
    ),
  );
  await tester.pumpAndSettle();
}
