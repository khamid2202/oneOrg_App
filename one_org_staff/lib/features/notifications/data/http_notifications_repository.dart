import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../domain/notifications_repository.dart';

/// Talks to the staff notifications API (`docs/staff/notifications.md`).
///
/// The inbox endpoints need nothing but a session — only `POST
/// /notifications/send` is permission-gated, and this app never sends.
class HttpNotificationsRepository implements NotificationsRepository {
  HttpNotificationsRepository({
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
  Future<NotificationPage> getNotifications(
    String token, {
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    final response = await _client.get(
      _buildUri('/notifications', {
        'page': '$page',
        'limit': '$limit',
        if (isRead != null) 'is_read': '$isRead',
      }),
      headers: _authHeaders(token),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load notifications.'),
      );
    }

    final body = responseBody is Map<String, dynamic>
        ? responseBody
        : const <String, dynamic>{};
    // The documented shape is a bare `{ items, total, … }`, but every other
    // repository here tolerates a `data` wrapper, so this one does too.
    final payload = body['data'] is Map<String, dynamic>
        ? body['data'] as Map<String, dynamic>
        : body;

    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => AppNotification.fromJson(Map<String, dynamic>.from(item)))
              .toList()
        : <AppNotification>[];

    return NotificationPage(
      items: items,
      total: _asInt(payload['total']) ?? items.length,
      page: _asInt(payload['page']) ?? page,
      pages: _asInt(payload['pages']) ?? 1,
      unreadCount: _asInt(payload['unread_count']) ?? 0,
    );
  }

  @override
  Future<int> getUnreadCount(String token) async {
    final response = await _client.get(
      _buildUri('/notifications/unread-count'),
      headers: _authHeaders(token),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load the unread count.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final direct = _asInt(responseBody['unread_count']);
      if (direct != null) return direct;
      final data = responseBody['data'];
      if (data is Map<String, dynamic>) {
        return _asInt(data['unread_count']) ?? 0;
      }
    }
    return 0;
  }

  @override
  Future<void> markAsRead(String token, {required int id}) async {
    final response = await _client.patch(
      _buildUri('/notifications/$id/read'),
      headers: _authHeaders(token),
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(
          _decodeBody(response.body),
          'Unable to mark the notification as read.',
        ),
      );
    }
  }

  @override
  Future<void> markAllAsRead(String token) async {
    final response = await _client.post(
      _buildUri('/notifications/read-all'),
      headers: _authHeaders(token),
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(
          _decodeBody(response.body),
          'Unable to mark everything as read.',
        ),
      );
    }
  }

  @override
  Future<void> registerDeviceToken(
    String token, {
    required String deviceToken,
    required String platform,
  }) async {
    final response = await _client.post(
      _buildUri('/notifications/device-token'),
      headers: _authHeaders(token),
      body: jsonEncode({'token': deviceToken, 'platform': platform}),
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(
          _decodeBody(response.body),
          'Unable to register this device for notifications.',
        ),
      );
    }
  }

  @override
  Future<void> unregisterDeviceToken(
    String token, {
    required String deviceToken,
  }) async {
    final response = await _client.delete(
      _buildUri('/notifications/device-token'),
      headers: _authHeaders(token),
      body: jsonEncode({'token': deviceToken}),
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(
          _decodeBody(response.body),
          'Unable to unregister this device.',
        ),
      );
    }
  }

  Map<String, String> _authHeaders(String token) => {
    ..._jsonHeaders,
    'Authorization': 'Bearer $token',
  };

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
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
