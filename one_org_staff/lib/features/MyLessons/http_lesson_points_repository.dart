import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/domain/auth_repository.dart';
import 'lesson_points_repository.dart';

class HttpLessonPointsRepository implements LessonPointsRepository {
  HttpLessonPointsRepository({
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
  Future<List<StudentEntry>> getStudentsForGroup(
    String token, {
    required int groupId,
    bool includeContacts = false,
  }) async {
    // `group_id` alone identifies the roster — a group belongs to exactly one
    // academic year. Sending `academic_year_id` as well would silently return
    // nothing whenever the configured year disagrees with the group's own.
    final response = await _client.get(
      _buildUri(
        '/students',
        queryParameters: {
          'group_id': groupId.toString(),
          'page': '1',
          'limit': '100',
          if (includeContacts) 'include': jsonEncode(['contacts']),
        },
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load students.'),
      );
    }

    final students =
        _extractStudents(responseBody)
            // An enrollment with a leave date is no longer in the class, so
            // it should not appear on the roster.
            .where((json) => json['leave_date'] == null)
            .map(StudentEntry.fromJson)
            .toList()
          ..sort((a, b) => a.fullName.compareTo(b.fullName));

    return students;
  }

  @override
  Future<void> createPointsBulk(
    String token,
    List<StudentPointDraft> points,
  ) async {
    final payload = points
        .map(
          (point) => {
            'person_id': point.personId,
            'group_id': point.groupId,
            if (point.subjectId != null) 'subject_id': point.subjectId,
            'points': point.points,
            'date': _formatDate(point.date),
            if (point.reason != null && point.reason!.trim().isNotEmpty)
              'reason': point.reason!.trim(),
          },
        )
        .toList();

    final response = await _client.post(
      _buildUri('/student-points/bulk'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode(payload),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to save points.'),
      );
    }
  }

  @override
  Future<Map<int, double>> getPointsForGroupAndDate(
    String token, {
    required int groupId,
    required DateTime date,
    int? subjectId,
  }) async {
    final dateStr = _formatDate(date);
    final response = await _client.get(
      _buildUri(
        '/student-points',
        queryParameters: {
          'group_id': groupId.toString(),
          if (subjectId != null) 'subject_id': subjectId.toString(),
          'start_date': dateStr,
          'end_date': dateStr,
          'limit': '100',
        },
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load points.'),
      );
    }

    final pointsMap = <int, double>{};
    for (final item in _extractPoints(responseBody)) {
      final personId = _asInt(item['person_id']);
      final pointsValue = _asDouble(item['points']);
      if (personId != null && pointsValue != null) {
        pointsMap[personId] = pointsValue;
      }
    }
    return pointsMap;
  }

  @override
  Future<List<GroupEntry>> getGroups(
    String token, {
    required int academicYearId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/groups',
        queryParameters: {'academic_year_id': academicYearId.toString()},
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load classes.'),
      );
    }

    final groups = <GroupEntry>[];
    if (responseBody is Map<String, dynamic>) {
      final results =
          responseBody['groups'] ??
          responseBody['data'] ??
          responseBody['result'];
      if (results is List) {
        for (final item in results) {
          if (item is Map<String, dynamic>) {
            groups.add(GroupEntry.fromJson(item));
          }
        }
      }
    } else if (responseBody is List) {
      for (final item in responseBody) {
        if (item is Map<String, dynamic>) {
          groups.add(GroupEntry.fromJson(item));
        }
      }
    }

    groups.sort((a, b) {
      final gradeCompare = a.grade.compareTo(b.grade);
      if (gradeCompare != 0) return gradeCompare;
      return a.className.compareTo(b.className);
    });

    return groups;
  }

  @override
  Future<List<AcademicYearEntry>> getAcademicYears(String token) async {
    final response = await _client.get(
      _buildUri('/academic-years'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load academic years.'),
      );
    }

    final years = <AcademicYearEntry>[];
    for (final item in _extractRows(responseBody, const [
      'result',
      'data',
      'academic_years',
    ])) {
      try {
        years.add(AcademicYearEntry.fromJson(item));
      } on FormatException {
        continue;
      }
    }

    return years;
  }

  @override
  Future<List<GuardianEntry>> getGuardians(
    String token, {
    required int personId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/guardians',
        queryParameters: {'person_id': personId.toString()},
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load guardians.'),
      );
    }

    final guardians = <GuardianEntry>[];
    for (final item in _extractRows(responseBody, const [
      'result',
      'data',
      'guardians',
    ])) {
      try {
        guardians.add(GuardianEntry.fromJson(item, fallbackPersonId: personId));
      } on FormatException {
        continue;
      }
    }
    return guardians;
  }

