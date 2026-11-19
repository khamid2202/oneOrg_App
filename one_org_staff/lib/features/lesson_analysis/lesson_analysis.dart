import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

/// Lesson observations (docs/staff/lesson-observations.md). An observer gives
/// a real lesson one mark and optional notes per criterion; the backend books
/// the mark as the teacher's points itself.
class Observation {
  Observation(this.raw);
  final Map<String, dynamic> raw;

  int get id => asInt(raw['id']) ?? 0;
  int? get teacherId => asInt(raw['teacher_id']);
  String get teacher => asStr(raw['teacher']) ?? '';
  String? get observer => asStr(raw['observer']);
  String get date => (asStr(raw['date']) ?? '').length >= 10
      ? asStr(raw['date'])!.substring(0, 10)
      : asStr(raw['date']) ?? '';
  num get points => asDouble(raw['points']) ?? 0;
  String get lesson => [
    _short(asStr(raw['start_time'])),
    asStr(raw['class_pair']),
    asStr(raw['subject']),
  ].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
  List<Map<String, dynamic>> get notes => raw['notes'] is List
      ? (raw['notes'] as List)
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList()
      : const [];
  bool get edited {
    final c = DateTime.tryParse('${raw['created_at']}');
    final u = DateTime.tryParse('${raw['updated_at']}');
    return c != null && u != null && u.difference(c).inSeconds > 60;
  }
}

String? _short(String? t) => t == null || t.length < 5 ? t : t.substring(0, 5);

String signedPoints(num n) {
  final v = (n * 10).round() / 10;
  final text = v == v.roundToDouble() ? '${v.toInt()}' : '$v';
  return v > 0 ? '+$text' : text;
}

Color? pointsTone(num n) => n > 0
    ? const Color(0xFF10B981)
    : n < 0
    ? const Color(0xFFF43F5E)
    : null;

Future<List<Observation>> fetchObservations(
  ApiClient api, [
  Map<String, Object?> query = const {},
]) async =>
    (await api.all('/lesson-observations', query)).map(Observation.new).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

enum AnalysisPeriod { thisMonth, lastMonth, all }

Map<String, Object?> periodQuery(AnalysisPeriod p, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return switch (p) {
    AnalysisPeriod.thisMonth => {
      'date_from': isoDay(DateTime(n.year, n.month, 1)),
      'date_to': isoDay(DateTime(n.year, n.month + 1, 0)),
    },
    AnalysisPeriod.lastMonth => {
      'date_from': isoDay(DateTime(n.year, n.month - 1, 1)),
      'date_to': isoDay(DateTime(n.year, n.month, 0)),
    },
    AnalysisPeriod.all => const {},
  };
}

/// A teacher's own results: every analysis of their lessons.
class MyLessonAnalysisPage extends StatefulWidget {
  const MyLessonAnalysisPage({super.key, required this.ctx});
  final StaffContext ctx;

  @override
  State<MyLessonAnalysisPage> createState() => _MyLessonAnalysisPageState();
}

class _MyLessonAnalysisPageState extends State<MyLessonAnalysisPage> {
  List<Observation>? _rows;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await fetchObservations(widget.ctx.api, {
        'teacher_id': widget.ctx.userId,
      });
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows;
    return SubPage(
      title: l.myLessonAnalysis,
      body: _error != null && rows == null
          ? ErrorState(error: _error!, onRetry: _load)
          : rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
          ? EmptyState(icon: Icons.fact_check_outlined, message: l.laNoneYet)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _StatStrip(rows: rows),
                  const SizedBox(height: 8),
                  ..._monthGroups(context, rows, (o) => AnalysisRow(o: o)),
                ],
              ),
            ),
    );
  }
}

