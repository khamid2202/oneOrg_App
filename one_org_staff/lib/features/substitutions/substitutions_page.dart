import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

String _hm(Object? t) {
  final s = '${t ?? ''}';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

String _day10(Object? v) {
  final s = '${v ?? ''}';
  return s.length >= 10 ? s.substring(0, 10) : s;
}

DateTime _monday(DateTime d) =>
    DateTime(d.year, d.month, d.day - (d.weekday - 1));

Color _typeTone(String? type) => switch (type) {
  'merge' => const Color(0xFF0EA5E9),
  'cancel' => const Color(0xFFF43F5E),
  _ => const Color(0xFF10B981),
};

/// Cover board (docs/staff/substitutions.md): two weeks grouped by day, with
/// each day's absences above its covers, merges and cancellations.
class SubstitutionsPage extends StatefulWidget {
  const SubstitutionsPage({super.key, required this.ctx});
  final StaffContext ctx;

  @override
  State<SubstitutionsPage> createState() => _SubstitutionsPageState();
}

class _SubstitutionsPageState extends State<SubstitutionsPage> {
  late DateTime _start = _monday(DateTime.now());
  List<Map<String, dynamic>>? _subs;
  List<Map<String, dynamic>> _absences = const [];
  Object? _error;

  StaffContext get ctx => widget.ctx;
  DateTime get _end => _start.add(const Duration(days: 13));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final range = {'from': isoDay(_start), 'to': isoDay(_end)};
      final results = await Future.wait([
        ctx.api.get('/substitutions', range),
        ctx.api.get('/teacher-absences', range),
      ]);
      if (!mounted) return;
      setState(() {
        _subs = ApiClient.rows(results[0]);
        _absences = ApiClient.rows(results[1]);
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _subs ??= const [];
        });
      }
    }
  }

  void _shift(int weeks) {
    setState(() {
      _start = _start.add(Duration(days: 7 * weeks));
      _subs = null;
    });
    _load();
  }

  Future<void> _remove(Map<String, dynamic> s) async {
    final l = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.subRemoveQ,
      message: l.subRemoveBody(
        '${s['class_pair'] ?? ''} ${s['subject'] ?? ''}',
        _hm(s['start_time']),
      ),
      confirmLabel: l.subRemove,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ctx.api.delete('/substitutions/${s['id']}');
      if (mounted) toast(context, l.subRemoved);
      _load();
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final today = isoDay(DateTime.now());
    final subs = _subs;
    final days =
        [for (var i = 0; i < 14; i++) isoDay(_start.add(Duration(days: i)))]
            .map(
              (day) => (
                day: day,
                subs:
                    (subs ?? const <Map<String, dynamic>>[])
                        .where((x) => _day10(x['date']) == day)
                        .toList()
                      ..sort(
                        (a, b) => '${a['start_time']}'.compareTo(
                          '${b['start_time']}',
                        ),
                      ),
                abs: _absences
                    .where(
                      (a) =>
                          _day10(a['date_from']).compareTo(day) <= 0 &&
                          day.compareTo(_day10(a['date_to'])) <= 0,
                    )
                    .toList(),
              ),
            )
            .where((d) => d.subs.isNotEmpty || d.abs.isNotEmpty)
            .toList();
    final canEdit = ctx.can('substitutions.update');
    final canDelete = ctx.can('substitutions.delete');

    return SubPage(
      title: l.substitutions,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNew(),
        icon: const Icon(Icons.person_off_outlined),
        label: Text(l.subNewAbsence),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.MMMd(locale).format(_start)} – ${DateFormat.MMMd(locale).format(_end)}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            if (_error != null) ErrorState(error: _error!, onRetry: _load),
            if (subs == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (days.isEmpty)
              EmptyState(icon: Icons.swap_horiz_rounded, message: l.subNone),
            for (final d in days) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
                child: Text(
                  '${DateFormat.MMMEd(locale).format(DateTime.parse(d.day))}${d.day == today ? ' · ${l.calToday}' : ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: d.day == today ? colors.softText : null,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final a in d.abs)
                    ActionChip(
                      avatar: const Icon(Icons.person_off_outlined, size: 16),
                      label: Text(
                        [
                          asStr(a['teacher']) ?? '',
                          if (a['lesson_instance_ids'] is List &&
                              (a['lesson_instance_ids'] as List).isNotEmpty)
                            l.subLessonsCount(
                              (a['lesson_instance_ids'] as List).length,
                            ),
                        ].join(' · '),
                      ),
                      onPressed: () => _openCover(asInt(a['id'])!),
                    ),
                ],
              ),
              if (d.subs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.subNoLessonsYet,
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
                ),
              for (final s in d.subs)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: AppCard(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 46,
                          child: Text(
                            _hm(s['start_time']),
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${asStr(s['subgroup']) == null ? s['class_pair'] ?? '' : '${s['class_pair']} (${s['subgroup']})'} · ${s['subject'] ?? ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${s['absent_teacher'] ?? ''} → ${s['type'] == 'cancel' ? '—' : s['substitute_teacher'] ?? ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Tag(
                          _typeLabel(l, asStr(s['type'])),
                          color: _typeTone(asStr(s['type'])),
                        ),
                        Icon(
                          Icons.notifications_active_outlined,
                          size: 16,
                          color: s['notified_at'] != null
                              ? const Color(0xFF10B981)
                              : colors.mutedText.withValues(alpha: 0.4),
                        ),
                        if (canEdit || canDelete)
                          PopupMenuButton<String>(
                            onSelected: (v) =>
                                v == 'edit' ? _openEdit(s) : _remove(s),
                            itemBuilder: (_) => [
                              if (canEdit)
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(l.edit),
                                ),
                              if (canDelete)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(l.subRemove),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openNew() async {
    final absenceId = await SubPage.push<int>(
      context,
      _NewAbsencePage(ctx: ctx),
    );
    if (absenceId != null && mounted) {
      await _openCover(absenceId);
    } else {
      _load();
    }
  }

  Future<void> _openCover(int absenceId) async {
    await SubPage.push(context, _CoverPage(ctx: ctx, absenceId: absenceId));
    _load();
  }

  Future<void> _openEdit(Map<String, dynamic> s) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(ctx: ctx, substitution: s),
    );
    if (saved == true) _load();
  }
}

String _typeLabel(AppLocalizations l, String? type) => switch (type) {
  'merge' => l.subMerge,
  'cancel' => l.subCancel,
  _ => l.subCover,
};

/// Teacher, dates and reason; returns the absence id.
class _NewAbsencePage extends StatefulWidget {
  const _NewAbsencePage({required this.ctx});
  final StaffContext ctx;

  @override
  State<_NewAbsencePage> createState() => _NewAbsencePageState();
}

class _NewAbsencePageState extends State<_NewAbsencePage> {
  List<Map<String, dynamic>> _teachers = const [];
  int? _teacher;
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now();
  String _reason = 'Sick';
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.ctx.teachers().then((t) {
      if (mounted) setState(() => _teachers = t);
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_teacher == null) return toast(context, l.laChooseTeacher);
    setState(() => _saving = true);
    final api = widget.ctx.api;
    try {
      final reason = [
        _reason,
        _note.text.trim(),
      ].where((s) => s.isNotEmpty).join(': ');
      int? id;
      try {
        id = asInt(
          ApiClient.one(
            await api.post('/teacher-absences', {
              'teacher_id': _teacher,
              'date_from': isoDay(_from),
              'date_to': isoDay(_to),
              'reason': reason,
            }),
          )['id'],
        );
      } catch (e) {
        // Already on file for these dates → carry on with that absence.
        final existing = ApiClient.rows(
          await api.get('/teacher-absences', {
            'from': isoDay(_from),
            'to': isoDay(_to),
            'teacher_id': _teacher,
          }),
        );
        if (existing.isEmpty) rethrow;
        id = asInt(existing.first['id']);
      }
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    Future<DateTime?> pick(DateTime initial) => showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    return SubPage(
      title: l.subNewAbsence,
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.subNext),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<int>(
            initialValue: _teacher,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.laTeacher),
            items: [
              for (final t in _teachers)
                DropdownMenuItem(
                  value: asInt(t['id']),
                  child: Text(personName(t)),
                ),
            ],
            onChanged: (v) => setState(() => _teacher = v),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await pick(_from);
                    if (d != null) {
                      setState(() {
                        _from = d;
                        if (_to.isBefore(d)) _to = d;
                      });
                    }
                  },
                  child: Text(DateFormat.MMMEd(locale).format(_from)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final d = await pick(_to);
                    if (d != null) {
                      setState(() {
                        _to = d;
                        if (_from.isAfter(d)) _from = d;
                      });
                    }
                  },
                  child: Text(DateFormat.MMMEd(locale).format(_to)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final (value, label) in [
                ('Sick', l.subReasonSick),
                ('Personal', l.subReasonPersonal),
                ('Business trip', l.subReasonTrip),
                ('Training', l.subReasonTraining),
                ('Other', l.calCatOther),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _reason == value,
                  onSelected: (_) => setState(() => _reason = value),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l.cashNote),
          ),
        ],
      ),
    );
  }
}

