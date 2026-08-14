import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:one_org_staff/features/MyClass/my_class.dart';
import 'package:one_org_staff/features/MyClass/student_info_view.dart';
import 'package:one_org_staff/features/MyClass/student_people_sync.dart';
import 'package:one_org_staff/features/MyLessons/http_lesson_points_repository.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/shared/editable_avatar.dart';

const _profile = AppUserProfile(
  id: 42,
  fullName: 'Ahror Teacher',
  subtitle: 'Teacher',
  email: 'teacher@oneorg.uz',
  phone: '+998 90 000 00 00',
  department: 'Maths',
  joinedDate: '01 Sep 2025',
);

final _group = GroupEntry(
  id: 9,
  grade: 9,
  className: 'B',
  academicYearId: 4,
  teacherIds: const [42],
);

final _students = [
  StudentEntry(
    id: 1,
    personId: 100,
    fullName: 'Yusupova Samira',
    code: 'DIS250383',
    status: 'present',
    contacts: const [
      ContactEntry(
        id: 7,
        personId: 100,
        fullName: 'Mubina',
        relationship: 'mother',
        phoneNumber: '+998901112233',
      ),
      ContactEntry(
        id: 8,
        personId: 100,
        fullName: 'Valijon',
        relationship: 'father',
        phoneNumber: '+998901112244',
      ),
    ],
  ),
  StudentEntry(
    id: 2,
    personId: 101,
    fullName: 'Nazarov Abdulloh',
    code: 'DIS250387',
    status: 'left',
  ),
];

final _studentWithDetails = StudentEntry(
  id: 1,
  personId: 100,
  fullName: 'Yusupova Samira',
  code: 'DIS250383',
  status: 'present',
  details: const PersonDetails(
    birthDate: '2010-03-15',
    gender: 'female',
    phone: '+998901234567',
    address: 'Tashkent, Yunusobod 4',
    passportNumber: 'AA1234567',
  ),
);