class _StatStrip extends StatelessWidget {
  const _StatStrip({required this.rows});
  final List<Observation> rows;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final total = rows.fold<num>(0, (s, o) => s + o.points);
    final q = periodQuery(AnalysisPeriod.thisMonth);
    final month = rows
        .where(
          (o) =>
              o.date.compareTo('${q['date_from']}') >= 0 &&
              o.date.compareTo('${q['date_to']}') <= 0,
        )
        .fold<num>(0, (s, o) => s + o.points);
    final latest = rows.isEmpty ? null : DateTime.tryParse(rows.first.date);
    return Row(
      children: [
        _Stat(l.laTotalPoints, signedPoints(total), pointsTone(total)),
        _Stat(l.laThisMonth, signedPoints(month), pointsTone(month)),
        _Stat(l.laAnalyses, '${rows.length}', null),
        _Stat(
          l.laLatest,
          latest == null ? '—' : DateFormat.MMMd(locale).format(latest),
          null,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value, this.tone);
  final String label;
  final String value;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: colors.softBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: tone,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(fontSize: 11, color: colors.mutedText),
            ),
          ],
        ),
      ),
    );
  }
}

List<Widget> _monthGroups(
  BuildContext context,
  List<Observation> rows,
  Widget Function(Observation) row,
) {
  final colors = appColorsOf(context);
  final locale = Localizations.localeOf(context).toString();
  final groups = <String, List<Observation>>{};
  for (final o in rows) {
    groups
        .putIfAbsent(o.date.length >= 7 ? o.date.substring(0, 7) : '', () => [])
        .add(o);
  }
  return [
    for (final e in groups.entries) ...[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(
          DateTime.tryParse('${e.key}-01') == null
              ? '—'
              : DateFormat.yMMMM(
                  locale,
                ).format(DateTime.parse('${e.key}-01')).toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: colors.mutedText,
          ),
        ),
      ),
      for (final o in e.value)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: row(o)),
    ],
  ];
}

/// One analysis: date, lesson, observer, points; tap shows the notes.
class AnalysisRow extends StatefulWidget {
  const AnalysisRow({
    super.key,
    required this.o,
    this.showObserver = true,
    this.onEdit,
    this.onDelete,
  });

  final Observation o;
  final bool showObserver;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  State<AnalysisRow> createState() => _AnalysisRowState();
}

class _AnalysisRowState extends State<AnalysisRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final o = widget.o;
    final d = DateTime.tryParse(o.date);
    return AppCard(
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: colors.softBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      d == null ? '—' : '${d.day}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: colors.softText,
                      ),
                    ),
                    Text(
                      d == null ? '' : DateFormat.E(locale).format(d),
                      style: TextStyle(fontSize: 10, color: colors.softText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      o.lesson.isEmpty ? o.teacher : o.lesson,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      [
                        if (widget.showObserver && o.observer != null)
                          o.observer!,
                        if (o.notes.isNotEmpty) l.laNotesCount(o.notes.length),
                        if (o.edited) l.pointsEdited,
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                  ],
                ),
              ),
              Text(
                signedPoints(o.points),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: pointsTone(o.points),
                ),
              ),
            ],
          ),
          if (_open) ...[
            const SizedBox(height: 8),
            if (o.notes.isEmpty)
              Text(l.laNoNotes, style: TextStyle(color: colors.mutedText))
            else
              for (final n in o.notes)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asStr(n['criterion']) ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.softText,
                        ),
                      ),
                      Text(asStr(n['note']) ?? ''),
                    ],
                  ),
                ),
            if (widget.onEdit != null || widget.onDelete != null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (widget.onEdit != null)
                    TextButton.icon(
                      onPressed: widget.onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l.edit),
                    ),
                  if (widget.onDelete != null)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                      onPressed: widget.onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(l.delete),
                    ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// Departments the user leads (head or deputy) and their current members.
Future<Set<int>> ledMemberIds(ApiClient api) async {
  try {
    final led = ApiClient.rows(await api.get('/departments/my')).where(
      (d) =>
          d['is_active'] != false &&
          (d['role'] == 'head' || d['role'] == 'deputy'),
    );
    final ids = <int>{};
    for (final d in led) {
      try {
        final full = ApiClient.one(await api.get('/departments/${d['id']}'));
        for (final m in (full['members'] as List? ?? const [])) {
          if (m is Map && m['is_current'] != false) {
            final id = asInt(m['user_id']);
            if (id != null) ids.add(id);
          }
        }
      } catch (_) {}
    }
    return ids;
  } catch (_) {
    return {};
  }
}