  @override
  Future<GuardianEntry> createGuardian(
    String token, {
    required int personId,
    required String fullName,
    required String relation,
    required String phone,
    String? workAddress,
    String? position,
  }) async {
    final response = await _client.post(
      _buildUri('/guardians'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'person_id': personId,
        'full_name': fullName.trim(),
        'relation': relation.trim(),
        'phone': phone.trim(),
        if (workAddress != null && workAddress.trim().isNotEmpty)
          'work_address': workAddress.trim(),
        if (position != null && position.trim().isNotEmpty)
          'position': position.trim(),
      }),
    );

    return _singleGuardian(
      response,
      personId: personId,
      fallbackMessage: 'Unable to add the guardian.',
    );
  }

  @override
  Future<GuardianEntry> updateGuardian(
    String token, {
    required int guardianId,
    String? fullName,
    String? relation,
    String? phone,
    String? workAddress,
    String? position,
  }) async {
    final response = await _client.patch(
      _buildUri('/guardians/$guardianId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        if (fullName != null) 'full_name': fullName.trim(),
        if (relation != null) 'relation': relation.trim(),
        if (phone != null) 'phone': phone.trim(),
        if (workAddress != null) 'work_address': workAddress.trim(),
        if (position != null) 'position': position.trim(),
      }),
    );

    return _singleGuardian(
      response,
      fallbackMessage: 'Unable to update the guardian.',
    );
  }

  @override
  Future<void> deleteGuardian(String token, {required int guardianId}) async {
    final response = await _client.delete(
      _buildUri('/guardians/$guardianId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(
          _decodeBody(response.body),
          'Unable to delete the guardian.',
        ),
      );
    }
  }

  GuardianEntry _singleGuardian(
    http.Response response, {
    int? personId,
    required String fallbackMessage,
  }) {
    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(_extractMessage(responseBody, fallbackMessage));
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'] ?? responseBody;
      if (result is Map<String, dynamic>) {
        return GuardianEntry.fromJson(result, fallbackPersonId: personId);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<List<DocumentEntry>> getDocuments(
    String token, {
    required int personId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/documents',
        queryParameters: {'person_id': personId.toString()},
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load documents.'),
      );
    }

    final documents = <DocumentEntry>[];
    for (final item in _extractRows(responseBody, const [
      'result',
      'data',
      'documents',
    ])) {
      try {
        documents.add(DocumentEntry.fromJson(item, fallbackPersonId: personId));
      } on FormatException {
        continue;
      }
    }
    return documents;
  }

  @override
  Future<DocumentEntry> createDocument(
    String token, {
    required int personId,
    required String documentName,
    required String documentType,
    required List<int> bytes,
    required String filename,
  }) async {
    // docs/staff/documents.md: multipart with person_id, document_name,
    // document_type and the binary `file`.
    final request = http.MultipartRequest('POST', _buildUri('/documents'))
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..fields['person_id'] = personId.toString()
      ..fields['document_name'] = documentName.trim()
      ..fields['document_type'] = documentType.trim()
      ..files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

    final streamed = await _client.send(request);
    final response = await http.Response.fromStream(streamed);

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to upload the document.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'] ?? responseBody;
      if (result is Map<String, dynamic>) {
        return DocumentEntry.fromJson(result, fallbackPersonId: personId);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<void> deleteDocument(String token, {required int documentId}) async {
    final response = await _client.delete(
      _buildUri('/documents/$documentId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(
          _decodeBody(response.body),
          'Unable to delete the document.',
        ),
      );
    }
  }

  @override
  Future<String?> uploadPersonPicture(
    String token, {
    required int personId,
    required List<int> bytes,
    required String filename,
  }) async {
    // docs/staff/persons.md: multipart field `file`, responds with
    // { ok, picture_url }.
    final request =
        http.MultipartRequest('POST', _buildUri('/persons/$personId/picture'))
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
  Future<String?> removePersonPicture(
    String token, {
    required int personId,
  }) async {
    final response = await _client.delete(
      _buildUri('/persons/$personId/picture'),
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

  @override
  Future<PersonDetails> updatePersonDetails(
    String token, {
    required int personId,
    required Map<String, String> changes,
  }) async {
    final response = await _client.patch(
      _buildUri('/persons/$personId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode(changes),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to save the student details.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'];
      if (result is Map<String, dynamic>) {
        return PersonDetails.fromJson(result);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<List<ContactEntry>> getContactsForStudent(
    String token, {
    required int personId,
  }) async {
    final response = await _client.get(
      _buildUri(
        '/contacts',
        queryParameters: {'person_id': personId.toString()},
      ),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to load contacts.'),
      );
    }

    final contacts = <ContactEntry>[];
    for (final item in _extractRows(responseBody, const [
      'result',
      'data',
      'contacts',
    ])) {
      try {
        contacts.add(ContactEntry.fromJson(item, fallbackPersonId: personId));
      } on FormatException {
        // One unusable row must not blank out the whole contact list.
        continue;
      }
    }

    return contacts;
  }

  @override
  Future<ContactEntry> createContact(
    String token, {
    required int personId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
  }) async {
    final response = await _client.post(
      _buildUri('/contacts'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'person_id': personId,
        'full_name': fullName.trim(),
        'relationship': relationship,
        'phone_number': phoneNumber.trim(),
      }),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to create contact.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'] ?? responseBody;
      if (result is Map<String, dynamic>) {
        return ContactEntry.fromJson(result, fallbackPersonId: personId);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<ContactEntry> updateContact(
    String token, {
    required int contactId,
    String? fullName,
    String? relationship,
    String? phoneNumber,
  }) async {
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName.trim();
    if (relationship != null) body['relationship'] = relationship;
    if (phoneNumber != null) body['phone_number'] = phoneNumber.trim();

    final response = await _client.patch(
      _buildUri('/contacts/$contactId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );

    final responseBody = _decodeBody(response.body);
    if (!_isSuccess(response.statusCode)) {
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to update contact.'),
      );
    }

    if (responseBody is Map<String, dynamic>) {
      final result = responseBody['result'] ?? responseBody;
      if (result is Map<String, dynamic>) {
        return ContactEntry.fromJson(result);
      }
    }

    throw const AuthFailure('Unexpected response from server.');
  }

  @override
  Future<void> deleteContact(String token, {required int contactId}) async {
    final response = await _client.delete(
      _buildUri('/contacts/$contactId'),
      headers: {..._jsonHeaders, 'Authorization': 'Bearer $token'},
    );

    if (!_isSuccess(response.statusCode)) {
      final responseBody = _decodeBody(response.body);
      throw AuthFailure(
        _extractMessage(responseBody, 'Unable to delete contact.'),
      );
    }
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value);
    }
    return null;
  }

  static String _normalizeBaseUrl(String baseUrl) {
    final trimmed = baseUrl.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri _buildUri(String path, {Map<String, String>? queryParameters}) {
    final uri = Uri.parse('$_baseUrl$path');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: queryParameters);
  }

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

  /// Pulls the row list out of a response, tolerating the API's varying
  /// envelope keys.
  List<Map<String, dynamic>> _extractRows(
    dynamic responseBody,
    List<String> keys,
  ) {
    if (responseBody is List) {
      return responseBody
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (responseBody is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in keys) {
      final value = responseBody[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return const [];
  }

  List<Map<String, dynamic>> _extractPoints(dynamic responseBody) {
    if (responseBody is List) {
      return responseBody
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (responseBody is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in const ['points', 'results', 'data', 'result']) {
      final value = responseBody[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    }

    return const [];
  }

  List<Map<String, dynamic>> _extractStudents(dynamic responseBody) {
    if (responseBody is List) {
      return responseBody
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }

    if (responseBody is! Map<String, dynamic>) {
      return const [];
    }

    for (final key in const ['students', 'result', 'data']) {
      final value = responseBody[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      if (value is Map<String, dynamic>) {
        final nested = value['students'];
        if (nested is List) {
          return nested
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList();
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

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
