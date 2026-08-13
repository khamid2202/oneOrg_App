import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

/// Two-way sync between Guardians and Contacts.
///
/// A parent is the same person whether stored as a Guardian
/// (docs/staff/guardians.md) or a Contact (docs/staff/contacts.md), so saving
/// one mirrors it into the other.
///
/// The two are matched **by phone number** within a person (plus the row's
/// previous phone on edits, so changing a number moves the mirror instead of
/// orphaning it). Mirroring is an **upsert** — it updates the matching row when
/// one exists, so re-saving never duplicates. The guardian-only fields
/// (`work_address`, `position`) are left untouched when syncing from a contact.
///
/// Mirroring is **best-effort**: the primary save is what the caller awaits and
/// surfaces errors for; a failure to mirror is swallowed so the thing the user
/// actually saved still succeeds.
///
/// This mirrors the web implementation in
/// `school-project/src/features/my-class/studentPeopleSync.js`.
class StudentPeopleSync {
  const StudentPeopleSync({
    required this.loadContacts,
    required this.createContact,
    required this.updateContact,
    required this.loadGuardians,
    required this.createGuardian,
    required this.updateGuardian,
  });

  final Future<List<ContactEntry>> Function(int personId) loadContacts;
  final Future<ContactEntry> Function({
    required int personId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
  })
  createContact;
  final Future<ContactEntry> Function({
    required int contactId,
    String? fullName,
    String? relationship,
    String? phoneNumber,
  })
  updateContact;

  final Future<List<GuardianEntry>> Function(int personId) loadGuardians;
  final Future<GuardianEntry> Function({
    required int personId,
    required String fullName,
    required String relation,
    required String phone,
    String? workAddress,
    String? position,
  })
  createGuardian;
  final Future<GuardianEntry> Function({
    required int guardianId,
    String? fullName,
    String? relation,
    String? phone,
    String? workAddress,
    String? position,
  })
  updateGuardian;

  /// Contacts cap `full_name` at 50 characters; guardians allow 255.
  static const contactNameMax = 50;