Widget _wrapPage({
  List<AcademicYearEntry> years = const [
    AcademicYearEntry(id: 4, name: '2026-2027', isActive: true),
    AcademicYearEntry(id: 3, name: '2025-2026', isActive: false),
  ],
  void Function(int? yearId)? onLoadGroups,
  void Function(bool includeContacts)? onLoadStudents,
  List<StudentEntry>? students,
  void Function(int personId, Map<String, String> changes)? onUpdatePerson,
  PersonDetails? updateResult,
  void Function(int personId)? onUploadPicture,
  void Function(int personId)? onRemovePicture,
  List<GuardianEntry>? guardians,
  List<DocumentEntry>? documents,
  void Function(String fullName, String relation, String phone)? onAddGuardian,
  void Function(String fullName, String relationship, String phone)?
  onMirrorContact,
  List<ContactEntry>? existingContacts,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: MyClassPage(
          loadProfile: () async => _profile,
          loadAcademicYears: () async => years,
          loadGroups: ({int? academicYearId}) async {
            onLoadGroups?.call(academicYearId);
            return [_group];
          },
          loadStudentsForGroup:
              (groupId, {bool includeContacts = false}) async {
                onLoadStudents?.call(includeContacts);
                return students ?? _students;
              },
          updatePersonDetails: ({required personId, required changes}) async {
            onUpdatePerson?.call(personId, changes);
            return updateResult ?? const PersonDetails();
          },
          uploadPersonPicture:
              ({required personId, required bytes, required filename}) async {
                onUploadPicture?.call(personId);
                return 'https://cdn.example.com/persons/$personId/a.jpg';
              },
          removePersonPicture: ({required personId}) async {
            onRemovePicture?.call(personId);
            return null;
          },
          peopleSync: StudentPeopleSync(
            loadContacts: (personId) async => existingContacts ?? const [],
            createContact:
                ({
                  required personId,
                  required fullName,
                  required relationship,
                  required phoneNumber,
                }) async {
                  onMirrorContact?.call(fullName, relationship, phoneNumber);
                  return ContactEntry(
                    id: 1,
                    personId: personId,
                    fullName: fullName,
                    relationship: relationship,
                    phoneNumber: phoneNumber,
                  );
                },
            updateContact:
                ({
                  required contactId,
                  fullName,
                  relationship,
                  phoneNumber,
                }) async {
                  onMirrorContact?.call(
                    fullName ?? '',
                    relationship ?? '',
                    phoneNumber ?? '',
                  );
                  return ContactEntry(
                    id: contactId,
                    fullName: fullName ?? '',
                    relationship: relationship ?? '',
                    phoneNumber: phoneNumber ?? '',
                  );
                },
            loadGuardians: (personId) async => guardians ?? const [],
            createGuardian:
                ({
                  required personId,
                  required fullName,
                  required relation,
                  required phone,
                  workAddress,
                  position,
                }) async {
                  onAddGuardian?.call(fullName, relation, phone);
                  return GuardianEntry(
                    id: 99,
                    personId: personId,
                    fullName: fullName,
                    relation: relation,
                    phone: phone,
                  );
                },
            updateGuardian:
                ({
                  required guardianId,
                  fullName,
                  relation,
                  phone,
                  workAddress,
                  position,
                }) async => GuardianEntry(
                  id: guardianId,
                  fullName: fullName ?? '',
                  relation: relation ?? '',
                  phone: phone ?? '',
                ),
          ),
          guardians: StudentGuardiansApi(
            load: (personId) async => guardians ?? const [],
            create:
                ({
                  required personId,
                  required fullName,
                  required relation,
                  required phone,
                  workAddress,
                  position,
                }) async {
                  onAddGuardian?.call(fullName, relation, phone);
                  return GuardianEntry(
                    id: 99,
                    personId: personId,
                    fullName: fullName,
                    relation: relation,
                    phone: phone,
                  );
                },
            update:
                ({
                  required guardianId,
                  fullName,
                  relation,
                  phone,
                  workAddress,
                  position,
                }) async => GuardianEntry(
                  id: guardianId,
                  fullName: fullName ?? '',
                  relation: relation ?? '',
                  phone: phone ?? '',
                ),
            delete: (guardianId) async {},
          ),
          documents: StudentDocumentsApi(
            load: (personId) async => documents ?? const [],
            create:
                ({
                  required personId,
                  required documentName,
                  required documentType,
                  required bytes,
                  required filename,
                }) async => DocumentEntry(
                  id: 1,
                  documentName: documentName,
                  documentType: documentType,
                ),
            delete: (documentId) async {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('roster parsing', () {
    test('reads code and photo from the nested person object', () {
      final student = StudentEntry.fromJson(const {
        'id': 12,
        'person_id': 100,
        'full_name': 'Yusupova Samira',
        'status': 'present',
        'person': {
          'id': 100,
          'code': 'DIS250383',
          'full_name': 'Yusupova Samira',
          'picture_url': 'https://cdn.example.com/p/100.jpg',
        },
      });

      expect(student.id, 12);
      expect(student.personId, 100);
      expect(student.code, 'DIS250383');
      expect(student.pictureUrl, 'https://cdn.example.com/p/100.jpg');
      expect(student.status, 'present');
      expect(student.contacts, isEmpty);
    });

    test('reads included contacts', () {
      final student = StudentEntry.fromJson(const {
        'id': 12,
        'person_id': 100,
        'full_name': 'Yusupova Samira',
        'contacts': [
          {
            'id': 7,
            'person_id': 100,
            'full_name': 'Mubina Xasanova',
            'relationship': 'mother',
            'phone_number': '+998901112233',
          },
        ],
      });

      expect(student.contacts.single.phoneNumber, '+998901112233');
      expect(student.contacts.single.relationshipLabel, 'Mom');
    });

    test('inherits the person id when a nested contact omits it', () {
      final student = StudentEntry.fromJson(const {
        'id': 12,
        'person_id': 100,
        'full_name': 'Yusupova Samira',
        'contacts': [
          {
            'id': 7,
            'full_name': 'Mubina',
            'relationship': 'mother',
            'phone_number': '+998901112233',
          },
        ],
      });

      expect(student.contacts.single.personId, 100);
    });

    test('drops malformed contacts instead of failing the student', () {
      final student = StudentEntry.fromJson(const {
        'id': 12,
        'person_id': 100,
        'full_name': 'Yusupova Samira',
        'contacts': [
          {'nonsense': true, 'full_name': 'No id'},
          {
            'id': 7,
            'person_id': 100,
            'full_name': 'Mubina',
            'relationship': 'mother',
            'phone_number': '+998901112233',
          },
        ],
      });

      expect(student.contacts, hasLength(1));
    });
  });

  group('PersonDetails.diffFrom', () {
    const original = PersonDetails(
      birthDate: '2010-03-15',
      gender: 'female',
      phone: '+998901234567',
      address: 'Tashkent',
      passportNumber: 'AA1234567',
    );

    test('is empty when nothing changed', () {
      expect(original.diffFrom(original), isEmpty);
    });

    test('includes only the changed fields', () {
      final edited = original.copyWith(phone: '+998900000000');
      expect(edited.diffFrom(original), {'phone': '+998900000000'});
    });

    test('sends an empty string for a cleared field', () {
      const edited = PersonDetails(
        birthDate: '2010-03-15',
        gender: 'female',
        phone: '+998901234567',
        address: '',
        passportNumber: 'AA1234567',
      );

      expect(edited.diffFrom(original), {'address': ''});
    });

    test('ignores whitespace-only differences', () {
      const edited = PersonDetails(
        birthDate: '2010-03-15',
        gender: 'female',
        phone: '  +998901234567  ',
        address: 'Tashkent',
        passportNumber: 'AA1234567',
      );

      expect(edited.diffFrom(original), isEmpty);
    });

    test('uses the API field names', () {
      const edited = PersonDetails(birthCertificateNumber: 'BC-1');
      expect(edited.diffFrom(const PersonDetails()), {
        'birth_certificate_number': 'BC-1',
      });
    });
  });

  group('AcademicYearEntry', () {
    test('marks the active year in its label', () {
      final active = AcademicYearEntry.fromJson(const {
        'id': 4,
        'name': '2026-2027',
        'is_active': true,
      });
      final past = AcademicYearEntry.fromJson(const {
        'id': 3,
        'name': '2025-2026',
        'is_active': false,
      });

      expect(active.label, '2026-2027 (active)');
      expect(past.label, '2025-2026');
    });

    test('falls back to the derived years when name is missing', () {
      final year = AcademicYearEntry.fromJson(const {
        'id': 4,
        'start_year': 2026,
        'end_year': 2027,
      });

      expect(year.name, '2026-2027');
      expect(year.isActive, isFalse);
    });
  });

  group('HttpLessonPointsRepository', () {
    test('asks for contacts alongside the roster when requested', () async {
      String? include;
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          include = request.url.queryParameters['include'];
          return http.Response(jsonEncode({'result': []}), 200);
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      await repository.getStudentsForGroup(
        'test-token',
        groupId: 9,
        includeContacts: true,
      );

      expect(jsonDecode(include!), ['contacts']);
    });

    test('omits include when contacts are not needed', () async {
      var hadInclude = true;
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          hadInclude = request.url.queryParameters.containsKey('include');
          return http.Response(jsonEncode({'result': []}), 200);
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      await repository.getStudentsForGroup('test-token', groupId: 9);

      expect(hadInclude, isFalse);
    });

    test('uploads a person picture as multipart field `file`', () async {
      String? contentType;
      List<int>? body;
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          // Keyed by person id, not the enrollment id.
          expect(request.url.path, '/persons/100/picture');
          expect(request.headers['Authorization'], 'Bearer test-token');
          contentType = request.headers['content-type'];
          body = request.bodyBytes;

          return http.Response(
            jsonEncode({
              'ok': true,
              'picture_url': 'https://cdn.example.com/persons/100/a.jpg',
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      final url = await repository.uploadPersonPicture(
        'test-token',
        personId: 100,
        bytes: const [1, 2, 3],
        filename: 'avatar.jpg',
      );

      expect(contentType, startsWith('multipart/form-data'));
      final decoded = utf8.decode(body!, allowMalformed: true);
      expect(decoded, contains('name="file"'));
      expect(url, 'https://cdn.example.com/persons/100/a.jpg');
    });

    test('removes a person picture', () async {
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.path, '/persons/100/picture');
          return http.Response(
            jsonEncode({'ok': true, 'picture_url': null}),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      expect(
        await repository.removePersonPicture('test-token', personId: 100),
        isNull,
      );
    });

    test('patches only the supplied person fields', () async {
      Map<String, dynamic>? body;
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/persons/100');
          expect(request.headers['Authorization'], 'Bearer test-token');
          body = jsonDecode(request.body) as Map<String, dynamic>;

          return http.Response(
            jsonEncode({
              'result': {
                'id': 100,
                'phone': '+998900000000',
                'address': 'Tashkent',
              },
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      final details = await repository.updatePersonDetails(
        'test-token',
        personId: 100,
        changes: const {'phone': '+998900000000'},
      );

      expect(body, {'phone': '+998900000000'});
      expect(details.phone, '+998900000000');
      expect(details.address, 'Tashkent');
    });

    test('loads academic years', () async {
      final repository = HttpLessonPointsRepository(
        client: MockClient((request) async {
          expect(request.url.path, '/academic-years');
          return http.Response(
            jsonEncode({
              'result': [
                {'id': 4, 'name': '2026-2027', 'is_active': true},
                {'id': 3, 'name': '2025-2026', 'is_active': false},
              ],
            }),
            200,
          );
        }),
        baseUrl: 'https://dev-api.oneorg.uz',
      );

      final years = await repository.getAcademicYears('test-token');

      expect(years.map((year) => year.id), [4, 3]);
      expect(years.first.isActive, isTrue);
    });
  });

  group('MyClassPage', () {
    testWidgets('shows the class, count and active year', (tester) async {
      await tester.pumpWidget(_wrapPage());
      await tester.pumpAndSettle();

      expect(find.text('9-B'), findsOneWidget);
      expect(find.text('2 students'), findsOneWidget);
      expect(find.text('2026-2027 (active)'), findsWidgets);
    });

    testWidgets('fetches the roster with contacts included', (tester) async {
      final includeFlags = <bool>[];
      await tester.pumpWidget(_wrapPage(onLoadStudents: includeFlags.add));
      await tester.pumpAndSettle();

      expect(includeFlags, isNotEmpty);
      expect(includeFlags.first, isTrue);
    });

    testWidgets('Info shows codes, Status shows statuses, Contacts shows '
        'numbers', (tester) async {
      await tester.pumpWidget(_wrapPage());
      await tester.pumpAndSettle();

      // Info is the default field.
      expect(find.text('CODE'), findsOneWidget);
      expect(find.text('DIS250383'), findsOneWidget);
      expect(find.text('DIS250387'), findsOneWidget);

      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();

      expect(find.text('STATUS'), findsOneWidget);
      expect(find.text('Present'), findsOneWidget);
      expect(find.text('Left'), findsOneWidget);
      expect(find.text('DIS250383'), findsNothing);

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      expect(find.text('CONTACT'), findsOneWidget);
      expect(find.text('+998901112233'), findsOneWidget);
      // Two contacts on the first student, none on the second.
      expect(find.text('Mom +1'), findsOneWidget);
      expect(find.text('None'), findsOneWidget);
    });

    testWidgets('changing the year refetches the group', (tester) async {
      final requestedYears = <int?>[];
      await tester.pumpWidget(_wrapPage(onLoadGroups: requestedYears.add));
      await tester.pumpAndSettle();

      expect(requestedYears, [4]);

      await tester.tap(find.text('2026-2027 (active)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('2025-2026').last);
      await tester.pumpAndSettle();

      expect(requestedYears, [4, 3]);
    });

    testWidgets('Info: tapping a student opens their personal details', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapPage(students: [_studentWithDetails]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      expect(find.text('Student info'), findsOneWidget);
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('15/03/2010'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.widgetWithText(TextField, '+998901234567'), findsOneWidget);
      expect(
        find.widgetWithText(TextField, 'Tashkent, Yunusobod 4'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'AA1234567'), findsOneWidget);
    });

    testWidgets('a swipe from the very screen edge returns to the roster', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapPage(students: [_studentWithDetails]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();
      expect(find.text('Student info'), findsOneWidget);

      // Start at x=5 — inside the real screen edge, but inside the page's 20px
      // padding too. The detector used to sit *under* that padding, so this
      // drag never reached it and the landing shell's detector took it instead,
      // dropping the user on the dashboard rather than the roster.
      await tester.timedDragFrom(
        const Offset(5, 400),
        const Offset(300, 0),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student info'), findsNothing);
      expect(find.text('Yusupova Samira'), findsOneWidget);
    });

    testWidgets('Status: tapping a student does nothing', (tester) async {
      await tester.pumpWidget(_wrapPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Status'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      expect(find.text('Student info'), findsNothing);
      expect(find.text('Contacts of'), findsNothing);
      // Still on the roster.
      expect(find.text('STATUS'), findsOneWidget);
    });

    testWidgets('Contacts: tapping a student opens their contacts', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapPage());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Contacts'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      // Same modal, opened on the Guardians tab.
      expect(find.text('Student info'), findsOneWidget);
      expect(find.text('Guardians'), findsWidgets);
      expect(find.text('No guardians recorded yet.'), findsOneWidget);
      // Not the profile form.
      expect(find.text('Birth Date'), findsNothing);
    });

    testWidgets('Info: the modal has Profile, Guardians and Documents', (
      tester,
    ) async {
      await tester.pumpWidget(_wrapPage(students: [_studentWithDetails]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Guardians'), findsOneWidget);
      expect(find.text('Documents'), findsOneWidget);
      // Lands on Profile.
      expect(find.text('Birth Date'), findsOneWidget);
    });

    testWidgets('Guardians: existing guardians are listed', (tester) async {
      await tester.pumpWidget(
        _wrapPage(
          students: [_studentWithDetails],
          guardians: const [
            GuardianEntry(
              id: 3,
              personId: 100,
              fullName: 'Valijon Valiyev',
              relation: 'father',
              phone: '+998901112233',
              position: 'Engineer',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardians'));
      await tester.pumpAndSettle();

      expect(find.text('Valijon Valiyev'), findsOneWidget);
      expect(find.text('father'), findsOneWidget);
      expect(find.text('+998901112233'), findsOneWidget);
      expect(find.text('Engineer'), findsOneWidget);
    });

    testWidgets('Guardians: adding one sends the required fields', (
      tester,
    ) async {
      String? sentName;
      String? sentRelation;
      String? sentPhone;

      await tester.pumpWidget(
        _wrapPage(
          students: [_studentWithDetails],
          onAddGuardian: (fullName, relation, phone) {
            sentName = fullName;
            sentRelation = relation;
            sentPhone = phone;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardians'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      expect(find.text('Add guardian'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Full name'),
        'Mubina Xasanova',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Relation'),
        'mother',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Phone'),
        '+998907776655',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(sentName, 'Mubina Xasanova');
      expect(sentRelation, 'mother');
      expect(sentPhone, '+998907776655');
    });

    testWidgets('Guardians: the form refuses to submit without a phone', (
      tester,
    ) async {
      var created = false;

      await tester.pumpWidget(
        _wrapPage(
          students: [_studentWithDetails],
          onAddGuardian: (_, _, _) => created = true,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardians'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Full name'),
        'No Phone',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();

      expect(created, isFalse);
      expect(
        find.text('Full name, relation and phone are required.'),
        findsOneWidget,
      );
    });

    testWidgets('Documents: uploaded documents are listed', (tester) async {
      await tester.pumpWidget(
        _wrapPage(
          students: [_studentWithDetails],
          documents: const [
            DocumentEntry(
              id: 5,
              personId: 100,
              documentName: 'Birth Certificate',
              documentType: 'certificate',
              documentUrl: 'https://storage.example.com/docs/birth.pdf',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('Birth Certificate'), findsOneWidget);
      expect(find.text('certificate'), findsOneWidget);
      expect(find.text('Upload'), findsOneWidget);
    });

    testWidgets('Documents: an empty list says so', (tester) async {
      await tester.pumpWidget(_wrapPage(students: [_studentWithDetails]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Documents'));
      await tester.pumpAndSettle();

      expect(find.text('No documents uploaded yet.'), findsOneWidget);
    });

    testWidgets('Info: saving sends only the fields that changed', (
      tester,
    ) async {
      Map<String, String>? sent;
      var personId = 0;

      await tester.pumpWidget(
        _wrapPage(
          students: [_studentWithDetails],
          onUpdatePerson: (id, changes) {
            personId = id;
            sent = changes;
          },
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      // Save is inert until something actually changes.
      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Save changes'),
            )
            .onPressed,
        isNull,
      );

      final addressField = find.widgetWithText(
        TextField,
        'Tashkent, Yunusobod 4',
      );
      await tester.ensureVisible(addressField);
      await tester.enterText(addressField, 'Samarkand');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save changes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save changes'));
      await tester.pumpAndSettle();

      expect(personId, 100);
      expect(sent, {'address': 'Samarkand'});
    });

    testWidgets('Info: cancel restores the stored values', (tester) async {
      await tester.pumpWidget(_wrapPage(students: [_studentWithDetails]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      final addressField = find.widgetWithText(
        TextField,
        'Tashkent, Yunusobod 4',
      );
      await tester.ensureVisible(addressField);
      await tester.enterText(addressField, 'Somewhere else');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(TextField, 'Tashkent, Yunusobod 4'),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextField, 'Somewhere else'), findsNothing);
    });

    testWidgets('Info: the student photo is keyed by person id', (
      tester,
    ) async {
      var removedFor = 0;

      await tester.pumpWidget(
        _wrapPage(
          // Remove is only offered when there is a photo to remove.
          students: [
            _studentWithDetails.copyWithPictureUrl(
              'https://cdn.example.com/persons/100/a.jpg',
            ),
          ],
          onRemovePicture: (personId) => removedFor = personId,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yusupova Samira'));
      await tester.pumpAndSettle();

      final avatar = find.byType(EditableAvatar);
      expect(avatar, findsOneWidget);
      // Pictures hang off the person record, not the enrollment (id 1).
      expect(tester.widget<EditableAvatar>(avatar).ownerId, 100);

      // Removal reaches the API with that same person id.
      await tester.tap(
        find.descendant(of: avatar, matching: find.byType(InkWell)).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remove photo'));
      await tester.pumpAndSettle();

      expect(removedFor, 100);
    });

    testWidgets('search matches on code as well as name', (tester) async {
      await tester.pumpWidget(_wrapPage());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'DIS250387');
      await tester.pumpAndSettle();

      expect(find.text('Nazarov Abdulloh'), findsOneWidget);
      expect(find.text('Yusupova Samira'), findsNothing);
    });
  });
}
