import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../MyLessons/lesson_points_repository.dart';
import '../domain/my_records.dart';
import 'period_bar.dart';
import 'package:one_org_staff/shared/app_toast.dart';

const _maxFileBytes = 10 * 1024 * 1024;

Color _statusColor(String status) => switch (status) {
  planInProgress => const Color(0xFF0EA5E9),
  planCompleted => positiveGreen,
  planPostponed => const Color(0xFFF59E0B),
  planCancelled => const Color(0xFFFB7185),
  _ => const Color(0xFF94A3B8),
};

String _statusLabel(AppLocalizations l, String status) => switch (status) {
  planInProgress => l.planInProgress,
  planCompleted => l.planDone,
  planPostponed => l.planPostponed,
  planCancelled => l.planCancelled,
  planPending => l.planNotStarted,
  _ => status,
};

String _priorityLabel(AppLocalizations l, String priority) =>
    switch (priority) {
      'low' => l.priorityLow,
      'medium' => l.priorityMedium,
      'high' => l.priorityHigh,
      'urgent' => l.priorityUrgent,
      _ => priority,
    };

String _categoryLabel(AppLocalizations l, String category) =>
    switch (category) {
      'curriculum' => l.categoryCurriculum,
      'lesson' => l.categoryLesson,
      'exam' => l.categoryExam,
      'meeting' => l.categoryMeeting,
      'administrative' => l.categoryAdministrative,
      'personal' => l.categoryPersonal,
      'general' => l.categoryGeneral,
      _ => category,
    };

String _range(BuildContext context, UserPlan plan) {
  final locale = Localizations.localeOf(context).toString();
  String date(DateTime? value) =>
      value == null ? '—' : DateFormat('d MMM y', locale).format(value);
  final from = date(plan.start);
  final to = date(plan.end);
  return from == to ? from : '$from → $to';
}

/// A teacher's yearly plan: the counts, the milestone track, and the entries,
/// where recording progress is one tap on a row's status.
class MyPlanPage extends StatefulWidget {
  const MyPlanPage({
    super.key,
    required this.repository,
    required this.userId,
    required this.loadYear,
    this.bottomInset = 0,
  });

  final MyRepository repository;
  final int userId;

  /// The active academic year; its dates scope the plan.
  final Future<AcademicYearEntry?> Function() loadYear;
  final double bottomInset;

  @override
  State<MyPlanPage> createState() => _MyPlanPageState();
}

class _MyPlanPageState extends State<MyPlanPage> {
  List<UserPlan>? _plans;
  AcademicYearEntry? _year;
  bool _failed = false;
  String? _filter;
  final Map<int, GlobalKey> _rowKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      AcademicYearEntry? year;
      try {
        year = await widget.loadYear();
      } catch (_) {
        // Without a year the whole plan shows, which still beats nothing.
      }
      final plans = await widget.repository.getPlans(
        userId: widget.userId,
        from: year?.startDate,
        to: year?.endDate,
      );
      if (!mounted) return;
      setState(() {
        _year = year;
        _plans = plans;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _snack(String message, ToastKind kind) =>
      showToast(context, message, kind: kind);

  Future<void> _changeStatus(UserPlan plan, String status) async {
    if (status == plan.status) return;
    final l = AppLocalizations.of(context);
    void replace(UserPlan next) => setState(() {
      _plans = [
        for (final item in _plans ?? const <UserPlan>[])
          item.id == plan.id ? next : item,
      ];
    });

    replace(plan.withStatus(status));
    try {
      await widget.repository.setPlanStatus(plan.id, status);
    } catch (_) {
      if (!mounted) return;
      replace(plan);
      _snack(l.planStatusFailed, ToastKind.error);
    }
  }

  Future<void> _pickStatus(UserPlan plan) async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final status in planStatuses)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: _statusColor(status),
                ),
                title: Text(
                  _statusLabel(l, status),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: status == plan.status
                    ? const Icon(Icons.check_rounded, size: 18)
                    : null,
                onTap: () => Navigator.pop(sheet, status),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _changeStatus(plan, picked);
  }

