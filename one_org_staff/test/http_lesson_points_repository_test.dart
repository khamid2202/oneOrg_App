import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/MyLessons/http_lesson_points_repository.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

void main() {
  test('loads students for a group from the paginated list endpoint', () async {
    var requestCount = 0;
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        requestCount += 1;

        expect(request.method, 'GET');
        expect(request.url.path, '/students');
        expect(request.url.queryParameters['group_id'], '42');
        expect(request.url.queryParameters['page'], '1');
        expect(request.url.queryParameters['limit'], '100');
        // The group already pins the academic year; sending it too would
        // return nothing whenever the configured year disagrees.
        expect(request.url.queryParameters.containsKey('academic_year_id'),
            isFalse);
        expect(request.headers['Authorization'], 'Bearer test-token');

        return http.Response(
          jsonEncode({
            'ok': true,
            'result': [
              {
                'id': 6,
                'person_id': 101,
                'group_id': 42,
                'leave_date': null,
                'full_name': 'Grace Hopper',
              },
              {
                'id': 5,
                'person_id': 100,
                'group_id': 42,
                'leave_date': null,
                'full_name': 'Ada Lovelace',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz/',
    );

    final students = await repository.getStudentsForGroup(
      'test-token',
      groupId: 42,
    );

    expect(requestCount, 1);
    // Enrollment `id` is distinct from the person id that points use.
    expect(students.map((student) => student.id), [5, 6]);
    expect(students.map((student) => student.fullName), [
      'Ada Lovelace',
      'Grace Hopper',
    ]);
  });

  test('omits enrollments that have already left the class', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': [
              {
                'id': 5,
                'person_id': 100,
                'full_name': 'Ada Lovelace',
                'leave_date': null,
              },
              {
                'id': 7,
                'person_id': 102,
                'full_name': 'Departed Student',
                'leave_date': '2026-05-30',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final students = await repository.getStudentsForGroup(
      'test-token',
      groupId: 42,
    );

    expect(students.map((student) => student.fullName), ['Ada Lovelace']);
  });

  test('saves bulk points with subject id when available', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/student-points/bulk');
        expect(request.headers['Authorization'], 'Bearer test-token');

        final payload = jsonDecode(request.body) as List<dynamic>;
        expect(payload, [
          {
            'person_id': 100,
            'group_id': 42,
            'subject_id': 9,
            'points': 8.5,
            'date': '2026-06-11',
          },
        ]);

        return http.Response('{"ok":true}', 201);
      }),
      baseUrl: 'https://dev-api.oneorg.uz/',
    );

    await repository.createPointsBulk('test-token', [
      StudentPointDraft(
        personId: 100,
        groupId: 42,
        subjectId: 9,
        points: 8.5,
        date: DateTime(2026, 6, 11),
      ),
    ]);
  });

  test('reads back existing points keyed by person id', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/student-points');
        expect(request.url.queryParameters['group_id'], '42');
        expect(request.url.queryParameters['start_date'], '2026-06-11');
        expect(request.url.queryParameters['end_date'], '2026-06-11');

        return http.Response(
          jsonEncode({
            'ok': true,
            'result': [
              {'id': 701, 'person_id': 100, 'group_id': 42, 'points': 8},
              {'id': 702, 'person_id': 101, 'group_id': 42, 'points': 7.5},
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final points = await repository.getPointsForGroupAndDate(
      'test-token',
      groupId: 42,
      date: DateTime(2026, 6, 11),
    );

    expect(points, {100: 8.0, 101: 7.5});
  });

  test('lists contacts by person id', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/contacts');
        expect(request.url.queryParameters['person_id'], '100');
        expect(request.url.queryParameters.containsKey('student_id'), isFalse);

        return http.Response(
          jsonEncode({
            'result': [
              {
                'id': 7,
                'person_id': 100,
                'full_name': 'Mubina Xasanova',
                'relationship': 'mother',
                'phone_number': '+998901112233',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final contacts = await repository.getContactsForStudent(
      'test-token',
      personId: 100,
    );

    expect(contacts.single.personId, 100);
    expect(contacts.single.relationshipLabel, 'Mom');
  });

  test('loads contacts even when rows omit person_id', () async {
    // The API does not always echo the filter field back; the caller already
    // knows which person it asked for.
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': [
              {
                'id': 7,
                'full_name': 'Mubina Xasanova',
                'relationship': 'mother',
                'phone_number': '+998901112233',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final contacts = await repository.getContactsForStudent(
      'test-token',
      personId: 100,
    );

    expect(contacts, hasLength(1));
    expect(contacts.single.phoneNumber, '+998901112233');
    // Filled in from the request.
    expect(contacts.single.personId, 100);
  });

  test('one unusable contact row does not blank out the list', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'result': [
              {'full_name': 'No id here', 'phone_number': '+1'},
              {
                'id': 8,
                'full_name': 'Valijon',
                'relationship': 'father',
                'phone_number': '+998901112244',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final contacts = await repository.getContactsForStudent(
      'test-token',
      personId: 100,
    );

    expect(contacts.map((contact) => contact.fullName), ['Valijon']);
  });

  test('creates a contact against the person, not the enrollment', () async {
    Map<String, dynamic>? body;
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/contacts');
        body = jsonDecode(request.body) as Map<String, dynamic>;

        return http.Response(
          jsonEncode({
            'result': {
              'id': 8,
              'person_id': 100,
              'full_name': 'Valijon Valiyev',
              'relationship': 'father',
              'phone_number': '+998901112244',
            },
          }),
          201,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final contact = await repository.createContact(
      'test-token',
      personId: 100,
      fullName: 'Valijon Valiyev',
      relationship: 'father',
      phoneNumber: '+998901112244',
    );

    expect(body, {
      'person_id': 100,
      'full_name': 'Valijon Valiyev',
      'relationship': 'father',
      'phone_number': '+998901112244',
    });
    expect(contact.id, 8);
  });

  test('lists guardians by person id', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/guardians');
        expect(request.url.queryParameters['person_id'], '100');
        return http.Response(
          jsonEncode({
            'result': [
              {
                'id': 3,
                'person_id': 100,
                'full_name': 'Valijon Valiyev',
                'relation': 'father',
                'phone': '+998901112233',
                'work_address': 'Tashkent',
                'position': 'Engineer',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final guardians = await repository.getGuardians(
      'test-token',
      personId: 100,
    );

    expect(guardians.single.fullName, 'Valijon Valiyev');
    expect(guardians.single.relation, 'father');
    expect(guardians.single.position, 'Engineer');
  });

  test('creates a guardian with the required fields', () async {
    Map<String, dynamic>? body;
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/guardians');
        body = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'result': {
              'id': 4,
              'person_id': 100,
              'full_name': 'Mubina',
              'relation': 'mother',
              'phone': '+998907776655',
            },
          }),
          201,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final guardian = await repository.createGuardian(
      'test-token',
      personId: 100,
      fullName: 'Mubina',
      relation: 'mother',
      phone: '+998907776655',
    );

    // Optional fields are omitted rather than sent empty.
    expect(body, {
      'person_id': 100,
      'full_name': 'Mubina',
      'relation': 'mother',
      'phone': '+998907776655',
    });
    expect(guardian.id, 4);
  });

  test('deletes a guardian by id', () async {
    var called = false;
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.method, 'DELETE');
        expect(request.url.path, '/guardians/3');
        called = true;
        return http.Response('', 204);
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    await repository.deleteGuardian('test-token', guardianId: 3);
    expect(called, isTrue);
  });

  test('lists documents by person id', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.url.path, '/documents');
        expect(request.url.queryParameters['person_id'], '100');
        return http.Response(
          jsonEncode({
            'result': [
              {
                'id': 5,
                'person_id': 100,
                'document_name': 'Birth Certificate',
                'document_type': 'certificate',
                'document_url': 'https://storage.example.com/docs/b.pdf',
              },
            ],
          }),
          200,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final documents = await repository.getDocuments(
      'test-token',
      personId: 100,
    );

    expect(documents.single.documentName, 'Birth Certificate');
    expect(documents.single.documentUrl, endsWith('b.pdf'));
  });

  test('uploads a document as multipart with its metadata fields', () async {
    String? contentType;
    List<int>? body;
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/documents');
        contentType = request.headers['content-type'];
        body = request.bodyBytes;
        return http.Response(
          jsonEncode({
            'result': {
              'id': 5,
              'person_id': 100,
              'document_name': 'Birth Certificate',
              'document_type': 'certificate',
              'document_url': 'https://storage.example.com/docs/b.pdf',
            },
          }),
          201,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    final document = await repository.createDocument(
      'test-token',
      personId: 100,
      documentName: 'Birth Certificate',
      documentType: 'certificate',
      bytes: const [1, 2, 3],
      filename: 'birth_cert.pdf',
    );

    expect(contentType, startsWith('multipart/form-data'));
    final decoded = utf8.decode(body!, allowMalformed: true);
    expect(decoded, contains('name="person_id"'));
    expect(decoded, contains('name="document_name"'));
    expect(decoded, contains('name="document_type"'));
    expect(decoded, contains('name="file"'));
    expect(decoded, contains('filename="birth_cert.pdf"'));
    expect(document.id, 5);
  });

  test('surfaces the API message when a document upload is rejected', () async {
    final repository = HttpLessonPointsRepository(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'File too large'}),
          400,
        );
      }),
      baseUrl: 'https://dev-api.oneorg.uz',
    );

    expect(
      () => repository.createDocument(
        'test-token',
        personId: 100,
        documentName: 'Big',
        documentType: 'other',
        bytes: const [1],
        filename: 'big.pdf',
      ),
      throwsA(
        isA<AuthFailure>().having(
          (error) => error.message,
          'message',
          'File too large',
        ),
      ),
    );
  });
}
