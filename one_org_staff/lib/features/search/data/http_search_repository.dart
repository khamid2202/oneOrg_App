import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../domain/app_search.dart';

/// People search the way the web's ⌘K palette does it: `/persons?search=`
/// for the names, and `/students?q=` alongside it for the "Left" badges.
class HttpSearchRepository implements SearchRepository {
  HttpSearchRepository({
    required http.Client client,
    required String baseUrl,
    required Future<String?> Function() readToken,
  }) : _client = client,
       _baseUrl = baseUrl.endsWith('/')
           ? baseUrl.substring(0, baseUrl.length - 1)
           : baseUrl,
       _readToken = readToken;

  final http.Client _client;
  final String _baseUrl;
  final Future<String?> Function() _readToken;

  static const pageSize = 25;
  static const _timeout = Duration(seconds: 12);

  /// Left person ids for the last term, asked once per term.
  (String, Future<Set<int>>)? _left;

  Future<dynamic> _get(String path, Map<String, String> query) async {
    final token = await _readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: query);
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(_timeout);
    if (response.statusCode == 403) throw const SearchLocked();
    dynamic body;
    try {
      body = response.body.trim().isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      body = null;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) return body;
    final message = body is Map ? body['message'] : null;
    throw AuthFailure(
      message is String && message.trim().isNotEmpty
          ? message
          : message is List && message.isNotEmpty
          ? message.join('\n')
          : 'Search failed.',
    );
  }

  static List<Map<String, dynamic>> _rows(dynamic body) {
    final result = body is Map ? body['result'] : null;
    return result is List
        ? result.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  static int? _int(dynamic value) => num.tryParse('$value')?.toInt();

  /// Newest enrollment first: later join date, then higher id.
  static int _newestFirst(Map<String, dynamic> a, Map<String, dynamic> b) {
    final byDate = '${b['join_date'] ?? ''}'.compareTo(
      '${a['join_date'] ?? ''}',
    );
    return byDate != 0
        ? byDate
        : (_int(b['id']) ?? 0).compareTo(_int(a['id']) ?? 0);
  }

  /// Best effort: a failure only means no badges.
  Future<Set<int>> _leftIds(String term) async {
    try {
      final rows = _rows(await _get('/students', {'q': term, 'limit': '100'}));
      final latest = <int, Map<String, dynamic>>{};
      for (final row in rows) {
        final id = _int(row['person_id'] ?? (row['person'] as Map?)?['id']);
        if (id == null) continue;
        final seen = latest[id];
        if (seen == null || _newestFirst(row, seen) < 0) latest[id] = row;
      }
      return {
        for (final entry in latest.entries)
          if ('${entry.value['status'] ?? ''}'.trim().toLowerCase() == 'left')
            entry.key,
      };
    } catch (_) {
      return const {};
    }
  }

  @override
  Future<PersonPage> searchPeople(String term, {int page = 1}) async {
    final trimmed = term.trim();
    final left = _left;
    final leftIds = left != null && left.$1 == trimmed
        ? left.$2
        : (_left = (trimmed, _leftIds(trimmed))).$2;
    final body = await _get('/persons', {
      'search': trimmed,
      'page': '$page',
      'limit': '$pageSize',
    });
    final gone = await leftIds;
    final people = [
      for (final row in _rows(body))
        ?PersonHit.fromJson(row, left: gone.contains(_int(row['id']))),
    ];
    final meta = body is Map ? body['meta'] : null;
    final total = meta is Map ? _int(meta['total']) : null;
    final pages = meta is Map ? _int(meta['pages']) : null;
    return PersonPage(
      people: people,
      total: total ?? people.length,
      pages: pages ?? (total == null ? 1 : (total / pageSize).ceil()),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> enrollmentsOf(int personId) async {
    final rows = _rows(
      await _get('/students', {'person_id': '$personId', 'limit': '100'}),
    );
    return rows..sort(_newestFirst);
  }
}
