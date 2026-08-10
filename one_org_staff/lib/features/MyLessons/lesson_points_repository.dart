class StudentEntry {
	const StudentEntry({
		required this.id,
		required this.fullName,
		this.nickname,
		this.studentGroupId,
	});

	final int id;
	final String fullName;
	final String? nickname;
	final int? studentGroupId;

	factory StudentEntry.fromJson(Map<String, dynamic> json) {
		final id = _asInt(json['student_id'] ?? json['id']);
		final fullName = _firstString(json, const ['full_name', 'fullName', 'name']);
		if (id == null || fullName == null) {
			throw const FormatException('Student entry is missing required fields.');
		}
		return StudentEntry(
			id: id,
			fullName: fullName,
			nickname: _firstString(json, const ['nickname', 'nick_name', 'nickName']),
			studentGroupId: _asInt(json['student_group_id'] ?? json['studentGroupId']),
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

class StudentPointDraft {
	const StudentPointDraft({
		required this.studentId,
		required this.groupId,
		required this.points,
		required this.date,
		this.subjectId,
		this.reason,
	});

	final int studentId;
	final int groupId;
	final double points;
	final DateTime date;
	final int? subjectId;
	final String? reason;
}

class ContactEntry {
	const ContactEntry({
		required this.id,
		required this.studentId,
		required this.fullName,
		required this.relationship,
		required this.phoneNumber,
		this.telegramId,
	});

	final int id;
	final int studentId;
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

	factory ContactEntry.fromJson(Map<String, dynamic> json) {
		final id = _asInt(json['id']);
		final studentId = _asInt(json['student_id'] ?? json['studentId']);
		final fullName = json['full_name'] ?? json['fullName'] ?? '';
		final relationship = json['relationship'] ?? 'other';
		final phoneNumber = json['phone_number'] ?? json['phoneNumber'] ?? '';
		final telegramId = json['telegram_id']?.toString();

		if (id == null || studentId == null) {
			throw const FormatException('Contact entry is missing required fields.');
		}

		return ContactEntry(
			id: id,
			studentId: studentId,
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

abstract class LessonPointsRepository {
	Future<List<StudentEntry>> getStudentsForGroup(
		String token, {
		required int groupId,
	});

	Future<void> createPointsBulk(
		String token,
		List<StudentPointDraft> points,
	);

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
		required int studentId,
	});

	Future<ContactEntry> createContact(
		String token, {
		required int studentId,
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