  Future<void> _openForm([UserPlan? plan]) async {
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _PlanForm(
        plan: plan,
        repository: widget.repository,
        existing: _plans ?? const [],
        yearStart: DateTime.tryParse(_year?.startDate ?? ''),
      ),
    );
    if (saved != null && mounted) {
      _snack(saved, ToastKind.success);
      await _load();
    }
  }

  void _showRow(UserPlan plan) {
    setState(() => _filter = null);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _rowKeys[plan.id]?.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0.3,
          duration: const Duration(milliseconds: 250),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final plans = _plans;
    final visible = (plans ?? const <UserPlan>[])
        .where((p) => _filter == null || p.status == _filter)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
          child: Row(
            children: [
              Text(
                l.myPlan,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _year?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ),
              TextButton.icon(
                onPressed: plans == null ? null : () => _openForm(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l.addMilestone),
              ),
            ],
          ),
        ),
        Expanded(
          child: _failed && plans == null
              ? RetryBanner(onRetry: _load)
              : plans == null
              ? const Center(child: CircularProgressIndicator())
              : plans.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.noPlanYet,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.mutedText),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    widget.bottomInset + 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _summary(context, l, plans),
                      const SizedBox(height: 8),
                      _Track(plans: plans, onSelect: _showRow),
                      const SizedBox(height: 6),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            PillChip(
                              label: l.all,
                              selected: _filter == null,
                              onTap: () => setState(() => _filter = null),
                            ),
                            for (final status in planStatuses)
                              PillChip(
                                label: _statusLabel(l, status),
                                selected: _filter == status,
                                onTap: () => setState(() => _filter = status),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            l.noMilestonesWithStatus,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.mutedText),
                          ),
                        ),
                      for (final plan in visible)
                        _row(context, l, plan, plans.indexOf(plan)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _summary(
    BuildContext context,
    AppLocalizations l,
    List<UserPlan> plans,
  ) {
    final colors = appColorsOf(context);
    final now = DateTime.now();
    final progress = planProgress(plans);
    Widget tile(String label, int value, Color? color) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: tabularFigures,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.mutedText),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              tile(l.milestones, plans.length, null),
              tile(
                l.planDone,
                plans.where((p) => p.status == planCompleted).length,
                positiveGreen,
              ),
              tile(
                l.planInProgress,
                plans.where((p) => p.status == planInProgress).length,
                _statusColor(planInProgress),
              ),
              tile(
                l.overdue,
                plans.where((p) => isOverdue(p, now)).length,
                negativeRed,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 7,
                    color: positiveGreen,
                    backgroundColor: colors.softBg,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$progress%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    UserPlan plan,
    int index,
  ) {
    final colors = appColorsOf(context);
    final overdue = isOverdue(plan, DateTime.now());
    final color = _statusColor(plan.status);
    final meta = [
      _range(context, plan),
      if (plan.category != null) _categoryLabel(l, plan.category!),
      _priorityLabel(l, plan.priority),
    ].join(' · ');

    return InkWell(
      key: _rowKeys[plan.id] ??= GlobalKey(),
      onTap: () => _openForm(plan),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: colors.line.withValues(alpha: 0.5)),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              child: Text(
                '${index + 1}'.padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plan.agenda,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                  if (overdue)
                    Text(
                      l.overdue,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: negativeRed,
                      ),
                    ),
                  if (plan.notes != null)
                    Text(
                      plan.notes!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  if (plan.attachments.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final file in plan.attachments)
                          _AttachmentLink(file: file),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: color.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(99),
              child: InkWell(
                borderRadius: BorderRadius.circular(99),
                onTap: () => _pickStatus(plan),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    _statusLabel(l, plan.status),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentLink extends StatelessWidget {
  const _AttachmentLink({required this.file});

  final PlanAttachment file;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final url = file.url;
    return GestureDetector(
      onTap: url == null
          ? null
          : () =>
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file_rounded, size: 13, color: colors.accent.ring),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 150),
            child: Text(
              file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.accent.ring),
            ),
          ),
        ],
      ),
    );
  }
}

/// One node per milestone in date order. Scrolls sideways: a year is one line.
class _Track extends StatelessWidget {
  const _Track({required this.plans, required this.onSelect});

  final List<UserPlan> plans;
  final ValueChanged<UserPlan> onSelect;

  static const _width = 76.0;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final current = currentPlanIndex(plans);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < plans.length; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(plans[i]),
              child: SizedBox(
                width: _width,
                child: Column(
                  children: [
                    SizedBox(
                      height: 34,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 4,
                                  color: i == 0
                                      ? Colors.transparent
                                      : (current == -1 || i <= current)
                                      ? positiveGreen
                                      : colors.softBg,
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  height: 4,
                                  color: i == plans.length - 1
                                      ? Colors.transparent
                                      : (current == -1 || i < current)
                                      ? positiveGreen
                                      : colors.softBg,
                                ),
                              ),
                            ],
                          ),
                          _node(i, current),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Text(
                        plans[i].agenda,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.15,
                          color: colors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _node(int index, int current) {
    final status = plans[index].status;
    final open = status == planPending || status == planInProgress;
    final color = open && index == current
        ? _statusColor(planInProgress)
        : _statusColor(status == planInProgress ? planPending : status);
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: status == planCompleted
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : status == planCancelled
          ? const Icon(Icons.close_rounded, size: 17, color: Colors.white)
          : Text(
              '${index + 1}'.padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
    );
  }
}

/// Create or edit a milestone. Closes with a message once it's saved.
class _PlanForm extends StatefulWidget {
  const _PlanForm({
    required this.plan,
    required this.repository,
    required this.existing,
    required this.yearStart,
  });

  final UserPlan? plan;
  final MyRepository repository;
  final List<UserPlan> existing;
  final DateTime? yearStart;

  @override
  State<_PlanForm> createState() => _PlanFormState();
}

class _PlanFormState extends State<_PlanForm> {
  final _agenda = TextEditingController();
  final _notes = TextEditingController();
  late DateTime _start;
  late DateTime _end;
  late String _status;
  late String _priority;
  late String _category;

