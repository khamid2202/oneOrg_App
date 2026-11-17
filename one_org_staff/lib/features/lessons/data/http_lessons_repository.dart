import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../../branches/data/branch_http_client.dart';
import '../domain/lessons_repository.dart';
import '../../grades/domain/gradebook.dart';
import 'offline_cache.dart';

/// The teaching day. Everything except the bell schedule goes across branches:
/// a teacher can open a lesson at any campus they work at, whichever is
/// selected on the dashboard.
class HttpLessonsRepository implements LessonsRepository {
  HttpLessonsRepository({
    required http.Client client,
    required String baseUrl,
    required Future<String?> Function() readToken,
    OfflineCache? cache,
  }) : _client = client,
       _cache = cache ?? OfflineCache(),
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _readToken = readToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _readToken;
  final OfflineCache _cache;

  static const _readTimeout = Duration(seconds: 12);
  static const _uploadTimeout = Duration(seconds: 30);

  Future<Map<String, String>> _headers() async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  dynamic _decode(http.Response response, String fallback) {
    dynamic body;
    try {
      body = response.body.trim().isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      body = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final message = body is Map ? body['message'] : null;
    if (message is String && message.trim().isNotEmpty) {
      throw AuthFailure(message);
    }
    if (message is List && message.isNotEmpty) {
      throw AuthFailure(message.join('\n'));
    }
    throw AuthFailure(fallback);
  }

  /// A GET whose last good answer is kept on the phone and stands in when
  /// there is no connection. [cacheKey] overrides the key built from the URL.
  Future<dynamic> _get(
    String path,
    String fallback, [
    Map<String, String>? query,
    String? cacheKey,
  ]) async {
    final headers = await _headers();
    final uri = _uri(path, query);
    final key = cacheKey ?? '${uri.path}?${uri.query}';

    final http.Response response;
    try {
      response = await _client.get(uri, headers: headers).timeout(_readTimeout);
    } on Exception {
      final remembered = await _cache.recall(key);
      if (remembered != null) return jsonDecode(remembered);
      rethrow;
    }
    if (response.statusCode >= 500) {
      final remembered = await _cache.recall(key);
      if (remembered != null) return jsonDecode(remembered);
    }
    final body = _decode(response, fallback);
    await _cache.remember(key, response.body);
    return body;
  }

  static String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
      : const [];

  @override
  Future<LessonDay> getDay(DateTime date) {
    return acrossBranches(() async {
      final query = {'date': _dateKey(date)};
      // `/my-lessons` reads the timetable, so it always lists the day.
      // `/timetable/my-lessons` lists the lesson records that scoring needs,
      // which don't exist on holidays or before a day is generated. The
      // timetable is the list and the records are laid over it.
      final results = await Future.wait([
        _settle(_get('/my-lessons', 'Unable to load your lessons.', query)),
        _settle(
          _get('/timetable/my-lessons', 'Unable to load your lessons.', query),
        ),
      ]);
      final timetable = results[0];
      final records = results[1];
      if (timetable.error != null && records.error != null) {
        throw timetable.error!;
      }

      List<Map<String, dynamic>> lessonsOf(dynamic body) =>
          _maps(body is Map ? body['lessons'] : null);

      final fromTimetable = lessonsOf(timetable.value);
      final instances = lessonsOf(
        records.value,
      ).where((row) => row['lesson_instance_id'] != null).toList();
      final instanceByEntry = {for (final row in instances) row['id']: row};

      final merged = [
        for (final row in fromTimetable)
          {...row, ...?instanceByEntry[row['id']]},
      ];
      // Lessons only the records know, e.g. ones covered as a substitute.
      final listed = fromTimetable.map((row) => row['id']).toSet();
      merged.addAll(instances.where((row) => !listed.contains(row['id'])));

      final lessons = merged.map(TeacherLesson.fromJson).toList()
        ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

      final meetingsSource = records.value is Map
          ? records.value
          : timetable.value;
      return LessonDay(
        lessons: lessons,
        meetings: _maps(
          meetingsSource is Map ? meetingsSource['meetings'] : null,
        ).map(TeacherMeeting.fromJson).toList(),
      );
    });
  }

  Future<_Settled> _settle(Future<dynamic> future) async {
    try {
      return _Settled(value: await future);
    } on Exception catch (error) {
      return _Settled(error: error);
    }
  }

  @override
  Future<List<BellPeriod>> getPeriods({
    int? academicYearId,
    required DateTime date,
  }) async {
    const cacheKey = '/bell-schedules';
    final dynamic body;
    if (academicYearId == null) {
      final remembered = await _cache.recall(cacheKey);
      if (remembered == null) return const [];
      body = jsonDecode(remembered);
    } else {
      body = await _get('/bell-schedules', 'Unable to load the bells.', {
        'academic_year_id': '$academicYearId',
      }, cacheKey);
    }
    final schedules = _maps(
      body is Map ? (body['result'] ?? body['data']) : body,
    );
    if (schedules.isEmpty) return const [];

    final schedule = schedules.firstWhere(
      (row) => row['is_default'] == true,
      orElse: () => schedules.first,
    );
    final weekday = date.weekday % 7; // The API counts from Sunday = 0.
    final periods = <BellPeriod>[];
    for (final row in _maps(schedule['periods'])) {
      final day = row['day_of_week'];
      if (day != null && day != weekday) continue;
      final start = minutesOfDay(row['start_time']?.toString());
      final end = minutesOfDay(row['end_time']?.toString());
      final number = row['period_number'];
      if (start == null || end == null || number is! num) continue;
      periods.add(BellPeriod(number: number.toInt(), start: start, end: end));
    }
    return periods..sort((a, b) => a.start.compareTo(b.start));
  }

  @override
  Future<GradingSheet> getSheet(int lessonId) {
    return acrossBranches(() async {
      const failed = 'Failed to load the lesson.';
      final results = await Future.wait([
        _get('/lesson-instances/$lessonId', failed),
        _get('/lesson-instances/$lessonId/grades', failed),
      ]);
      final lesson = LessonDetail.fromJson(
        Map<String, dynamic>.from(results[0]['result'] as Map),
      );
      final left = await _leftStudentIds(lesson.groupIds);
      return GradingSheet(
        lesson: lesson,
        students: _students(results[1], left),
      );
    });
  }

  List<SheetStudent> _students(dynamic body, Set<int> left) {
    final result = body is Map ? body['result'] : null;
    return _maps(result is Map ? result['students'] : null)
        .map(SheetStudent.fromJson)
        .where((student) => !left.contains(student.studentId))
        .toList();
  }

  /// Enrollments marked as left. The sheet only drops students by leave date,
  /// so someone marked left without one would still be listed. Best effort.
  Future<Set<int>> _leftStudentIds(List<int> groupIds) async {
    final lists = await Future.wait(
      groupIds.toSet().map((groupId) async {
        try {
          final body = await _get('/students', 'Unable to load students.', {
            'group_id': '$groupId',
            'status': 'left',
            'limit': '100',
          });
          return _maps(body is Map ? body['result'] : null);
        } on Exception {
          return const <Map<String, dynamic>>[];
        }
      }),
    );
    return lists
        .expand((rows) => rows)
        .map((row) => row['id'])
        .whereType<num>()
        .map((id) => id.toInt())
        .toSet();
  }

  @override
  Future<void> upload(
    UploadKind kind,
    int lessonId,
    Map<String, dynamic> body,
  ) {
    return acrossBranches(() async {
      final Map<String, String> headers;
      try {
        headers = await _headers();
      } on AuthFailure catch (error) {
        throw UploadRetryLater(error.message);
      }
      final encoded = jsonEncode(body);
      final http.Response response;
      try {
        response = await switch (kind) {
          UploadKind.attendance => _client.put(
            _uri('/lesson-instances/$lessonId/attendance'),
            headers: headers,
            body: encoded,
          ),
          UploadKind.grades => _client.put(
            _uri('/lesson-instances/$lessonId/grades'),
            headers: headers,
            body: encoded,
          ),
          UploadKind.behavior => _client.post(
            _uri('/behavior/marks'),
            headers: headers,
            body: encoded,
          ),
        }.timeout(_uploadTimeout);
      } on Exception catch (error) {
        throw UploadRetryLater('$error');
      }

      final status = response.statusCode;
      if (status >= 200 && status < 300) return;
      final message = _messageOf(response) ?? 'Upload failed ($status)';
      if (status >= 500 || const [401, 408, 429].contains(status)) {
        throw UploadRetryLater(message);
      }
      throw UploadRefused(message);
    });
  }

  @override
  Future<void> clearOffline() => _cache.clear();

  static String? _messageOf(http.Response response) {
    try {
      final message = (jsonDecode(response.body) as Map)['message'];
      if (message is String && message.trim().isNotEmpty) return message;
      if (message is List && message.isNotEmpty) return message.join('\n');
    } catch (_) {}
    return null;
  }

  @override
  Future<List<RecentGrade>> getRecentGrades({int limit = 3}) async {
    final body = await _get(
      '/lesson-grades/gradebook/recent',
      'Unable to load recent grades.',
      {'limit': '$limit'},
    );
    final rows = body is Map ? body['result'] : body;
    return _maps(rows).map(RecentGrade.fromJson).toList();
  }

  @override
  Future<List<GradebookPair>> getMyGradebooks({int? academicYearId}) async {
    final body = await _get(
      '/lesson-grades/gradebook/mine',
      'Unable to load your classes.',
      academicYearId == null ? null : {'academic_year_id': '$academicYearId'},
      '/lesson-grades/gradebook/mine',
    );
    final rows = body is Map ? body['result'] : body;
    return _maps(rows).map(GradebookPair.fromJson).toList();
  }

  @override
  Future<Gradebook> getGradebook(int groupId, int subjectId) async {
    final body = await _get(
      '/lesson-grades/gradebook',
      'Unable to load the gradebook.',
      {'group_id': '$groupId', 'subject_id': '$subjectId'},
    );
    final result = body is Map ? body['result'] : null;
    return result is Map
        ? Gradebook.fromJson(Map<String, dynamic>.from(result))
        : const Gradebook();
  }

  @override
  Future<BehaviorRoster> getBehaviorRoster() async {
    final body = await _get(
      '/behavior/students',
      'Unable to load the student list.',
    );
    if (body is! Map) return const BehaviorRoster();
    final mine = _maps(body['myClasses']);
    return BehaviorRoster(
      students: _maps(body['students']).map(BehaviorStudent.fromJson).toList(),
      myClasses: [for (final row in mine) '${row['className']}'],
      homeroomClass: mine
          .where((row) => row['homeroom'] == true)
          .map((row) => '${row['className']}')
          .firstOrNull,
    );
  }

  @override
  Future<List<BehaviorHistoryEntry>> getBehaviorHistory() async {
    final body = await _get('/behavior/marks', 'Unable to load the history.');
    return _maps(
      body is Map ? body['marks'] : null,
    ).map(BehaviorHistoryEntry.fromJson).toList();
  }

  @override
  Future<BehaviorStatistics> getBehaviorStatistics({
    String? from,
    String? to,
  }) async {
    final body = await _get(
      '/behavior/statistics',
      'Unable to load the statistics.',
      {'from': ?from, 'to': ?to},
    );
    return body is Map
        ? BehaviorStatistics.fromJson(Map<String, dynamic>.from(body))
        : const BehaviorStatistics();
  }

  @override
  Future<BehaviorReasons> getBehaviorReasons() async {
    final body = await _get('/behavior/reasons', 'Unable to load reasons.');
    final reasons = body is Map ? body['reasons'] : null;
    if (reasons is! Map) return const BehaviorReasons();
    return BehaviorReasons(
      positive: _maps(
        reasons['positive'],
      ).map(BehaviorReason.fromJson).toList(),
      negative: _maps(
        reasons['negative'],
      ).map(BehaviorReason.fromJson).toList(),
    );
  }

  @override
  Future<List<BehaviorMark>> getBehaviorMarks(int lessonId) {
    return acrossBranches(() async {
      final body = await _get('/behavior/marks', 'Unable to load marks.', {
        'lessonInstanceId': '$lessonId',
      });
      return _maps(
        body is Map ? body['marks'] : null,
      ).map(BehaviorMark.fromJson).toList();
    });
  }
}

class _Settled {
  const _Settled({this.value, this.error});

  final dynamic value;
  final Exception? error;
}
