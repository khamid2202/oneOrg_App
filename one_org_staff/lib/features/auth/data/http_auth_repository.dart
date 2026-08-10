import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required http.Client client,
    required String baseUrl,
  })  : _client = client,
        _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      _buildUri('/auth/signin'),
      headers: _jsonHeaders,
      body: jsonEncode({
        'username': username,
        'password': password,
        'uses_bearer_token': 'true',
      }),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(_extractMessage(responseBody, 'Sign in failed.'));
    }

    if (responseBody is! Map<String, dynamic>) {
      throw const AuthFailure('Unexpected response from the server.');
    }

    final user = responseBody['user'];
    if (user is! Map<String, dynamic>) {
      throw const AuthFailure('Login succeeded but user data was missing.');
    }

    final token = user['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthFailure('Login succeeded but no token was returned.');
    }

    return token;
  }

  @override
  Future<String> updatePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final response = await _client.patch(
      _buildUri('/settings/password'),
      headers: {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to update the password.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final message = responseBody['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return 'Password updated successfully.';
  }

  @override
  Future<void> validate(String token) async {
    final response = await _client.get(
      _buildUri('/auth/validate'),
      headers: {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      },
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Session validation failed.'),
      );
    }

    if (responseBody is Map<String, dynamic> && responseBody['ok'] == false) {
      throw const AuthFailure('Session validation failed.');
    }
  }

  @override
  Future<void> revoke(String token) async {
    await _client.post(
      _buildUri('/auth/revoke'),
      headers: {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      },
    );
  }

  @override
  Future<AppUserProfile> getCurrentUser(String token) async {
    final response = await _client.get(
      _buildUri('/users/me'),
      headers: {
        ..._jsonHeaders,
        'Authorization': 'Bearer $token',
      },
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load the current user.'),
      );
    }

    final userMap = _extractUserMap(responseBody);
    return AppUserProfile.fromJson(userMap);
  }

  static const _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

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

  Map<String, dynamic> _extractUserMap(dynamic responseBody) {
    if (responseBody is! Map<String, dynamic>) {
      throw const AuthFailure('Unexpected profile response from the server.');
    }

    final directUser = responseBody['user'];
    if (directUser is Map<String, dynamic>) {
      return directUser;
    }

    final data = responseBody['data'];
    if (data is Map<String, dynamic>) {
      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) {
        return nestedUser;
      }
      return data;
    }

    return responseBody;
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