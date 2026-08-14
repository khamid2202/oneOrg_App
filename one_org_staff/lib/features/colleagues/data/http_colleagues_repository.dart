import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../domain/colleagues_repository.dart';

/// Reads the staff directory from `GET /users` (docs/staff/users.md).
///
/// Listing users needs only an authenticated session — no `users.read`
/// permission — which is what lets a teacher open this page.
class HttpColleaguesRepository implements ColleaguesRepository {
  HttpColleaguesRepository({
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
  Future<List<Colleague>> getColleagues(String token) async {
    final response = await _client.get(
      _buildUri('/users'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load colleagues.'),
      );
    }

    return _extractUsers(responseBody).map(Colleague.fromJson).toList();
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildUri(String path) => Uri.parse('$_baseUrl$path');

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

  /// The documented shape is `{ ok, meta, users: [...] }`, but the other
  /// repositories here all tolerate a bare list or a `data` wrapper, so this
  /// one does too rather than being the single endpoint that breaks on it.
  List<Map<String, dynamic>> _extractUsers(dynamic responseBody) {
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

    for (final key in const ['users', 'result']) {
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
      for (final key in const ['users', 'result']) {
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
