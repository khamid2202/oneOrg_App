import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../features/MyLessons/lesson_points_repository.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

class ResetGradesPage extends StatefulWidget {
  const ResetGradesPage({super.key, required this.ctx});

  final StaffContext ctx;

  @override
  State<ResetGradesPage> createState() => _ResetGradesPageState();
}

class _ResetGradesPageState extends State<ResetGradesPage> {
  AcademicYearEntry? _year;
  DateTime? _firstDate;
  DateTime? _lastDate;
  late DateTime _date = DateTime.now();
  List<Map<String, dynamic>> _groups = const [];
  List<Map<String, dynamic>>? _lessons;
  final Set<int> _selectedGroupIds = {};
  final Set<int> _selectedLessonIds = {};
  bool _showAll = false;
  bool _loadingSetup = true;
  bool _loadingLessons = false;
  bool _saving = false;
  Object? _error;
  int _request = 0;

  StaffContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _loadSetup();
  }

  static DateTime? _dateOf(String? value) {
    if (value == null || value.length < 10) return null;
    return DateTime.tryParse(value.substring(0, 10));
  }

  Future<void> _loadSetup() async {
    try {
      final year = await ctx.academicYear();
      if (!mounted) return;
      if (year == null || !year.isActive) {
        setState(() {
          _year = null;
          _loadingSetup = false;
        });
        return;
      }
      final first = _dateOf(year.startDate);
      final last = _dateOf(year.endDate);
      final today = DateTime.now();
      final initial = first != null && today.isBefore(first)
          ? first
          : last != null && today.isAfter(last)
          ? last
          : today;
      setState(() {
        _year = year;
        _firstDate = first;
        _lastDate = last;
        _date = initial;
      });
      try {
        final body = await ctx.api.get('/groups', {
          'academic_year_id': year.id,
          'limit': 1000,
        });
        final values = body is Map ? body['groups'] : null;
        final groups = values is List
            ? values.whereType<Map>().map(Map<String, dynamic>.from).toList()
            : <Map<String, dynamic>>[];
        groups.sort((a, b) => _groupName(a).compareTo(_groupName(b)));
        if (mounted) setState(() => _groups = groups);
      } catch (_) {
        // The date's lessons remain useful when a class list cannot load.
      }
      await _loadLessons();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loadingSetup = false);
    }
  }

  Future<void> _loadLessons() async {
    final year = _year;
    if (year == null) return;
    final request = ++_request;
    setState(() {
      _loadingLessons = true;
      _error = null;
      _lessons = null;
      _selectedLessonIds.clear();
    });
    try {
      final body = await ctx.api.get('/lesson-instances', {
        'date': isoDay(_date),
        'academic_year_id': year.id,
      });
      final rows = ApiClient.rows(body)
        ..sort((a, b) {
          final time = '${a['start_time']}'.compareTo('${b['start_time']}');
          if (time != 0) return time;
          final group = _groupName(a).compareTo(_groupName(b));
          return group != 0
              ? group
              : '${a['subject']}'.compareTo('${b['subject']}');
        });
      if (mounted && request == _request) setState(() => _lessons = rows);
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) {
        setState(() => _loadingLessons = false);
      }
    }
  }

  static String _groupName(Map<String, dynamic> group) =>
      asStr(group['class_pair']) ??
      asStr(group['name']) ??
      '${group['grade'] ?? ''}${group['class'] ?? ''}';

  List<Map<String, dynamic>> get _classLessons {
    final selected = _selectedGroupIds;
    return (_lessons ?? const <Map<String, dynamic>>[]).where((lesson) {
      if (lesson['is_graded'] != true) return false;
      if (selected.isEmpty) return true;
      final rawIds = lesson['group_ids'] is List
          ? lesson['group_ids'] as List
          : [lesson['group_id']];
      return rawIds.map(asInt).whereType<int>().any(selected.contains);
    }).toList();
  }

  List<Map<String, dynamic>> get _visibleLessons => _showAll
      ? _classLessons
      : _classLessons
            .where((lesson) => (asInt(lesson['grades_entered']) ?? 0) > 0)
            .toList();

  List<Map<String, dynamic>> get _chosen => _visibleLessons
      .where((lesson) => _selectedLessonIds.contains(asInt(lesson['id'])))
      .toList();

  int get _chosenGrades => _chosen.fold(
    0,
    (sum, lesson) => sum + (asInt(lesson['grades_entered']) ?? 0),
  );

  String _periodKey(Map<String, dynamic> lesson) =>
      asInt(lesson['period_number']) != null
      ? 'P${lesson['period_number']}'
      : asStr(lesson['time_slot']) ??
            asStr(lesson['start_time'])?.substring(0, 5) ??
            '—';

  void _toggleLessons(Iterable<int> ids) {
    final values = ids.toList();
    final allSelected =
        values.isNotEmpty && values.every(_selectedLessonIds.contains);
    setState(() {
      if (allSelected) {
        _selectedLessonIds.removeAll(values);
      } else {
        _selectedLessonIds.addAll(values);
      }
    });
  }

  Future<void> _pickDate() async {
    final first = _firstDate;
    final last = _lastDate;
    if (first == null || last == null) return;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    setState(() => _date = picked);
    _loadLessons();
  }

  void _shiftDate(int days) {
    final next = _date.add(Duration(days: days));
    if ((_firstDate == null || !next.isBefore(_firstDate!)) &&
        (_lastDate == null || !next.isAfter(_lastDate!))) {
      setState(() => _date = next);
      _loadLessons();
    }
  }

  Future<void> _pickClasses() async {
    final l = AppLocalizations.of(context);
    final search = TextEditingController();
    final picked = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var selected = Set<int>.from(_selectedGroupIds);
        return StatefulBuilder(
          builder: (context, update) {
            final query = search.text.trim().toLowerCase();
            final visible = _groups
                .where(
                  (group) => _groupName(group).toLowerCase().contains(query),
                )
                .toList();
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.78,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l.resetGradesSelectClasses,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, selected),
                            child: Text(l.done),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: search,
                        onChanged: (_) => update(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: l.resetGradesSearchClasses,
                          isDense: true,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: Icon(
                        selected.isEmpty
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                      ),
                      title: Text(l.resetGradesAllClasses),
                      onTap: () => update(() => selected.clear()),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final group = visible[index];
                          final id = asInt(group['id']);
                          if (id == null) return const SizedBox.shrink();
                          return CheckboxListTile(
                            value: selected.contains(id),
                            title: Text(_groupName(group)),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (value) => update(() {
                              if (value == true) {
                                selected.add(id);
                              } else {
                                selected.remove(id);
                              }
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    search.dispose();
    if (picked == null || !mounted) return;
    setState(() {
      _selectedGroupIds
        ..clear()
        ..addAll(picked);
      _selectedLessonIds.clear();
    });
  }

  Future<void> _confirmReset() async {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final readableDate = DateFormat.MMMEd(locale).format(_date);
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.resetGradesConfirmTitle(chosen.length, readableDate)),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.resetGradesConfirmBody),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final lesson in chosen)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${_groupName(lesson)} · ${asStr(lesson['subject']) ?? ''}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_periodKey(lesson)),
                        trailing: Text(
                          '${asInt(lesson['grades_entered']) ?? 0}',
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: Text(l.cancel),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _saving ? null : () => Navigator.pop(context, true),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(l.reset),
          ),
        ],
      ),
    );
    if (confirmed == true) await _runReset(chosen);
  }

  Future<void> _runReset(List<Map<String, dynamic>> chosen) async {
    final l = AppLocalizations.of(context);
    final year = _year;
    if (year == null || _saving) return;
    setState(() => _saving = true);
    try {
      final body = await ctx.api.post('/lesson-grades/reset', {
        'academic_year_id': year.id,
        'date': isoDay(_date),
        'lesson_instance_ids': chosen
            .map((lesson) => asInt(lesson['id']))
            .whereType<int>()
            .toList(),
      });
      final meta = body is Map && body['meta'] is Map
          ? body['meta'] as Map
          : const {};
      final count = asInt(meta['reset_rows']) ?? 0;
      final done = chosen
          .map((lesson) => asInt(lesson['id']))
          .whereType<int>()
          .toSet();
      if (mounted) {
        setState(() {
          _lessons = (_lessons ?? const <Map<String, dynamic>>[])
              .map(
                (lesson) => done.contains(asInt(lesson['id']))
                    ? {...lesson, 'grades_entered': 0}
                    : lesson,
              )
              .toList();
          _selectedLessonIds.clear();
        });
        toast(context, l.resetGradesCleared(count));
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.resetGradesFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final year = _year;
    final lessons = _visibleLessons;
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final lesson in lessons) {
      groups.putIfAbsent(_periodKey(lesson), () => []).add(lesson);
    }
    final ids = lessons
        .map((lesson) => asInt(lesson['id']))
        .whereType<int>()
        .toList();
    final selectedCount = ids.where(_selectedLessonIds.contains).length;
    final allValue = selectedCount == 0
        ? false
        : selectedCount == ids.length
        ? true
        : null;

    return SubPage(
      title: l.resetGradesTitle,
      body: _loadingSetup
          ? const Center(child: CircularProgressIndicator())
          : year == null
          ? EmptyState(
              icon: Icons.calendar_month_outlined,
              message: l.resetGradesNoActiveYear,
            )
          : _error != null && _lessons == null
          ? ErrorState(error: _error!, onRetry: _loadLessons)
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: _loadLessons,
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      _chosen.isEmpty ? 24 : 112,
                    ),
                    children: [
                      Row(
                        children: [
                          IconButton(
                            tooltip: l.resetGradesPreviousDay,
                            onPressed:
                                _firstDate != null &&
                                    !_date.isAfter(_firstDate!)
                                ? null
                                : () => _shiftDate(-1),
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: _pickDate,
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                              ),
                              label: Text(
                                DateFormat.MMMEd(locale).format(_date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: l.resetGradesNextDay,
                            onPressed:
                                _lastDate != null && !_date.isBefore(_lastDate!)
                                ? null
                                : () => _shiftDate(1),
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _groups.isEmpty ? null : _pickClasses,
                            icon: const Icon(Icons.class_rounded, size: 18),
                            label: Text(
                              _selectedGroupIds.isEmpty
                                  ? l.resetGradesAllClasses
                                  : l.resetGradesClassesSelected(
                                      _selectedGroupIds.length,
                                    ),
                            ),
                          ),
                          SegmentedButton<bool>(
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(l.resetGradesGraded),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(l.resetGradesAll),
                              ),
                            ],
                            selected: {_showAll},
                            onSelectionChanged: (selection) => setState(() {
                              _showAll = selection.first;
                              _selectedLessonIds.clear();
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_loadingLessons)
                        const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (lessons.isEmpty)
                        EmptyState(
                          icon: Icons.event_busy_outlined,
                          message: !_showAll && _classLessons.isNotEmpty
                              ? l.resetGradesNothingGraded
                              : l.resetGradesNothing,
                        )
                      else ...[
                        AppCard(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            value: allValue,
                            tristate: true,
                            title: Text(l.resetGradesSelectAll),
                            subtitle: Text(
                              l.resetGradesSelectedCount(
                                selectedCount,
                                ids.length,
                              ),
                            ),
                            onChanged: (_) => _toggleLessons(ids),
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in groups.entries) ...[
                          _PeriodHeader(
                            title: entry.key,
                            count: entry.value.length,
                            selected: entry.value
                                .map((lesson) => asInt(lesson['id']))
                                .whereType<int>()
                                .where(_selectedLessonIds.contains)
                                .length,
                            onTap: () => _toggleLessons(
                              entry.value
                                  .map((lesson) => asInt(lesson['id']))
                                  .whereType<int>(),
                            ),
                          ),
                          for (final lesson in entry.value)
                            _LessonTile(
                              lesson: lesson,
                              period: _periodKey(lesson),
                              selected: _selectedLessonIds.contains(
                                asInt(lesson['id']),
                              ),
                              groupName: _groupName(lesson),
                              onTap: () {
                                final id = asInt(lesson['id']);
                                if (id != null) _toggleLessons([id]);
                              },
                            ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (_chosen.isNotEmpty)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: Material(
                      elevation: 4,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                        child: Row(
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_chosen.length}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  l.resetGradesGradedCount(_chosenGrades),
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: l.resetGradesClearSelection,
                              onPressed: () =>
                                  setState(() => _selectedLessonIds.clear()),
                              icon: const Icon(Icons.close_rounded),
                            ),
                            FilledButton.icon(
                              onPressed: _saving ? null : _confirmReset,
                              style: FilledButton.styleFrom(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.error,
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onError,
                              ),
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.restart_alt_rounded),
                              label: Text(l.reset),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _PeriodHeader extends StatelessWidget {
  const _PeriodHeader({
    required this.title,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final int count;
  final int selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 4),
        child: Row(
          children: [
            Icon(
              selected == 0
                  ? Icons.check_box_outline_blank_rounded
                  : selected == count
                  ? Icons.check_box_rounded
                  : Icons.indeterminate_check_box_rounded,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            Text(
              '$selected/$count',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({
    required this.lesson,
    required this.period,
    required this.selected,
    required this.groupName,
    required this.onTap,
  });

  final Map<String, dynamic> lesson;
  final String period;
  final bool selected;
  final String groupName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final graded = asInt(lesson['grades_entered']) ?? 0;
    final roster = asInt(lesson['roster_size']) ?? 0;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: selected,
        onChanged: (_) => onTap(),
        title: Row(
          children: [
            SizedBox(
              width: 46,
              child: Text(
                groupName,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                asStr(lesson['subject']) ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              roster > 0 ? '$graded/$roster' : '$graded',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: graded > 0
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
        subtitle: Text(
          [
            period,
            ?asStr(lesson['substitute_teacher']) ?? asStr(lesson['teacher']),
          ].join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        dense: true,
      ),
    );
  }
}
