import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../domain/point_report_repository.dart';

/// Reads point rows from `GET /student-points` (docs/staff/points.md).
///
/// Unlike the web — which pulls every point a group has ever had and filters in
/// the browser — this asks the API for the date span it needs. The span still
/// covers the previous week as well as the reporting period, because the report
/// shows both, but it does not grow without bound as the year goes on.
class HttpPointReportRepository implements PointReportRepository {
  HttpPointReportRepository({
    required http.Client client,
    required String baseUrl,
    this.pageSize = 100,
  }) : _client = client,
       _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client _client;
  final String _baseUrl;
  final int pageSize;

  /// Stops a malformed `meta` from spinning forever. At 100 rows a page this is
  /// 20,000 points for one group and one month — far past any real class.
  static const _maxPages = 200;

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  @override
  Future<List<StudentPoint>> getPoints(
    String token, {
    required int groupId,
    required DateTime start,
    required DateTime end,
  }) async {
    final points = <StudentPoint>[];
    var page = 1;

    while (page <= _maxPages) {
      final response = await _client.get(
        _buildUri('/student-points', {
          'group_id': '$groupId',
          'start_date': _formatDate(start),
          'end_date': _formatDate(end),
          'page': '$page',
          'limit': '$pageSize',
        }),
        headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      );

      final responseBody = _decodeBody(response.body);
      if (!_isSuccess(response.statusCode)) {
        throw AuthFailure(
          _extractMessage(responseBody, 'Unable to load the point report.'),
        );
      }

      final rows = _extractPoints(responseBody);
      points.addAll(rows.map(StudentPoint.fromJson));

      // An empty page ends the walk even when `meta` is missing or wrong,
      // which is also what stops a single-page response from looping.
      if (rows.isEmpty || rows.length < pageSize) {
        break;
      }

      final meta = responseBody is Map<String, dynamic>
          ? responseBody['meta']
          : null;
      if (meta is Map<String, dynamic>) {
        final total = _asInt(meta['total']);
        if (total != null && points.length >= total) {
          break;
        }
      }

      page++;
    }

    return points;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildUri(String path, Map<String, String> queryParameters) =>
      Uri.parse('$_baseUrl$path').replace(queryParameters: queryParameters);

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  static String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

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

  List<Map<String, dynamic>> _extractPoints(dynamic responseBody) {
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

    for (final key in const ['points', 'result']) {
      final value = responseBody[key];
      if (value is List) {
        return asMaps(value);
      }
    }

    final data = responseBody['data'];
    if (data is List) {
      return asMaps(data);
    }
    if (data is Map<String, dynamic>) {
      for (final key in const ['points', 'result']) {
        final value = data[key];
        if (value is List) {
          return asMaps(value);
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
}
