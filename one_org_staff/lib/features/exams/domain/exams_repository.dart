/// Models and the repository contract behind the Exams page.
///
/// Ported from the web staff app's `features/exams` (ExamsHub, UserExams,
/// ExamsOfClasses and ExamGradingView), which reads `docs/staff/exams.md`,
/// `docs/staff/exam-periods.md` and `docs/staff/exam-results.md`.
library;

/// One exam window, from `GET /exam-periods`.
class ExamPeriod {
  const ExamPeriod({
    required this.id,
    required this.name,
    this.academicYearId,
    this.description,
    this.date,
    this.isActive = true,
    this.acceptScores = true,
  });

  final int id;
  final String name;
  final int? academicYearId;
  final String? description;

  /// The period's own date (`exam_periods.date`), an ISO `YYYY-MM-DD` string.
  final String? date;

  final bool isActive;
  final bool acceptScores;

  /// What the create form's dropdown shows — the web renders `name (date)`.
  String get labelWithDate => date == null ? name : '$name ($date)';

  factory ExamPeriod.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    if (id == null) {
      throw const FormatException('Exam period is missing an id.');
    }

    return ExamPeriod(
      id: id,
      name: _asString(json['name']) ?? 'Period #$id',
      academicYearId: _asInt(json['academic_year_id'] ?? json['academicYearId']),
      description: _asString(json['description']),
      date: _asString(json['date']),
      isActive: json['is_active'] != false,
      acceptScores: json['accept_scores'] != false,
    );
  }
}

/// One exam definition, from `GET /exams`.
class Exam {
  const Exam({
    required this.id,
    required this.examPeriodId,
    required this.subjectId,
    required this.maxScore,
    this.groupIds = const [],
    this.createdAt,
    this.createdBy,
  });

  final int id;
  final int examPeriodId;
  final int subjectId;
  final int maxScore;

  /// The classes sitting this exam. The API allows several; the web's create
  /// form deliberately posts only one, so in practice this holds one id.
  final List<int> groupIds;

  final DateTime? createdAt;
  final int? createdBy;

  factory Exam.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final examPeriodId = _asInt(json['exam_period_id'] ?? json['examPeriodId']);
    final subjectId = _asInt(json['subject_id'] ?? json['subjectId']);
    if (id == null || examPeriodId == null || subjectId == null) {
      throw const FormatException('Exam is missing required fields.');
    }

    final rawGroupIds = json['group_ids'] ?? json['groupIds'];
    final groupIds = <int>[];
    if (rawGroupIds is List) {
      for (final item in rawGroupIds) {
        final parsed = _asInt(item);
        if (parsed != null) {
          groupIds.add(parsed);
        }
      }
    }

    return Exam(
      id: id,
      examPeriodId: examPeriodId,
      subjectId: subjectId,
      maxScore: _asInt(json['max_score'] ?? json['maxScore']) ?? 100,
      groupIds: groupIds,
      createdAt: _asDate(json['created_at'] ?? json['createdAt']),
      createdBy: _asInt(json['created_by'] ?? json['createdBy']),
    );
  }
}

/// One subject, from the bare array `GET /subjects` returns.
class SubjectEntry {
  const SubjectEntry({required this.id, required this.name});

  final int id;
  final String name;

  /// Homeroom is a timetable placeholder rather than an examinable subject, so
  /// the create form hides it — same rule as the web.
  bool get isHomeroom => name.trim().toLowerCase() == 'homeroom';

  factory SubjectEntry.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id'] ?? json['subject_id']);
    if (id == null) {
      throw const FormatException('Subject is missing an id.');
    }
    return SubjectEntry(
      id: id,
      name: _asString(json['name'] ?? json['subject_name']) ?? 'Subject #$id',
    );
  }
}

/// One student's score on one exam, from `GET /exam-results?exam_id=…`.
class ExamResult {
  const ExamResult({
    required this.id,
    required this.studentId,
    required this.examId,
    required this.score,
  });

  final int id;

  /// The *enrollment* id — `/students` calls the same value `student_id`.
  final int studentId;

  final int examId;
  final double score;

  factory ExamResult.fromJson(Map<String, dynamic> json) {
    final id = _asInt(json['id']);
    final studentId = _asInt(json['student_id'] ?? json['studentId']);
    final examId = _asInt(json['exam_id'] ?? json['examId']);
    if (id == null || studentId == null || examId == null) {
      throw const FormatException('Exam result is missing required fields.');
    }
    return ExamResult(
      id: id,
      studentId: studentId,
      examId: examId,
      score: _asDouble(json['score']) ?? 0,
    );
  }
}

/// A score the grading screen wants created.
class ExamResultDraft {
  const ExamResultDraft({
    required this.studentId,
    required this.examId,
    required this.score,
  });

  final int studentId;
  final int examId;
  final double score;
}

abstract class ExamsRepository {
  Future<List<ExamPeriod>> getExamPeriods(
    String token, {
    bool? isActive,
    int? academicYearId,
  });

  Future<List<Exam>> getExams(String token, {int? examPeriodId});

  Future<Exam> createExam(
    String token, {
    required int examPeriodId,
    required int subjectId,
    required List<int> groupIds,
    required int maxScore,
  });

  Future<void> deleteExam(String token, {required int examId});

  Future<List<SubjectEntry>> getSubjects(String token);

  Future<List<ExamResult>> getExamResults(String token, {required int examId});

  Future<void> createExamResultsBulk(String token, List<ExamResultDraft> drafts);

  Future<void> updateExamResult(
    String token, {
    required int resultId,
    required double score,
  });

  Future<void> deleteExamResult(String token, {required int resultId});
}

int? _asInt(dynamic value) {
  if (value is int) return value;
  if (value is double) return value.round();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

String? _asString(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  if (value is num) return value.toString();
  return null;
}

DateTime? _asDate(dynamic value) {
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
