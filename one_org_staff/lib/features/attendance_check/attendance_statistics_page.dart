import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

/// Attendance totals and class/student breakdowns from the web's statistics API.
class AttendanceStatisticsPage extends StatefulWidget {
  const AttendanceStatisticsPage({super.key, required this.ctx});

  final StaffContext ctx;

  @override
  State<AttendanceStatisticsPage> createState() =>
      _AttendanceStatisticsPageState();
}

class _AttendanceStatisticsPageState extends State<AttendanceStatisticsPage> {
  bool _month = false;
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _groups = [];
  List<Map<String, dynamic>> _students = [];
  Object? _error;
  bool _loading = true;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final now = DateTime.now();
    final start = _month
        ? DateTime(now.year, now.month)
        : DateTime(now.year, now.month, now.day - now.weekday + 1);
    final query = {'start_date': isoDay(start), 'end_date': isoDay(now)};
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.ctx.api.get('/attendance/statistics', query),
        widget.ctx.api.get('/attendance/statistics/by-group', query),
        widget.ctx.api.get('/attendance/statistics/by-student', query),
      ]);
      if (!mounted || request != _request) return;
      setState(() {
        _summary = ApiClient.one(results[0]);
        _groups = ApiClient.rows(results[1]);
        _students = ApiClient.rows(results[2]);
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final summary = _summary;
    final groups = [..._groups]
      ..sort(
        (a, b) => (asDouble(a['attendance_rate']) ?? 0).compareTo(
          asDouble(b['attendance_rate']) ?? 0,
        ),
      );
    final students = [..._students]
      ..sort(
        (a, b) => (asDouble(a['attendance_rate']) ?? 0).compareTo(
          asDouble(b['attendance_rate']) ?? 0,
        ),
      );

    Widget count(String label, String key) => Expanded(
      child: Column(
        children: [
          Text(
            '${asInt(summary?[key]) ?? 0}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          Text(label, style: TextStyle(color: colors.mutedText, fontSize: 12)),
        ],
      ),
    );

    Widget section(
      String title,
      List<Map<String, dynamic>> rows,
      String Function(Map<String, dynamic>) name,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty) Text(l.attNoMarks),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: AppCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      name(row),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${NumberFormat('0.#').format(asDouble(row['attendance_rate']) ?? 0)}%',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${asInt(row['present']) ?? 0} + ${asInt(row['late']) ?? 0} / ${asInt(row['total']) ?? 0}',
                        style: TextStyle(color: colors.mutedText, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return SubPage(
      title: l.attStatistics,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.attThisWeek)),
                ButtonSegment(value: true, label: Text(l.attThisMonth)),
              ],
              selected: {_month},
              onSelectionChanged: (values) {
                setState(() => _month = values.first);
                _load();
              },
            ),
            if (_loading) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              ErrorState(error: _error!, onRetry: _load),
            ],
            if (!_loading && _error == null && summary != null) ...[
              const SizedBox(height: 16),
              AppCard(
                child: Column(
                  children: [
                    Text(
                      l.attAttendanceRate,
                      style: TextStyle(color: colors.mutedText),
                    ),
                    Text(
                      '${NumberFormat('0.#').format(asDouble(summary['attendance_rate']) ?? 0)}%',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        count(l.attPresent, 'present'),
                        count(l.attLate, 'late'),
                        count(l.attAbsent, 'absent'),
                        count(l.attExcused, 'excused'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              section(
                l.attByClass,
                groups,
                (row) =>
                    asStr(row['class_pair'])?.replaceAll('-', '') ??
                    asStr(row['group_name']) ??
                    '#${row['group_id']}',
              ),
              const SizedBox(height: 16),
              section(
                l.attByStudent,
                students,
                (row) => asStr(row['full_name']) ?? '#${row['student_id']}',
              ),
            ],
          ],
        ),
      ),
    );
  }
}
