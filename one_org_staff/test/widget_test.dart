// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:one_org_staff/app/app.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';
import 'package:one_org_staff/features/auth/data/token_storage.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/features/Profile/profilepage.dart';
import 'package:one_org_staff/shared/underline_tabs.dart';
import 'package:one_org_staff/features/MyClass/my_class.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';
import 'package:one_org_staff/features/exams/presentation/exams_page.dart';
import 'package:one_org_staff/features/point_report/domain/point_report_repository.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_page.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
    expect(find.text('Quick Access'), findsNothing);
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

    expect(find.text('Quick Access'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    // Twice: once in the bottom navbar, once as a dashboard row.
    expect(find.text('Lessons'), findsNWidgets(2));
    expect(find.text('Colleagues'), findsNWidgets(2));
    // Dashboard row only — Timetable was taken off the navbar.
    expect(find.text('Timetable'), findsOneWidget);
    expect(find.text('My Class'), findsOneWidget);
    expect(find.text('Point report'), findsOneWidget);
    // Only in the navbar — the dashboard's Profile and Sign Out cards were
    // removed; the header avatar is the way into the profile now.
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Sign Out'), findsNothing);
  });

  testWidgets('profile tab shows user data, theme switch, and password form', (
    WidgetTester tester,
  ) async {
    final controller = AuthController(
      authRepository: FakeAuthRepository(
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
      ),
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

    // The name and email show in the header card and again in the
    // Personal Information rows, matching the web layout.
    expect(find.text('Ahror Teacher'), findsNWidgets(2));
    expect(find.text('teacher@oneorg.uz'), findsNWidgets(2));
    expect(find.text('@ahror'), findsOneWidget);
    expect(find.text('Personal Information'), findsOneWidget);
    expect(find.text('Account Details'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('teacher'), findsOneWidget);

    // Password moved behind its own tab.
    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.text('Update password'), findsWidgets);

    // Sign out sits with the account, on the Profile tab.
    await tester.tap(
      find.descendant(
        of: find.byType(UnderlineTabs<ProfileTab>),
        matching: find.text('Profile'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsOneWidget);

    // Theme lives under System, and no longer carries the sign-out button or
    // the swatch preview strip.
    await tester.tap(find.text('System'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsNothing);
    expect(find.text('Primary button'), findsNothing);
    expect(find.text('Highlight'), findsNothing);
    expect(find.text('Accent text'), findsNothing);

    final switchFinder = find.byType(Switch);
    await tester.ensureVisible(switchFinder);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);

    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
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

    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Colleagues'),
      ),
    );
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
    expect(find.text('Personal Information'), findsOneWidget);

    // Back to the dashboard, then into My Class from its row.
    await tester.tap(
      find.descendant(of: find.byType(BottomMenu), matching: find.text('Home')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Class'));
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
        matching: find.text('Point report'),
      ),
      findsNothing,
    );

    await tester.ensureVisible(find.text('Point report'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point report'));
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
    );

    await tester.pumpWidget(OneOrgStaffApp(controller: controller));
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(BottomMenu),
        matching: find.text('Lessons'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mathematics'), findsOneWidget);
    expect(find.text('08:30-09:15'), findsOneWidget);
    expect(find.text('6-B'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
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
    await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -120));
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

    expect(find.text('Quick Access'), findsOneWidget);
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
