int? _int(dynamic value) => value is num
    ? value.toInt()
    : value is String
    ? num.tryParse(value)?.toInt()
    : null;

double? _double(dynamic value) => value is num
    ? value.toDouble()
    : value is String
    ? double.tryParse(value)
    : null;

/// One class and subject a teacher has a gradebook for.
class GradebookPair {
  const GradebookPair({
    required this.groupId,
    required this.className,
    required this.subjectId,
    required this.subject,
    this.teaches = false,
    this.homeroom = false,
  });

  final int groupId;
  final String className;
  final int subjectId;
  final String subject;
  final bool teaches;
  final bool homeroom;

  factory GradebookPair.fromJson(Map<String, dynamic> json) => GradebookPair(
    groupId: _int(json['group_id']) ?? 0,
    className: json['class']?.toString() ?? '',
    subjectId: _int(json['subject_id']) ?? 0,
    subject: json['subject']?.toString() ?? '',
    teaches: json['teaches'] == true,
    homeroom: json['homeroom'] == true,
  );
}

class GradebookClass {
  const GradebookClass({
    required this.id,
    required this.name,
    required this.teaches,
    required this.homeroom,
  });

  final int id;
  final String name;
  final bool teaches;
  final bool homeroom;
}

/// Classes they teach first, then their homeroom class.
List<GradebookClass> gradebookClasses(List<GradebookPair> pairs) {
  final byId = <int, GradebookClass>{};
  for (final pair in pairs) {
    final seen = byId[pair.groupId];
    byId[pair.groupId] = GradebookClass(
      id: pair.groupId,
      name: pair.className,
      teaches: pair.teaches || (seen?.teaches ?? false),
      homeroom: pair.homeroom || (seen?.homeroom ?? false),
    );
  }
  final all = byId.values.toList();
  return [...all.where((c) => c.teaches), ...all.where((c) => !c.teaches)];
}

/// One class's subjects: the ones they teach first, then by name.
List<GradebookPair> gradebookSubjects(List<GradebookPair> pairs, int groupId) {
  return pairs.where((pair) => pair.groupId == groupId).toList()..sort((a, b) {
    if (a.teaches != b.teaches) return a.teaches ? -1 : 1;
    return a.subject.compareTo(b.subject);
  });
}

class GradebookStudent {
  const GradebookStudent({
    required this.studentId,
    required this.personId,
    required this.name,
  });

  final int studentId;
  final int personId;
  final String name;

  /// "Abdisattarov S." — the surname and the first name's initial.
  String get shortName {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts[1].isEmpty) return parts.first;
    return '${parts[0]} ${parts[1].substring(0, 1)}.';
  }
}

class GradebookLesson {
  const GradebookLesson({
    required this.lessonId,
    required this.date,
    required this.startTime,
  });

  final int lessonId;

  /// YYYY-MM-DD.
  final String date;
  final String startTime;
}

class GradebookExam {
  const GradebookExam({
    required this.examId,
    required this.period,
    required this.date,
    required this.maxScore,
  });

  final int examId;
  final String period;
  final String date;
  final double maxScore;

  /// "Q1", "2W", "Sep": short enough for a phone column.
  String get shortPeriod {
    final name = period.toLowerCase();
    if (name.contains('quarter')) return 'Q1';
    if (RegExp(r'2[- ]?week').hasMatch(name)) return '2W';
    if (name.contains('sep')) return 'Sep';
    return period.length > 4 ? period.substring(0, 4) : period;
  }
}

class GradebookGrade {
  const GradebookGrade({
    required this.score,
    this.comment,
    this.imported = false,
  });

  final double score;
  final String? comment;
  final bool imported;
}

class ExamCell {
  const ExamCell({required this.score, required this.percent});

  final double score;
  final double percent;
}

class GradebookRow {
  const GradebookRow({
    required this.student,
    required this.daily,
    required this.exams,
    required this.dailyAverage,
    required this.examAverage,
  });

  final GradebookStudent student;
  final List<GradebookGrade?> daily;
  final List<ExamCell?> exams;
  final double? dailyAverage;
  final double? examAverage;
}

double _round1(double value) => (value * 10).roundToDouble() / 10;

double? _mean(Iterable<double> values) {
  if (values.isEmpty) return null;
  return _round1(values.reduce((a, b) => a + b) / values.length);
}

/// What the table shows for one month, or for the whole year.
class GradebookView {
  const GradebookView({
    required this.lessons,
    required this.exams,
    required this.rows,
    required this.classDaily,
    required this.classExams,
    required this.classDailyAverage,
    required this.classExamAverage,
  });

  final List<GradebookLesson> lessons;
  final List<GradebookExam> exams;
  final List<GradebookRow> rows;
  final List<double?> classDaily;
  final List<double?> classExams;
  final double? classDailyAverage;
  final double? classExamAverage;
}

/// One class in one subject, like a paper gradebook.
class Gradebook {
  const Gradebook({
    this.students = const [],
    this.lessons = const [],
    this.exams = const [],
    this.grades = const {},
    this.examResults = const {},
  });

