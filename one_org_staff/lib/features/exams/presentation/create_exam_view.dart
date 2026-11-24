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
import 'package:one_org_staff/shared/app_toast.dart';

/// "Create a new exam" — a port of the web's `UserExams`.
///
/// Same rules as the web: the exam periods offered are the active ones, the
/// subjects and classes offered are only those the signed-in teacher actually
/// teaches (read off the timetable), Homeroom is filtered out because it is a
/// timetable placeholder rather than an examinable subject. Parallel choice
/// classes share one setup row and are created together.
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

  void _showMessage(String message, [ToastKind kind = ToastKind.warning]) {
    if (!mounted) {
      return;
    }
    showToast(context, message, kind: kind);
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

    final data = await _dataFuture;
    if (!mounted) return;
    final groupIds = data.groupIdsFor(subjectId, groupId);
    var highMaxConfirmed = false;
    final reviewed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review exam before creating'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.periodNames[periodId] ?? 'Period #$periodId'),
              Text(data.subjectNames[subjectId] ?? 'Subject #$subjectId'),
              Text(data.groupLabelFor(subjectId, groupId)),
              Text(
                '$maxScore points',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              if (maxScore >= 100) ...[
                const SizedBox(height: 12),
                const Text(
                  'Double-check this 100+ point maximum against the exam plan.',
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('This maximum is intentional'),
                  value: highMaxConfirmed,
                  onChanged: (value) =>
                      setDialogState(() => highMaxConfirmed = value ?? false),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Back'),
            ),
            FilledButton(
              onPressed: maxScore >= 100 && !highMaxConfirmed
                  ? null
                  : () => Navigator.pop(context, true),
              child: const Text('Create exam'),
            ),
          ],
        ),
      ),
    );
    if (reviewed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await widget.api.createExam(
        examPeriodId: periodId,
        subjectId: subjectId,
        groupIds: groupIds,
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
      _showMessage('Exam created', ToastKind.success);
      _reloadExams();
    } catch (error) {
      _showMessage(
        examErrorMessage(error, 'Failed to create exam'),
        ToastKind.error,
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _delete(List<Exam> exams) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete exam'),
        content: Text(
          exams.length == 1
              ? 'This removes the exam and every score recorded against it.'
              : 'This removes ${exams.length} parallel class exams and every score recorded against them.',
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
      await Future.wait([
        for (final exam in exams) widget.api.deleteExam(exam.id),
      ]);
      _showMessage('Exam deleted', ToastKind.success);
      _reloadExams();
    } catch (error) {
      _showMessage(
        examErrorMessage(error, 'Failed to delete exam'),
        ToastKind.error,
      );
      _reloadExams();
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
                : (value) => setState(() {
                    _subjectId = value;
                    _groupId = null;
                  }),
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
              if (_groupId != null && _subjectId != null)
                ExamPill(
                  icon: Icons.groups_rounded,
                  label: data.groupLabelFor(_subjectId!, _groupId!),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_subjectId == null)
            Text(
              'Choose a subject to see its classes.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.mutedText,
              ),
            )
          else if (data.groupsForSubject(_subjectId).isEmpty)
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
                  for (final group in data.groupsForSubject(_subjectId))
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
          final grouped = <String, List<(Exam, int)>>{};
          for (final exam in snapshot.data ?? const <Exam>[]) {
            if (exam.groupIds.isEmpty) {
              rows.add(_ExamRow(exams: [exam], groupIds: const []));
            } else {
              for (final groupId in exam.groupIds) {
                final choice = data.choiceKeyFor(exam.subjectId, groupId);
                final key = choice == null
                    ? 'exam:${exam.id}:$groupId'
                    : '$choice:${exam.examPeriodId}:${exam.maxScore}';
                grouped.putIfAbsent(key, () => []).add((exam, groupId));
              }
            }
          }
          for (final members in grouped.values) {
            final exams = {
              for (final member in members) member.$1.id: member.$1,
            }.values.toList();
            final groupIds = members
                .map((member) => member.$2)
                .toSet()
                .toList();
            rows.add(_ExamRow(exams: exams, groupIds: groupIds));
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
                  const DropdownMenuItem(
                    value: null,
                    child: Text('All periods'),
                  ),
                  for (final period in data.periods)
                    DropdownMenuItem(
                      value: period.id,
                      child: Text(period.name, overflow: TextOverflow.ellipsis),
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
                    onDelete: () => _delete(rows[index].exams),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Choice classes that share one exam scale appear on one row.
class _ExamRow {
  const _ExamRow({required this.exams, required this.groupIds});

  final List<Exam> exams;
  final List<int> groupIds;

  Exam get exam => exams.first;
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
    final group = row.groupIds.isEmpty
        ? '—'
        : row.groupIds
              .map((id) => data.groupNames[id] ?? 'Unknown')
              .join(' + ');
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

class ExamGroupOption {
  const ExamGroupOption({
    required this.id,
    required this.groupIds,
    required this.name,
  });

  /// Stable selection id: the first class id in [groupIds].
  final int id;
  final List<int> groupIds;
  final String name;
}

int _compareClassNames(String a, String b) {
  final gradeA = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '') ?? 999;
  final gradeB = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '') ?? 999;
  final grade = gradeA.compareTo(gradeB);
  return grade == 0 ? a.compareTo(b) : grade;
}

/// Everything the create screen needs, resolved together so the form never
/// renders half-populated.
class CreateExamData {
  const CreateExamData({
    required this.periods,
    required this.mySubjects,
    required this.myGroups,
    required this.subjectGroups,
    required this.subjectChoiceKeys,
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
  final Map<int, List<ExamGroupOption>> subjectGroups;
  final Map<int, Map<int, String>> subjectChoiceKeys;

  final Map<int, String> periodNames;
  final Map<int, String> subjectNames;
  final Map<int, String> groupNames;
  final Map<int, String> userNames;

  List<ExamGroupOption> groupsForSubject(int? subjectId) =>
      subjectGroups[subjectId] ?? const [];

  List<int> groupIdsFor(int subjectId, int groupId) =>
      groupsForSubject(
        subjectId,
      ).where((option) => option.id == groupId).firstOrNull?.groupIds ??
      [groupId];

  String groupLabelFor(int subjectId, int groupId) =>
      groupsForSubject(
        subjectId,
      ).where((option) => option.id == groupId).firstOrNull?.name ??
      groupNames[groupId] ??
      'Group $groupId';

  String? choiceKeyFor(int subjectId, int groupId) =>
      subjectChoiceKeys[subjectId]?[groupId];

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
      if (lesson.isTaughtBy(profile.id)) {
        return true;
      }
      // Falls back to the label only when the row carries no teacher id.
      return lesson.teacherId == null &&
          myName.isNotEmpty &&
          normalize(lesson.teacherLabel) == myName;
    });

    final mySubjects = <int, ExamOption>{};
    final myGroups = <int, ExamOption>{};
    final assignmentChoiceKeys = <int, Map<int, String>>{};
    final assignmentGroupIds = <int, Set<int>>{};
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
      if (subjectId != null && groupId != null) {
        assignmentGroupIds.putIfAbsent(subjectId, () => {}).add(groupId);
        final choiceKey = lesson.choiceExamKey;
        if (choiceKey != null) {
          assignmentChoiceKeys
              .putIfAbsent(subjectId, () => {})
              .putIfAbsent(groupId, () => choiceKey);
        }
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
    final groupOptionsBySubject = <int, List<ExamGroupOption>>{};
    for (final subject in selectableSubjects) {
      final choiceKeys = assignmentChoiceKeys[subject.id] ?? const {};
      final groupIds = assignmentGroupIds[subject.id] ?? const <int>{};
      final buckets = <String, List<int>>{};
      for (final groupId in groupIds) {
        final choiceKey = choiceKeys[groupId];
        buckets
            .putIfAbsent(choiceKey ?? 'group:$groupId', () => [])
            .add(groupId);
      }
      final options = <ExamGroupOption>[];
      for (final bucket in buckets.values) {
        bucket.sort(
          (a, b) =>
              _compareClassNames(groupNames[a] ?? '', groupNames[b] ?? ''),
        );
        options.add(
          ExamGroupOption(
            id: bucket.first,
            groupIds: bucket,
            name: bucket.map((id) => groupNames[id] ?? 'Group $id').join(' + '),
          ),
        );
      }
      options.sort((a, b) => _compareClassNames(a.name, b.name));
      groupOptionsBySubject[subject.id] = options;
    }

    return CreateExamData(
      periods: periods,
      mySubjects: selectableSubjects,
      myGroups: selectableGroups,
      subjectGroups: groupOptionsBySubject,
      subjectChoiceKeys: assignmentChoiceKeys,
      periodNames: {for (final period in periods) period.id: period.name},
      subjectNames: subjectNames,
      groupNames: groupNames,
      userNames: {
        for (final colleague in colleagues) colleague.id: colleague.displayName,
      },
    );
  }
}
