/// Daily score rules, the same as the web's `gradingUtils.js` and the backend's
/// `lesson-grading.ts`, so a row can show its score while the teacher taps. The
/// server stays the authority: the sheet is replaced with its answer on save.
library;

/// Grading v2 (2026-11): attendance is no longer a category. Being on time
/// gives nothing, being late takes points off, and the teacher grades five
/// categories adding up to 100. Rows graded before the change carry
/// `grading_version: 1` and keep the old math.
const gradingVersion = 2;

/// Most a late student can lose (45+ minutes late).
const maxLateDeduction = 20;

/// v1: every category, attendance included, was out of 20.
const v1CategoryMax = 20;
const lessonMinutes = 45;
const lowScoreThreshold = 40;

const materialsScore = 'materials_score';
const homeworkDoneScore = 'homework_done_score';
const homeworkScore = 'homework_score'; // accuracy
const activityScore = 'activity_score';
const notesScore = 'notes_score';

/// The five categories the teacher fills in (20 + 10 + 30 + 20 + 20 = 100).
const teacherScoreFields = [
  materialsScore,
  homeworkDoneScore,
  homeworkScore,
  activityScore,
  notesScore,
];

const categoryMax = {
  materialsScore: 20,
  homeworkDoneScore: 10,
  homeworkScore: 30,
  activityScore: 20,
  notesScore: 20,
};

/// What the header checkbox gives everyone: full marks. A sheet opens empty; nothing is filled in by itself.
const categoryDefaults = {
  materialsScore: 20,
  homeworkDoneScore: 10,
  homeworkScore: 30,
  activityScore: 20,
  notesScore: 20,
};

const _quick20 = [20, 15, 10, 5, 0];
const _quickValues = {
  materialsScore: _quick20,
  homeworkDoneScore: [10, 5, 0],
  homeworkScore: [30, 25, 20, 15, 10, 0],
  activityScore: _quick20,
  notesScore: _quick20,
};

/// Whether [field] is graded in a row of [version]; v1 had no "homework brought".
bool appliesTo(String field, int version) =>
    version != 1 || field != homeworkDoneScore;

/// The fields a row of [version] grades.
List<String> fieldsFor(int version) =>
    teacherScoreFields.where((f) => appliesTo(f, version)).toList();

int maxFor(String field, int version) =>
    version == 1 ? v1CategoryMax : categoryMax[field]!;

int startFor(String field, int version) {
  final start = categoryDefaults[field]!;
  return version == 1 && start > v1CategoryMax ? v1CategoryMax : start;
}

List<int> quickValuesFor(String field, int version) =>
    version == 1 ? _quick20 : _quickValues[field]!;

const statusPresent = 'present';
const statusLate = 'late';
const statusAbsent = 'absent';
const statusExcused = 'excused';

double _round1(double value) => (value * 10).round() / 10;

/// v2: on time → 0; late → −20 × minutes / 45 (45+ → −20); absent or
/// excused → 0.
double? lateDeduction(String? status, int? minutesLate) {
  if (status == statusLate) {
    final late = (minutesLate ?? 0).clamp(0, lessonMinutes);
    final points = _round1(maxLateDeduction * late / lessonMinutes);
    return points == 0 ? 0 : -points;
  }
  if (status == statusPresent ||
      status == statusAbsent ||
      status == statusExcused) {
    return 0;
  }
  return null;
}

/// v1: present → 20; late → 20 × (45 − minutes) / 45; absent or excused → 0.
double? v1AttendanceScore(String? status, int? minutesLate) {
  if (status == statusPresent) return v1CategoryMax.toDouble();
  if (status == statusLate) {
    final late = (minutesLate ?? 0).clamp(0, lessonMinutes);
    return _round1(v1CategoryMax * (lessonMinutes - late) / lessonMinutes);
  }
  if (status == statusAbsent || status == statusExcused) return 0;
  return null;
}

/// What the attendance mark adds (v1) or takes off (v2).
double? attendancePart(String? status, int? minutesLate, int version) =>
    version == 1
    ? v1AttendanceScore(status, minutesLate)
    : lateDeduction(status, minutesLate);

/// Only present and late students are graded by the teacher.
bool isGradable(String? status) =>
    status == statusPresent || status == statusLate;

/// One student's editable row.
class GradeDraft {
  GradeDraft({
    this.status,
    this.minutesLate,
    Map<String, int?>? scores,
    this.comment = '',
    this.importedScore,
    this.stashedScores,
    this.version = gradingVersion,
  }) : scores = scores ?? {};

  /// 1 for rows graded before grading v2, which keep the old math.
  final int version;

  String? status;
  int? minutesLate;
  final Map<String, int?> scores;
  String comment;

