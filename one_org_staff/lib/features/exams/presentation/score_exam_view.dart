import 'package:flutter/material.dart';

import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/exams/domain/exams_repository.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';

import 'exam_common.dart';
import 'exam_grading_view.dart';
import 'exams_page.dart';

/// "Score the exam" — a port of the web's `ExamsOfClasses`.
///
/// Three steps, same as the web: pick an exam period, pick an exam for a class
/// you're timetabled to teach its subject to (whoever created it — co-teachers
/// share exams), then grade that class on [ExamGradingView]. A subgroup
/// teacher can only score their subgroup.
class ScoreExamView extends StatefulWidget {
  const ScoreExamView({
    super.key,
    required this.api,
    required this.onBack,
    required this.onUnsavedGuardChanged,
  });

  final ExamsApi api;
  final VoidCallback onBack;

  /// Hands the page above a check to run before it navigates away — non-null
  /// only while the grading sheet holds unsaved edits.
  final ValueChanged<Future<bool> Function()?> onUnsavedGuardChanged;

  @override
  State<ScoreExamView> createState() => _ScoreExamViewState();
}

class _ScoreExamViewState extends State<ScoreExamView> {
  late Future<ScoreExamData> _dataFuture;

  ExamPeriod? _selectedPeriod;
  _GradingTarget? _target;

  final _gradingKey = GlobalKey<ExamGradingViewState>();

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  @override
  void dispose() {
    widget.onUnsavedGuardChanged(null);
    super.dispose();
  }

  Future<ScoreExamData> _load() async {
    final api = widget.api;
    final academicYearId = await api.resolveAcademicYearId();

    Future<List<T>> optional<T>(Future<List<T>> future) =>
        future.catchError((Object _) => <T>[]);

    final results = await Future.wait([
      api.loadExams(),
      api.loadExamPeriods(academicYearId: academicYearId),
      api.loadProfile(),
      optional(api.loadSubjects()),
      optional(api.loadGroups(academicYearId: academicYearId)),
      optional(api.loadTimetable(academicYearId: academicYearId)),
    ]);

    final myUserId = (results[2] as AppUserProfile).id;
    final timetable = results[5] as List<TimetableLesson>;

    // Who is in each of the teacher's subgroups, by division.
    final subgroupStudents = <String, Set<int>>{};
    final loadDivision = api.loadDivision;
    if (loadDivision != null) {
      final divisionIds = {
        for (final lesson in timetable)
          if (lesson.isTaughtBy(myUserId) &&
              lesson.subgroupId != null &&
              lesson.divisionId != null)
            lesson.divisionId!,
      };
      final divisions = await Future.wait([
        for (final id in divisionIds)
          loadDivision(id).catchError((Object _) => <String, dynamic>{}),
      ]);
      for (final division in divisions) {
        for (final subgroup in division['subgroups'] as List? ?? const []) {
          if (subgroup is! Map) continue;
          for (final student in subgroup['students'] as List? ?? const []) {
            if (student is! Map) continue;
            final studentId = student['student_id'];
            final groupId = student['group_id'];
            if (studentId is! num || groupId is! num) continue;
            subgroupStudents
                .putIfAbsent('${subgroup['id']}:${groupId.toInt()}', () => {})
                .add(studentId.toInt());
          }
        }
      }
    }

    final data = ScoreExamData(
      exams: results[0] as List<Exam>,
      periods: results[1] as List<ExamPeriod>,
      myUserId: myUserId,
      timetable: timetable,
      subgroupStudents: subgroupStudents,
      subjectNames: {
        for (final subject in results[3] as List<SubjectEntry>)
          subject.id: subject.name,
      },
      groupNames: {
        for (final group in results[4] as List<GroupEntry>)
          group.id: group.classPair,
      },
    );

    return data;
  }

  void _retry() {
    setState(() {
      _selectedPeriod = null;
      _target = null;
      _dataFuture = _load();
    });
  }

