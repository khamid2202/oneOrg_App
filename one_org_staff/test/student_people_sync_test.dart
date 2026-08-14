import 'package:flutter_test/flutter_test.dart';
import 'package:one_org_staff/features/MyClass/student_people_sync.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

/// Records every write so a test can assert what the mirror did.
class _Recorder {
  final List<Map<String, Object?>> contactCreates = [];
  final List<Map<String, Object?>> contactUpdates = [];
  final List<Map<String, Object?>> guardianCreates = [];
  final List<Map<String, Object?>> guardianUpdates = [];
}

StudentPeopleSync _sync(
  _Recorder log, {
  List<ContactEntry> contacts = const [],
  List<GuardianEntry> guardians = const [],
  bool contactsThrow = false,
}) {
  return StudentPeopleSync(
    loadContacts: (personId) async {
      if (contactsThrow) {
        throw const AuthFailure('contacts unavailable');
      }
      return contacts;
    },
    createContact:
        ({
          required personId,
          required fullName,
          required relationship,
          required phoneNumber,
        }) async {
          log.contactCreates.add({
            'personId': personId,
            'fullName': fullName,
            'relationship': relationship,
            'phoneNumber': phoneNumber,
          });
          return ContactEntry(
            id: 1,
            personId: personId,
            fullName: fullName,
            relationship: relationship,
            phoneNumber: phoneNumber,
          );
        },
    updateContact:
        ({required contactId, fullName, relationship, phoneNumber}) async {
          log.contactUpdates.add({
            'contactId': contactId,
            'fullName': fullName,
            'relationship': relationship,
            'phoneNumber': phoneNumber,
          });
          return ContactEntry(
            id: contactId,
            fullName: fullName ?? '',
            relationship: relationship ?? '',
            phoneNumber: phoneNumber ?? '',
          );
        },
    loadGuardians: (personId) async => guardians,
    createGuardian:
        ({
          required personId,
          required fullName,
          required relation,
          required phone,
          workAddress,
          position,
        }) async {
          log.guardianCreates.add({
            'personId': personId,
            'fullName': fullName,
            'relation': relation,
            'phone': phone,
            'workAddress': workAddress,
            'position': position,
          });
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
        }) async {
          log.guardianUpdates.add({
            'guardianId': guardianId,
            'fullName': fullName,
            'relation': relation,
            'phone': phone,
            'workAddress': workAddress,
            'position': position,
          });
          return GuardianEntry(
            id: guardianId,
            fullName: fullName ?? '',
            relation: relation ?? '',
            phone: phone ?? '',
          );
        },
  );
}

