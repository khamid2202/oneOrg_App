import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

/// A department's statistics for its heads and deputies (and `read_all`
/// holders, who can pick any department): lessons, attendance and grade
/// completeness, averages and exams per teacher, subject and class over the
/// active year — the web's `/my-department`.
class MyDepartmentPage extends StatefulWidget {
  const MyDepartmentPage({super.key, required this.ctx});
  final StaffContext ctx;

  @override
  State<MyDepartmentPage> createState() => _MyDepartmentPageState();
}

class _Dept {
  const _Dept(this.id, this.name, this.role);
  final int id;
  final String name;
  final String? role;
}

class _MyDepartmentPageState extends State<MyDepartmentPage> {
  List<_Dept>? _departments;
  int? _departmentId;
  int? _groupId;
  List<(int, String)> _groups = const [];
  String _tab = 'teachers';
  String _sort = 'name';
  bool _desc = false;
  Map<String, dynamic>? _stats;
  bool _loading = false;
  Object? _error;

  StaffContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    setState(() => _error = null);
    try {
      final readAll = ctx.can('departments.read_all');
      final mine = ApiClient.rows(await ctx.api.get('/departments/my'))
          .where(
            (d) =>
                d['is_active'] != false &&
                (d['role'] == 'head' || d['role'] == 'deputy'),
          )
          .toList();
      final ids = {for (final d in mine) asInt(d['id'])};
      final all = readAll
          ? ApiClient.rows(
              await ctx.api.get('/departments', {'is_active': 'true'}),
            )
          : const <Map<String, dynamic>>[];
      final list = [
        for (final d in mine)
          _Dept(asInt(d['id'])!, asStr(d['name']) ?? '', asStr(d['role'])),
        for (final d in all)
          if (!ids.contains(asInt(d['id'])))
            _Dept(asInt(d['id'])!, asStr(d['name']) ?? '', null),
      ];
      if (!mounted) return;
      setState(() {
        _departments = list;
        _departmentId = list.firstOrNull?.id;
      });
      _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _departments = const [];
        });
      }
    }
  }

  Future<void> _load() async {
    final id = _departmentId;
    if (id == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final year = await ctx.academicYear();
      final body = await ctx.api.get('/departments/$id/statistics', {
        if (year?.startDate != null && year?.endDate != null) ...{
          'start_date': year!.startDate!.substring(0, 10),
          'end_date': year.endDate!.substring(0, 10),
        },
        'group_id': _groupId,
      });
      final stats = ApiClient.one(body);
      if (!mounted || id != _departmentId) return;
      setState(() {
        _stats = stats;
        if (_groupId == null) {
          _groups = [
            for (final g in (stats['groups'] as List? ?? const []))
              if (g is Map)
                (
                  asInt(g['group_id']) ?? 0,
                  _groupName(Map<String, dynamic>.from(g)),
                ),
          ]..sort((a, b) => a.$2.compareTo(b.$2));
        }
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static String _groupName(Map<String, dynamic> g) =>
      asStr(g['name']) ??
      [g['grade'], g['class']].where((p) => p != null).join('-');

  static String _fmt(Object? v, [String suffix = '']) {
    final n = asDouble(v);
    if (n == null) return '—';
    final text = n == n.roundToDouble() ? '${n.toInt()}' : n.toStringAsFixed(1);
    return '$text$suffix';
  }

  static Color? _completeness(Object? v) {
    final n = asDouble(v);
    if (n == null) return null;
    return n < 70
        ? Colors.red.shade600
        : n < 90
        ? Colors.amber.shade700
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final departments = _departments;
    final stats = _stats;
    final summary = stats?['summary'] is Map
        ? Map<String, dynamic>.from(stats!['summary'])
        : null;

    String roleLabel(String? r) => r == 'head'
        ? l.deptHead
        : r == 'deputy'
        ? l.deptDeputy
        : '';

    final title = departments != null && departments.length == 1
        ? departments.first.name
        : l.myDepartment;

    Widget body;
    if (departments == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (departments.isEmpty) {
      body = _error != null
          ? ErrorState(error: _error!, onRetry: _loadDepartments)
          : EmptyState(icon: Icons.account_tree_outlined, message: l.deptNone);
    } else {
      final rows = _rows(stats);
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (departments.length > 1)
              DropdownButtonFormField<int>(
                initialValue: _departmentId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.myDepartment),
                items: [
                  for (final d in departments)
                    DropdownMenuItem(
                      value: d.id,
                      child: Text(
                        d.role == null
                            ? d.name
                            : '${d.name} · ${roleLabel(d.role)}',
                      ),
                    ),
                ],
                onChanged: (v) {
                  setState(() {
                    _departmentId = v;
                    _groupId = null;
                    _groups = const [];
                  });
                  _load();
                },
              ),
            if (summary != null) ...[
              const SizedBox(height: 8),
              Text(
                l.deptCounts(
                  asInt(summary['subject_count']) ?? 0,
                  asInt(summary['member_count']) ?? 0,
                ),
                style: TextStyle(color: colors.mutedText, fontSize: 12),
              ),
              const SizedBox(height: 8),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 6,
                crossAxisSpacing: 6,
                childAspectRatio: 1.5,
                children: [
                  _tile(l.deptLessons, _fmt(summary['lessons']), null),
                  _tile(
                    l.deptAttendanceTaken,
                    _fmt(summary['attendance_marked_percent'], '%'),
                    _completeness(summary['attendance_marked_percent']),
                  ),
                  _tile(
                    l.deptGradesEntered,
                    _fmt(summary['grades_entered_percent'], '%'),
                    _completeness(summary['grades_entered_percent']),
                  ),
                  _tile(l.deptAvgGrade, _fmt(summary['average_grade']), null),
                  _tile(
                    l.deptAttendance,
                    _fmt(summary['attendance_rate'], '%'),
                    null,
                  ),
                  _tile(
                    l.deptExamAvg,
                    _fmt(summary['exam_average_percent'], '%'),
                    null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'teachers', label: Text(l.deptTeachers)),
                ButtonSegment(value: 'subjects', label: Text(l.deptSubjects)),
                ButtonSegment(value: 'groups', label: Text(l.deptClasses)),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() {
                _tab = s.first;
                _sort = 'name';
                _desc = false;
              }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_groups.isNotEmpty)
                  Expanded(
                    child: DropdownButton<int?>(
                      value: _groupId,
                      isExpanded: true,
                      hint: Text(l.deptAllClasses),
                      items: [
                        DropdownMenuItem(
                          value: null,
                          child: Text(l.deptAllClasses),
                        ),
                        for (final g in _groups)
                          DropdownMenuItem(value: g.$1, child: Text(g.$2)),
                      ],
                      onChanged: (v) {
                        setState(() => _groupId = v);
                        _load();
                      },
                    ),
                  )
                else
                  const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.sort_rounded),
                  onSelected: (v) => setState(() {
                    if (_sort == v) {
                      _desc = !_desc;
                    } else {
                      _sort = v;
                      _desc = v != 'name';
                    }
                  }),
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'name', child: Text(l.laSortName)),
                    PopupMenuItem(value: 'lessons', child: Text(l.deptLessons)),
                    PopupMenuItem(
                      value: 'attendance_marked_percent',
                      child: Text(l.deptAttendanceTaken),
                    ),
                    PopupMenuItem(
                      value: 'grades_entered_percent',
                      child: Text(l.deptGradesEntered),
                    ),
                    PopupMenuItem(
                      value: 'average_grade',
                      child: Text(l.deptAvgGrade),
                    ),
                    PopupMenuItem(
                      value: 'attendance_rate',
                      child: Text(l.deptAttendance),
                    ),
                    if (_tab == 'teachers')
                      PopupMenuItem(value: 'kpi_points', child: Text(l.deptKpi))
                    else
                      PopupMenuItem(
                        value: 'exam_average_percent',
                        child: Text(l.deptExamAvg),
                      ),
                  ],
                ),
              ],
            ),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null) ErrorState(error: _error!, onRetry: _load),
            for (final r in rows) _rowCard(context, l, r, roleLabel),
          ],
        ),
      );
    }
    return SubPage(title: title, body: body);
  }

  List<Map<String, dynamic>> _rows(Map<String, dynamic>? stats) {
    if (stats == null) return const [];
    final raw = stats[_tab];
    final list = raw is List
        ? raw.whereType<Map>().map((m) {
            final row = Map<String, dynamic>.from(m);
            row['_name'] = _tab == 'teachers'
                ? asStr(row['full_name']) ?? ''
                : _tab == 'subjects'
                ? asStr(row['name']) ?? ''
                : _groupName(row);
            return row;
          }).toList()
        : <Map<String, dynamic>>[];
    final sign = _desc ? -1 : 1;
    list.sort((a, b) {
      if (_sort == 'name') {
        return sign * '${a['_name']}'.compareTo('${b['_name']}');
      }
      final x = asDouble(a[_sort]), y = asDouble(b[_sort]);
      if (x == null) return y == null ? 0 : 1;
      if (y == null) return -1;
      return sign * x.compareTo(y);
    });
    return list;
  }

  Widget _tile(String label, String value, Color? tone) {
    final colors = appColorsOf(context);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: colors.softBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: tone,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: colors.mutedText),
          ),
        ],
      ),
    );
  }

  Widget _rowCard(
    BuildContext context,
    AppLocalizations l,
    Map<String, dynamic> r,
    String Function(String?) roleLabel,
  ) {
    final colors = appColorsOf(context);
    final role = asStr(r['role']);
    Widget fig(String label, String value, [Color? tone]) => Padding(
      padding: const EdgeInsets.only(right: 14, top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.w700, color: tone),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: colors.mutedText)),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${r['_name']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                if (role == 'head' || role == 'deputy')
                  Tag(roleLabel(role), color: colors.accent.solid),
              ],
            ),
            Wrap(
              children: [
                fig(l.deptLessons, _fmt(r['lessons'])),
                fig(
                  l.deptAttendanceTaken,
                  _fmt(r['attendance_marked_percent'], '%'),
                  _completeness(r['attendance_marked_percent']),
                ),
                fig(
                  l.deptGradesEntered,
                  _fmt(r['grades_entered_percent'], '%'),
                  _completeness(r['grades_entered_percent']),
                ),
                fig(l.deptGrades, _fmt(r['grade_count'])),
                fig(l.deptAvgGrade, _fmt(r['average_grade'])),
                fig(l.deptAttendance, _fmt(r['attendance_rate'], '%')),
                if (_tab == 'teachers')
                  fig(l.deptKpi, _fmt(r['kpi_points']))
                else
                  fig(
                    l.deptExamAvg,
                    (asInt(r['exam_result_count']) ?? 0) > 0
                        ? '${_fmt(r['exam_average_percent'], '%')} (${r['exam_result_count']})'
                        : '—',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
