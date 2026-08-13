/// Personal details carried on the `person` object that read endpoints attach
/// to every enrollment. Every field is optional — the API returns nulls freely.
class PersonDetails {
	const PersonDetails({
		this.birthDate,
		this.gender,
		this.phone,
		this.address,
		this.passportNumber,
		this.birthCertificateNumber,
	});

	final String? birthDate;
	final String? gender;
	final String? phone;
	final String? address;
	final String? passportNumber;
	final String? birthCertificateNumber;

	/// The API field names, so a patch body can be built without the caller
	/// knowing the wire format.
	static const birthDateKey = 'birth_date';
	static const genderKey = 'gender';
	static const phoneKey = 'phone';
	static const addressKey = 'address';
	static const passportNumberKey = 'passport_number';
	static const birthCertificateNumberKey = 'birth_certificate_number';

	PersonDetails copyWith({
		String? birthDate,
		String? gender,
		String? phone,
		String? address,
		String? passportNumber,
		String? birthCertificateNumber,
	}) {
		return PersonDetails(
			birthDate: birthDate ?? this.birthDate,
			gender: gender ?? this.gender,
			phone: phone ?? this.phone,
			address: address ?? this.address,
			passportNumber: passportNumber ?? this.passportNumber,
			birthCertificateNumber:
					birthCertificateNumber ?? this.birthCertificateNumber,
		);
	}

	/// Fields that differ from [original], keyed by their API names.
	///
	/// Only changed fields are included, so a partial edit never overwrites
	/// something the teacher did not touch. A field cleared in the form maps to
	/// an empty string, which is how the API is told to erase it.
	Map<String, String> diffFrom(PersonDetails original) {
		final changes = <String, String>{};

		void compare(String key, String? mine, String? theirs) {
			final next = mine?.trim() ?? '';
			final previous = theirs?.trim() ?? '';
			if (next != previous) {
				changes[key] = next;
			}
		}

		compare(birthDateKey, birthDate, original.birthDate);
		compare(genderKey, gender, original.gender);
		compare(phoneKey, phone, original.phone);
		compare(addressKey, address, original.address);
		compare(passportNumberKey, passportNumber, original.passportNumber);
		compare(
			birthCertificateNumberKey,
			birthCertificateNumber,
			original.birthCertificateNumber,
		);

		return changes;
	}

	bool get isEmpty =>
			birthDate == null &&
			gender == null &&
			phone == null &&
			address == null &&
			passportNumber == null &&
			birthCertificateNumber == null;

	factory PersonDetails.fromJson(Map<String, dynamic> json) {
		String? read(List<String> keys) {
			for (final key in keys) {
				final value = json[key];
				if (value is String && value.trim().isNotEmpty) {
					return value.trim();
				}
			}
			return null;
		}

		return PersonDetails(
			birthDate: read(const ['birth_date', 'birthDate']),
			gender: read(const ['gender']),
			phone: read(const ['phone', 'phone_number', 'phoneNumber']),
			address: read(const ['address']),
			passportNumber: read(const ['passport_number', 'passportNumber']),
			birthCertificateNumber: read(const [
				'birth_certificate_number',
				'birthCertificateNumber',
			]),
		);
	}
}

class StudentEntry {
	const StudentEntry({
		required this.id,
		required this.personId,
		required this.fullName,
		this.nickname,
		this.code,
		this.pictureUrl,
		this.status,
		this.contacts = const [],
		this.details = const PersonDetails(),
	});

	/// The enrollment id, distinct from [personId].
	final int id;

	/// The underlying person id. `/contacts` and `/student-points` key by this.
	final int personId;

	final String fullName;
	final String? nickname;

	/// The person code, e.g. `DIS250383`.
	final String? code;

	final String? pictureUrl;

	/// Enrollment status, e.g. `present` or `left`.
	final String? status;

	/// Only populated when the roster was fetched with `include=["contacts"]`.
	final List<ContactEntry> contacts;

	/// Personal details from the attached person record.
	final PersonDetails details;