  /// A mark imported from EduPage, standing in until a teacher grades.
  final double? importedScore;

  /// Scores kept aside while marked absent, so undoing a mis-tap restores them.
  Map<String, int?>? stashedScores;

  GradeDraft copy() => GradeDraft(
    status: status,
    minutesLate: minutesLate,
    scores: {...scores},
    comment: comment,
    importedScore: importedScore,
    stashedScores: stashedScores == null ? null : {...stashedScores!},
    version: version,
  );

  bool get hasTeacherScores =>
      teacherScoreFields.any((field) => scores[field] != null);

  /// Every category that applies to this row has a score.
  bool get isComplete =>
      fieldsFor(version).every((field) => scores[field] != null);

  /// Some categories scored, others not: the teacher is still grading it.
  bool get isPartlyGraded =>
      isGradable(status) && hasTeacherScores && !isComplete;

  /// The categories added up, empty ones counting as 0, minus the lateness
  /// deduction (never below 0).
  double get total {
    if (importedScore != null && !hasTeacherScores) return importedScore!;
    final attendance = attendancePart(status, minutesLate, version) ?? 0;
    final teacher = teacherScoreFields.fold<int>(
      0,
      (sum, field) => sum + (scores[field] ?? 0),
    );
    final sum = _round1(attendance + teacher);
    return sum < 0 ? 0 : sum;
  }

  /// The server rejects a graded score under 40 without a comment. Asked
  /// only once every category is scored, not while the teacher is going.
  bool get needsComment =>
      isGradable(status) &&
      isComplete &&
      total < lowScoreThreshold &&
      comment.trim().isEmpty;

  /// Present, with every empty category at its usual mark: what ticking all
  /// the header checkboxes gives a student. The sheet never does this alone.
  void prefill() {
    if (status == null) {
      status = statusPresent;
      minutesLate = null;
    }
    if (isGradable(status)) {
      for (final field in fieldsFor(version)) {
        scores[field] ??= startFor(field, version);
      }
    }
  }

  /// Applies an attendance mark. [minutes] is ignored unless [keepMinutes] is
  /// false, which is how the late picker sets or clears them.
  void mark(String next, {int? minutes, bool keepMinutes = true}) {
    final was = status;
    final wasGradable = isGradable(was);
    status = next;
    if (next != statusLate) {
      minutesLate = null;
    } else if (!keepMinutes) {
      minutesLate = minutes;
    }

    if (!isGradable(next)) {
      if (wasGradable) {
        stashedScores = {
          for (final field in teacherScoreFields) field: scores[field],
        };
      }
      for (final field in fieldsFor(version)) {
        scores[field] = 0;
      }
    } else if (was != null && !wasGradable) {
      for (final field in fieldsFor(version)) {
        final kept = stashedScores;
        scores[field] = kept?[field];
      }
      stashedScores = null;
    }
  }

  /// Back to "not marked" (undoing a mark made here): scores kept aside by
  /// an absence come back, and an absence's fixed 0s are emptied.
  void clearMark() {
    final wasGradable = isGradable(status);
    status = null;
    minutesLate = null;
    if (!wasGradable) {
      for (final field in teacherScoreFields) {
        scores[field] = stashedScores?[field];
      }
    }
    stashedScores = null;
  }

  bool attendanceDiffers(GradeDraft other) =>
      status != other.status ||
      (status == statusLate && minutesLate != other.minutesLate);

  bool gradesDiffer(GradeDraft other) =>
      teacherScoreFields.any((f) => scores[f] != other.scores[f]) ||
      comment.trim() != other.comment.trim();
}

/// When teachers lose write access: 3 days after the lesson ends, and never
/// past the Saturday 08:00 that closes the week's grading.
DateTime? editWindowClosesAt(DateTime? date, String? endTime) {
  if (date == null) return null;
  final parts = (endTime ?? '23:59:59').split(':');
  int part(int index, int fallback) =>
      index < parts.length ? int.tryParse(parts[index]) ?? fallback : fallback;
  final ends = DateTime(
    date.year,
    date.month,
    date.day,
    part(0, 23),
    part(1, 59),
    part(2, 59),
  );
  final threeDays = ends.add(const Duration(days: 3));
  final daysToSaturday = (DateTime.saturday - ends.weekday + 7) % 7;
  var saturday = DateTime(ends.year, ends.month, ends.day + daysToSaturday, 8);
  if (!saturday.isAfter(ends)) {
    saturday = DateTime(saturday.year, saturday.month, saturday.day + 7, 8);
  }
  return saturday.isBefore(threeDays) ? saturday : threeDays;
}

/// 72, or 16.5 — never 72.0.
String formatScore(num value) => value == value.roundToDouble()
    ? '${value.round()}'
    : value.toStringAsFixed(1);
