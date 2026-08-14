// Point report domain — the aggregation the web app does inside
// `usePointReportData`, extracted into plain Dart so it can be tested without
// pumping a widget.

/// Which bucket a point falls into within a subject.
enum PointCategory { homework, performance }

/// Attendance penalties are recorded as points too, but they belong to the
/// student rather than to any subject, so they are counted separately.
enum AttendancePenalty { late, absent, excused }

/// How the reporting period is chosen.
enum PointReportDateMode { weekly, single, range }

/// One row from `GET /student-points` (docs/staff/points.md).
class StudentPoint {
  const StudentPoint({
    required this.id,
    required this.personId,
    required this.points,
    this.subjectName,
    this.reason,
    this.date,
  });

  final int id;

  /// `/student-points` keys by person, not by enrollment — see
  /// [StudentEntry.personId].
  final int personId;

  final double points;
  final String? subjectName;
  final String? reason;
  final DateTime? date;

  /// Homework / performance, read from `reason`. Matches the web's
  /// `resolvePointCategory`: a substring test, because the API returns free
  /// text like "Homework check" or "Class performance".
  PointCategory? get category {
    final reason = this.reason?.trim().toLowerCase();
    if (reason == null || reason.isEmpty) {
      return null;
    }
    if (reason.contains('home')) {
      return PointCategory.homework;
    }
    if (reason.contains('perform')) {
      return PointCategory.performance;
    }
    return null;
  }

  /// Mirrors the web's `resolveAttendancePenaltyType`, including the
  /// `lateness`/`absence` spellings the API also uses.
  AttendancePenalty? get penalty {
    switch (reason?.trim().toLowerCase()) {
      case 'lateness':
      case 'late':
        return AttendancePenalty.late;
      case 'absence':
      case 'absent':
        return AttendancePenalty.absent;
      case 'excused':
        return AttendancePenalty.excused;
      default:
        return null;
    }
  }

  factory StudentPoint.fromJson(Map<String, dynamic> json) {
    return StudentPoint(
      id: _asInt(json['id']) ?? -1,
      personId: _asInt(json['person_id'] ?? json['personId']) ?? -1,
      points: _asDouble(json['points']),
      subjectName: _asString(json['subject_name'] ?? json['subject']),
      reason: _asString(json['reason']),
      date: _asDate(json['date']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Non-numeric point values count as zero rather than throwing — one bad row
  /// must not blank the whole report.
  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  static String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  static DateTime? _asDate(dynamic value) {
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value.trim());
      if (parsed != null) {
        return DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    return null;
  }
}

/// An inclusive day range, normalised so comparisons ignore the time of day.
class DateRange {
  DateRange(DateTime start, DateTime end)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day);

  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return !day.isBefore(start) && !day.isAfter(end);
  }

  /// The Monday–Sunday week containing [date]. The web pins
  /// `weekStartsOn: 1`, so the two apps agree on where a week begins.
  factory DateRange.weekOf(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final monday = day.subtract(Duration(days: day.weekday - DateTime.monday));
    return DateRange(monday, monday.add(const Duration(days: 6)));
  }

  factory DateRange.singleDay(DateTime date) => DateRange(date, date);

  /// The week before this range starts — the "Pr. week" column on the web.
  DateRange get previousWeek =>
      DateRange.weekOf(start.subtract(const Duration(days: 7)));
}

/// Per-subject totals for one student.
class SubjectTotals {
  const SubjectTotals({
    this.homework = 0,
    this.performance = 0,
    this.total = 0,
  });

  final double homework;
  final double performance;

  /// Every point on the subject, including those in neither bucket — the web
  /// adds uncategorised points to the total but to no category.
  final double total;

  SubjectTotals _adding(double value, PointCategory? category) {
    return SubjectTotals(
      homework: homework + (category == PointCategory.homework ? value : 0),
      performance:
          performance + (category == PointCategory.performance ? value : 0),
      total: total + value,
    );
  }
}

/// Everything the report shows for one student over the chosen period.
class StudentPointTotals {
  const StudentPointTotals({
    this.subjects = const {},
    this.penalties = const {},
    this.previousWeekTotal = 0,
  });

  /// Subject name → its buckets.
  final Map<String, SubjectTotals> subjects;