	factory StudentEntry.fromJson(Map<String, dynamic> json) {
		final id = _asInt(json['student_id'] ?? json['id']);
		final personId = _asInt(json['person_id'] ?? json['personId']);
		final fullName = _firstString(json, const ['full_name', 'fullName', 'name']);
		if (id == null || personId == null || fullName == null) {
			throw const FormatException('Student entry is missing required fields.');
		}

		// Reads hydrate the enrollment with its person; the code and photo live
		// there, not on the enrollment itself.
		final person = json['person'];
		final personMap = person is Map<String, dynamic>
				? person
				: const <String, dynamic>{};

		final contacts = <ContactEntry>[];
		final rawContacts = json['contacts'];
		if (rawContacts is List) {
			for (final item in rawContacts) {
				if (item is Map<String, dynamic>) {
					try {
						contacts.add(
							ContactEntry.fromJson(item, fallbackPersonId: personId),
						);
					} on FormatException {
						continue;
					}
				}
			}
		}

		return StudentEntry(
			id: id,
			personId: personId,
			fullName: fullName,
			nickname: _firstString(json, const ['nickname', 'nick_name', 'nickName']),
			code: _firstString(json, const ['code']) ??
					_firstString(personMap, const ['code']),
			pictureUrl: _firstString(json, const ['picture_url', 'pictureUrl']) ??
					_firstString(personMap, const ['picture_url', 'pictureUrl']),
			status: _firstString(json, const ['status']),
			contacts: contacts,
			details: PersonDetails.fromJson(personMap),
		);
	}

	/// [pictureUrl] is passed positionally-as-nullable on purpose: clearing a
	/// photo must be expressible.
	StudentEntry copyWithPictureUrl(String? pictureUrl) {
		return StudentEntry(
			id: id,
			personId: personId,
			fullName: fullName,
			nickname: nickname,
			code: code,
			pictureUrl: pictureUrl,
			status: status,
			contacts: contacts,
			details: details,
		);
	}

	StudentEntry copyWithDetails(PersonDetails details) {
		return StudentEntry(
			id: id,
			personId: personId,
			fullName: fullName,
			nickname: nickname,
			code: code,
			pictureUrl: pictureUrl,
			status: status,
			contacts: contacts,
			details: details,
		);
	}

	static String? _firstString(Map<String, dynamic> json, List<String> keys) {
		for (final key in keys) {
			final value = json[key];
			if (value is String && value.trim().isNotEmpty) {
				return value.trim();
			}
		}
		return null;
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
}

/// A guardian record from `/guardians`, keyed by `person_id`.
class GuardianEntry {
	const GuardianEntry({
		required this.id,
		required this.fullName,
		required this.relation,
		required this.phone,
		this.personId,
		this.workAddress,
		this.position,
	});

	final int id;
	final String fullName;
	final String relation;
	final String phone;

	/// Nullable for the same reason as [ContactEntry.personId]: the caller
	/// already knows which person it asked for.
	final int? personId;
	final String? workAddress;
	final String? position;

	factory GuardianEntry.fromJson(
		Map<String, dynamic> json, {
		int? fallbackPersonId,
	}) {
		final id = _asInt(json['id']);
		if (id == null) {
			throw const FormatException('Guardian entry is missing an id.');
		}

		String? read(List<String> keys) {
			for (final key in keys) {
				final value = json[key];
				if (value is String && value.trim().isNotEmpty) {
					return value.trim();
				}
			}
			return null;
		}

		return GuardianEntry(
			id: id,
			personId:
					_asInt(json['person_id'] ?? json['personId']) ?? fallbackPersonId,
			fullName: read(const ['full_name', 'fullName']) ?? '',
			relation: read(const ['relation', 'relationship']) ?? 'other',
			phone: read(const ['phone', 'phone_number', 'phoneNumber']) ?? '',
			workAddress: read(const ['work_address', 'workAddress']),
			position: read(const ['position']),
		);
	}

	static int? _asInt(dynamic value) {
		if (value is int) return value;
		if (value is String) return int.tryParse(value);
		return null;
	}
}

/// A document record from `/documents`, keyed by `person_id`.
class DocumentEntry {
	const DocumentEntry({
		required this.id,
		required this.documentName,
		required this.documentType,
		this.personId,
		this.documentUrl,
	});

	final int id;
	final String documentName;
	final String documentType;
	final int? personId;

	/// The stored file. Absent means there is nothing to open.
	final String? documentUrl;