  final List<GradebookStudent> students;
  final List<GradebookLesson> lessons;
  final List<GradebookExam> exams;

  /// student id → lesson id → grade.
  final Map<int, Map<int, GradebookGrade>> grades;

  /// person id → exam id → score.
  final Map<int, Map<int, double>> examResults;

  bool get isEmpty => students.isEmpty || (lessons.isEmpty && exams.isEmpty);

  factory Gradebook.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> rows(String key) => json[key] is List
        ? (json[key] as List)
              .whereType<Map>()
              .map(Map<String, dynamic>.from)
              .toList()
        : const [];

    final grades = <int, Map<int, GradebookGrade>>{};
    final rawGrades = json['grades'];
    if (rawGrades is Map) {
      rawGrades.forEach((student, lessons) {
        final studentId = _int(student);
        if (studentId == null || lessons is! Map) return;
        lessons.forEach((lesson, grade) {
          final lessonId = _int(lesson);
          final score = grade is Map ? _double(grade['score']) : null;
          if (lessonId == null || score == null) return;
          final comment = (grade as Map)['comment']?.toString();
          (grades[studentId] ??= {})[lessonId] = GradebookGrade(
            score: score,
            comment: comment == null || comment.isEmpty ? null : comment,
            imported: grade['imported'] == true,
          );
        });
      });
    }

    final results = <int, Map<int, double>>{};
    final rawResults = json['exam_results'];
    if (rawResults is Map) {
      rawResults.forEach((person, exams) {
        final personId = _int(person);
        if (personId == null || exams is! Map) return;
        exams.forEach((exam, score) {
          final examId = _int(exam);
          final value = _double(score);
          if (examId != null && value != null) {
            (results[personId] ??= {})[examId] = value;
          }
        });
      });
    }

    return Gradebook(
      students: [
        for (final row in rows('students'))
          GradebookStudent(
            studentId: _int(row['student_id']) ?? 0,
            personId: _int(row['person_id']) ?? 0,
            name: row['name']?.toString() ?? '',
          ),
      ],
      lessons: [
        for (final row in rows('lessons'))
          GradebookLesson(
            lessonId: _int(row['lesson_id']) ?? 0,
            date: row['date']?.toString() ?? '',
            startTime: row['start_time']?.toString() ?? '',
          ),
      ],
      exams: [
        for (final row in rows('exams'))
          GradebookExam(
            examId: _int(row['exam_id']) ?? 0,
            period: row['period']?.toString() ?? '',
            date: row['date']?.toString() ?? '',
            maxScore: _double(row['max_score']) ?? 0,
          ),
      ],
      grades: grades,
      examResults: results,
    );
  }

  /// The "YYYY-MM" months that have a lesson or an exam, oldest first.
  List<String> get months {
    final keys = <String>{
      for (final lesson in lessons)
        if (lesson.date.length >= 7) lesson.date.substring(0, 7),
      for (final exam in exams)
        if (exam.date.length >= 7) exam.date.substring(0, 7),
    };
    return keys.toList()..sort();
  }

  GradebookView view({String? month, bool sortByAverage = false}) {
    bool inMonth(String date) => month == null || date.startsWith(month);
    final shownLessons = lessons.where((l) => inMonth(l.date)).toList();
    final shownExams = exams.where((e) => inMonth(e.date)).toList();

    final rows = [
      for (final student in students)
        () {
          final daily = [
            for (final lesson in shownLessons)
              grades[student.studentId]?[lesson.lessonId],
          ];
          final examCells = [
            for (final exam in shownExams)
              () {
                final score = examResults[student.personId]?[exam.examId];
                return score == null || exam.maxScore <= 0
                    ? null
                    : ExamCell(
                        score: score,
                        percent: _round1(score / exam.maxScore * 100),
                      );
              }(),
          ];
          return GradebookRow(
            student: student,
            daily: daily,
            exams: examCells,
            dailyAverage: _mean(daily.nonNulls.map((g) => g.score)),
            examAverage: _mean(examCells.nonNulls.map((e) => e.percent)),
          );
        }(),
    ];
    if (sortByAverage) {
      rows.sort(
        (a, b) => (b.dailyAverage ?? -1).compareTo(a.dailyAverage ?? -1),
      );
    }

    return GradebookView(
      lessons: shownLessons,
      exams: shownExams,
      rows: rows,
      classDaily: [
        for (var i = 0; i < shownLessons.length; i++)
          _mean(rows.map((r) => r.daily[i]?.score).nonNulls),
      ],
      classExams: [
        for (var i = 0; i < shownExams.length; i++)
          _mean(rows.map((r) => r.exams[i]?.percent).nonNulls),
      ],
      classDailyAverage: _mean(rows.map((r) => r.dailyAverage).nonNulls),
      classExamAverage: _mean(rows.map((r) => r.examAverage).nonNulls),
    );
  }
}