void main() {
  group('phone matching', () {
    test('ignores formatting differences', () {
      expect(
        StudentPeopleSync.samePhone('+998 90 111 22 33', '+998901112233'),
        isTrue,
      );
      expect(
        StudentPeopleSync.samePhone('+998-90-111-22-33', '+998901112233'),
        isTrue,
      );
    });

    test('two blanks are not a match', () {
      expect(StudentPeopleSync.samePhone('', ''), isFalse);
      expect(StudentPeopleSync.samePhone(null, null), isFalse);
    });

    test('different numbers do not match', () {
      expect(
        StudentPeopleSync.samePhone('+998901112233', '+998907776655'),
        isFalse,
      );
    });
  });

  group('relationship normalisation', () {
    test('maps common aliases onto the contact vocabulary', () {
      expect(StudentPeopleSync.normalizeRelationship('Dad'), 'father');
      expect(StudentPeopleSync.normalizeRelationship('MOM'), 'mother');
      expect(StudentPeopleSync.normalizeRelationship('grandpa'), 'grandfather');
    });

    test('anything unrecognised becomes other', () {
      expect(StudentPeopleSync.normalizeRelationship('neighbour'), 'other');
      expect(StudentPeopleSync.normalizeRelationship(''), 'other');
      expect(StudentPeopleSync.normalizeRelationship(null), 'other');
    });
  });

  group('guardian saves mirror into contacts', () {
    test('a new guardian creates a matching contact', () async {
      final log = _Recorder();
      await _sync(log).saveGuardian(
        personId: 100,
        fullName: 'Valijon Valiyev',
        relation: 'father',
        phone: '+998 90 111 22 33',
      );

      expect(log.guardianCreates, hasLength(1));
      expect(log.contactCreates.single, {
        'personId': 100,
        'fullName': 'Valijon Valiyev',
        'relationship': 'father',
        // Compacted for storage.
        'phoneNumber': '+998901112233',
      });
    });

    test(
      'an existing contact on the same phone is updated, not duplicated',
      () async {
        final log = _Recorder();
        await _sync(
          log,
          contacts: const [
            ContactEntry(
              id: 7,
              personId: 100,
              fullName: 'Old Name',
              relationship: 'other',
              phoneNumber: '+998901112233',
            ),
          ],
        ).saveGuardian(
          personId: 100,
          guardianId: 3,
          fullName: 'Valijon Valiyev',
          relation: 'father',
          phone: '+998901112233',
        );

        expect(log.contactCreates, isEmpty);
        expect(log.contactUpdates.single['contactId'], 7);
        expect(log.contactUpdates.single['fullName'], 'Valijon Valiyev');
      },
    );

    test(
      'changing the number moves the mirror instead of orphaning it',
      () async {
        final log = _Recorder();
        await _sync(
          log,
          contacts: const [
            ContactEntry(
              id: 7,
              personId: 100,
              fullName: 'Valijon',
              relationship: 'father',
              phoneNumber: '+998901112233',
            ),
          ],
        ).saveGuardian(
          personId: 100,
          guardianId: 3,
          fullName: 'Valijon',
          relation: 'father',
          phone: '+998900000000',
          previousPhone: '+998901112233',
        );

        // Matched on the old number, so the same contact row is repointed.
        expect(log.contactCreates, isEmpty);
        expect(log.contactUpdates.single['contactId'], 7);
        expect(log.contactUpdates.single['phoneNumber'], '+998900000000');
      },
    );

    test('an identical mirror is left alone', () async {
      final log = _Recorder();
      await _sync(
        log,
        contacts: const [
          ContactEntry(
            id: 7,
            personId: 100,
            fullName: 'Valijon',
            relationship: 'father',
            phoneNumber: '+998901112233',
          ),
        ],
      ).saveGuardian(
        personId: 100,
        guardianId: 3,
        fullName: 'Valijon',
        relation: 'father',
        phone: '+998901112233',
      );

      expect(log.contactCreates, isEmpty);
      expect(log.contactUpdates, isEmpty);
    });

    test('a long guardian name is clamped to the contact limit', () async {
      final log = _Recorder();
      final longName = 'A' * 80;

      await _sync(log).saveGuardian(
        personId: 100,
        fullName: longName,
        relation: 'father',
        phone: '+998901112233',
      );

      expect(
        (log.contactCreates.single['fullName']! as String).length,
        StudentPeopleSync.contactNameMax,
      );
    });

    test('a failing mirror does not fail the guardian save', () async {
      final log = _Recorder();

      final saved = await _sync(log, contactsThrow: true).saveGuardian(
        personId: 100,
        fullName: 'Valijon',
        relation: 'father',
        phone: '+998901112233',
      );

      expect(saved.fullName, 'Valijon');
      expect(log.contactCreates, isEmpty);
    });
  });

  group('contact saves mirror into guardians', () {
    test('a new contact creates a matching guardian', () async {
      final log = _Recorder();
      await _sync(log).saveContact(
        personId: 100,
        fullName: 'Mubina Xasanova',
        relationship: 'mother',
        phoneNumber: '+998907776655',
      );

      expect(log.contactCreates, hasLength(1));
      expect(log.guardianCreates.single['fullName'], 'Mubina Xasanova');
      expect(log.guardianCreates.single['relation'], 'mother');
      expect(log.guardianCreates.single['phone'], '+998907776655');
    });

    test('the guardian-only fields are left untouched on update', () async {
      final log = _Recorder();
      await _sync(
        log,
        guardians: const [
          GuardianEntry(
            id: 3,
            personId: 100,
            fullName: 'Old',
            relation: 'mother',
            phone: '+998907776655',
            workAddress: 'Somewhere',
            position: 'Doctor',
          ),
        ],
      ).saveContact(
        personId: 100,
        contactId: 7,
        fullName: 'Mubina Xasanova',
        relationship: 'mother',
        phoneNumber: '+998907776655',
      );

      final update = log.guardianUpdates.single;
      expect(update['guardianId'], 3);
      expect(update['fullName'], 'Mubina Xasanova');
      // Not sent, so the stored work address and position survive.
      expect(update['workAddress'], isNull);
      expect(update['position'], isNull);
    });

    test('a contact with no phone is not mirrored', () async {
      final log = _Recorder();
      await _sync(log).saveContact(
        personId: 100,
        fullName: 'No Phone',
        relationship: 'other',
        phoneNumber: '',
      );

      expect(log.guardianCreates, isEmpty);
      expect(log.guardianUpdates, isEmpty);
    });
  });
}