  /// While false, moving the start carries the one-month end along.
  late bool _endEdited;
  final List<PlanFile> _files = [];
  final List<String> _removed = [];
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final plan = widget.plan;
    _endEdited = plan != null;
    if (plan != null) {
      _agenda.text = plan.agenda;
      _notes.text = plan.notes ?? '';
      final now = DateTime.now();
      _start = plan.start ?? now;
      _end = plan.end ?? _start;
      _status = plan.status;
      _priority = plan.priority;
      _category = plan.category ?? 'general';
    } else {
      _start = nextMilestoneStart(
        widget.existing,
        yearStart: widget.yearStart,
        now: DateTime.now(),
      );
      _end = addMonths(_start, 1);
      _status = planPending;
      _priority = 'medium';
      _category = 'curriculum';
    }
  }

  @override
  void dispose() {
    _agenda.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool start}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = picked;
        if (!_endEdited) _end = addMonths(picked, 1);
      } else {
        _end = picked;
        _endEdited = true;
      }
    });
  }

  Future<void> _addFiles() async {
    final l = AppLocalizations.of(context);
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || !mounted) return;
    final tooBig = <String>[];
    setState(() {
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;
        if (bytes.length > _maxFileBytes) {
          tooBig.add(file.name);
        } else {
          _files.add(PlanFile(name: file.name, bytes: bytes));
        }
      }
      _error = tooBig.isEmpty ? null : l.fileTooBig(tooBig.first);
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_agenda.text.trim().isEmpty) {
      setState(() => _error = l.milestoneNeedsTitle);
      return;
    }
    if (_end.isBefore(_start)) {
      setState(() => _error = l.endBeforeStart);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    final editing = widget.plan != null;
    try {
      await widget.repository.savePlan(
        PlanDraft(
          agenda: _agenda.text,
          notes: _notes.text,
          start: _start,
          end: _end,
          status: _status,
          priority: _priority,
          category: _category,
        ),
        id: widget.plan?.id,
        files: _files,
        removeAttachmentKeys: _removed,
      );
      navigator.pop(editing ? l.milestoneUpdated : l.milestoneAdded);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.couldNotSaveMilestone;
        });
      }
    }
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final plan = widget.plan!;
    final navigator = Navigator.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(l.deleteMilestoneTitle),
        content: Text(l.deleteMilestoneBody(plan.agenda)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialog, true),
            style: TextButton.styleFrom(foregroundColor: negativeRed),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.repository.deletePlan(plan.id);
      navigator.pop(l.milestoneDeleted);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = l.couldNotDeleteMilestone;
        });
      }
    }
  }

  Widget _options(
    String label,
    List<String> values,
    String selected,
    String Function(String) name,
    ValueChanged<String> onPick,
  ) {
    final colors = appColorsOf(context);
    final all = values.contains(selected) ? values : [selected, ...values];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.mutedText)),
          const SizedBox(height: 3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final value in all)
                  PillChip(
                    label: name(value),
                    selected: value == selected,
                    onTap: () => setState(() => onPick(value)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final plan = widget.plan;
    final existing = (plan?.attachments ?? const <PlanAttachment>[])
        .where((file) => !_removed.contains(file.key))
        .toList();
    final dates = DateFormat('d MMM y', locale);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              plan == null ? l.addMilestone : l.editMilestone,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _agenda,
              maxLength: 255,
              decoration: InputDecoration(
                hintText: l.milestoneTitleHint,
                counterText: '',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 6,
              children: [
                PillChip(
                  label: '${l.starts}: ${dates.format(_start)}',
                  selected: false,
                  onTap: () => _pickDate(start: true),
                ),
                PillChip(
                  label: '${l.ends}: ${dates.format(_end)}',
                  selected: false,
                  onTap: () => _pickDate(start: false),
                ),
              ],
            ),
            _options(
              l.status,
              planStatuses,
              _status,
              (v) => _statusLabel(l, v),
              (v) => _status = v,
            ),
            _options(
              l.priority,
              planPriorities,
              _priority,
              (v) => _priorityLabel(l, v),
              (v) => _priority = v,
            ),
            _options(
              l.category,
              planCategories,
              _category,
              (v) => _categoryLabel(l, v),
              (v) => _category = v,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: l.notes,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            for (final file in existing)
              _fileRow(file.name, () => setState(() => _removed.add(file.key))),
            for (final file in _files)
              _fileRow(
                file.name,
                () => setState(() => _files.remove(file)),
                added: true,
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _addFiles,
                icon: const Icon(Icons.attach_file_rounded, size: 17),
                label: Text(l.addFiles),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: negativeRed),
                ),
              ),
            Row(
              children: [
                if (plan != null)
                  TextButton(
                    onPressed: _busy ? null : _delete,
                    style: TextButton.styleFrom(foregroundColor: negativeRed),
                    child: Text(l.delete),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent.solid,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(plan == null ? l.addMilestone : l.save),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileRow(String name, VoidCallback onRemove, {bool added = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(
            added ? Icons.upload_file_rounded : Icons.attach_file_rounded,
            size: 16,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, size: 16),
          ),
        ],
      ),
    );
  }
}
