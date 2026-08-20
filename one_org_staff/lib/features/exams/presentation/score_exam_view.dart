import 'package:flutter/material.dart';

import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/exams/domain/exams_repository.dart';

import 'exam_common.dart';
import 'exam_grading_view.dart';
import 'exams_page.dart';

/// "Score the exam" — a port of the web's `ExamsOfClasses`.
///
/// Three steps, same as the web: pick an exam period, pick one of *your own*
/// exams in it (the list is filtered to `created_by == me`), then grade the
/// class on [ExamGradingView].
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
    ]);

    final data = ScoreExamData(
      exams: results[0] as List<Exam>,
      periods: results[1] as List<ExamPeriod>,
      myUserId: (results[2] as AppUserProfile).id,
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
      subjectName: data.subjectNames[target.exam.subjectId] ?? 'Unknown subject',
      onBack: _closeGrading,
      onDirtyChanged: _onGradingDirtyChanged,
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
        if (period == null)
          _buildPeriods(data)
        else
          _buildExams(data, period),
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
          examCount: data.examsFor(period).length,
          onTap: () => setState(() => _selectedPeriod = period),
        );
      },
    );
  }

  Widget _buildExams(ScoreExamData data, ExamPeriod period) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final exams = data.examsFor(period);

    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Created Exams',
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
                final exam = exams[index];
                final groupId = exam.groupIds.isEmpty
                    ? null
                    : exam.groupIds.first;
                final className = groupId == null
                    ? 'No Group'
                    : data.groupNames[groupId] ?? 'Class $groupId';

                return _ExamTile(
                  exam: exam,
                  data: data,
                  // Without a class there is no roster to grade, so the card
                  // stays inert rather than opening an empty sheet.
                  onTap: groupId == null
                      ? null
                      : () => setState(
                          () => _target = _GradingTarget(
                            exam: exam,
                            groupId: groupId,
                            className: className,
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
  });

  final Exam exam;
  final int groupId;
  final String className;
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
  const _ExamTile({required this.exam, required this.data, required this.onTap});

  final Exam exam;
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
                      children: [
                        if (exam.groupIds.isEmpty)
                          Text(
                            'No Group',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.mutedText,
                            ),
                          )
                        else
                          for (final groupId in exam.groupIds)
                            ExamPill(
                              label:
                                  data.groupNames[groupId] ?? 'Class $groupId',
                            ),
                      ],
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

/// Everything the scoring flow reads, resolved in one pass.
class ScoreExamData {
  const ScoreExamData({
    required this.exams,
    required this.periods,
    required this.myUserId,
    required this.subjectNames,
    required this.groupNames,
  });

  final List<Exam> exams;
  final List<ExamPeriod> periods;
  final int myUserId;
  final Map<int, String> subjectNames;
  final Map<int, String> groupNames;

  /// The signed-in teacher's own exams inside [period]. Someone else's exam is
  /// theirs to grade, so it never appears here — same filter as the web.
  List<Exam> examsFor(ExamPeriod period) {
    return exams
        .where(
          (exam) =>
              exam.createdBy != null &&
              exam.createdBy == myUserId &&
              exam.examPeriodId == period.id,
        )
        .toList();
  }
}
