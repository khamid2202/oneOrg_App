import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../lessons/data/offline_cache.dart';
import '../domain/auth_repository.dart';

class HttpAuthRepository implements AuthRepository {
  HttpAuthRepository({
    required http.Client client,
    required String baseUrl,
    OfflineCache? cache,
  }) : _client = client,
       _baseUrl = _normalizeBaseUrl(baseUrl),
       _cache = cache;

  static const _profileKey = '/users/me';

  final http.Client _client;
  final String _baseUrl;
  final OfflineCache? _cache;

  @override
  Future<String> signIn({
    required String username,
    required String password,
  }) async {
    final response = await _client
        .post(
          _buildUri('/auth/signin'),
          headers: _jsonHeaders,
          body: jsonEncode({
            'username': username,
            'password': password,
            'uses_bearer_token': 'true',
          }),
        )
        .timeout(const Duration(seconds: 12));

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
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
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
    final response = await _client
        .get(
          _buildUri('/auth/validate'),
          headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
        )
        .timeout(const Duration(seconds: 12));

    // Only an authentication rejection proves that the stored token is invalid.
    if (response.statusCode != 401 &&
        response.statusCode != 403 &&
        !_isSuccess(response.statusCode)) {
      throw SessionUncheckable(response.statusCode);
    }

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
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );
  }

  @override
  Future<AppUserProfile> getCurrentUser(String token) async {
    final http.Response response;
    try {
      response = await _client
          .get(
            _buildUri(_profileKey),
            headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 12));
    } on Exception {
      final kept = await _keptProfile();
      if (kept != null) return kept;
      rethrow;
    }
    if (response.statusCode >= 500) {
      final kept = await _keptProfile();
      if (kept != null) return kept;
    }

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load the current user.'),
      );
    }

    final userMap = _extractUserMap(responseBody);
    final profile = AppUserProfile.fromJson(userMap);
    await _cache?.remember(_profileKey, response.body);
    return profile;
  }

  /// The last profile seen, so name and permissions survive a lost connection.
  Future<AppUserProfile?> _keptProfile() async {
    final body = await _cache?.recall(_profileKey);
    if (body == null) return null;
    try {
      return AppUserProfile.fromJson(_extractUserMap(_decodeBody(body)));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String?> uploadProfilePicture(
    String token, {
    required int userId,
    required List<int> bytes,
    required String filename,
  }) async {
    // docs/staff/users.md: POST /users/:id/picture, multipart field `file`,
    // responds with { ok, picture_url }.
    final request =
        http.MultipartRequest('POST', _buildUri('/users/$userId/picture'))
          ..headers.addAll({
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          })
          ..files.add(
            http.MultipartFile.fromBytes('file', bytes, filename: filename),
          );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to upload the picture.'),
      );
    }

    return _extractPictureUrl(responseBody);
  }

  @override
  Future<String?> removeProfilePicture(
    String token, {
    required int userId,
  }) async {
    final response = await _client.delete(
      _buildUri('/users/$userId/picture'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to remove the picture.'),
      );
    }

    return _extractPictureUrl(responseBody);
  }

  @override
  Future<ProfileContact> loadContact(String token) async {
    final response = await _client.get(
      _buildUri('/settings/profile'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );
    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load contact details.'),
      );
    }
    return ProfileContact.fromJson(responseBody);
  }

  @override
  Future<ProfileContact> updateContact(
    String token, {
    required String email,
    required String phone,
  }) async {
    final response = await _client.patch(
      _buildUri('/settings/profile'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      // UpdateProfileDto takes `phone_number`, the name reads return too.
      body: jsonEncode({'email': email, 'phone_number': phone}),
    );
    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      // Duplicates come back as a 400 with "Email is already taken" etc.
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to update contact details.'),
      );
    }
    final saved = ProfileContact.fromJson(responseBody);
    // Prefer the server's copy; fall back to what was sent.
    return ProfileContact(
      email: saved.email.isNotEmpty ? saved.email : email,
      phone: saved.phone.isNotEmpty ? saved.phone : phone,
    );
  }

  @override
  Future<void> sendSuggestion(
    String token, {
    required String message,
    required bool anonymous,
  }) async {
    final response = await _client.post(
      _buildUri('/suggestions'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({'message': message, 'anonymous': anonymous}),
    );
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(_decodeBody(response.body), 'Could not send.'),
      );
    }
  }

  String? _extractPictureUrl(dynamic responseBody) {
    if (responseBody is! Map<String, dynamic>) {
      return null;
    }

    final url = responseBody['picture_url'] ?? responseBody['pictureUrl'];
    if (url is String && url.trim().isNotEmpty) {
      return url.trim();
    }

    return null;
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