class _Row {
  bool include = true;
  String type = 'cover';
  int? teacherId;
  int? mergeId;
  bool force = false;
  String? error;
  bool needsForce = false;
}

/// Cover each lesson of an absence: a substitute, a merge, or a cancellation.
class _CoverPage extends StatefulWidget {
  const _CoverPage({required this.ctx, required this.absenceId});
  final StaffContext ctx;
  final int absenceId;

  @override
  State<_CoverPage> createState() => _CoverPageState();
}

class _CoverPageState extends State<_CoverPage> {
  Map<String, dynamic>? _absence;
  Object? _error;
  final Map<int, _Row> _rows = {};
  final Map<int, List<Map<String, dynamic>>> _suggest = {};
  final Map<String, List<Map<String, dynamic>>> _dayLessons = {};
  Set<int>? _branchTeachers;
  bool _saving = false;

  StaffContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    ctx.staff().then((s) {
      if (mounted) {
        setState(() => _branchTeachers = {for (final u in s) ?asInt(u['id'])});
      }
    });
  }

  List<Map<String, dynamic>> get _lessons =>
      ((_absence?['affected_lessons'] as List?) ?? const [])
          .whereType<Map>()
          .map(Map<String, dynamic>.from)
          .where((x) => x['role'] != 'additional')
          .toList();

  Future<void> _load() async {
    try {
      final absence = ApiClient.one(
        await ctx.api.get('/teacher-absences/${widget.absenceId}'),
      );
      if (!mounted) return;
      setState(() {
        _absence = absence;
        _error = null;
      });
      for (final x in _lessons.where((x) => x['needs_cover'] == true)) {
        final id = asInt(x['id'])!;
        _rows.putIfAbsent(id, _Row.new);
        ctx.api
            .get('/substitutions/suggest', {
              'lesson_instance_id': id,
              'include_ineligible': 'true',
              'limit': 100,
            })
            .then((res) {
              final r = res is Map ? res['result'] ?? res : null;
              final list = r is Map ? r['suggestions'] : null;
              if (mounted) {
                setState(() => _suggest[id] = ApiClient.rows({'result': list}));
              }
            })
            .catchError((_) {});
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _ensureDay(String day) async {
    if (_dayLessons.containsKey(day)) return;
    _dayLessons[day] = const [];
    try {
      final list = ApiClient.rows(
        await ctx.api.get('/lesson-instances', {'date': day}),
      );
      if (mounted) setState(() => _dayLessons[day] = list);
    } catch (_) {}
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final todo = _lessons.where((x) {
      final r = _rows[asInt(x['id'])];
      return x['needs_cover'] == true && r != null && r.include;
    }).toList();
    for (final x in todo) {
      final r = _rows[asInt(x['id'])]!;
      if (r.type == 'cover' && r.teacherId == null ||
          r.type == 'merge' && r.mergeId == null) {
        return toast(context, l.subPickEach);
      }
    }
    setState(() => _saving = true);
    var failed = 0;
    for (final x in todo) {
      final id = asInt(x['id'])!;
      final r = _rows[id]!;
      try {
        await ctx.api.post('/substitutions', {
          'lesson_instance_id': id,
          'type': r.type,
          'notify': true,
          'force': r.force,
          if (r.type == 'cover') 'substitute_teacher_id': r.teacherId,
          if (r.type == 'merge') 'merge_with_lesson_instance_id': r.mergeId,
        });
        r.error = null;
      } catch (e) {
        failed++;
        final message = errorText(e, l.calChangeFailed);
        r.error = message.replaceFirst(
          RegExp(r'\s*Send force.*$', caseSensitive: false),
          '',
        );
        r.needsForce = RegExp('force', caseSensitive: false).hasMatch(message);
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (failed == 0) {
      toast(context, l.subSaved);
      Navigator.pop(context);
    } else {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final a = _absence;
    final lessons = _lessons;
    final open = lessons.where((x) => x['needs_cover'] == true).toList();
    final arranged = lessons.where((x) => x['needs_cover'] != true).toList();
    return SubPage(
      title: a == null
          ? l.substitutions
          : l.subCoverFor(asStr(a['teacher']) ?? ''),
      actions: [
        if (open.isNotEmpty)
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l.save),
          ),
      ],
      body: _error != null && a == null
          ? ErrorState(error: _error!, onRetry: _load)
          : a == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                Text(
                  [
                    _day10(a['date_from']) == _day10(a['date_to'])
                        ? DateFormat.MMMEd(
                            locale,
                          ).format(DateTime.parse(_day10(a['date_from'])))
                        : '${_day10(a['date_from'])} → ${_day10(a['date_to'])}',
                    ?asStr(a['reason']),
                  ].join(' · '),
                  style: TextStyle(color: colors.mutedText),
                ),
                if (lessons.isEmpty)
                  EmptyState(
                    icon: Icons.event_available_outlined,
                    message: l.subNoAffected,
                  ),
                for (final x in open) _lessonCard(context, l, x),
                if (arranged.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
                    child: Text(
                      l.subArranged,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final x in arranged)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                      ),
                      title: Text(
                        '${_hm(x['start_time'])} · ${x['class_pair'] ?? ''} · ${x['subject'] ?? ''}',
                      ),
                      subtitle: Text(_day10(x['date'])),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _lessonCard(
    BuildContext context,
    AppLocalizations l,
    Map<String, dynamic> x,
  ) {
    final colors = appColorsOf(context);
    final id = asInt(x['id'])!;
    final r = _rows.putIfAbsent(id, _Row.new);
    final all = _suggest[id];
    final options = all == null || _branchTeachers == null
        ? all
        : all
              .where((s) => _branchTeachers!.contains(asInt(s['teacher_id'])))
              .toList();
    final day = _day10(x['date']);
    final merges = (_dayLessons[day] ?? const <Map<String, dynamic>>[])
        .where(
          (o) =>
              asInt(o['id']) != id &&
              '${o['start_time']}'.compareTo('${x['end_time']}') < 0 &&
              '${x['start_time']}'.compareTo('${o['end_time']}') < 0,
        )
        .toList();

    String suggestion(Map<String, dynamic> s) {
      final flags = <String>[
        if (s['eligible'] == false) ...[
          if (s['busy'] == true) l.subBusy,
          if (s['absent'] == true) l.subAbsent,
          if (s['unavailable'] == true) l.subUnavailable,
        ],
        if (s['qualified'] == true) l.subSubject,
        if (s['teaches_class'] == true) l.subKnowsClass,
        l.subCoversMonth(asInt(s['covers_this_month']) ?? 0),
      ];
      return '${s['full_name'] ?? ''} · ${flags.join(' · ')}';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: r.include,
                  onChanged: (v) => setState(() => r.include = v ?? true),
                ),
                Expanded(
                  child: Text(
                    '${DateFormat.E(Localizations.localeOf(context).toString()).format(DateTime.parse(day))} ${_hm(x['start_time'])} · ${x['class_pair'] ?? ''}${asStr(x['subgroup']) == null ? '' : ' (${x['subgroup']})'} · ${x['subject'] ?? ''}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (r.include) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'cover', label: Text(l.subCover)),
                  ButtonSegment(value: 'merge', label: Text(l.subMerge)),
                  ButtonSegment(value: 'cancel', label: Text(l.subCancel)),
                ],
                selected: {r.type},
                onSelectionChanged: (s) {
                  setState(() => r.type = s.first);
                  if (s.first == 'merge') _ensureDay(day);
                },
              ),
              const SizedBox(height: 8),
              if (r.type == 'cover')
                options == null
                    ? const LinearProgressIndicator()
                    : DropdownButtonFormField<int>(
                        initialValue: r.teacherId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l.subSubstitute,
                          isDense: true,
                        ),
                        items: [
                          for (final s in options)
                            DropdownMenuItem(
                              value: asInt(s['teacher_id']),
                              child: Text(
                                suggestion(s),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: s['eligible'] == false
                                      ? colors.mutedText
                                      : null,
                                ),
                              ),
                            ),
                        ],
                        onChanged: (v) => setState(() => r.teacherId = v),
                      ),
              if (r.type == 'merge')
                DropdownButtonFormField<int>(
                  initialValue: r.mergeId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.subMergeWith,
                    isDense: true,
                  ),
                  items: [
                    for (final o in merges)
                      DropdownMenuItem(
                        value: asInt(o['id']),
                        child: Text(
                          '${_hm(o['start_time'])} · ${o['class_pair'] ?? ''} · ${o['subject'] ?? ''} · ${o['teacher'] ?? ''}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => r.mergeId = v),
                ),
              if (r.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    r.error!,
                    style: TextStyle(color: Colors.red.shade600, fontSize: 12),
                  ),
                ),
              if (r.needsForce)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.subAssignAnyway),
                  value: r.force,
                  onChanged: (v) => setState(() => r.force = v ?? false),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Change a saved arrangement: its type, substitute or merge.
class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.ctx, required this.substitution});
  final StaffContext ctx;
  final Map<String, dynamic> substitution;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late String _type = asStr(widget.substitution['type']) ?? 'cover';
  late int? _teacher = asInt(widget.substitution['substitute_teacher_id']);
  List<Map<String, dynamic>>? _options;
  bool _notify = true;
  bool _force = false;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    widget.ctx.api
        .get('/substitutions/suggest', {
          'lesson_instance_id': widget.substitution['lesson_instance_id'],
          'include_ineligible': 'true',
          'limit': 100,
        })
        .then((res) {
          final r = res is Map ? res['result'] ?? res : null;
          if (mounted) {
            setState(
              () => _options = ApiClient.rows({
                'result': r is Map ? r['suggestions'] : null,
              }),
            );
          }
        })
        .catchError((_) {
          if (mounted) setState(() => _options = const []);
        });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ctx.api
          .patch('/substitutions/${widget.substitution['id']}', {
            'type': _type,
            if (_type == 'cover') 'substitute_teacher_id': _teacher,
            'notify': _notify,
            if (_force) 'force': true,
          });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = errorText(
            e,
            l.calChangeFailed,
          ).replaceFirst(RegExp(r'\s*Send force.*$', caseSensitive: false), ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = widget.substitution;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${_hm(s['start_time'])} · ${s['class_pair'] ?? ''} · ${s['subject'] ?? ''}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'cover', label: Text(l.subCover)),
              ButtonSegment(value: 'cancel', label: Text(l.subCancel)),
            ],
            selected: {_type == 'merge' ? 'cover' : _type},
            onSelectionChanged: (v) => setState(() => _type = v.first),
          ),
          const SizedBox(height: 8),
          if (_type == 'cover')
            _options == null
                ? const LinearProgressIndicator()
                : DropdownButtonFormField<int>(
                    initialValue:
                        _options!.any((o) => asInt(o['teacher_id']) == _teacher)
                        ? _teacher
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.subSubstitute),
                    items: [
                      for (final o in _options!)
                        DropdownMenuItem(
                          value: asInt(o['teacher_id']),
                          child: Text('${o['full_name'] ?? ''}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _teacher = v),
                  ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.calNotify),
            value: _notify,
            onChanged: (v) => setState(() => _notify = v),
          ),
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Colors.red.shade600)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.subAssignAnyway),
              value: _force,
              onChanged: (v) => setState(() => _force = v ?? false),
            ),
          ],
          FilledButton(onPressed: _saving ? null : _save, child: Text(l.save)),
        ],
      ),
    );
  }
}
