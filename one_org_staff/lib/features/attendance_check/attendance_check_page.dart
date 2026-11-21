import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';
import 'attendance_statistics_page.dart';

enum _State { done, overdue, open, upcoming, cancelled, empty }

const _rank = {
  _State.overdue: 4,
  _State.open: 3,
  _State.upcoming: 2,
  _State.done: 1,
  _State.empty: 0,
  _State.cancelled: 0,
};

String _hhmm(Object? t) {
  final s = '${t ?? ''}';
  return s.length >= 5 ? s.substring(0, 5) : s;
}

_State _stateOf(Map<String, dynamic> l, String date, String today, String now) {
  if (l['status'] == 'cancelled') return _State.cancelled;
  if ((asInt(l['attendance_marked']) ?? 0) > 0) return _State.done;
  if (asInt(l['roster_size']) == 0) return _State.empty;
  if (date.compareTo(today) < 0 ||
      (date == today && _hhmm(l['end_time']).compareTo(now) <= 0)) {
    return _State.overdue;
  }
  if (date == today && _hhmm(l['start_time']).compareTo(now) <= 0) {
    return _State.open;
  }
  return _State.upcoming;
}

Color _tone(_State s) => switch (s) {
  _State.done => const Color(0xFF10B981),
  _State.overdue => const Color(0xFFEF4444),
  _State.open => const Color(0xFFF59E0B),
  _State.upcoming => Colors.blueGrey,
  _State.cancelled || _State.empty => Colors.grey,
};

/// Today's attendance, lesson by lesson: every class with its periods, and
/// which lessons are marked — the web's Attendance "Today" board.
class AttendanceCheckPage extends StatefulWidget {
  const AttendanceCheckPage({super.key, required this.ctx});
  final StaffContext ctx;

  @override
  State<AttendanceCheckPage> createState() => _AttendanceCheckPageState();
}

