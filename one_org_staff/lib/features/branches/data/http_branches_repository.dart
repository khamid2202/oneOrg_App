import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/domain/auth_repository.dart';
import '../domain/branches_repository.dart';

class HttpBranchesRepository implements BranchesRepository {
  HttpBranchesRepository({required http.Client client, required String baseUrl})
    : _client = client,
      _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;

  final http.Client _client;
  final String _baseUrl;

  @override
  Future<List<Branch>?> getMyBranches(String token) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/branches/my'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 404) {
      return null;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const AuthFailure('Unable to load your branches.');
    }

    final body = jsonDecode(response.body);
    final rows = body is Map<String, dynamic> ? body['result'] : null;
    if (rows is! List) {
      throw const AuthFailure('Unable to load your branches.');
    }
    return rows.whereType<Map<String, dynamic>>().map(Branch.fromJson).toList();
  }
}
