import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/features/MyClass/dombit_pdf.dart';
import 'package:one_org_staff/features/landing/application/next_lesson_day.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/cashier/cashier_page.dart';
import 'package:one_org_staff/features/landing/domain/app_items.dart';
import 'package:one_org_staff/features/lesson_analysis/lesson_analysis.dart';
import 'package:one_org_staff/shared/api_client.dart';

AppUserProfile _profile({List<String> roles = const [], List<String>? perms}) =>
    AppUserProfile(
      id: 1,
      fullName: 'A B',
      subtitle: '',
      email: '',
      phone: '',
      department: '',
      joinedDate: '',
      roles: roles,
      permissions: perms,
    );

void main() {
  group('access to the pages ported from the web', () {
    test('a plain teacher gets Calendar and their own analysis only', () {
      final a = AppAccess(_profile(roles: ['teacher'], perms: const []));
      expect(a.allows(AppItem.calendar), isTrue);
      expect(a.allows(AppItem.myLessonAnalysis), isTrue);
      for (final item in [
        AppItem.lessonAnalysis,
        AppItem.myDepartment,
        AppItem.substitutions,
        AppItem.attendanceCheck,
        AppItem.cashier,
        AppItem.staffPoints,
        AppItem.fundings,
      ]) {
        expect(a.allows(item), isFalse, reason: '$item');
      }
    });

    test('each admin page follows its permission key', () {
      AppAccess with_(String key) => AppAccess(_profile(perms: [key]));
      expect(
        with_('lesson_observations.read').allows(AppItem.lessonAnalysis),
        isTrue,
      );
      expect(with_('departments.read').allows(AppItem.myDepartment), isTrue);
      expect(
        with_('substitutions.create').allows(AppItem.substitutions),
        isTrue,
      );
      expect(
        with_('substitutions.read').allows(AppItem.substitutions),
        isFalse,
      );
      expect(
        with_('attendance.update').allows(AppItem.attendanceCheck),
        isTrue,
      );
      expect(with_('cashier.read').allows(AppItem.cashier), isTrue);
      expect(with_('user_points.create').allows(AppItem.staffPoints), isTrue);
      expect(with_('fundings.read').allows(AppItem.fundings), isTrue);
    });

    test('admins see every one but their own analysis, unless they teach', () {
      final a = AppAccess(_profile(roles: ['admin']));
      expect(
        pushedItems.where((i) => i != AppItem.myLessonAnalysis).every(a.allows),
        isTrue,
      );
      expect(a.allows(AppItem.myLessonAnalysis), isFalse);
      final teaching = AppAccess(_profile(roles: ['admin', 'teacher']));
      expect(pushedItems.every(teaching.allows), isTrue);
    });
  });

  test('money formats like the web cashier', () {
    expect(money(5), r'$5');
    expect(money(-2.5), r'−$2.50');
    expect(money(null), r'$0');
  });

  test('cashier reasons drop their source prefix', () {
    expect(describeReason('Cashier: spend · pen'), 'pen');
    expect(describeReason('Dombit: spend T00012 · lunch'), 'lunch');
    expect(describeReason('homework'), 'homework');
  });

  test('compareClass puts 9B before 10A', () {
    expect((['10A', '9B', '9A']..sort(compareClass)), ['9A', '9B', '10A']);
  });

  test('signed points and the observation date', () {
    expect(signedPoints(20), '+20');
    expect(signedPoints(-5), '-5');
    expect(signedPoints(0), '0');
    expect(Observation({'date': '2026-11-03T00:00:00Z'}).date, '2026-11-03');
  });

  test('ApiClient.rows reads result, items and data lists', () {
    expect(
      ApiClient.rows({
        'result': [
          {'a': 1},
        ],
      }).length,
      1,
    );
    expect(
      ApiClient.rows({
        'result': {
          'items': [
            {'a': 1},
            {'a': 2},
          ],
        },
      }).length,
      2,
    );
    expect(ApiClient.rows(null), isEmpty);
    expect(
      userRoles({
        'roles': [
          'teacher',
          {'name': 'hod'},
        ],
      }),
      ['teacher', 'hod'],
    );
  });

  group('lesson countdown', () {
    final day = NextLessonDay(
      day: DateTime(2026, 11, 19),
      items: const [
        TodayItem(
          start: '08:30',
          end: '09:15',
          classLabel: '9B',
          subject: 'Math',
        ),
        TodayItem(
          start: '09:15',
          end: '10:00',
          classLabel: '',
          subject: 'Meeting',
        ),
        TodayItem(
          start: '12:00',
          end: '12:40',
          classLabel: '7A',
          subject: '',
          isLunchDuty: true,
        ),
      ],
    );

    test('shows m:ss left while a lesson or lunch duty is on', () {
      expect(lessonCountdown(day, DateTime(2026, 11, 19, 8, 30)), '45:00');
      expect(lessonCountdown(day, DateTime(2026, 11, 19, 12, 10)), '30:00');
      expect(lessonCountdown(day, DateTime(2026, 11, 19, 9, 14, 55)), '0:05');
    });

    test('is empty at the bell, in meetings and on other days', () {
      expect(lessonCountdown(day, DateTime(2026, 11, 19, 9, 15)), isNull);
      expect(lessonCountdown(day, DateTime(2026, 11, 19, 9, 30)), isNull);
      expect(lessonCountdown(day, DateTime(2026, 11, 20, 8, 40)), isNull);
      expect(lessonCountdown(null, DateTime(2026, 11, 19, 8, 40)), isNull);
    });
  });

  group('Dombit \$ PDF', () {
    test('writes dollars the way the web does', () {
      expect(dombitMoney(0), r'$0');
      expect(dombitMoney(0, sign: true), '');
      expect(dombitMoney(12), r'$12');
      expect(dombitMoney(2, sign: true), r'+$2');
      expect(dombitMoney(-3.5), r'−$3.50');
    });

    test('builds a PDF from a class report', () async {
      pw.Font font(String name) => pw.Font.ttf(
        File('assets/pdf/$name').readAsBytesSync().buffer.asByteData(),
      );
      final bytes = await buildDombitPdf(
        {
          'class_name': '9B',
          'from': '2026-11-09',
          'to': '2026-11-15',
          'students': [
            {'person_id': 1, 'code': 'DIS-001', 'balance': 12, 'change': -2},
            {'person_id': 2, 'code': 'DIS-002', 'balance': -1.5},
          ],
          'negatives': [
            {
              'person_id': 1,
              'date': '2026-11-10',
              'reason': 'Опоздание',
              'comment': 'kech qoldi',
              'dollars': -2,
            },
          ],
        },
        regular: font('DejaVuSans.ttf'),
        bold: font('DejaVuSans-Bold.ttf'),
        logoSvg: File('assets/pdf/logo.svg').readAsStringSync(),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });
  });
}