/// Lesson Analysis for the Director, Academic Director and HODs: every teacher
/// with how often they were analysed in the period and the points it gave.
class LessonAnalysisPage extends StatefulWidget {
  const LessonAnalysisPage({super.key, required this.ctx});
  final StaffContext ctx;

  @override
  State<LessonAnalysisPage> createState() => _LessonAnalysisPageState();
}

class _LessonAnalysisPageState extends State<LessonAnalysisPage> {
  AnalysisPeriod _period = AnalysisPeriod.thisMonth;
  String _sort = 'last';
  String _search = '';
  bool _deptOnly = true;
  List<Observation>? _rows;
  List<Map<String, dynamic>> _teachers = const [];
  Set<int> _members = const {};
  Object? _error;
  int _req = 0;

  StaffContext get ctx => widget.ctx;
  bool get _canCreate => ctx.can('lesson_observations.create');

  @override
  void initState() {
    super.initState();
    _load();
    ctx.teachers().then((t) {
      if (mounted) setState(() => _teachers = t);
    });
    ledMemberIds(ctx.api).then((m) {
      if (mounted) setState(() => _members = m);
    });
  }

  Future<void> _load() async {
    final id = ++_req;
    setState(() => _error = null);
    try {
      final rows = await fetchObservations(ctx.api, periodQuery(_period));
      if (mounted && id == _req) setState(() => _rows = rows);
    } catch (e) {
      if (mounted && id == _req) setState(() => _error = e);
    }
  }

  bool _inScope(int? id) =>
      _members.isEmpty || !_deptOnly || (id != null && _members.contains(id));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final rows = (_rows ?? const <Observation>[])
        .where((o) => _inScope(o.teacherId))
        .toList();

    final names = <int, String>{
      for (final t in _teachers) asInt(t['id'])!: personName(t),
      for (final o in rows)
        if (o.teacherId != null) o.teacherId!: o.teacher,
    };
    final pool = names.keys.where(_inScope).toList();
    final info = <int, ({int count, num points, String last})>{};
    for (final o in rows) {
      final id = o.teacherId;
      if (id == null) continue;
      final t = info[id];
      info[id] = (
        count: (t?.count ?? 0) + 1,
        points: (t?.points ?? 0) + o.points,
        last: t == null || o.date.compareTo(t.last) > 0 ? o.date : t.last,
      );
    }
    final term = _search.trim().toLowerCase();
    final list =
        pool
            .where(
              (id) => term.isEmpty || names[id]!.toLowerCase().contains(term),
            )
            .toList()
          ..sort((a, b) {
            final ia = info[a], ib = info[b];
            int byName() => names[a]!.compareTo(names[b]!);
            if (_sort == 'name') return byName();
            if ((ia == null) != (ib == null)) return ia != null ? -1 : 1;
            if (ia == null || ib == null) return byName();
            if (_sort == 'most') {
              return ib.points.compareTo(ia.points) != 0
                  ? ib.points.compareTo(ia.points)
                  : byName();
            }
            if (_sort == 'least') {
              return ia.points.compareTo(ib.points) != 0
                  ? ia.points.compareTo(ib.points)
                  : byName();
            }
            final c = ib.last.compareTo(ia.last);
            return c != 0 ? c : byName();
          });
    final analysed = pool.where(info.containsKey).length;
    final percent = pool.isEmpty ? 0 : (analysed * 100 / pool.length).round();

