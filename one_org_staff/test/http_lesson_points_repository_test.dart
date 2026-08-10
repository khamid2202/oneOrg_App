import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/MyLessons/http_lesson_points_repository.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

void main() {
  test(
    'loads students with configured academic year and string group id filter',
    () async {
      var requestCount = 0;
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          requestCount += 1;

          expect(request.method, 'GET');
          expect(request.url.path, '/students/all');
          expect(request.url.queryParameters['academic_year_id'], '7');
          expect(request.url.queryParameters['include_group'], 'true');
          expect(request.url.queryParameters['limit'], '100');
          expect(request.url.queryParameters['page'], '1');
          expect(request.headers['Authorization'], 'Bearer test-token');

          final filter =
              jsonDecode(request.url.queryParameters['filter']!)
                  as Map<String, dynamic>;
          expect(filter['group_ids'], ['42']);

          return http.Response(
            jsonEncode({
              'students': [
                {'id': 5, 'full_name': 'Ada Lovelace'},
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz/',
        academicYearId: 7,
      );

      final students = await repository.getStudentsForGroup(
        'test-token',
        groupId: 42,
      );

      expect(requestCount, 1);
      expect(students.single.fullName, 'Ada Lovelace');
    },
  );

  test('saves bulk points with subject id when available', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/student-points/bulk');
        expect(request.headers['Authorization'], 'Bearer test-token');

        final payload = jsonDecode(request.body) as List<dynamic>;
        expect(payload, [
          {
            'student_id': 5,
            'group_id': 42,
            'subject_id': 9,
            'points': 8.5,
            'date': '2026-06-11',
          },
        ]);

        return http.Response('{"ok":true}', 201);
      }),
      baseUrl: 'https://dev-api.oneorg.uz/',
      academicYearId: 7,
    );

    await repository.createPointsBulk('test-token', [
      StudentPointDraft(
        studentId: 5,
        groupId: 42,
        subjectId: 9,
        points: 8.5,
        date: DateTime(2026, 6, 11),
      ),
    ]);
  });
}