	factory DocumentEntry.fromJson(
		Map<String, dynamic> json, {
		int? fallbackPersonId,
	}) {
		final id = _asInt(json['id']);
		if (id == null) {
			throw const FormatException('Document entry is missing an id.');
		}

		String? read(List<String> keys) {
			for (final key in keys) {
				final value = json[key];
				if (value is String && value.trim().isNotEmpty) {
					return value.trim();
				}
			}
			return null;
		}

		return DocumentEntry(
			id: id,
			personId:
					_asInt(json['person_id'] ?? json['personId']) ?? fallbackPersonId,
			documentName: read(const ['document_name', 'documentName']) ?? 'Document',
			documentType: read(const ['document_type', 'documentType']) ?? '',
			documentUrl: read(const ['document_url', 'documentUrl']),
		);
	}

	static int? _asInt(dynamic value) {
		if (value is int) return value;
		if (value is String) return int.tryParse(value);
		return null;
	}
}

class StudentPointDraft {
	const StudentPointDraft({
		required this.personId,
		required this.groupId,
		required this.points,
		required this.date,
		this.subjectId,
		this.reason,
	});

	final int personId;
	final int groupId;
	final double points;
	final DateTime date;
	final int? subjectId;
	final String? reason;
}

class ContactEntry {
	const ContactEntry({
		required this.id,
		required this.fullName,
		required this.relationship,
		required this.phoneNumber,
		this.personId,
		this.telegramId,
	});

	final int id;

	/// Nullable because nothing needs it: contacts are always read or created
	/// for a person the caller already identified, and update/delete address the
	/// contact by its own [id].
	final int? personId;
	final String fullName;
	final String relationship;
	final String phoneNumber;
	final String? telegramId;

	String get relationshipLabel {
		switch (relationship) {
			case 'mother':
				return 'Mom';
			case 'father':
				return 'Dad';
			case 'brother':
				return 'Brother';
			case 'sister':
				return 'Sister';
			case 'grandfather':
				return 'Grandpa';
			case 'grandmother':
				return 'Grandma';
			case 'uncle':
				return 'Uncle';
			case 'aunt':
				return 'Aunt';
			case 'cousin':
				return 'Cousin';
			case 'self':
				return 'Self';
			default:
				return 'Other';
		}
	}

	/// [fallbackPersonId] is the person the contacts were fetched for. The API
	/// does not always echo `person_id` back on a filtered read, and the caller
	/// already knows it, so a missing one is not a reason to reject the row.
	factory ContactEntry.fromJson(
		Map<String, dynamic> json, {
		int? fallbackPersonId,
	}) {
		final id = _asInt(json['id']);
		final personId =
				_asInt(json['person_id'] ?? json['personId']) ?? fallbackPersonId;
		final fullName = json['full_name'] ?? json['fullName'] ?? '';
		final relationship = json['relationship'] ?? 'other';
		final phoneNumber = json['phone_number'] ?? json['phoneNumber'] ?? '';
		final telegramId = json['telegram_id']?.toString();

		// Only the contact's own id is genuinely required — it is what update and
		// delete address.
		if (id == null) {
			throw const FormatException('Contact entry is missing an id.');
		}

		return ContactEntry(
			id: id,
			personId: personId,
			fullName: fullName.toString().trim(),
			relationship: relationship.toString().trim(),
			phoneNumber: phoneNumber.toString().trim(),
			telegramId: telegramId,
		);
	}

	static int? _asInt(dynamic value) {
		if (value is int) return value;
		if (value is String) return int.tryParse(value);
		return null;
	}
}

class GroupEntry {
	const GroupEntry({
		required this.id,
		required this.grade,
		required this.className,
		required this.academicYearId,
		required this.teacherIds,
		this.teacherName,
	});

	final int id;
	final int grade;
	final String className;
	final int academicYearId;
	final List<int> teacherIds;
	final String? teacherName;

	String get classPair => '$grade-$className';

	factory GroupEntry.fromJson(Map<String, dynamic> json) {
		final id = _asInt(json['id']);
		final grade = _asInt(json['grade']);
		final className = json['class'] ?? json['className'] ?? json['class_name'];
		final academicYearId = _asInt(json['academic_year_id'] ?? json['academicYearId']) ?? 0;

		if (id == null || grade == null || className == null) {
			throw const FormatException('Group entry is missing required fields.');
		}

		final teacherIdsRaw = json['teacher_ids'] ?? json['teacherIds'] ?? [];
		final teacherIds = <int>[];
		if (teacherIdsRaw is List) {
			for (final item in teacherIdsRaw) {
				final parsed = _asInt(item);
				if (parsed != null) {
					teacherIds.add(parsed);
				}
			}
		}

		final teacherName = json['teacher_name'] ?? json['teacherName'];

		return GroupEntry(
			id: id,
			grade: grade,
			className: className.toString().trim(),
			academicYearId: academicYearId,
			teacherIds: teacherIds,
			teacherName: teacherName?.toString().trim(),
		);
	}