class _AttendanceCheckPageState extends State<AttendanceCheckPage> {
  late String _date = isoDay(DateTime.now());
  List<Map<String, dynamic>>? _lessons;
  Object? _error;
  bool _onlyMissing = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(minutes: 3), (_) {
      if (_date == isoDay(DateTime.now())) _load();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final body = await widget.ctx.api.get('/lesson-instances', {
        'date': _date,
      });
      final rows = ApiClient.rows(
        body is Map && body['lessons'] is List
            ? {'result': body['lessons']}
            : body,
      );
      if (mounted) {
        setState(() {
          _lessons = rows;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _shift(int days) {
    setState(() {
      _date = isoDay(DateTime.parse(_date).add(Duration(days: days)));
      _lessons = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final today = isoDay(DateTime.now());
    final now = DateFormat('HH:mm').format(DateTime.now());
    final lessons = _lessons ?? const <Map<String, dynamic>>[];

    // classId → period → lessons
    final cells = <int, Map<int, List<Map<String, dynamic>>>>{};
    final names = <int, String>{};
    for (final x in lessons) {
      final p = asInt(x['period_number']) ?? 0;
      final ids = x['group_ids'] is List
          ? (x['group_ids'] as List).map(asInt).whereType<int>().toList()
          : [?asInt(x['group_id'])];
      for (final id in ids) {
        names[id] ??= id == asInt(x['group_id'])
            ? (asStr(x['class_pair'])?.replaceAll('-', '') ??
                  '${x['grade'] ?? ''}${x['class'] ?? ''}')
            : '#$id';
        cells.putIfAbsent(id, () => {}).putIfAbsent(p, () => []).add(x);
      }
    }
    final totals = {for (final s in _State.values) s: 0};
    final seen = <Object?>{};
    for (final x in lessons) {
      if (seen.add(x['id'])) {
        totals[_stateOf(x, _date, today, now)] =
            totals[_stateOf(x, _date, today, now)]! + 1;
      }
    }
    int gradeOf(String n) =>
        int.tryParse(RegExp(r'^\d+').stringMatch(n) ?? '') ?? 999;
    final order = cells.keys.toList()
      ..sort((a, b) {
        final c = gradeOf(names[a]!) - gradeOf(names[b]!);
        return c != 0 ? c : names[a]!.compareTo(names[b]!);
      });

    return SubPage(
      title: l.attendanceCheck,
      actions: [
        IconButton(
          tooltip: l.attStatistics,
          icon: const Icon(Icons.bar_chart_rounded),
          onPressed: () => SubPage.push<void>(
            context,
            AttendanceStatisticsPage(ctx: widget.ctx),
          ),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    _date == today
                        ? l.calToday
                        : DateFormat.MMMEd(
                            locale,
                          ).format(DateTime.parse(_date)),
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
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                Tag(
                  '${l.attNotMarked}: ${totals[_State.overdue]}',
                  color: _tone(_State.overdue),
                ),
                Tag(
                  '${l.attOnNow}: ${totals[_State.open]}',
                  color: _tone(_State.open),
                ),
                Tag(
                  '${l.attMarked}: ${totals[_State.done]}',
                  color: _tone(_State.done),
                ),
                Tag(
                  '${l.attLater}: ${totals[_State.upcoming]}',
                  color: _tone(_State.upcoming),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(l.attOnlyMissing),
              value: _onlyMissing,
              onChanged: (v) => setState(() => _onlyMissing = v),
            ),
            if (_error != null) ErrorState(error: _error!, onRetry: _load),
            if (_lessons == null && _error == null)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_lessons != null && lessons.isEmpty)
              EmptyState(
                icon: Icons.event_busy_outlined,
                message: l.attNoLessons,
              ),
            for (final id in order)
              if (!_onlyMissing ||
                  cells[id]!.values
                      .expand((e) => e)
                      .any(
                        (x) => _stateOf(x, _date, today, now) == _State.overdue,
                      ))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 44,
                          child: Text(
                            names[id]!,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final p
                                  in (cells[id]!.keys.toList()..sort()))
                                _cell(
                                  context,
                                  p,
                                  cells[id]![p]!,
                                  today,
                                  now,
                                  colors,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    int period,
    List<Map<String, dynamic>> list,
    String today,
    String now,
    AppColors colors,
  ) {
    final states = list.map((x) => _stateOf(x, _date, today, now)).toList()
      ..sort((a, b) => _rank[b]! - _rank[a]!);
    final tone = _tone(states.first);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _details(list, today, now),
      child: Container(
        width: 38,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.12),
          border: Border.all(color: tone.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$period',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: tone,
                fontSize: 12,
              ),
            ),
            if (states.first == _State.done)
              Icon(Icons.check_rounded, size: 12, color: tone),
            if (list.length > 1)
              Text(
                '×${list.length}',
                style: TextStyle(fontSize: 9, color: tone),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _details(
    List<Map<String, dynamic>> list,
    String today,
    String now,
  ) async {
    final l = AppLocalizations.of(context);
    String stateText(_State s) => switch (s) {
      _State.done => l.attMarked,
      _State.overdue => l.attNotMarked,
      _State.open => l.attOnNow,
      _State.upcoming => l.attLater,
      _State.cancelled => l.calCancelled,
      _State.empty => l.attNoStudents,
    };
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            for (final x in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.circle,
                  size: 12,
                  color: _tone(_stateOf(x, _date, today, now)),
                ),
                title: Text(
                  [
                    asStr(x['subject']),
                    asStr(x['subgroup']),
                  ].whereType<String>().join(' · '),
                ),
                subtitle: Text(
                  [
                    '${_hhmm(x['start_time'])}–${_hhmm(x['end_time'])}',
                    ?asStr(x['substitute_teacher']) ?? asStr(x['teacher']),
                    stateText(_stateOf(x, _date, today, now)),
                    if ((asInt(x['attendance_absent']) ?? 0) > 0)
                      '${l.attAbsent}: ${x['attendance_absent']}',
                    if ((asInt(x['attendance_late']) ?? 0) > 0)
                      '${l.attLate}: ${x['attendance_late']}',
                  ].join(' · '),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