  /// Digits with an optional leading `+`, so formatting differences do not
  /// stop two rows matching.
  static String compactPhone(String? value) {
    final raw = (value ?? '').trim();
    final hasPlus = raw.startsWith('+');
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return hasPlus ? '+' : '';
    }
    return hasPlus ? '+$digits' : digits;
  }

  static bool samePhone(String? a, String? b) {
    final na = compactPhone(a);
    final nb = compactPhone(b);
    return na.isNotEmpty && na == nb;
  }

  static String clampName(String? name) {
    final trimmed = (name ?? '').trim();
    return trimmed.length <= contactNameMax
        ? trimmed
        : trimmed.substring(0, contactNameMax);
  }

  /// Guardians store a free-text relation; contacts take a fixed set. Anything
  /// unrecognised becomes `other`.
  static const _relationshipAliases = {
    'dad': 'father',
    'father': 'father',
    'mom': 'mother',
    'mother': 'mother',
    'brother': 'brother',
    'sister': 'sister',
    'grandfather': 'grandfather',
    'grandpa': 'grandfather',
    'grandmother': 'grandmother',
    'grandma': 'grandmother',
    'uncle': 'uncle',
    'aunt': 'aunt',
    'cousin': 'cousin',
    'self': 'self',
    'guardian': 'other',
    'parent': 'other',
    'other': 'other',
  };

  static String normalizeRelationship(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    if (normalized.isEmpty) {
      return 'other';
    }
    return _relationshipAliases[normalized] ?? 'other';
  }

  /// Saves a guardian, then mirrors it into contacts.
  ///
  /// [previousPhone] is the guardian's phone before this edit, so a changed
  /// number updates the same contact rather than creating a second one.
  Future<GuardianEntry> saveGuardian({
    required int personId,
    int? guardianId,
    required String fullName,
    required String relation,
    required String phone,
    String? workAddress,
    String? position,
    String? previousPhone,
  }) async {
    final saved = guardianId == null
        ? await createGuardian(
            personId: personId,
            fullName: fullName,
            relation: relation,
            phone: phone,
            workAddress: workAddress,
            position: position,
          )
        : await updateGuardian(
            guardianId: guardianId,
            fullName: fullName,
            relation: relation,
            phone: phone,
            workAddress: workAddress,
            position: position,
          );

    await _mirrorGuardianToContact(
      personId: personId,
      fullName: fullName,
      relation: relation,
      phone: phone,
      previousPhone: previousPhone,
    );

    return saved;
  }

  /// Saves a contact, then mirrors it into guardians.
  Future<ContactEntry> saveContact({
    required int personId,
    int? contactId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
    String? previousPhone,
  }) async {
    final saved = contactId == null
        ? await createContact(
            personId: personId,
            fullName: fullName,
            relationship: relationship,
            phoneNumber: phoneNumber,
          )
        : await updateContact(
            contactId: contactId,
            fullName: fullName,
            relationship: relationship,
            phoneNumber: phoneNumber,
          );

    await _mirrorContactToGuardian(
      personId: personId,
      fullName: fullName,
      relationship: relationship,
      phone: phoneNumber,
      previousPhone: previousPhone,
    );

    return saved;
  }

  Future<void> _mirrorGuardianToContact({
    required int personId,
    required String fullName,
    required String relation,
    required String phone,
    String? previousPhone,
  }) async {
    final name = clampName(fullName);
    final number = compactPhone(phone);
    if (name.isEmpty || number.isEmpty) {
      return;
    }
    final relationship = normalizeRelationship(relation);

    try {
      final contacts = await loadContacts(personId);
      final match = _firstWhereOrNull(
        contacts,
        (contact) =>
            samePhone(contact.phoneNumber, number) ||
            (previousPhone != null &&
                samePhone(contact.phoneNumber, previousPhone)),
      );

      if (match == null) {
        await createContact(
          personId: personId,
          fullName: name,
          relationship: relationship,
          phoneNumber: number,
        );
        return;
      }

      final unchanged =
          match.fullName == name &&
          match.relationship == relationship &&
          samePhone(match.phoneNumber, number);
      if (unchanged) {
        return;
      }

      await updateContact(
        contactId: match.id,
        fullName: name,
        relationship: relationship,
        phoneNumber: number,
      );
    } catch (_) {
      // Best effort: the guardian save already succeeded.
    }
  }

  Future<void> _mirrorContactToGuardian({
    required int personId,
    required String fullName,
    required String relationship,
    required String phone,
    String? previousPhone,
  }) async {
    final name = fullName.trim();
    final number = compactPhone(phone);
    if (name.isEmpty || number.isEmpty) {
      return;
    }
    final relation = relationship.trim().isEmpty
        ? 'other'
        : relationship.trim();

    try {
      final guardians = await loadGuardians(personId);
      final match = _firstWhereOrNull(
        guardians,
        (guardian) =>
            samePhone(guardian.phone, number) ||
            (previousPhone != null && samePhone(guardian.phone, previousPhone)),
      );

      if (match == null) {
        await createGuardian(
          personId: personId,
          fullName: name,
          relation: relation,
          phone: number,
        );
        return;
      }

      final unchanged =
          match.fullName == name &&
          match.relation == relation &&
          samePhone(match.phone, number);
      if (unchanged) {
        return;
      }

      // Only the shared fields are synced — omitting work_address and position
      // keeps the guardian's own values.
      await updateGuardian(
        guardianId: match.id,
        fullName: name,
        relation: relation,
        phone: number,
      );
    } catch (_) {
      // Best effort: the contact save already succeeded.
    }
  }

  static T? _firstWhereOrNull<T>(List<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) {
        return item;
      }
    }
    return null;
  }
}