	static int? _asInt(dynamic value) {
		if (value is int) return value;
		if (value is String) return int.tryParse(value);
		return null;
	}
}

class AcademicYearEntry {
	const AcademicYearEntry({
		required this.id,
		required this.name,
		required this.isActive,
	});

	final int id;
	final String name;
	final bool isActive;

	String get label => isActive ? '$name (active)' : name;

	factory AcademicYearEntry.fromJson(Map<String, dynamic> json) {
		final id = _asInt(json['id']);
		if (id == null) {
			throw const FormatException('Academic year is missing an id.');
		}

		final name = json['name'];
		final startYear = _asInt(json['start_year']);
		final endYear = _asInt(json['end_year']);

		return AcademicYearEntry(
			id: id,
			name: name is String && name.trim().isNotEmpty
					? name.trim()
					: (startYear != null && endYear != null
							? '$startYear-$endYear'
							: 'Year $id'),
			isActive: json['is_active'] == true,
		);
	}

	static int? _asInt(dynamic value) {
		if (value is int) return value;
		if (value is String) return int.tryParse(value);
		return null;
	}
}

abstract class LessonPointsRepository {
	/// Set [includeContacts] on screens that show contact details, so the roster
	/// arrives in one request instead of one lookup per student.
	Future<List<StudentEntry>> getStudentsForGroup(
		String token, {
		required int groupId,
		bool includeContacts = false,
	});

	Future<List<AcademicYearEntry>> getAcademicYears(String token);

	Future<List<GuardianEntry>> getGuardians(
		String token, {
		required int personId,
	});

	Future<GuardianEntry> createGuardian(
		String token, {
		required int personId,
		required String fullName,
		required String relation,
		required String phone,
		String? workAddress,
		String? position,
	});

	Future<GuardianEntry> updateGuardian(
		String token, {
		required int guardianId,
		String? fullName,
		String? relation,
		String? phone,
		String? workAddress,
		String? position,
	});

	Future<void> deleteGuardian(String token, {required int guardianId});

	Future<List<DocumentEntry>> getDocuments(
		String token, {
		required int personId,
	});

	/// Uploads a file against the person. `file` is required on create.
	Future<DocumentEntry> createDocument(
		String token, {
		required int personId,
		required String documentName,
		required String documentType,
		required List<int> bytes,
		required String filename,
	});

	Future<void> deleteDocument(String token, {required int documentId});

	/// Uploads [bytes] as the person's picture and returns the new URL.
	///
	/// Keyed by person id, not the enrollment id.
	Future<String?> uploadPersonPicture(
		String token, {
		required int personId,
		required List<int> bytes,
		required String filename,
	});

	/// Clears the person's picture. Returns the (now null) URL.
	Future<String?> removePersonPicture(String token, {required int personId});

	/// Applies [changes] (API field names to values) to a person and returns the
	/// stored result.
	Future<PersonDetails> updatePersonDetails(
		String token, {
		required int personId,
		required Map<String, String> changes,
	});

	Future<void> createPointsBulk(
		String token,
		List<StudentPointDraft> points,
	);

	/// Points already recorded for the group on [date], keyed by **person id**.
	Future<Map<int, double>> getPointsForGroupAndDate(
		String token, {
		required int groupId,
		required DateTime date,
		int? subjectId,
	});

	Future<List<GroupEntry>> getGroups(
		String token, {
		required int academicYearId,
	});

	Future<List<ContactEntry>> getContactsForStudent(
		String token, {
		required int personId,
	});

	Future<ContactEntry> createContact(
		String token, {
		required int personId,
		required String fullName,
		required String relationship,
		required String phoneNumber,
	});

	Future<ContactEntry> updateContact(
		String token, {
		required int contactId,
		String? fullName,
		String? relationship,
		String? phoneNumber,
	});

	Future<void> deleteContact(
		String token, {
		required int contactId,
	});
}
