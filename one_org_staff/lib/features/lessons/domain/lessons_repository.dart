import '../../grades/domain/gradebook.dart';
import 'lesson_grading.dart';

int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return num.tryParse(value)?.toInt();
  return null;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

String? _asString(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime? _asDate(dynamic value) {
  final text = _asString(value);
  if (text == null || text.length < 10) return null;
  return DateTime.tryParse(text.substring(0, 10));
}

/// Minutes since midnight of "08:30:00" or "08:30".
int? minutesOfDay(String? time) {
  if (time == null) return null;
  final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(time);
  if (match == null) return null;
  return int.parse(match[1]!) * 60 + int.parse(match[2]!);
}

/// One of the teacher's lessons on a day.
class TeacherLesson {
  const TeacherLesson({
    required this.id,
    required this.subject,
    required this.classLabel,
    this.instanceId,
    this.fullClassLabel,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.subgroup,
    this.status,
    this.isSubstitution = false,
    this.attendanceTaken = false,
    this.gradesEntered = 0,
    this.tags = const [],
    this.isLunchDuty = false,
    this.isGraded = true,
    this.substitutionType,
    this.gradedThisWeek,
  });

  /// The timetable entry id.
  final int? id;

  /// Null when the date has no lesson record: a holiday, before the published
  /// timetable starts, or not generated yet. Such a lesson can't be scored.
  final int? instanceId;
  final String subject;

  /// Short form, e.g. "9C".
  final String classLabel;

  /// Long form, e.g. "9-C".
  final String? fullClassLabel;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final String? room;
  final String? subgroup;
  final String? status;
  final bool isSubstitution;
  final bool attendanceTaken;
  final int gradesEntered;

  /// The timetable entry's tags, e.g. `lab` or `after` ("+ after the lesson").
  final List<String> tags;

  /// A lunch duty slot: shown on the schedule, nothing to mark or grade.
  final bool isLunchDuty;

  /// False for a subject that takes attendance but no scores.
  final bool isGraded;

  /// Set on your own lesson that someone covers, merges or cancels.
  final String? substitutionType;

  /// How many of this class's lessons in the subject were graded this week.
  final int? gradedThisWeek;

  bool get isCancelled => status == 'cancelled';

  /// The web's `showsWeeklyCount`: "Graded N times this week" shows on a
  /// gradable lesson that is yours to teach today.
  bool get showsWeeklyCount =>
      instanceId != null &&
      isGraded &&
      !isLunchDuty &&
      !isCancelled &&
      (substitutionType == null || isSubstitution) &&
      gradedThisWeek != null;

  factory TeacherLesson.fromJson(Map<String, dynamic> json) {
    final grade = _asString(json['grade']);
    final letter = _asString(json['class']);
    final pair = _asString(json['class_pair']);
    return TeacherLesson(
      id: _asInt(json['id']),
      instanceId: _asInt(json['lesson_instance_id']),
      subject: _asString(json['subject']) ?? '',
      classLabel:
          _asString(json['class_pair_compact']) ??
          (grade != null && letter != null ? '$grade$letter' : pair ?? ''),
      fullClassLabel: pair,
      date: _asDate(json['date']),
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
      room: _asString(json['room']),
      subgroup: _asString(json['subgroup']),
      status: _asString(json['status']),
      isSubstitution: json['is_substitution'] == true,
      attendanceTaken: json['attendance_taken'] == true,
      gradesEntered: _asInt(json['grades_entered']) ?? 0,
      tags: json['tags'] is List
          ? [
              for (final tag in json['tags'] as List)
                if (_asString(tag) != null) _asString(tag)!,
            ]
          : const [],
      isLunchDuty: json['is_lunch_duty'] == true,
      isGraded: json['is_graded'] != false,
      substitutionType: _asString(json['substitution_type']),
      gradedThisWeek: _asInt(json['graded_lessons_this_week']),
    );
  }
}

/// A weekly staff meeting. It has no class, attendance or grading.
class TeacherMeeting {
  const TeacherMeeting({
    required this.title,
    this.startTime,
    this.endTime,
    this.room,
  });

  final String title;
  final String? startTime;
  final String? endTime;
  final String? room;

  factory TeacherMeeting.fromJson(Map<String, dynamic> json) => TeacherMeeting(
    title: _asString(json['title']) ?? '',
    startTime: _asString(json['start_time']),
    endTime: _asString(json['end_time']),
    room: _asString(json['room']),
  );
}

class LessonDay {
  const LessonDay({required this.lessons, this.meetings = const []});

  final List<TeacherLesson> lessons;
  final List<TeacherMeeting> meetings;
}

class OfflinePackInfo {
  const OfflinePackInfo({
    required this.preparedAt,
    required this.from,
    required this.through,
    required this.lessonCount,
  });

  final DateTime preparedAt;
  final DateTime from;
  final DateTime through;
  final int lessonCount;

  Map<String, dynamic> toJson() => {
    'preparedAt': preparedAt.toIso8601String(),
    'from': _dayKey(from),
    'through': _dayKey(through),
    'lessonCount': lessonCount,
  };

  factory OfflinePackInfo.fromJson(Map<String, dynamic> json) =>
      OfflinePackInfo(
        preparedAt: DateTime.parse(json['preparedAt'] as String),
        from: DateTime.parse(json['from'] as String),
        through: DateTime.parse(json['through'] as String),
        lessonCount: _asInt(json['lessonCount']) ?? 0,
      );

  static String _dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

abstract interface class OfflineLessonsPreparer {
  Future<OfflinePackInfo?> prepareOffline({
    int? academicYearId,
    bool force = false,
  });
  Future<OfflinePackInfo?> readOfflinePack();
}

/// A lesson the teacher graded recently, with its class average.
class RecentGrade {
  const RecentGrade({
    required this.lessonId,
    required this.classLabel,
    required this.subject,
    required this.average,
    this.groupId,
    this.subjectId,
  });

  final int lessonId;
  final String classLabel;
  final String subject;
  final double average;
  final int? groupId;
  final int? subjectId;

  factory RecentGrade.fromJson(Map<String, dynamic> json) => RecentGrade(
    lessonId: _asInt(json['lesson_id']) ?? 0,
    classLabel: _asString(json['class']) ?? '',
    subject: _asString(json['subject']) ?? '',
    average: _asDouble(json['average']) ?? 0,
    groupId: _asInt(json['group_id']),
    subjectId: _asInt(json['subject_id']),
  );
}

/// One period of the school day, in minutes since midnight.
class BellPeriod {
  const BellPeriod({
    required this.number,
    required this.start,
    required this.end,
  });

  final int number;
  final int start;
  final int end;
}

/// One student's row on a lesson's sheet.
class SheetStudent {
  SheetStudent({
    required this.studentId,
    required this.fullName,
    this.status,
    this.minutesLate,
    Map<String, int?>? scores,
    this.comment = '',
    this.importedScore,
    this.makeupScore,
    this.version = gradingVersion,
    this.pictureUrl,
  }) : scores = scores ?? {};

  /// The student's photo. The sheet doesn't carry it; it comes from the
  /// class's `/students` list.
  String? pictureUrl;

  /// 1 for rows graded before grading v2 (see lesson_grading.dart).
  final int version;

  final int studentId;
  final String fullName;
  String? status;
  int? minutesLate;
  final Map<String, int?> scores;
  String comment;
  final double? importedScore;
  final double? makeupScore;

  factory SheetStudent.fromJson(Map<String, dynamic> json) => SheetStudent(
    studentId: _asInt(json['student_id'])!,
    fullName: _asString(json['full_name']) ?? '',
    status: _asString(json['status']),
    minutesLate: _asInt(json['minutes_late']),
    scores: {
      for (final field in teacherScoreFields) field: _asInt(json[field]),
    },
    comment: _asString(json['comment']) ?? '',
    importedScore: _asDouble(json['imported_score']),
    makeupScore: _asDouble(json['makeup_score']),
    version: _asInt(json['grading_version']) ?? gradingVersion,
  );

  GradeDraft toDraft() => GradeDraft(
    status: status,
    minutesLate: minutesLate,
    scores: {...scores},
    comment: comment,
    importedScore: importedScore,
    version: version,
  );

  /// Records a mark the server accepted. Absence fixes every category at 0.
  void applyMark(String nextStatus, int? minutes) {
    status = nextStatus;
    minutesLate = nextStatus == statusLate ? minutes : null;
    if (!isGradable(nextStatus)) {
      for (final field in fieldsFor(version)) {
        scores[field] = 0;
      }
    }
  }
}

class LessonDetail {
  const LessonDetail({
    required this.id,
    this.subject,
    this.classLabel,
    this.date,
    this.startTime,
    this.endTime,
    this.room,
    this.status,
    this.cancelReason,
    this.groupIds = const [],
  });

  final int id;
  final String? subject;
  final String? classLabel;
  final DateTime? date;
  final String? startTime;
  final String? endTime;
  final String? room;
  final String? status;
  final String? cancelReason;
  final List<int> groupIds;

  bool get isCancelled => status == 'cancelled';

  factory LessonDetail.fromJson(Map<String, dynamic> json) {
    final many = json['group_ids'];
    final single = _asInt(json['group_id']);
    return LessonDetail(
      id: _asInt(json['id'])!,
      subject: _asString(json['subject']),
      classLabel: _asString(json['class_pair']),
      date: _asDate(json['date']),
      startTime: _asString(json['start_time']),
      endTime: _asString(json['end_time']),
      room: _asString(json['room']),
      status: _asString(json['status']),
      cancelReason: _asString(json['cancel_reason']),
      groupIds: many is List && many.isNotEmpty
          ? many.map(_asInt).whereType<int>().toList()
          : [?single],
    );
  }
}

class GradingSheet {
  const GradingSheet({required this.lesson, required this.students});

  final LessonDetail lesson;
  final List<SheetStudent> students;
}

enum UploadKind { attendance, grades, behavior }

/// The server answered and refused: retrying the same thing can't help.
class UploadRefused implements Exception {
  const UploadRefused(this.message);

  final String message;
}

/// No answer, a busy server, or an expired session: worth trying again.
class UploadRetryLater implements Exception {
  const UploadRetryLater(this.message);

  final String message;
}

class BehaviorReason {
  const BehaviorReason({required this.id, required this.label});

  final String id;
  final String label;

  factory BehaviorReason.fromJson(Map<String, dynamic> json) => BehaviorReason(
    id: json['id'].toString(),
    label: _asString(json['label']) ?? '',
  );
}

class BehaviorReasons {
  const BehaviorReasons({this.positive = const [], this.negative = const []});

  final List<BehaviorReason> positive;
  final List<BehaviorReason> negative;

  bool get isEmpty => positive.isEmpty && negative.isEmpty;

  List<BehaviorReason> of(String type) =>
      type == behaviorPositive ? positive : negative;
}

const behaviorPositive = 'positive';
const behaviorNegative = 'negative';

class BehaviorMark {
  const BehaviorMark({
    required this.id,
    required this.studentId,
    required this.type,
    this.reasonLabel,
    this.comment,
  });

  final String id;
  final String studentId;
  final String type;
  final String? reasonLabel;
  final String? comment;

  factory BehaviorMark.fromJson(Map<String, dynamic> json) => BehaviorMark(
    id: json['id'].toString(),
    studentId: json['studentId'].toString(),
    type: json['type'].toString(),
    reasonLabel: _asString(json['reasonLabel']),
    comment: _asString(json['comment']),
  );
}

/// A mark in the school's history, with who gave it and when.
class BehaviorHistoryEntry {
  const BehaviorHistoryEntry({
    required this.id,
    required this.studentName,
    required this.className,
    required this.type,
    this.reasonLabel,
    this.comment,
    this.authorName,
    this.createdAt,
  });

  final String id;
  final String studentName;
  final String className;
  final String type;
  final String? reasonLabel;
  final String? comment;
  final String? authorName;
  final DateTime? createdAt;

  factory BehaviorHistoryEntry.fromJson(Map<String, dynamic> json) =>
      BehaviorHistoryEntry(
        id: json['id'].toString(),
        studentName: _asString(json['studentName']) ?? '',
        className: _asString(json['className']) ?? '',
        type: json['type'].toString(),
        reasonLabel: _asString(json['reasonLabel']),
        comment: _asString(json['comment']),
        authorName: _asString(json['authorName']),
        createdAt: DateTime.tryParse(
          json['createdAt']?.toString() ?? '',
        )?.toLocal(),
      );
}

class BehaviorStudent {
  const BehaviorStudent({
    required this.id,
    required this.fullName,
    required this.className,
  });

  final String id;
  final String fullName;
  final String className;

  factory BehaviorStudent.fromJson(Map<String, dynamic> json) =>
      BehaviorStudent(
        id: json['id'].toString(),
        fullName: _asString(json['fullName']) ?? '',
        className: _asString(json['className']) ?? '',
      );
}

/// Every student who can be marked, and the caller's own classes.
class BehaviorRoster {
  const BehaviorRoster({
    this.students = const [],
    this.myClasses = const [],
    this.homeroomClass,
  });

  final List<BehaviorStudent> students;

  /// Homeroom first, then the classes they teach.
  final List<String> myClasses;
  final String? homeroomClass;
}

/// One bar of the statistics: a class or a week.
class BehaviorStatRow {
  const BehaviorStatRow({
    required this.label,
    required this.positive,
    required this.negative,
    required this.total,
  });

  final String label;
  final int positive;
  final int negative;
  final int total;
}

class BehaviorReasonCount {
  const BehaviorReasonCount({
    required this.id,
    required this.type,
    required this.total,
  });

  final String id;
  final String type;
  final int total;
}

class BehaviorStatistics {
  const BehaviorStatistics({
    this.total = 0,
    this.positive = 0,
    this.negative = 0,
    this.byClass = const [],
    this.byWeek = const [],
    this.byReason = const [],
  });

  final int total;
  final int positive;
  final int negative;
  final List<BehaviorStatRow> byClass;
  final List<BehaviorStatRow> byWeek;
  final List<BehaviorReasonCount> byReason;

  factory BehaviorStatistics.fromJson(Map<String, dynamic> json) {
    List<Map> rows(String key) =>
        json[key] is List ? (json[key] as List).whereType<Map>().toList() : [];
    BehaviorStatRow row(Map item, String labelKey) => BehaviorStatRow(
      label: item[labelKey]?.toString() ?? '',
      positive: _asInt(item['positive']) ?? 0,
      negative: _asInt(item['negative']) ?? 0,
      total: _asInt(item['total']) ?? 0,
    );
    final summary = json['summary'] is Map ? json['summary'] as Map : const {};
    return BehaviorStatistics(
      total: _asInt(summary['total']) ?? 0,
      positive: _asInt(summary['positive']) ?? 0,
      negative: _asInt(summary['negative']) ?? 0,
      byClass: [for (final r in rows('byClass')) row(r, 'className')],
      byWeek: [for (final r in rows('byWeek')) row(r, 'week')],
      byReason: [
        for (final r in rows('byReason'))
          BehaviorReasonCount(
            id: r['id'].toString(),
            type: r['type'].toString(),
            total: _asInt(r['total']) ?? 0,
          ),
      ],
    );
  }
}

abstract class LessonsRepository {
  /// The teacher's day, across every branch they work at.
  Future<LessonDay> getDay(DateTime date);

  /// The school day's periods. Empty when the bell schedule can't be read.
  /// With no [academicYearId], the last schedule kept on the phone.
  Future<List<BellPeriod>> getPeriods({
    int? academicYearId,
    required DateTime date,
  });

  Future<GradingSheet> getSheet(int lessonId);

  /// The teacher's latest graded lessons, newest first.
  Future<List<RecentGrade>> getRecentGrades({int limit = 3});

  /// Sends one save kept on the phone. Throws [UploadRefused] when the server
  /// says no; anything else means it can be tried again.
  Future<void> upload(UploadKind kind, int lessonId, Map<String, dynamic> body);

  /// The classes and subjects the teacher has a gradebook for. With no
  /// [academicYearId], the latest year or what's kept on the phone.
  Future<List<GradebookPair>> getMyGradebooks({int? academicYearId});

  Future<Gradebook> getGradebook(int groupId, int subjectId);

  Future<BehaviorReasons> getBehaviorReasons();

  Future<BehaviorRoster> getBehaviorRoster();

  Future<List<BehaviorHistoryEntry>> getBehaviorHistory();

  /// [from] and [to] are YYYY-MM-DD; null leaves that side open.
  Future<BehaviorStatistics> getBehaviorStatistics({String? from, String? to});

  Future<List<BehaviorMark>> getBehaviorMarks(int lessonId);

  /// Forgets what's kept for offline use. Sign-out calls this.
  Future<void> clearOffline();
}