    return SubPage(
      title: l.lessonAnalysis,
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _newAnalysis(),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.laNewAnalysis),
            )
          : null,
      body: _error != null && _rows == null
          ? ErrorState(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                children: [
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final (p, label) in [
                        (AnalysisPeriod.thisMonth, l.laThisMonth),
                        (AnalysisPeriod.lastMonth, l.laLastMonth),
                        (AnalysisPeriod.all, l.laAllTime),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _period == p,
                          onSelected: (_) {
                            setState(() => _period = p);
                            _load();
                          },
                        ),
                      if (_members.isNotEmpty)
                        FilterChip(
                          label: Text(l.laMyDepartment),
                          selected: _deptOnly,
                          onSelected: (v) => setState(() => _deptOnly = v),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AppCard(
                    color: colors.softBg,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: percent / 100,
                                strokeWidth: 6,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.laAnalysedOf(analysed, pool.length),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${l.laAnalyses}: ${rows.length} · ${l.laTotalPoints}: ${signedPoints(rows.fold<num>(0, (s, o) => s + o.points))}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.mutedText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search_rounded),
                            hintText: l.search,
                          ),
                          onChanged: (v) => setState(() => _search = v),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.sort_rounded),
                        initialValue: _sort,
                        onSelected: (v) => setState(() => _sort = v),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'last',
                            child: Text(l.laSortLast),
                          ),
                          PopupMenuItem(
                            value: 'most',
                            child: Text(l.laSortMost),
                          ),
                          PopupMenuItem(
                            value: 'least',
                            child: Text(l.laSortLeast),
                          ),
                          PopupMenuItem(
                            value: 'name',
                            child: Text(l.laSortName),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_rows == null)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  for (final id in list)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: colors.avatarPlaceholder,
                        child: Text(
                          names[id]!.isEmpty ? '?' : names[id]![0],
                          style: TextStyle(color: colors.softText),
                        ),
                      ),
                      title: Text(names[id]!),
                      subtitle: Text(
                        info[id] == null
                            ? l.laNotAnalysed
                            : '${l.laAnalysesCount(info[id]!.count)} · ${DateFormat.MMMd(locale).format(DateTime.parse(info[id]!.last))}',
                      ),
                      trailing: info[id] == null
                          ? null
                          : Text(
                              signedPoints(info[id]!.points),
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: pointsTone(info[id]!.points),
                              ),
                            ),
                      onTap: () async {
                        await SubPage.push(
                          context,
                          TeacherAnalysisPage(
                            ctx: ctx,
                            teacherId: id,
                            name: names[id]!,
                          ),
                        );
                        _load();
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _newAnalysis() async {
    final saved = await SubPage.push<bool>(
      context,
      AnalysisFormPage(ctx: ctx, teachers: _teachers),
    );
    if (saved == true) _load();
  }
}

/// One teacher's timeline of analyses, with edit and delete for whoever may.
class TeacherAnalysisPage extends StatefulWidget {
  const TeacherAnalysisPage({
    super.key,
    required this.ctx,
    required this.teacherId,
    required this.name,
  });
  final StaffContext ctx;
  final int teacherId;
  final String name;

  @override
  State<TeacherAnalysisPage> createState() => _TeacherAnalysisPageState();
}

class _TeacherAnalysisPageState extends State<TeacherAnalysisPage> {
  List<Observation>? _rows;
  Object? _error;

  StaffContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final rows = await fetchObservations(ctx.api, {
        'teacher_id': widget.teacherId,
      });
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _delete(Observation o) async {
    final l = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.laDeleteQ,
      message: l.laDeleteBody,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok) return;
    try {
      await ctx.api.delete('/lesson-observations/${o.id}');
      if (mounted) toast(context, l.laDeleted);
      _load();
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = _rows;
    final canUpdate = ctx.can('lesson_observations.update');
    final canDelete = ctx.can('lesson_observations.delete');
    return SubPage(
      title: widget.name,
      floatingActionButton: ctx.can('lesson_observations.create')
          ? FloatingActionButton.extended(
              onPressed: () async {
                final saved = await SubPage.push<bool>(
                  context,
                  AnalysisFormPage(
                    ctx: ctx,
                    teachers: [
                      {'id': widget.teacherId, 'full_name': widget.name},
                    ],
                    teacherId: widget.teacherId,
                  ),
                );
                if (saved == true) _load();
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l.laNewAnalysis),
            )
          : null,
      body: _error != null && rows == null
          ? ErrorState(error: _error!, onRetry: _load)
          : rows == null
          ? const Center(child: CircularProgressIndicator())
          : rows.isEmpty
          ? EmptyState(
              icon: Icons.fact_check_outlined,
              message: l.laNotAnalysed,
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                children: [
                  _StatStrip(rows: rows),
                  ..._monthGroups(
                    context,
                    rows,
                    (o) => AnalysisRow(
                      o: o,
                      onEdit: canUpdate
                          ? () async {
                              final saved = await SubPage.push<bool>(
                                context,
                                AnalysisFormPage(
                                  ctx: ctx,
                                  teachers: const [],
                                  observation: o,
                                ),
                              );
                              if (saved == true) _load();
                            }
                          : null,
                      onDelete: canDelete ? () => _delete(o) : null,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

/// New analysis (teacher → lesson → points → notes) or an edit of one
/// (points and notes only).
class AnalysisFormPage extends StatefulWidget {
  const AnalysisFormPage({
    super.key,
    required this.ctx,
    required this.teachers,
    this.teacherId,
    this.observation,
  });

  final StaffContext ctx;
  final List<Map<String, dynamic>> teachers;
  final int? teacherId;
  final Observation? observation;

  @override
  State<AnalysisFormPage> createState() => _AnalysisFormPageState();
}

class _AnalysisFormPageState extends State<AnalysisFormPage> {
  int? _teacherId;
  List<Map<String, dynamic>> _lessons = const [];
  Set<int> _done = const {};
  int? _lessonId;
  bool _lessonsLoading = false;
  final _points = TextEditingController(text: '0');
  List<Map<String, dynamic>> _criteria = const [];
  final Map<int, TextEditingController> _notes = {};
  bool _saving = false;

  bool get _isEdit => widget.observation != null;
  StaffContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    final o = widget.observation;
    if (o != null) {
      _points.text =
          '${o.points is double && o.points == o.points.roundToDouble() ? o.points.toInt() : o.points}';
      for (final n in o.notes) {
        final id = asInt(n['criterion_id']);
        if (id != null) {
          _notes[id] = TextEditingController(text: asStr(n['note']) ?? '');
        }
      }
    } else if (widget.teacherId != null) {
      _teacherId = widget.teacherId;
      _loadLessons();
    }
    _loadCriteria();
  }

  Future<void> _loadCriteria() async {
    try {
      final rows = ApiClient.rows(
        await ctx.api.get('/lesson-observation-criteria'),
      );
      if (mounted) setState(() => _criteria = rows);
    } catch (_) {}
  }

  Future<void> _loadLessons() async {
    final teacher = _teacherId;
    if (teacher == null) return;
    setState(() {
      _lessonsLoading = true;
      _lessons = const [];
      _lessonId = null;
    });
    try {
      final now = DateTime.now();
      final list =
          ApiClient.rows(
                await ctx.api.get('/lesson-instances', {
                  'teacher_id': teacher,
                  'from': isoDay(now.subtract(const Duration(days: 59))),
                  'to': isoDay(now),
                }),
              )
              .where((x) => x['status'] != 'cancelled' && _started(x, now))
              .toList()
            ..sort(
              (a, b) => '${b['date']} ${b['start_time']}'.compareTo(
                '${a['date']} ${a['start_time']}',
              ),
            );
      Set<int> done = {};
      if (list.isNotEmpty) {
        try {
          final mine = await fetchObservations(ctx.api, {
            'teacher_id': teacher,
            'observer_id': ctx.userId,
            'date_from': list.last['date'],
          });
          done = {for (final o in mine) ?asInt(o.raw['lesson_instance_id'])};
        } catch (_) {}
      }
      if (!mounted || teacher != _teacherId) return;
      setState(() {
        _lessons = list;
        _done = done;
        _lessonId = list
            .map((x) => asInt(x['id']))
            .firstWhere(
              (id) => id != null && !done.contains(id),
              orElse: () => null,
            );
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _lessonsLoading = false);
    }
  }

  static bool _started(Map<String, dynamic> lesson, DateTime now) {
    final date = DateTime.tryParse(
      '${lesson['date']}'.padRight(10).substring(0, 10).trim(),
    );
    if (date == null) return false;
    final parts = '${lesson['start_time'] ?? '00:00'}'.split(':');
    final start = DateTime(
      date.year,
      date.month,
      date.day,
      int.tryParse(parts[0]) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    return !start.isAfter(now);
  }

  String _lessonLabel(Map<String, dynamic> x) {
    final locale = Localizations.localeOf(context).toString();
    final d = DateTime.tryParse('${x['date']}');
    return [
      d == null ? '${x['date']}' : DateFormat.MMMEd(locale).format(d),
      _short(asStr(x['start_time'])),
      asStr(x['class_pair']),
      asStr(x['subject']),
    ].whereType<String>().join(' · ');
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final value = int.tryParse(_points.text.trim());
    if (!_isEdit && _teacherId == null) {
      return toast(context, l.laChooseTeacher);
    }
    if (!_isEdit && _lessonId == null) return toast(context, l.laChooseLesson);
    if (value == null || value.abs() > 100000) {
      return toast(context, l.laPointsWhole);
    }
    final notes = [
      for (final e in _notes.entries)
        if (e.value.text.trim().isNotEmpty)
          {'criterion_id': e.key, 'note': e.value.text.trim()},
    ];
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await ctx.api.patch('/lesson-observations/${widget.observation!.id}', {
          'points': value,
          'notes': notes,
        });
      } else {
        await ctx.api.post('/lesson-observations', {
          'lesson_instance_id': _lessonId,
          'teacher_id': _teacherId,
          'points': value,
          'notes': notes,
        });
      }
      if (mounted) {
        toast(context, l.laSaved);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.laSaveFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final shown = _criteria
        .where(
          (c) =>
              c['is_active'] != false ||
              (_notes[asInt(c['id'])]?.text.trim().isNotEmpty ?? false),
        )
        .toList();
    return SubPage(
      title: _isEdit ? l.laEditAnalysis : l.laNewAnalysis,
      actions: [
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isEdit)
            AppCard(
              color: colors.softBg,
              child: Text(
                '${widget.observation!.teacher}\n${widget.observation!.date} · ${widget.observation!.lesson}',
              ),
            )
          else ...[
            DropdownButtonFormField<int>(
              initialValue: _teacherId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l.laTeacher),
              items: [
                for (final t in widget.teachers)
                  DropdownMenuItem(
                    value: asInt(t['id']),
                    child: Text(personName(t)),
                  ),
              ],
              onChanged: widget.teacherId != null
                  ? null
                  : (v) {
                      setState(() => _teacherId = v);
                      _loadLessons();
                    },
            ),
            const SizedBox(height: 12),
            if (_lessonsLoading)
              const LinearProgressIndicator()
            else if (_teacherId != null && _lessons.isEmpty)
              Text(l.laNoLessons, style: TextStyle(color: colors.mutedText))
            else if (_lessons.isNotEmpty)
              DropdownButtonFormField<int>(
                initialValue: _lessonId,
                isExpanded: true,
                decoration: InputDecoration(labelText: l.laLesson),
                items: [
                  for (final x in _lessons)
                    DropdownMenuItem(
                      value: asInt(x['id']),
                      enabled: !_done.contains(asInt(x['id'])),
                      child: Text(
                        _done.contains(asInt(x['id']))
                            ? '${_lessonLabel(x)} · ${l.laAnalysed}'
                            : _lessonLabel(x),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _lessonId = v),
              ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _points,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(labelText: l.laPoints),
          ),
          const SizedBox(height: 16),
          if (shown.isNotEmpty)
            Text(
              l.laNotes,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          for (final c in shown)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextField(
                controller: _notes.putIfAbsent(
                  asInt(c['id'])!,
                  TextEditingController.new,
                ),
                minLines: 1,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: asStr(c['name']) ?? asStr(c['title']) ?? '',
                  helperText: asStr(c['description']),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
