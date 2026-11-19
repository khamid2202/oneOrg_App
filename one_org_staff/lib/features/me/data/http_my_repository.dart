import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../../lessons/data/offline_cache.dart';
import '../domain/my_records.dart';

/// `/user-plans`, `/user-points`, `/fundings` and `/funding-categories`. Reads
/// keep their last good answer for when there's no connection.
class HttpMyRepository implements MyRepository {
  HttpMyRepository({
    required http.Client client,
    required String baseUrl,
    required Future<String?> Function() readToken,
    OfflineCache? cache,
    int? Function()? branchId,
  }) : _client = client,
       _branchId = branchId,
       _cache = cache ?? OfflineCache(),
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _readToken = readToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _readToken;
  final OfflineCache _cache;

  /// The branch the server filters by, so each branch keeps its own copy.
  final int? Function()? _branchId;

  static const _pageLimit = 100;
  static const _maxPages = 50;
  static const _readTimeout = Duration(seconds: 12);
  static const _writeTimeout = Duration(seconds: 60);

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
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message = body is Map ? body['message'] : null;
    if (message is String && message.trim().isNotEmpty) {
      throw AuthFailure(message);
    }
    if (message is List && message.isNotEmpty) {
      throw AuthFailure(message.join('\n'));
    }
    throw AuthFailure(fallback);
  }

  Future<dynamic> _get(
    String path,
    Map<String, String> query,
    String fallback,
  ) async {
    final headers = await _headers();
    final uri = _uri(path, query);
    final key = '${uri.path}?${uri.query}&branch=${_branchId?.call() ?? ''}';

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

  static List<Map<String, dynamic>> _rows(dynamic body) {
    final result = body is Map ? body['result'] : null;
    return result is List
        ? result.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  /// The server caps a page at 100; a person's history needs them all.
  Future<List<Map<String, dynamic>>> _all(
    String path,
    Map<String, String> query,
    String fallback,
  ) async {
    final base = {...query, 'limit': '$_pageLimit'};
    final first = await _get(path, {...base, 'page': '1'}, fallback);
    final rows = _rows(first);
    final meta = first is Map ? first['meta'] : null;
    final total = meta is Map ? num.tryParse('${meta['total']}') : null;
    if (total == null) return rows;
    final pages = (total / _pageLimit).ceil().clamp(1, _maxPages);
    if (pages == 1) return rows;
    final rest = await Future.wait([
      for (var page = 2; page <= pages; page++)
        _get(path, {...base, 'page': '$page'}, fallback),
    ]);
    return [...rows, for (final body in rest) ..._rows(body)];
  }

  @override
  Future<List<UserPlan>> getPlans({
    required int userId,
    String? from,
    String? to,
  }) async {
    final rows = await _all('/user-plans', {
      'user_id': '$userId',
      'date_from': ?from,
      'date_to': ?to,
      'sort_by': 'start_date',
      'order': 'ASC',
    }, 'Unable to load your plan.');
    return sortedPlans(rows.map(UserPlan.fromJson));
  }

  Future<void> _sendJson(
    String method,
    String path,
    Map<String, dynamic>? body,
    String fallback,
  ) async {
    final request = http.Request(method, _uri(path))
      ..headers.addAll(await _headers());
    if (body != null) request.body = jsonEncode(body);
    final streamed = await _client.send(request).timeout(_writeTimeout);
    _decode(await http.Response.fromStream(streamed), fallback);
  }

  Future<dynamic> _sendFiles(
    String method,
    String path,
    List<PlanFile> files, {
    Map<String, String> fields = const {},
  }) async {
    final headers = await _headers()
      ..remove('Content-Type');
    final request = http.MultipartRequest(method, _uri(path))
      ..headers.addAll(headers)
      ..fields.addAll(fields);
    for (final file in files) {
      request.files.add(
        http.MultipartFile.fromBytes('files', file.bytes, filename: file.name),
      );
    }
    final streamed = await _client.send(request).timeout(_writeTimeout);
    return _decode(
      await http.Response.fromStream(streamed),
      'Unable to save the files.',
    );
  }

  @override
  Future<void> savePlan(
    PlanDraft draft, {
    int? id,
    List<PlanFile> files = const [],
    List<String> removeAttachmentKeys = const [],
  }) async {
    const fallback = 'Unable to save the milestone.';
    if (id == null) {
      if (files.isEmpty) {
        await _sendJson('POST', '/user-plans', draft.toJson(), fallback);
      } else {
        await _sendFiles(
          'POST',
          '/user-plans',
          files,
          fields: draft.toJson().map((k, v) => MapEntry(k, '$v')),
        );
      }
      return;
    }
    await _sendJson('PATCH', '/user-plans/$id', {
      ...draft.toJson(),
      if (removeAttachmentKeys.isNotEmpty)
        'remove_attachment_keys': removeAttachmentKeys,
    }, fallback);
    if (files.isNotEmpty) {
      await _sendFiles('POST', '/user-plans/$id/attachments', files);
    }
  }

  @override
  Future<void> setPlanStatus(int id, String status) => _sendJson(
    'PATCH',
    '/user-plans/$id',
    {'status': status},
    'Unable to update the status.',
  );

  @override
  Future<void> deletePlan(int id) => _sendJson(
    'DELETE',
    '/user-plans/$id',
    null,
    'Unable to delete the milestone.',
  );

  @override
  Future<List<PointRecord>> getPoints(int userId) async {
    final rows = await _all('/user-points', {
      'user_id': '$userId',
    }, 'Unable to load your points.');
    return rows.map(PointRecord.fromJson).toList();
  }

  @override
  Future<List<Funding>> getFundings(int userId) async {
    final rows = await _all('/fundings', {
      'user_id': '$userId',
    }, 'Unable to load your savings.');
    return rows.map(Funding.fromJson).toList();
  }

  static const _recentLimit = '10';

  @override
  Future<List<PointRecord>> getRecentPoints(
    int userId, {
    required String from,
  }) async {
    final body = await _get('/user-points', {
      'user_id': '$userId',
      'date_from': from,
      'sort_by': 'created_at',
      'order': 'desc',
      'limit': _recentLimit,
    }, 'Unable to load your points.');
    return _rows(body).map(PointRecord.fromJson).toList();
  }

  @override
  Future<List<Funding>> getRecentFundings(
    int userId, {
    required String from,
  }) async {
    final body = await _get('/fundings', {
      'user_id': '$userId',
      'date_from': from,
      'sort_by': 'created_at',
      'order': 'desc',
      'limit': _recentLimit,
    }, 'Unable to load your savings.');
    return _rows(body).map(Funding.fromJson).toList();
  }

  @override
  Future<List<CalendarEntry>> getCalendar({
    required String from,
    required String to,
  }) async {
    final body = await _get('/calendar', {
      'from': from,
      'to': to,
      'sources': 'event,holiday,exam_period',
    }, 'Unable to load your calendar.');
    return _rows(body).map(CalendarEntry.fromJson).toList();
  }

  @override
  Future<List<CalendarEntry>> getFullCalendar({
    required String from,
    required String to,
  }) async {
    final body = await _get('/calendar', {
      'from': from,
      'to': to,
    }, 'Unable to load the calendar.');
    return _rows(body).map(CalendarEntry.fromJson).toList();
  }

  @override
  Future<List<LessonObservation>> getMyObservations(int userId) async {
    final rows = await _all('/lesson-observations', {
      'teacher_id': '$userId',
    }, 'Unable to load your lesson analyses.');
    final list = rows.map(LessonObservation.fromJson).toList()
      ..sort((a, b) {
        final day = b.date.compareTo(a.date);
        return day != 0
            ? day
            : (b.startTime ?? '').compareTo(a.startTime ?? '');
      });
    return list;
  }

  @override
  Future<List<MyDepartmentEntry>> getMyDepartments() async {
    final body = await _get(
      '/departments/my',
      const {},
      'Unable to load your departments.',
    );
    return _rows(body).map(MyDepartmentEntry.fromJson).toList();
  }

  @override
  Future<DepartmentStats> getDepartmentStats(
    int departmentId, {
    int? groupId,
  }) async {
    final body = await _get('/departments/$departmentId/statistics', {
      if (groupId != null) 'group_id': '$groupId',
    }, 'Unable to load the statistics.');
    final result = body is Map ? body['result'] : null;
    return DepartmentStats.fromJson(
      result is Map ? Map<String, dynamic>.from(result) : const {},
    );
  }

  @override
  Future<List<FundingCategory>> getFundingCategories() async {
    final body = await _get(
      '/funding-categories',
      const {},
      'Unable to load the categories.',
    );
    return [
      for (final row in _rows(body))
        FundingCategory(
          id: num.tryParse('${row['id']}')?.toInt() ?? 0,
          name: row['name']?.toString() ?? '',
        ),
    ];
  }
}
