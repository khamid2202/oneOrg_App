import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/domain/auth_repository.dart';
import 'time_table_repository.dart';

class HttpTimetableRepository implements TimetableRepository {
  HttpTimetableRepository({
    required http.Client client,
    required String baseUrl,
  }) : _client = client,
       _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<TimetableLesson>> getTimetable(String token) async {
    final response = await _client.get(
      _buildUri('/timetable'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load the timetable.'),
      );
    }

    final lessons = _extractLessons(
      responseBody,
    ).map(TimetableLesson.fromJson).toList()..sort(_compareTimetableEntries);

    return lessons;
  }

  @override
  Future<TimetableDaySchedule> getMyLessons(
    String token, {
    required DateTime date,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/timetable/my-lessons',
        queryParameters: {'date': _formatDate(date)},
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load the timetable.'),
      );
    }

    final lessons = _extractLessons(
      responseBody,
    ).map(TimetableLesson.fromJson).toList()..sort(_compareMyLessons);

    return TimetableDaySchedule(
      date: DateTime(date.year, date.month, date.day),
      lessons: lessons,
    );
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

  List<Map<String, dynamic>> _extractLessons(dynamic responseBody) {
    if (responseBody is List) {
      return responseBody
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (responseBody is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in const ['lessons', 'timetable', 'result']) {
      final value = responseBody[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    final data = responseBody['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (data is Map<String, dynamic>) {
      for (final key in const ['lessons', 'timetable', 'result']) {
        final value = data[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
        }
      }
    }

    return const [];
  }

  int _compareMyLessons(TimetableLesson left, TimetableLesson right) {
    final leftValue = left.startTime ?? left.timeLabel;
    final rightValue = right.startTime ?? right.timeLabel;
    final timeComparison = leftValue.compareTo(rightValue);
    if (timeComparison != 0) {
      return timeComparison;
    }
    return left.title.compareTo(right.title);
  }

  int _compareTimetableEntries(TimetableLesson left, TimetableLesson right) {
    final dayComparison = (left.dayIndex ?? 999).compareTo(
      right.dayIndex ?? 999,
    );
    if (dayComparison != 0) {
      return dayComparison;
    }

    final timeComparison = (left.timeId ?? 999).compareTo(right.timeId ?? 999);
    if (timeComparison != 0) {
      return timeComparison;
    }

    final labelComparison = left.timeLabel.compareTo(right.timeLabel);
    if (labelComparison != 0) {
      return labelComparison;
    }

    return left.title.compareTo(right.title);
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
