import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../domain/exams_repository.dart';

/// Talks to `/exam-periods`, `/exams`, `/exam-results` and `/subjects` — the
/// same four resources the web Exams page uses.
class HttpExamsRepository implements ExamsRepository {
  HttpExamsRepository({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<ExamPeriod>> getExamPeriods(
    String token, {
    bool? isActive,
    int? academicYearId,
  }) async {
    final body = await _get(
      token,
      '/exam-periods',
      query: {
        if (isActive != null) 'is_active': isActive.toString(),
        if (academicYearId != null)
          'academic_year_id': academicYearId.toString(),
      },
      failure: 'Unable to load exam periods.',
    );

    return _parse(body, ExamPeriod.fromJson);
  }

  @override
  Future<List<Exam>> getExams(String token, {int? examPeriodId}) async {
    final body = await _get(
      token,
      '/exams',
      query: {
        if (examPeriodId != null) 'exam_period_id': examPeriodId.toString(),
      },
      failure: 'Unable to load exams.',
    );

    return _parse(body, Exam.fromJson);
  }

  @override
  Future<Exam> createExam(
    String token, {
    required int examPeriodId,
    required int subjectId,
    required List<int> groupIds,
    required int maxScore,
  }) async {
    final response = await _client.post(
      _buildUri('/exams'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'exam_period_id': examPeriodId,
        'subject_id': subjectId,
        if (groupIds.isNotEmpty) 'group_ids': groupIds,
        'max_score': maxScore,
      }),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(_extractMessage(responseBody, 'Unable to create exam.'));
    }

    final result = responseBody is Map<String, dynamic>
        ? responseBody['result']
        : null;
    if (result is Map) {
      return Exam.fromJson(Map<String, dynamic>.from(result));
    }

    throw const AuthFailure('The server did not return the created exam.');
  }

  @override
  Future<void> deleteExam(String token, {required int examId}) async {
    await _delete(token, '/exams/$examId', failure: 'Unable to delete exam.');
  }

  @override
  Future<List<SubjectEntry>> getSubjects(String token) async {
    // `/subjects` answers with a bare array (docs/staff/subjects.md), but the
    // shared parser tolerates the envelope the other endpoints use.
    final body = await _get(
      token,
      '/subjects',
      failure: 'Unable to load subjects.',
    );

    return _parse(body, SubjectEntry.fromJson);
  }

  @override
  Future<List<ExamResult>> getExamResults(
    String token, {
    required int examId,
  }) async {
    final body = await _get(
      token,
      '/exam-results',
      query: {'exam_id': examId.toString()},
      failure: 'Unable to load exam results.',
    );

    return _parse(body, ExamResult.fromJson);
  }

  @override
  Future<void> createExamResultsBulk(
    String token,
    List<ExamResultDraft> drafts,
  ) async {
    if (drafts.isEmpty) {
      return;
    }

    final response = await _client.post(
      _buildUri('/exam-results/bulk'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode([
        for (final draft in drafts)
          {
            'student_id': draft.studentId,
            'exam_id': draft.examId,
            'score': draft.score,
          },
      ]),
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(_decodeBody(response.body), 'Unable to save grades.'),
      );
    }
  }

  @override
  Future<void> updateExamResult(
    String token, {
    required int resultId,
    required double score,
  }) async {
    // One request per changed row: `PATCH /exam-results/bulk` rejects the array
    // payload with a DTO validation error, which the web hit too.
    final response = await _client.patch(
      _buildUri('/exam-results/$resultId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({'score': score}),
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(_decodeBody(response.body), 'Unable to update a grade.'),
      );
    }
  }

  @override
  Future<void> deleteExamResult(String token, {required int resultId}) async {
    await _delete(
      token,
      '/exam-results/$resultId',
      failure: 'Unable to clear a grade.',
    );
  }

  Future<dynamic> _get(
    String token,
    String path, {
    Map<String, String>? query,
    required String failure,
  }) async {
    final response = await _client.get(
      _buildUri(path, queryParameters: query),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(_extractMessage(responseBody, failure));
    }
    return responseBody;
  }

  Future<void> _delete(
    String token,
    String path, {
    required String failure,
  }) async {
    final response = await _client.delete(
      _buildUri(path),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(_extractMessage(_decodeBody(response.body), failure));
    }
  }

  /// Maps rows through [fromJson], skipping any the API returns malformed
  /// rather than failing the whole list.
  List<T> _parse<T>(dynamic body, T Function(Map<String, dynamic>) fromJson) {
    final rows = _extractRows(body);
    final parsed = <T>[];
    for (final row in rows) {
      try {
        parsed.add(fromJson(row));
      } on FormatException {
        continue;
      }
    }
    return parsed;
  }

  List<Map<String, dynamic>> _extractRows(dynamic responseBody) {
    List<Map<String, dynamic>> asMaps(List value) => value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    if (responseBody is List) {
      return asMaps(responseBody);
    }

    if (responseBody is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in const ['result', 'results', 'data', 'subjects']) {
      final value = responseBody[key];
      if (value is List) {
        return asMaps(value);
      }
    }

    return const [];
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  dynamic _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  String _extractMessage(dynamic responseBody, String fallback) {
    if (responseBody is Map<String, dynamic>) {
      final message = responseBody['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
      if (message is List && message.isNotEmpty) {
        return message.join('\n');
      }
    }

    if (responseBody is String && responseBody.trim().isNotEmpty) {
      return responseBody;
    }

    return fallback;
  }
}
