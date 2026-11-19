import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../features/auth/domain/auth_repository.dart';

/// A thin JSON client for the pages that came over from the web without a
/// repository of their own (Calendar, Lesson Analysis, My Department,
/// Substitutions, Attendance, Cashier, Staff Points, Fundings).
///
/// Every call carries the session token; the branch header is added by the
/// [http.Client] it is given (`BranchHttpClient`). Errors surface as
/// [AuthFailure] with the server's own `message`, like the other repositories.
class ApiClient {
  ApiClient({
    required http.Client client,
    required String baseUrl,
    required Future<String?> Function() readToken,
  }) : _client = client,
       _readToken = readToken,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _readToken;

  static const _timeout = Duration(seconds: 20);

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

  Uri _uri(String path, Map<String, Object?>? query) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null) return uri;
    final params = <String, String>{
      for (final e in query.entries)
        if (e.value != null && '${e.value}'.isNotEmpty) e.key: '${e.value}',
    };
    return params.isEmpty ? uri : uri.replace(queryParameters: params);
  }

  dynamic _decode(http.Response response) {
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
    throw AuthFailure('Request failed (${response.statusCode}).');
  }

  Future<dynamic> get(String path, [Map<String, Object?>? query]) async {
    final response = await _client
        .get(_uri(path, query), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> post(String path, [Object? body]) async {
    final response = await _client
        .post(
          _uri(path, null),
          headers: await _headers(),
          body: jsonEncode(body ?? const {}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> patch(String path, [Object? body]) async {
    final response = await _client
        .patch(
          _uri(path, null),
          headers: await _headers(),
          body: jsonEncode(body ?? const {}),
        )
        .timeout(_timeout);
    return _decode(response);
  }

  Future<dynamic> delete(String path) async {
    final response = await _client
        .delete(_uri(path, null), headers: await _headers())
        .timeout(_timeout);
    return _decode(response);
  }

  /// `result` as a list of maps (empty when missing).
  static List<Map<String, dynamic>> rows(dynamic body) {
    final result = body is Map ? body['result'] : body;
    final list = result is Map && result['items'] is List
        ? result['items']
        : result is Map && result['data'] is List
        ? result['data']
        : result;
    return list is List
        ? list.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  /// `result` as a map (empty when missing).
  static Map<String, dynamic> one(dynamic body) {
    final result = body is Map ? body['result'] : null;
    return result is Map ? Map<String, dynamic>.from(result) : const {};
  }

  /// Every page of a paged list, up to [maxPages] pages of [limit].
  Future<List<Map<String, dynamic>>> all(
    String path, [
    Map<String, Object?> query = const {},
    int limit = 100,
    int maxPages = 30,
  ]) async {
    final out = <Map<String, dynamic>>[];
    for (var page = 1; page <= maxPages; page++) {
      final body = await get(path, {...query, 'page': page, 'limit': limit});
      final rows = ApiClient.rows(body);
      out.addAll(rows);
      final meta = body is Map ? body['meta'] : null;
      final total = meta is Map ? num.tryParse('${meta['total']}') : null;
      if (rows.length < limit || (total != null && out.length >= total)) break;
    }
    return out;
  }
}

/// Small readers for loosely typed JSON.
int? asInt(Object? v) =>
    v is int ? v : (v is num ? v.toInt() : int.tryParse('${v ?? ''}'));
double? asDouble(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
String? asStr(Object? v) {
  if (v == null) return null;
  final s = '$v'.trim();
  return s.isEmpty ? null : s;
}

/// "First Last" from a user/person-shaped map.
String personName(Map<String, dynamic>? m) {
  if (m == null) return '';
  final full = asStr(m['full_name']) ?? asStr(m['name']);
  if (full != null) return full;
  final person = m['person'];
  if (person is Map) return personName(Map<String, dynamic>.from(person));
  return [
    asStr(m['first_name']),
    asStr(m['last_name']),
  ].whereType<String>().join(' ');
}

/// A local date as `YYYY-MM-DD`.
String isoDay(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Role names from a user map; roles may be strings or `{name}` objects.
List<String> userRoles(Map<String, dynamic> u) {
  final roles = u['roles'];
  if (roles is! List) return const [];
  return [
    for (final r in roles)
      if (r is String) r else if (r is Map && r['name'] != null) '${r['name']}',
  ];
}