  /// Attendance penalties, which sit outside any subject.
  final Map<AttendancePenalty, double> penalties;

  final double previousWeekTotal;

  double get subjectTotal =>
      subjects.values.fold(0, (sum, value) => sum + value.total);

  double get penaltyTotal =>
      penalties.values.fold(0, (sum, value) => sum + value);

  /// What the "Total" column shows: subject points plus attendance penalties,
  /// which are already negative.
  double get total => subjectTotal + penaltyTotal;

  bool get isEmpty => subjects.isEmpty && penalties.isEmpty;
}

/// The aggregated report — the result of bucketing raw points by student.
class PointReport {
  const PointReport({required this.byPersonId, required this.subjects});

  final Map<int, StudentPointTotals> byPersonId;

  /// Every subject seen in the period, sorted, so the breakdown has a stable
  /// order across students.
  final List<String> subjects;

  StudentPointTotals totalsFor(int personId) =>
      byPersonId[personId] ?? const StudentPointTotals();

  /// Buckets [points] into per-student totals for [range], counting the week
  /// before [range] separately for the previous-week comparison.
  ///
  /// Points outside both windows are ignored, which is what lets the caller
  /// fetch one span covering both and slice it here.
  factory PointReport.aggregate({
    required Iterable<StudentPoint> points,
    required DateRange range,
  }) {
    final previous = range.previousWeek;

    final subjectsByStudent = <int, Map<String, SubjectTotals>>{};
    final penaltiesByStudent = <int, Map<AttendancePenalty, double>>{};
    final previousTotals = <int, double>{};
    final subjectNames = <String>{};

    for (final point in points) {
      final date = point.date;
      if (date == null) {
        continue;
      }

      if (previous.contains(date)) {
        previousTotals[point.personId] =
            (previousTotals[point.personId] ?? 0) + point.points;
      }

      if (!range.contains(date)) {
        continue;
      }

      final penalty = point.penalty;
      if (penalty != null) {
        final forStudent = penaltiesByStudent.putIfAbsent(
          point.personId,
          () => <AttendancePenalty, double>{},
        );
        forStudent[penalty] = (forStudent[penalty] ?? 0) + point.points;
        continue;
      }

      final subject = point.subjectName;
      if (subject == null) {
        continue;
      }

      subjectNames.add(subject);
      final forStudent = subjectsByStudent.putIfAbsent(
        point.personId,
        () => <String, SubjectTotals>{},
      );
      forStudent[subject] = (forStudent[subject] ?? const SubjectTotals())
          ._adding(point.points, point.category);
    }

    final personIds = <int>{
      ...subjectsByStudent.keys,
      ...penaltiesByStudent.keys,
      ...previousTotals.keys,
    };

    return PointReport(
      byPersonId: {
        for (final personId in personIds)
          personId: StudentPointTotals(
            subjects: subjectsByStudent[personId] ?? const {},
            penalties: penaltiesByStudent[personId] ?? const {},
            previousWeekTotal: previousTotals[personId] ?? 0,
          ),
      },
      subjects: subjectNames.toList()..sort(),
    );
  }
}

abstract class PointReportRepository {
  /// Every point for [groupId] between [start] and [end] inclusive, following
  /// pagination to the end.
  Future<List<StudentPoint>> getPoints(
    String token, {
    required int groupId,
    required DateTime start,
    required DateTime end,
  });
}

/// Title-cases a raw subject key for display, with the same override the web
/// applies so "m_tongue" doesn't render as "M Tongue".
String formatSubjectLabel(String value) {
  final raw = value.trim();
  if (raw.isEmpty) {
    return '';
  }

  final normalized = raw.toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  if (normalized == 'm_tongue' || normalized == 'mother_tongue') {
    return 'M.Toungue';
  }

  return raw
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .split(' ')
      .map((token) {
        if (token.isEmpty) return token;
        // Leave acronyms alone.
        if (token == token.toUpperCase()) return token;
        return token[0].toUpperCase() + token.substring(1).toLowerCase();
      })
      .join(' ');
}

/// Formats a point value for display.
///
/// Whole numbers lose the trailing `.0`; halves keep one decimal. Positives
/// carry an explicit `+` so a gain never reads as a loss at a glance — the
/// shared image goes to parents, where an ambiguous `5` would be worse than
/// useless.
String formatPoints(double value) {
  final rounded = (value * 10).roundToDouble() / 10;
  final text = rounded == rounded.roundToDouble()
      ? rounded.toStringAsFixed(0)
      : rounded.toStringAsFixed(1);
  return rounded > 0 ? '+$text' : text;
}

/// A column the report can show. Subject columns are keyed `subject:<name>`,
/// matching the web so the two apps describe a selection the same way.
class PointReportColumn {
  const PointReportColumn({required this.key, required this.label});

