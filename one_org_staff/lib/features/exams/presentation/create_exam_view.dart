import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';
import 'package:one_org_staff/features/exams/domain/exams_repository.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';

import 'exam_common.dart';
import 'exams_page.dart';

/// "Create a new exam" — a port of the web's `UserExams`.
///
/// Same rules as the web: the exam periods offered are the active ones, the
/// subjects and classes offered are only those the signed-in teacher actually
/// teaches (read off the timetable), Homeroom is filtered out because it is a
/// timetable placeholder rather than an examinable subject, and exactly one
/// class is posted per exam even though the API accepts several.
class CreateExamView extends StatefulWidget {
  const CreateExamView({super.key, required this.api, required this.onBack});

  final ExamsApi api;
  final VoidCallback onBack;

  @override
  State<CreateExamView> createState() => _CreateExamViewState();
}

class _CreateExamViewState extends State<CreateExamView> {
  late Future<CreateExamData> _dataFuture;
  Future<List<Exam>>? _examsFuture;

  int? _periodId;
  int? _subjectId;
  int? _groupId;
  final _maxScoreController = TextEditingController(text: '100');
  bool _submitting = false;

  /// `null` means "All periods", the filter's default.
  int? _filterPeriodId;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadData();
    _reloadExams();
  }

  @override
  void dispose() {
    _maxScoreController.dispose();
    super.dispose();
  }

  Future<CreateExamData> _loadData() async {
    final api = widget.api;
    final academicYearId = await api.resolveAcademicYearId();

    // The reference lists only supply display names, so a failure there must
    // not take the form down with it — same "non-blocking" split as the web.
    Future<List<T>> optional<T>(Future<List<T>> future) =>
        future.catchError((Object _) => <T>[]);

    final results = await Future.wait([
      api.loadExamPeriods(isActive: true, academicYearId: academicYearId),
      api.loadProfile(),
      api.loadTimetable(academicYearId: academicYearId),
      optional(api.loadSubjects()),
      optional(api.loadGroups(academicYearId: academicYearId)),
      optional(api.loadColleagues()),
    ]);

    final periods = results[0] as List<ExamPeriod>;
    final profile = results[1] as AppUserProfile;
    final timetable = results[2] as List<TimetableLesson>;
    final subjects = results[3] as List<SubjectEntry>;
    final groups = results[4] as List<GroupEntry>;
    final colleagues = results[5] as List<Colleague>;

    final data = CreateExamData.build(
      periods: periods,
      profile: profile,
      timetable: timetable,
      subjects: subjects,
      groups: groups,
      colleagues: colleagues,
    );

    return data;
  }

  void _reloadExams() {
    final future = widget.api.loadExams(examPeriodId: _filterPeriodId);
    // Claim the error now: FutureBuilder only subscribes on the next frame, and
    // a faster rejection would otherwise surface as an unhandled async error.
    future.then<void>((_) {}, onError: (Object _) {});
    _examsFuture = future;
    if (mounted) {
      setState(() {});
    }
  }

  void _retry() {
    setState(() {
      _dataFuture = _loadData();
    });
    _reloadExams();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _submit() async {
    final periodId = _periodId;
    final subjectId = _subjectId;
    final groupId = _groupId;

    if (periodId == null) {
      _showMessage('Select an exam period');
      return;
    }
    if (subjectId == null) {
      _showMessage('Select a subject');
      return;
    }
    if (groupId == null) {
      _showMessage('Select at least one group');
      return;
    }

    final maxScore = int.tryParse(_maxScoreController.text.trim());
    if (maxScore == null || maxScore < 1) {
      _showMessage('Max score must be at least 1');
      return;
    }

    setState(() => _submitting = true);
    try {
      await widget.api.createExam(
        examPeriodId: periodId,
        subjectId: subjectId,
        groupIds: [groupId],
        maxScore: maxScore,
      );
      if (!mounted) {
        return;
      }
      // The period stays selected — the web keeps it too, since a teacher
      // usually enters several exams for the same window in a row.
      setState(() {
        _subjectId = null;
        _groupId = null;
        _maxScoreController.text = '100';
      });
      _showMessage('Exam created');
      _reloadExams();
    } catch (error) {
      _showMessage(examErrorMessage(error, 'Failed to create exam'));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _delete(Exam exam) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete exam'),
        content: const Text(
          'This removes the exam and every score recorded against it.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await widget.api.deleteExam(exam.id);
      _showMessage('Exam deleted');
      _reloadExams();
    } catch (error) {
      _showMessage(examErrorMessage(error, 'Failed to delete exam'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CreateExamData>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExamHeader(
              title: 'My Exams',
              subtitle:
                  'Create exams for your assigned classes and track existing '
                  'ones.',
              onBack: widget.onBack,
            ),
            const SizedBox(height: 16),
            if (loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              ExamErrorState(
                message: examErrorMessage(
                  snapshot.error,
                  'Unable to load exams right now.',
                ),
                onRetry: _retry,
              )
            else ...[
              _buildForm(snapshot.data!),
              const SizedBox(height: 16),
              _buildList(snapshot.data!),
            ],
          ],
        );
      },
    );
  }

  Widget _buildForm(CreateExamData data) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return ExamCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create exam',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),

          DropdownButtonFormField<int>(
            initialValue: _periodId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Exam period *',
              prefixIcon: const Icon(Icons.event_rounded),
              hintText: data.periods.isEmpty
                  ? 'No active exam periods'
                  : 'Select exam period',
            ),
            items: [
              for (final period in data.periods)
                DropdownMenuItem(
                  value: period.id,
                  child: Text(
                    period.labelWithDate,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: data.periods.isEmpty
                ? null
                : (value) => setState(() => _periodId = value),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<int>(
            initialValue: _subjectId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Subject *',
              prefixIcon: const Icon(Icons.menu_book_rounded),
              hintText: data.mySubjects.isEmpty
                  ? 'No subjects found'
                  : 'Select subject',
            ),
            items: [
              for (final subject in data.mySubjects)
                DropdownMenuItem(
                  value: subject.id,
                  child: Text(subject.name, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: data.mySubjects.isEmpty
                ? null
                : (value) => setState(() => _subjectId = value),
          ),
          if (data.mySubjects.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Subjects come from your timetable. Contact admin if missing.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.mutedText,
              ),
            ),
          ],
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Groups *',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_groupId != null)
                ExamPill(
                  icon: Icons.groups_rounded,
                  label: data.groupNames[_groupId] ?? 'Group $_groupId',
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.myGroups.isEmpty)
            Text(
              'No groups found in your timetable assignments.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.mutedText,
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: colors.softBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.border),
              ),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                children: [
                  for (final group in data.myGroups)
                    // One class per exam: picking a second would have to
                    // replace the first, so the others read as unavailable
                    // once a choice is made — the web dims them the same way.
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _groupId == group.id,
                      title: Text(group.name),
                      enabled: _groupId == null || _groupId == group.id,
                      onChanged: (checked) => setState(
                        () => _groupId = checked == true ? group.id : null,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: _maxScoreController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Max score *',
                    hintText: '100',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded, size: 20),
                    label: Text(_submitting ? 'Creating…' : 'Create exam'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList(CreateExamData data) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return FutureBuilder<List<Exam>>(
      future: _examsFuture,
      builder: (context, snapshot) {
        final loading =
            _examsFuture == null ||
            snapshot.connectionState != ConnectionState.done;
        final rows = <_ExamRow>[];
        if (!loading && !snapshot.hasError) {
          for (final exam in snapshot.data ?? const <Exam>[]) {
            if (exam.groupIds.isEmpty) {
              rows.add(_ExamRow(exam: exam, groupId: null));
            } else {
              for (final groupId in exam.groupIds) {
                rows.add(_ExamRow(exam: exam, groupId: groupId));
              }
            }
          }
        }

        return ExamCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exams list',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          loading
                              ? 'Loading…'
                              : '${rows.length} exam${rows.length == 1 ? '' : 's'} found',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: loading ? null : _reloadExams,
                    icon: const Icon(Icons.refresh_rounded),
                    tooltip: 'Refresh',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<int?>(
                initialValue: _filterPeriodId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Period',
                  prefixIcon: Icon(Icons.filter_alt_rounded),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All periods')),
                  for (final period in data.periods)
                    DropdownMenuItem(
                      value: period.id,
                      child: Text(
                        period.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) {
                  setState(() => _filterPeriodId = value);
                  _reloadExams();
                },
              ),
              const SizedBox(height: 12),

              if (loading)
                const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                ExamErrorState(
                  message: examErrorMessage(
                    snapshot.error,
                    'Failed to load exams',
                  ),
                  onRetry: _reloadExams,
                )
              else if (rows.isEmpty)
                const ExamNotice(
                  icon: Icons.menu_book_rounded,
                  title: 'No exams yet',
                  detail: 'Create your first exam using the form',
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ExamListTile(
                    row: rows[index],
                    data: data,
                    onDelete: () => _delete(rows[index].exam),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// One exam paired with one of its classes. An exam covering two classes shows
/// as two rows, matching the web's `examRows` flatMap.
class _ExamRow {
  const _ExamRow({required this.exam, required this.groupId});

  final Exam exam;
  final int? groupId;
}

class _ExamListTile extends StatelessWidget {
  const _ExamListTile({
    required this.row,
    required this.data,
    required this.onDelete,
  });

  final _ExamRow row;
  final CreateExamData data;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final exam = row.exam;

    final subject = data.subjectNames[exam.subjectId] ?? 'Unknown subject';
    final period =
        data.periodNames[exam.examPeriodId] ?? 'Period #${exam.examPeriodId}';
    final group = row.groupId == null
        ? '—'
        : data.groupNames[row.groupId] ?? 'Unknown';
    final author =
        data.userNames[exam.createdBy] ?? 'User #${exam.createdBy ?? '-'}';

    return Container(
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subject,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      period,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.mutedText,
                      ),
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
              Icon(Icons.groups_rounded, size: 14, color: colors.mutedText),
              const SizedBox(width: 4),
              Text(
                group,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: colors.mutedText,
              ),
              const SizedBox(width: 4),
              Text(
                formatExamDate(exam.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.mutedText,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red,
                tooltip: 'Delete exam',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          Text(
            'Created by $author',
            style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Everything the create screen needs, resolved together so the form never
/// renders half-populated.
class CreateExamData {
  const CreateExamData({
    required this.periods,
    required this.mySubjects,
    required this.myGroups,
    required this.periodNames,
    required this.subjectNames,
    required this.groupNames,
    required this.userNames,
  });

  /// The active exam periods, the only ones the web offers.
  final List<ExamPeriod> periods;

  /// Subjects the signed-in teacher is timetabled for, Homeroom removed.
  final List<ExamOption> mySubjects;

  /// Classes the signed-in teacher is timetabled for.
  final List<ExamOption> myGroups;

  final Map<int, String> periodNames;
  final Map<int, String> subjectNames;
  final Map<int, String> groupNames;
  final Map<int, String> userNames;

  /// Derives the pickers and the lookup maps the list rows read.
  ///
  /// The teacher's own subjects and classes come off the timetable rather than
  /// the full `/subjects` and `/groups` lists, so the form only offers what
  /// they actually teach — exactly what the web does.
  factory CreateExamData.build({
    required List<ExamPeriod> periods,
    required AppUserProfile profile,
    required List<TimetableLesson> timetable,
    required List<SubjectEntry> subjects,
    required List<GroupEntry> groups,
    required List<Colleague> colleagues,
  }) {
    String normalize(String? value) => (value ?? '').trim().toLowerCase();
    final myName = normalize(profile.fullName);

    final mine = timetable.where((lesson) {
      if (lesson.teacherId != null && lesson.teacherId == profile.id) {
        return true;
      }
      // Falls back to the label only when the row carries no teacher id.
      return lesson.teacherId == null &&
          myName.isNotEmpty &&
          normalize(lesson.teacherLabel) == myName;
    });

    final mySubjects = <int, ExamOption>{};
    final myGroups = <int, ExamOption>{};
    for (final lesson in mine) {
      final subjectId = lesson.subjectId;
      if (subjectId != null && !mySubjects.containsKey(subjectId)) {
        mySubjects[subjectId] = ExamOption(id: subjectId, name: lesson.title);
      }

      final groupId = lesson.groupId;
      if (groupId != null && !myGroups.containsKey(groupId)) {
        myGroups[groupId] = ExamOption(
          id: groupId,
          name: lesson.groupLabel ?? 'Group \$groupId',
        );
      }
    }

    final subjectNames = <int, String>{
      for (final subject in subjects) subject.id: subject.name,
      for (final subject in mySubjects.values) subject.id: subject.name,
    };
    final groupNames = <int, String>{
      for (final group in groups) group.id: group.classPair,
      for (final group in myGroups.values) group.id: group.name,
    };

    final selectableSubjects =
        mySubjects.values.where((subject) => !subject.isHomeroom).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final selectableGroups = myGroups.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return CreateExamData(
      periods: periods,
      mySubjects: selectableSubjects,
      myGroups: selectableGroups,
      periodNames: {for (final period in periods) period.id: period.name},
      subjectNames: subjectNames,
      groupNames: groupNames,
      userNames: {
        for (final colleague in colleagues) colleague.id: colleague.displayName,
      },
    );
  }
}