  /// Runs the grading sheet's own discard prompt, if one is open and dirty.
  Future<bool> _confirmLeaveGrading() async {
    return await _gradingKey.currentState?.confirmDiscard() ?? true;
  }

  void _onGradingDirtyChanged(bool dirty) {
    widget.onUnsavedGuardChanged(dirty ? _confirmLeaveGrading : null);
  }

  Future<void> _closeGrading() async {
    if (!await _confirmLeaveGrading()) {
      return;
    }
    if (!mounted) {
      return;
    }
    widget.onUnsavedGuardChanged(null);
    setState(() => _target = null);
  }

  void _back() {
    if (_target != null) {
      _closeGrading();
      return;
    }
    if (_selectedPeriod != null) {
      setState(() => _selectedPeriod = null);
      return;
    }
    widget.onBack();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ScoreExamData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExamHeader(
                title: 'Exam Results',
                subtitle: 'Select an exam period to view and grade exams',
                onBack: widget.onBack,
              ),
              const SizedBox(height: 24),
              const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExamHeader(
                title: 'Exam Results',
                subtitle: 'Select an exam period to view and grade exams',
                onBack: widget.onBack,
              ),
              const SizedBox(height: 16),
              ExamErrorState(
                message: examErrorMessage(
                  snapshot.error,
                  'Failed to load exam results',
                ),
                onRetry: _retry,
              ),
            ],
          );
        }

        final data = snapshot.data!;

        // A nested detector so a swipe inside the grading sheet steps back to
        // the exam list rather than all the way out of the feature.
        return SwipeBackDetector(
          enabled: _target != null,
          onSwipeBack: _closeGrading,
          underneathChild: _buildBrowser(data),
          child: _target == null
              ? const SizedBox.shrink()
              : _buildGrading(data, _target!),
        );
      },
    );
  }

  Widget _buildGrading(ScoreExamData data, _GradingTarget target) {
    return ExamGradingView(
      key: _gradingKey,
      api: widget.api,
      exam: target.exam,
      groupId: target.groupId,
      className: target.className,
      subjectName:
          data.subjectNames[target.exam.subjectId] ?? 'Unknown subject',
      onBack: _closeGrading,
      onDirtyChanged: _onGradingDirtyChanged,
      allowedStudentIds: target.allowedStudentIds,
      additionalTargets: [
        for (final member in target.members.skip(1))
          ExamScoringTarget(exam: member.exam, groupId: member.groupId),
      ],
    );
  }

  /// The period grid, or the exams inside the chosen period.
  Widget _buildBrowser(ScoreExamData data) {
    final period = _selectedPeriod;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExamHeader(
          title: 'Exam Results',
          subtitle: period == null
              ? 'Select an exam period to view and grade exams'
              : 'Viewing exams for ${period.name}',
          onBack: _back,
        ),
        const SizedBox(height: 16),
        if (period == null) _buildPeriods(data) else _buildExams(data, period),
      ],
    );
  }

  Widget _buildPeriods(ScoreExamData data) {
    if (data.periods.isEmpty) {
      return const ExamNotice(
        icon: Icons.event_busy_rounded,
        title: 'No exam periods found',
        detail: 'Ask your admin to create an exam period first.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: data.periods.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final period = data.periods[index];
        return _PeriodTile(
          period: period,
          examCount: data.targetsFor(period).length,
          onTap: () => setState(() => _selectedPeriod = period),
        );
      },
    );
  }

  Widget _buildExams(ScoreExamData data, ExamPeriod period) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final exams = data.targetsFor(period);

    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Exams',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${exams.length} exam${exams.length == 1 ? '' : 's'} in this period',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedText),
          ),
          const SizedBox(height: 14),
          if (exams.isEmpty)
            const ExamNotice(
              icon: Icons.description_outlined,
              title: 'No exams for this period',
              detail: 'Create exams from the Exams tab first.',
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: exams.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final target = exams[index];
                final groupId = target.groupId;
                final className =
                    target.className ??
                    data.groupNames[groupId] ??
                    'Class $groupId';

                return _ExamTile(
                  exam: target.exam,
                  className: className,
                  data: data,
                  onTap: () => setState(
                    () => _target = _GradingTarget(
                      exam: target.exam,
                      groupId: groupId,
                      className: className,
                      allowedStudentIds: target.allowedStudentIds,
                      members: target.scoringTargets,
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// Which exam, for which class, the grading sheet is open on.
class _GradingTarget {
  const _GradingTarget({
    required this.exam,
    required this.groupId,
    required this.className,
    this.allowedStudentIds,
    this.members = const [],
  });

  final Exam exam;
  final int groupId;
  final String className;
  final Set<int>? allowedStudentIds;
  final List<ExamTargetMember> members;
}

class _PeriodTile extends StatelessWidget {
  const _PeriodTile({
    required this.period,
    required this.examCount,
    required this.onTap,
  });

  final ExamPeriod period;
  final int examCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.line),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colors.softBg,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: colors.softText,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (period.date != null) period.date!,
                        '$examCount of yours',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: colors.mutedText),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExamTile extends StatelessWidget {
  const _ExamTile({
    required this.exam,
    required this.className,
    required this.data,
    required this.onTap,
  });

  final Exam exam;
  final String className;
  final ScoreExamData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [ExamPill(label: className)],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExamPill(label: '${exam.maxScore} pts'),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 15,
                    color: colors.mutedText,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      data.subjectNames[exam.subjectId] ?? 'Unknown subject',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, thickness: 1, color: colors.line),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'CREATED',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.mutedText,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatExamDate(exam.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.mutedText,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One exam-class member in a teacher's score target.
class ExamTargetMember {
  const ExamTargetMember({
    required this.exam,
    required this.groupId,
    required this.className,
    this.allowedStudentIds,
  });

  final Exam exam;
  final int groupId;
  final String className;
  final Set<int>? allowedStudentIds;
}

/// A class exam, or parallel choice-class exams grouped into one score sheet.
class ExamTarget {
  const ExamTarget({
    required this.exam,
    required this.groupId,
    this.allowedStudentIds,
    this.className,
    this.choiceKey,
    this.members = const [],
  });

  final Exam exam;
  final int groupId;

  /// Enrollment ids of the teacher's subgroup; null for the whole class.
  final Set<int>? allowedStudentIds;
  final String? className;
  final String? choiceKey;
  final List<ExamTargetMember> members;

  List<ExamTargetMember> get scoringTargets => members.isNotEmpty
      ? members
      : [
          ExamTargetMember(
            exam: exam,
            groupId: groupId,
            className: className ?? 'Class $groupId',
            allowedStudentIds: allowedStudentIds,
          ),
        ];
}

/// The web's `ExamsOfClasses` rule: an exam is yours to score for each of its
/// classes where the timetable has you (or you as a co-teacher) teaching its
/// subject, whoever created it. Teaching only subgroups of that class limits
/// the sheet to those subgroups' students ([subgroupStudents] is keyed
/// `"subgroupId:groupId"`).
List<ExamTarget> examTargets({
  required List<Exam> exams,
  required int periodId,
  required List<TimetableLesson> timetable,
  required int myUserId,
  required Map<String, Set<int>> subgroupStudents,
  Map<int, String> groupNames = const {},
}) {
  final wholeGroup = <String>{};
  final subgroups = <String, Set<int>>{};
  final choiceKeys = <String, String>{};
  for (final lesson in timetable) {
    final subjectId = lesson.subjectId;
    final groupId = lesson.groupId;
    if (subjectId == null || groupId == null || !lesson.isTaughtBy(myUserId)) {
      continue;
    }
    final key = '$subjectId:$groupId';
    final subgroupId = lesson.subgroupId;
    if (subgroupId == null) {
      wholeGroup.add(key);
    } else {
      subgroups.putIfAbsent(key, () => {}).add(subgroupId);
      final choiceKey = lesson.choiceExamKey;
      if (choiceKey != null) choiceKeys.putIfAbsent(key, () => choiceKey);
    }
  }

  final rows = <ExamTarget>[];
  for (final exam in exams.where((e) => e.examPeriodId == periodId)) {
    for (final groupId in exam.groupIds) {
      final key = '${exam.subjectId}:$groupId';
      final groupName = groupNames[groupId] ?? 'Class $groupId';
      if (wholeGroup.contains(key)) {
        rows.add(
          ExamTarget(
            exam: exam,
            groupId: groupId,
            className: groupName,
            members: [
              ExamTargetMember(
                exam: exam,
                groupId: groupId,
                className: groupName,
              ),
            ],
          ),
        );
      } else if (subgroups[key] case final ids?) {
        rows.add(
          ExamTarget(
            exam: exam,
            groupId: groupId,
            className: groupName,
            choiceKey: choiceKeys[key],
            allowedStudentIds: {
              for (final subgroupId in ids)
                ...?subgroupStudents['$subgroupId:$groupId'],
            },
            members: [
              ExamTargetMember(
                exam: exam,
                groupId: groupId,
                className: groupName,
                allowedStudentIds: {
                  for (final subgroupId in ids)
                    ...?subgroupStudents['$subgroupId:$groupId'],
                },
              ),
            ],
          ),
        );
      }
    }
  }

  final merged = <String, List<ExamTarget>>{};
  for (final row in rows) {
    final key = row.choiceKey == null
        ? 'exam:${row.exam.id}:group:${row.groupId}'
        : '${row.choiceKey}:${row.exam.maxScore}';
    merged.putIfAbsent(key, () => []).add(row);
  }
  return [
    for (final group in merged.values)
      if (group.length == 1)
        group.single
      else
        ExamTarget(
          exam: group.first.exam,
          groupId: group.first.groupId,
          choiceKey: group.first.choiceKey,
          className: _combinedClassNames(group.expand((row) => row.members)),
          allowedStudentIds: {
            for (final row in group) ...?row.allowedStudentIds,
          },
          members: [for (final row in group) ...row.members],
        ),
  ];
}

String _combinedClassNames(Iterable<ExamTargetMember> members) {
  final unique =
      {
        for (final member in members) member.groupId: member.className,
      }.entries.toList()..sort((a, b) {
        final gradeA =
            int.tryParse(RegExp(r'^\d+').stringMatch(a.value) ?? '') ?? 999;
        final gradeB =
            int.tryParse(RegExp(r'^\d+').stringMatch(b.value) ?? '') ?? 999;
        final grade = gradeA.compareTo(gradeB);
        return grade == 0 ? a.value.compareTo(b.value) : grade;
      });
  return unique.map((entry) => entry.value).join(' + ');
}

/// Everything the scoring flow reads, resolved in one pass.
class ScoreExamData {
  const ScoreExamData({
    required this.exams,
    required this.periods,
    required this.myUserId,
    required this.subjectNames,
    required this.groupNames,
    this.timetable = const [],
    this.subgroupStudents = const {},
  });

  final List<Exam> exams;
  final List<ExamPeriod> periods;
  final int myUserId;
  final List<TimetableLesson> timetable;
  final Map<String, Set<int>> subgroupStudents;
  final Map<int, String> subjectNames;
  final Map<int, String> groupNames;

  /// The classes of exams in [period] this teacher can score.
  List<ExamTarget> targetsFor(ExamPeriod period) => examTargets(
    exams: exams,
    periodId: period.id,
    timetable: timetable,
    myUserId: myUserId,
    subgroupStudents: subgroupStudents,
    groupNames: groupNames,
  );
}
