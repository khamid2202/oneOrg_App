import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/domain/auth_repository.dart';
import '../lessons/data/offline_cache.dart';

double? _number(dynamic value) => value is num
    ? value.toDouble()
    : num.tryParse('${value ?? ''}')?.toDouble();

int? _int(dynamic value) => _number(value)?.toInt();

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

List<Map<String, dynamic>> _maps(dynamic value) => value is List
    ? value.whereType<Map>().map(Map<String, dynamic>.from).toList()
    : const [];

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

/// One subject's imported (Edupage) average for the class.
class SubjectAverage {
  const SubjectAverage({
    required this.subject,
    required this.average,
    this.lowest,
    this.highest,
  });

  final String subject;
  final double? average;
  final double? lowest;
  final double? highest;
}

/// The class's grades in one go: Edupage averages, OneOrg's daily scores, and
/// each student's main score, as the web's class Grades tab shows them.
class ClassGrades {
  const ClassGrades({
    this.importedAverage,
    this.dailyAverage,
    this.dailyLessons = 0,
    this.categories = const {},
    this.subjects = const [],
    this.importedByPerson = const {},
    this.dailyByPerson = const {},
  });

  final double? importedAverage;
  final double? dailyAverage;
  final int dailyLessons;

  /// `average_attendance` … `average_notes`, each out of 20.
  final Map<String, double?> categories;
  final List<SubjectAverage> subjects;
  final Map<int, double> importedByPerson;
  final Map<int, double> dailyByPerson;

  /// Edupage is the main score; the daily one stands in until there is one.
  double? get classAverage =>
      importedAverage ?? (dailyLessons > 0 ? dailyAverage : null);

  double? scoreOf(int personId) =>
      importedByPerson[personId] ?? dailyByPerson[personId];

  bool get isEmpty => classAverage == null && subjects.isEmpty;

  static ClassGrades fromBodies({
    dynamic imported,
    dynamic daily,
    dynamic byStudent,
  }) {
    final importedResult = _map(_map(imported)['result']);
    final dailyResult = _map(_map(daily)['result']);
    return ClassGrades(
      importedAverage: _number(_map(importedResult['summary'])['average']),
      dailyAverage: _number(dailyResult['average_score']),
      dailyLessons: _int(dailyResult['lessons']) ?? 0,
      categories: {
        for (final key in classGradeCategories) key: _number(dailyResult[key]),
      },
      subjects: [
        for (final row in _maps(importedResult['by_subject']))
          if (_text(row['subject']) != null)
            SubjectAverage(
              subject: _text(row['subject'])!,
              average: _number(row['average']),
              lowest: _number(row['lowest']),
              highest: _number(row['highest']),
            ),
      ],
      importedByPerson: {
        for (final row in _maps(importedResult['by_student']))
          if (_int(row['person_id']) != null && _number(row['average']) != null)
            _int(row['person_id'])!: _number(row['average'])!,
      },
      dailyByPerson: {
        for (final row in _maps(_map(byStudent)['result']))
          if (_int(row['person_id']) != null &&
              _number(row['average_score']) != null)
            _int(row['person_id'])!: _number(row['average_score'])!,
      },
    );
  }
}

const classGradeCategories = [
  'average_attendance',
  'average_materials',
  'average_homework',
  'average_activity',
  'average_notes',
];

/// One behavior mark given to someone in the class.
class ClassMark {
  const ClassMark({
    required this.id,
    required this.studentName,
    required this.positive,
    this.studentId,
    this.reason,
    this.comment,
    this.authorName,
    this.createdAt,
  });

  final String id;

  /// The enrollment id. Older marks from the Telegram bot only have a name.
  final int? studentId;
  final String studentName;
  final bool positive;
  final String? reason;
  final String? comment;
  final String? authorName;
  final DateTime? createdAt;

  /// The reason and the teacher's comment, as the web's full history shows
  /// them: "Late · Came after the bell".
  String get detail =>
      [?reason, if (comment != null && comment != reason) comment!].join(' · ');

  factory ClassMark.fromJson(Map<String, dynamic> json) => ClassMark(
    id: '${json['id']}',
    studentId: _int(json['studentId']),
    studentName: _text(json['studentName']) ?? '',
    positive: json['type'] == 'positive',
    reason: _text(json['reasonLabel']) ?? _text(json['comment']),
    comment: _text(json['comment']),
    authorName: _text(json['authorName']),
    createdAt: DateTime.tryParse('${json['createdAt'] ?? ''}')?.toLocal(),
  );
}

/// One line of a grade trend: the class, a student or a subject. [values] is
/// the average per bucket (null when there were too few grades); [change] is
/// the points gained or lost over the window (null under two values).
class TrendSeries {
  const TrendSeries({
    required this.id,
    required this.name,
    this.values = const [],
    this.average,
    this.change,
    this.gradeCount = 0,
    this.subjects = const [],
  });

