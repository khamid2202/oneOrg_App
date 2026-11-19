/// Records behind the Calendar, My Lesson Analysis and My Department pages,
/// the same APIs as the web's `/calendar`, `/my-lesson-analysis` and
/// `/my-department`.
library;

int? _int(dynamic value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

double? _num(dynamic value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}');

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

/// One analysis of one of my lessons (`GET /lesson-observations`).
class LessonObservation {
  const LessonObservation({
    required this.id,
    required this.date,
    required this.points,
    this.startTime,
    this.classPair,
    this.subject,
    this.observer,
    this.createdAt,
    this.updatedAt,
    this.notes = const [],
  });

  factory LessonObservation.fromJson(Map<String, dynamic> json) {
    final notes = json['notes'];
    return LessonObservation(
      id: _int(json['id']) ?? 0,
      date: json['date']?.toString() ?? '',
      points: _num(json['points']) ?? 0,
      startTime: _text(json['start_time']),
      classPair: _text(json['class_pair']),
      subject: _text(json['subject']),
      observer: _text(json['observer']),
      createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      updatedAt: DateTime.tryParse('${json['updated_at'] ?? ''}')?.toLocal(),
      notes: notes is List
          ? [
              for (final note in notes.whereType<Map>())
                if (_text(note['note']) != null)
                  ObservationNote(
                    criterion: _text(note['criterion']) ?? '',
                    note: _text(note['note'])!,
                  ),
            ]
          : const [],
    );
  }

  final int id;

  /// The lesson's day, "YYYY-MM-DD".
  final String date;
  final double points;

  /// "HH:MM:SS".
  final String? startTime;
  final String? classPair;
  final String? subject;
  final String? observer;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<ObservationNote> notes;

  /// Changed more than a minute after it was saved.
  bool get edited =>
      createdAt != null &&
      updatedAt != null &&
      updatedAt!.difference(createdAt!).inSeconds > 60;
}

class ObservationNote {
  const ObservationNote({required this.criterion, required this.note});

  final String criterion;
  final String note;
}

/// A department I'm in (`GET /departments/my`), with my role there.
class MyDepartmentEntry {
  const MyDepartmentEntry({
    required this.id,
    required this.name,
    required this.role,
    this.active = true,
  });

  factory MyDepartmentEntry.fromJson(Map<String, dynamic> json) =>
      MyDepartmentEntry(
        id: _int(json['id']) ?? 0,
        name: json['name']?.toString() ?? '',
        role: json['role']?.toString() ?? 'member',
        active: json['is_active'] != false,
      );

  final int id;
  final String name;

  /// `head`, `deputy` or `member`.
  final String role;
  final bool active;

  /// Heads and deputies see the department's statistics.
  bool get leads => role == 'head' || role == 'deputy';
}

/// One row of department statistics: the whole department, a teacher, a
/// subject or a class. Percentages and averages are null when there is
/// nothing to count.
class DepartmentFigures {
  const DepartmentFigures({
    required this.id,
    required this.name,
    this.role,
    this.lessons,
    this.attendanceMarked,
    this.gradesEntered,
    this.gradeCount,
    this.averageGrade,
    this.attendanceRate,
    this.examAverage,
    this.examCount,
    this.kpiPoints,
  });

  factory DepartmentFigures.fromJson(
    Map<String, dynamic> json, {
    String idKey = 'id',
  }) {
    final grade = _text(json['grade']);
    final letter = _text(json['class']);
    final name =
        _text(json['full_name']) ??
        _text(json['name']) ??
        [?grade, ?letter].join('-');
    return DepartmentFigures(
      id: _int(json[idKey]) ?? 0,
      name: name,
      role: _text(json['role']),
      lessons: _int(json['lessons']),
      attendanceMarked: _num(json['attendance_marked_percent']),
      gradesEntered: _num(json['grades_entered_percent']),
      gradeCount: _int(json['grade_count']),
      averageGrade: _num(json['average_grade']),
      attendanceRate: _num(json['attendance_rate']),
      examAverage: _num(json['exam_average_percent']),
      examCount: _int(json['exam_result_count']),
      kpiPoints: _num(json['kpi_points']),
    );
  }

  final int id;
  final String name;

  /// A teacher's role in the department.
  final String? role;
  final int? lessons;

  /// Share of lessons with attendance taken.
  final double? attendanceMarked;

  /// Share of lessons with grades entered.
  final double? gradesEntered;
  final int? gradeCount;
  final double? averageGrade;

  /// Share of attendance marks that are present or late.
  final double? attendanceRate;
  final double? examAverage;
  final int? examCount;
  final double? kpiPoints;
}

/// `GET /departments/:id/statistics`.
class DepartmentStats {
  const DepartmentStats({
    required this.summary,
    required this.subjectCount,
    required this.memberCount,
    this.teachers = const [],
    this.subjects = const [],
    this.groups = const [],
  });

  factory DepartmentStats.fromJson(Map<String, dynamic> json) {
    List<DepartmentFigures> rows(String key, String idKey) {
      final list = json[key];
      return list is List
          ? [
              for (final row in list.whereType<Map>())
                DepartmentFigures.fromJson(
                  Map<String, dynamic>.from(row),
                  idKey: idKey,
                ),
            ]
          : const [];
    }

    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};
    return DepartmentStats(
      summary: DepartmentFigures.fromJson(summary),
      subjectCount: _int(summary['subject_count']) ?? 0,
      memberCount: _int(summary['member_count']) ?? 0,
      teachers: rows('teachers', 'user_id'),
      subjects: rows('subjects', 'subject_id'),
      groups: rows('groups', 'group_id'),
    );
  }

  final DepartmentFigures summary;
  final int subjectCount;
  final int memberCount;
  final List<DepartmentFigures> teachers;
  final List<DepartmentFigures> subjects;
  final List<DepartmentFigures> groups;
}