  final String key;
  final String label;

  static const no = 'no';
  static const id = 'id';
  static const name = 'name';
  static const previousWeek = 'pr-week';

  /// One key covers Late and Absent together, as on the web.
  static const attendance = 'attendance';
  static const total = 'total';

  static const subjectPrefix = 'subject:';

  static String subjectKey(String subject) => '$subjectPrefix$subject';

  static bool isSubject(String key) => key.startsWith(subjectPrefix);

  static String subjectOf(String key) => key.substring(subjectPrefix.length);
}

/// Which columns are showing, and the rules for keeping that choice sane as the
/// available subjects change from week to week.
class PointReportColumns {
  const PointReportColumns(this.selected);

  final Set<String> selected;

  /// Hidden by default: teachers share these tables with parents, and the web's
  /// own default screenshot hides the name column. Everything else starts on.
  static const hiddenByDefault = {PointReportColumn.name};

  bool shows(String key) => selected.contains(key);

  bool get showsNo => shows(PointReportColumn.no);
  bool get showsId => shows(PointReportColumn.id);
  bool get showsName => shows(PointReportColumn.name);
  bool get showsPreviousWeek => shows(PointReportColumn.previousWeek);
  bool get showsAttendance => shows(PointReportColumn.attendance);
  bool get showsTotal => shows(PointReportColumn.total);

  /// The subjects to render, in the order [available] lists them.
  List<String> visibleSubjects(List<String> available) => [
    for (final subject in available)
      if (shows(PointReportColumn.subjectKey(subject))) subject,
  ];

  /// Every column the picker offers for [subjects], in table order.
  static List<PointReportColumn> optionsFor(List<String> subjects) => [
    const PointReportColumn(key: PointReportColumn.no, label: 'No.'),
    const PointReportColumn(key: PointReportColumn.id, label: 'ID'),
    const PointReportColumn(key: PointReportColumn.name, label: 'Ism/Familya'),
    const PointReportColumn(
      key: PointReportColumn.previousWeek,
      label: 'Pr-week',
    ),
    const PointReportColumn(
      key: PointReportColumn.attendance,
      label: 'Late/Absent',
    ),
    for (final subject in subjects)
      PointReportColumn(
        key: PointReportColumn.subjectKey(subject),
        label: formatSubjectLabel(subject),
      ),
    const PointReportColumn(key: PointReportColumn.total, label: 'Total'),
  ];

  /// The starting selection: everything except [hiddenByDefault].
  factory PointReportColumns.defaults(List<String> subjects) {
    return PointReportColumns({
      for (final option in optionsFor(subjects))
        if (!hiddenByDefault.contains(option.key)) option.key,
    });
  }

  PointReportColumns toggle(String key) {
    final next = {...selected};
    if (!next.remove(key)) {
      next.add(key);
    }
    return PointReportColumns(next);
  }

  PointReportColumns selectAll(List<String> subjects) => PointReportColumns({
    for (final option in optionsFor(subjects)) option.key,
  });

  PointReportColumns clearAll() => const PointReportColumns({});

  /// Folds newly-available columns into an existing choice.
  ///
  /// A subject that appears on next week's timetable should show up rather than
  /// stay hidden because it did not exist when the choice was made; a subject
  /// that has gone away is forgotten. Columns the user deliberately switched
  /// off — recorded in [deselected] — stay off.
  PointReportColumns reconcile(
    List<String> subjects, {
    Set<String> deselected = const {},
  }) {
    final options = optionsFor(subjects).map((option) => option.key).toSet();
    return PointReportColumns({
      for (final key in options)
        if (selected.contains(key) || !deselected.contains(key)) key,
    });
  }
}