  final int id;
  final String name;
  final List<double?> values;
  final double? average;
  final double? change;
  final int gradeCount;

  /// A student's subjects: (subject id, average, change).
  final List<({int id, double? average, double? change})> subjects;

  factory TrendSeries.fromJson(Map<String, dynamic> json) => TrendSeries(
    id: _int(json['id']) ?? 0,
    name: _text(json['name']) ?? '',
    values: [for (final v in json['values'] as List? ?? const []) _number(v)],
    average: _number(json['average']),
    change: _number(json['change']),
    gradeCount: _int(json['grade_count']) ?? 0,
    subjects: [
      for (final s in _maps(json['subjects']))
        (
          id: _int(s['id']) ?? 0,
          average: _number(s['average']),
          change: _number(s['change']),
        ),
    ],
  );
}

/// `/lesson-grades/statistics/trend` for one class: the class line, each
/// student's line and each subject's, by week or month.
class GradeTrend {
  const GradeTrend({
    required this.bucket,
    required this.buckets,
    required this.overall,
    this.rows = const [],
    this.subjects = const [],
  });

  final String bucket;

  /// Each bucket's first day, "YYYY-MM-DD".
  final List<String> buckets;
  final TrendSeries overall;
  final List<TrendSeries> rows;
  final List<TrendSeries> subjects;

  factory GradeTrend.fromJson(Map<String, dynamic> json) => GradeTrend(
    bucket: _text(json['bucket']) ?? 'week',
    buckets: [for (final b in json['buckets'] as List? ?? const []) '$b'],
    overall: TrendSeries.fromJson(_map(json['overall'])),
    rows: _maps(json['rows']).map(TrendSeries.fromJson).toList(),
    subjects: _maps(json['subjects']).map(TrendSeries.fromJson).toList(),
  );
}

/// What My Class asks about a class beyond its roster.
abstract class ClassInsightsRepository {
  Future<ClassGrades> grades(int groupId);

  /// Newest first. [className] is the compact form the marks use: "9B".
  Future<List<ClassMark>> marks(String className);

  /// The class's daily scores over time; [bucket] is "week" or "month".
  Future<GradeTrend> trend({
    required int groupId,
    required int academicYearId,
    required String bucket,
    int? subjectId,
  });
}

/// "9-B" → "9B", the form behavior marks are filed under.
String compactClassName(String classPair) =>
    classPair.replaceAll(RegExp(r'[\s-]'), '');

class HttpClassInsightsRepository implements ClassInsightsRepository {
  HttpClassInsightsRepository({
    required http.Client client,
    required String baseUrl,
    required Future<String?> Function() readToken,
    OfflineCache? cache,
    int? Function()? branchId,
  }) : _client = client,
       _cache = cache,
       _branchId = branchId,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _readToken = readToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _readToken;
  final OfflineCache? _cache;
  final int? Function()? _branchId;

  static const _timeout = Duration(seconds: 12);

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final key = '${uri.path}?${uri.query}&branch=${_branchId?.call() ?? ''}';
    final http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(_timeout);
    } on Exception {
      final remembered = await _cache?.recall(key);
      if (remembered != null) return jsonDecode(remembered);
      rethrow;
    }
    if (response.statusCode >= 500) {
      final remembered = await _cache?.recall(key);
      if (remembered != null) return jsonDecode(remembered);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthFailure('Request failed (${response.statusCode}).');
    }
    await _cache?.remember(key, response.body);
    return jsonDecode(response.body);
  }

  /// Any of the three may be refused or missing; the others still show.
  Future<dynamic> _maybe(String path, Map<String, String> query) async {
    try {
      return await _get(path, query);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ClassGrades> grades(int groupId) async {
    final query = {'group_id': '$groupId'};
    final bodies = await Future.wait([
      _maybe('/lesson-grades/statistics/imported', query),
      _maybe('/lesson-grades/statistics', query),
      _maybe('/lesson-grades/statistics/by-student', query),
    ]);
    if (bodies.every((body) => body == null)) {
      throw const AuthFailure("Couldn't load grades.");
    }
    return ClassGrades.fromBodies(
      imported: bodies[0],
      daily: bodies[1],
      byStudent: bodies[2],
    );
  }

  @override
  Future<List<ClassMark>> marks(String className) async {
    final body = await _get('/behavior/marks', {'className': className});
    final marks = _maps(_map(body)['marks']).map(ClassMark.fromJson).toList()
      ..sort((a, b) {
        final at = a.createdAt, bt = b.createdAt;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });
    return marks;
  }

  @override
  Future<GradeTrend> trend({
    required int groupId,
    required int academicYearId,
    required String bucket,
    int? subjectId,
  }) async {
    final body = await _get('/lesson-grades/statistics/trend', {
      'academic_year_id': '$academicYearId',
      'bucket': bucket,
      'group_id': '$groupId',
      'subject_id': ?subjectId?.toString(),
    });
    return GradeTrend.fromJson(_map(_map(body)['result']));
  }
}
