import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/domain/auth_repository.dart';
import 'lesson_points_repository.dart';

class HttpLessonPointsRepository implements LessonPointsRepository {
  HttpLessonPointsRepository({
    required http.Client client,
    required String baseUrl,
    required int academicYearId,
  }) : _client = client,
       _baseUrl = _normalizeBaseUrl(baseUrl),
       _academicYearId = academicYearId;

  final http.Client _client;
  final String _baseUrl;
  final int _academicYearId;

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<StudentEntry>> getStudentsForGroup(
    String token, {
    required int groupId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/students/all',
        queryParameters: {
          'academic_year_id': _academicYearId.toString(),
          'include_group': 'true',
          'limit': '100',
          'page': '1',
          'filter': jsonEncode({
            'group_ids': [groupId.toString()],
          }),
        },
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load students.'),
      );
    }

    final students =
        _extractStudents(responseBody).map(StudentEntry.fromJson).toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    return students;
  }

  @override
  Future<void> createPointsBulk(
    String token,
    List<StudentPointDraft> points,
  ) async {
    final payload = points
        .map(
          (point) => {
            'student_id': point.studentId,
            'group_id': point.groupId,
            if (point.subjectId != null) 'subject_id': point.subjectId,
            'points': point.points,
            'date': _formatDate(point.date),
            if (point.reason != null && point.reason!.trim().isNotEmpty)
              'reason': point.reason!.trim(),
          },
        )
        .toList();

    final response = await _client.post(
      _buildUri('/student-points/bulk'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode(payload),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to save points.'),
      );
    }
  }

  @override
  Future<Map<int, double>> getPointsForGroupAndDate(
    String token, {
    required int groupId,
    required DateTime date,
    int? subjectId,
  }) async {
    final dateStr = _formatDate(date);
    final response = await _client.get(
      _buildUri(
        '/student-points',
        queryParameters: {
          'group_id': groupId.toString(),
          if (subjectId != null) 'subject_id': subjectId.toString(),
          'start_date': dateStr,
          'end_date': dateStr,
          'limit': '100',
        },
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load points.'),
      );
    }

    final pointsMap = <int, double>{};
    if (responseBody is Map<String, dynamic>) {
      final results = responseBody['points'] ??
          responseBody['results'] ??
          responseBody['data'] ??
          responseBody['result'];
      if (results is List) {
        for (final item in results) {
          if (item is Map<String, dynamic>) {
            final studentId = _asInt(item['student_id']);
            final pointsValue = _asDouble(item['points']);
            if (studentId != null && pointsValue != null) {
              pointsMap[studentId] = pointsValue;
            }
          }
        }
      }
    } else if (responseBody is List) {
      for (final item in responseBody) {
        if (item is Map<String, dynamic>) {
          final studentId = _asInt(item['student_id']);
          final pointsValue = _asDouble(item['points']);
          if (studentId != null && pointsValue != null) {
            pointsMap[studentId] = pointsValue;
          }
        }
      }
    }
    return pointsMap;
  }

  @override
  Future<List<GroupEntry>> getGroups(
    String token, {
    required int academicYearId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/groups',
        queryParameters: {
          'academic_year_id': academicYearId.toString(),
        },
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load classes.'),
      );
    }

    final groups = <GroupEntry>[];
    if (responseBody is Map<String, dynamic>) {
      final results = responseBody['groups'] ?? responseBody['data'] ?? responseBody['result'];
      if (results is List) {
        for (final item in results) {
          if (item is Map<String, dynamic>) {
            groups.add(GroupEntry.fromJson(item));
          }
        }
      }
    } else if (responseBody is List) {
      for (final item in responseBody) {
        if (item is Map<String, dynamic>) {
          groups.add(GroupEntry.fromJson(item));
        }
      }
    }

    groups.sort((a, b) {
      final gradeCompare = a.grade.compareTo(b.grade);
      if (gradeCompare != 0) return gradeCompare;
      return a.className.compareTo(b.className);
    });

    return groups;
  }

  @override
  Future<List<ContactEntry>> getContactsForStudent(
    String token, {
    required int studentId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/contacts',
        queryParameters: {
          'student_id': studentId.toString(),
        },
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load contacts.'),
      );
    }

    final contacts = <ContactEntry>[];
    if (responseBody is Map<String, dynamic>) {
      final results = responseBody['result'] ?? responseBody['data'] ?? responseBody['contacts'];
      if (results is List) {
        for (final item in results) {
          if (item is Map<String, dynamic>) {
            contacts.add(ContactEntry.fromJson(item));
          }
        }
      }
    } else if (responseBody is List) {
      for (final item in responseBody) {
        if (item is Map<String, dynamic>) {
          contacts.add(ContactEntry.fromJson(item));
        }
      }
    }

    return contacts;
  }

  @override
  Future<ContactEntry> createContact(
    String token, {
    required int studentId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
  }) async {
    final response = await _client.post(
      _buildUri('/contacts'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'student_id': studentId,
        'full_name': fullName.trim(),
        'relationship': relationship,
        'phone_number': phoneNumber.trim(),
      }),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to create contact.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'] ?? responseBody;
      if (result is Map<String, dynamic>) {
        return ContactEntry.fromJson(result);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<ContactEntry> updateContact(
    String token, {
    required int contactId,
    String? fullName,
    String? relationship,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName.trim();
    if (relationship != null) body['relationship'] = relationship;
    if (phoneNumber != null) body['phone_number'] = phoneNumber.trim();

    final response = await _client.patch(
      _buildUri('/contacts/$contactId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to update contact.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'] ?? responseBody;
      if (result is Map<String, dynamic>) {
        return ContactEntry.fromJson(result);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<void> deleteContact(
    String token, {
    required int contactId,
  }) async {
    final response = await _client.delete(
      _buildUri('/contacts/$contactId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    if (!_isSuccess(response.statusCode)) {
      final responseBody = _decodeBody(response.body);
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to delete contact.'),
      );
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
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

  List<Map<String, dynamic>> _extractStudents(dynamic responseBody) {
    if (responseBody is List) {
      return responseBody
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (responseBody is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in const ['students', 'result', 'data']) {
      final value = responseBody[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (value is Map<String, dynamic>) {
        final nested = value['students'];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }

    return const [];
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
