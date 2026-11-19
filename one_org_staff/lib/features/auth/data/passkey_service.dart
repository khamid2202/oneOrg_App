import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:passkeys/authenticator.dart';
import 'package:passkeys/types.dart';

/// Thrown when the user closed the system passkey sheet: not an error to show.
class PasskeyCancelled implements Exception {}

/// Why a passkey sign-in or registration failed, for the message shown.
enum PasskeyProblem {
  noneOnDevice,
  unavailable,
  alreadyOnDevice,
  rejected,
  other,
}

/// Staff passkeys (the same endpoints as the web app, docs/staff/sign-in.md):
/// usernameless sign-in, and adding one to the signed-in account. The relying
/// party is whatever domain the server names; the app must be associated with
/// it (iOS Associated Domains + the site's /.well-known files, see README).
class PasskeyService {
  PasskeyService({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

  final http.Client _client;
  final String _baseUrl;
  final _authenticator = PasskeyAuthenticator();

  static const _json = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
  Map<String, String> _auth(String token) => {
    ..._json,
    'Authorization': 'Bearer $token',
  };

  /// Signs in with a passkey on this phone (or synced to it). Returns the
  /// session token, like the password sign-in.
  Future<String> signIn() => _guard(() async {
    final started = await _post('/auth/passkey/options', _json, const {});
    final result =
        (started['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final options =
        (result['options'] as Map?)?.cast<String, dynamic>() ?? const {};
    final response = await _authenticator.authenticate(
      AuthenticateRequestType.fromJson(
        options,
        preferImmediatelyAvailableCredentials: false,
      ),
    );
    final body = await _post('/auth/passkey/signin', _json, {
      'challenge_id': '${result['challenge_id']}',
      'response': response.toJson(),
      'uses_bearer_token': true,
    });
    final token = (body['user'] as Map?)?['token'];
    if (token is! String || token.isEmpty) throw const _ServerRejected();
    return token;
  });

  /// Creates a passkey on this phone for the signed-in account.
  Future<void> add(String token) => _guard(() async {
    final started = await _post(
      '/auth/account/passkeys/options',
      _auth(token),
      const {},
    );
    final options =
        (started['result'] as Map?)?.cast<String, dynamic>() ?? const {};
    final response = await _authenticator.register(
      RegisterRequestType.fromJson(options),
    );
    await _post('/auth/account/passkeys', _auth(token), {
      'response': response.toJson(),
    });
  });

  /// Whether the signed-in account already has any passkey.
  Future<bool> hasAny(String token) async {
    final r = await _client.get(
      Uri.parse('$_baseUrl/auth/account/passkeys'),
      headers: _auth(token),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw const _ServerRejected();
    }
    final list = (jsonDecode(r.body) as Map?)?['result'];
    return list is List && list.isNotEmpty;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, String> headers,
    Object body,
  ) async {
    final r = await _client.post(
      Uri.parse('$_baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw const _ServerRejected();
    }
    final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
    return decoded is Map ? decoded.cast<String, dynamic>() : const {};
  }

  static Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PasskeyAuthCancelledException {
      throw PasskeyCancelled();
    } on PlatformException catch (e) {
      if (e.code == 'cancelled') throw PasskeyCancelled();
      rethrow;
    }
  }
}

class _ServerRejected implements Exception {
  const _ServerRejected();
}

PasskeyProblem passkeyProblemOf(Object error) => switch (error) {
  NoCredentialsAvailableException() => PasskeyProblem.noneOnDevice,
  ExcludeCredentialsCanNotBeRegisteredException() =>
    PasskeyProblem.alreadyOnDevice,
  DomainNotAssociatedException() ||
  DeviceNotSupportedException() ||
  PasskeyUnsupportedException() ||
  MissingGoogleSignInException() ||
  SyncAccountNotAvailableException() ||
  AuthenticatorException() => PasskeyProblem.unavailable,
  _ServerRejected() => PasskeyProblem.rejected,
  _ => PasskeyProblem.other,
};
