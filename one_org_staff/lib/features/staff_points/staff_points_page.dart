import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';
import '../me/domain/my_records.dart';
import '../me/presentation/my_points_page.dart';
import '../me/presentation/period_bar.dart' show signedNumber, toneOf;

enum _Period { week, month, year, all }

Map<String, Object?> _range(_Period p) {
  final n = DateTime.now();
  return switch (p) {
    _Period.week => {
      'date_from': isoDay(DateTime(n.year, n.month, n.day - (n.weekday - 1))),
      'date_to': isoDay(n),
    },
    _Period.month => {
      'date_from': isoDay(DateTime(n.year, n.month, 1)),
      'date_to': isoDay(DateTime(n.year, n.month + 1, 0)),
    },
    _Period.year => {
      'date_from': '${n.year}-01-01',
      'date_to': '${n.year}-12-31',
    },
    _Period.all => const {},
  };
}

/// Everyone's points: totals per staff member for a period, and awarding or
/// deducting — the guarded counterpart of My Points (`user_points.*`).
class StaffPointsPage extends StatefulWidget {
  const StaffPointsPage({super.key, required this.ctx, required this.me});
  final StaffContext ctx;
  final MyRepository? me;

  @override
  State<StaffPointsPage> createState() => _StaffPointsPageState();
}

class _StaffPointsPageState extends State<StaffPointsPage> {
  _Period _period = _Period.month;
  List<Map<String, dynamic>>? _records;
  List<Map<String, dynamic>> _staff = const [];
  String _search = '';
  bool _teachersOnly = false;
  Object? _error;
  int _req = 0;

  StaffContext get ctx => widget.ctx;

  @override
  void initState() {
    super.initState();
    _load();
    ctx.staff().then((s) {
      if (mounted) setState(() => _staff = s);
    });
  }

  Future<void> _load() async {
    final id = ++_req;
    setState(() => _error = null);
    try {
      final rows = await ctx.api.all('/user-points', _range(_period), 100, 50);
      if (mounted && id == _req) setState(() => _records = rows);
    } catch (e) {
      if (mounted && id == _req) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final totals = <int, int>{};
    final counts = <int, int>{};
    for (final r in _records ?? const <Map<String, dynamic>>[]) {
      final id = asInt(r['user_id']) ?? asInt((r['user'] as Map?)?['id']);
      if (id == null) continue;
      totals[id] = (totals[id] ?? 0) + (asDouble(r['points'])?.round() ?? 0);
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final users = <int, Map<String, dynamic>>{
      for (final u in _staff)
        if (asInt(u['id']) != null &&
            (u['status'] == null || u['status'] == 'active'))
          asInt(u['id'])!: u,
    };
    for (final r in _records ?? const <Map<String, dynamic>>[]) {
      final id = asInt(r['user_id']);
      if (id != null && !users.containsKey(id)) {
        users[id] = {
          'id': id,
          'full_name':
              asStr(r['user_name']) ??
              asStr((r['user'] as Map?)?['full_name']) ??
              '#$id',
        };
      }
    }
    final term = _search.trim().toLowerCase();
    final list =
        users.values
            .where(
              (u) =>
                  (term.isEmpty ||
                      personName(u).toLowerCase().contains(term)) &&
                  (!_teachersOnly || userRoles(u).contains('teacher')),
            )
            .toList()
          ..sort((a, b) {
            final c = (totals[asInt(b['id'])] ?? 0).compareTo(
              totals[asInt(a['id'])] ?? 0,
            );
            return c != 0 ? c : personName(a).compareTo(personName(b));
          });
    final net = totals.values.fold<int>(0, (s, v) => s + v);

    return SubPage(
      title: l.staffPoints,
      floatingActionButton: ctx.can('user_points.create')
          ? FloatingActionButton.extended(
              onPressed: () => _award(null),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.spAward),
            )
          : null,
      body: _error != null && _records == null
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
                        (_Period.week, l.spThisWeek),
                        (_Period.month, l.laThisMonth),
                        (_Period.year, l.spThisYear),
                        (_Period.all, l.laAllTime),
                      ])
                        ChoiceChip(
                          label: Text(label),
                          selected: _period == p,
                          onSelected: (_) {
                            setState(() => _period = p);
                            _load();
                          },
                        ),
                      FilterChip(
                        label: Text(l.deptTeachers),
                        selected: _teachersOnly,
                        onSelected: (v) => setState(() => _teachersOnly = v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l.search,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${l.historyCount(_records?.length ?? 0)} · ${signedNumber(net)}',
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                  ),
                  if (_records == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  for (final u in list)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: CircleAvatar(
                        backgroundColor: colors.avatarPlaceholder,
                        backgroundImage: asStr(u['picture_url']) == null
                            ? null
                            : NetworkImage(asStr(u['picture_url'])!),
                        child: asStr(u['picture_url']) == null
                            ? Text(
                                personName(u).isEmpty ? '?' : personName(u)[0],
                                style: TextStyle(color: colors.softText),
                              )
                            : null,
                      ),
                      title: Text(personName(u)),
                      subtitle: Text(
                        l.historyCount(counts[asInt(u['id'])] ?? 0),
                      ),
                      trailing: Text(
                        signedNumber(totals[asInt(u['id'])] ?? 0),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: toneOf(totals[asInt(u['id'])] ?? 0),
                        ),
                      ),
                      onTap: () => _openUser(u),
                    ),
                ],
              ),
            ),
    );
  }

  Future<void> _award(Map<String, dynamic>? user) async {
    final saved = await SubPage.push<bool>(
      context,
      PointsFormPage(ctx: ctx, user: user),
    );
    if (saved == true) _load();
  }

  Future<void> _openUser(Map<String, dynamic> u) async {
    final me = widget.me;
    final id = asInt(u['id'])!;
    if (me == null) return;
    await SubPage.push(
      context,
      _UserPointsPage(
        ctx: ctx,
        me: me,
        user: u,
        userId: id,
        onAward: () => _award(u),
      ),
    );
    _load();
  }
}

class _UserPointsPage extends StatefulWidget {
  const _UserPointsPage({
    required this.ctx,
    required this.me,
    required this.user,
    required this.userId,
    required this.onAward,
  });
  final StaffContext ctx;
  final MyRepository me;
  final Map<String, dynamic> user;
  final int userId;
  final Future<void> Function() onAward;

  @override
  State<_UserPointsPage> createState() => _UserPointsPageState();
}

class _UserPointsPageState extends State<_UserPointsPage> {
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SubPage(
      title: personName(widget.user),
      floatingActionButton: widget.ctx.can('user_points.create')
          ? FloatingActionButton.extended(
              onPressed: () async {
                await widget.onAward();
                if (mounted) setState(() => _version++);
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(l.spAward),
            )
          : null,
      body: MyPointsPage(
        key: ValueKey('points-${widget.userId}-$_version'),
        repository: widget.me,
        userId: widget.userId,
        loadNames: () async => {
          for (final u in await widget.ctx.staff())
            if (asInt(u['id']) != null) asInt(u['id'])!: personName(u),
        },
        bottomInset: 80,
      ),
    );
  }
}

/// Award or deduct points for one or more staff members.
class PointsFormPage extends StatefulWidget {
  const PointsFormPage({super.key, required this.ctx, this.user});
  final StaffContext ctx;
  final Map<String, dynamic>? user;

  @override
  State<PointsFormPage> createState() => _PointsFormPageState();
}

class _PointsFormPageState extends State<PointsFormPage> {
  final Set<int> _recipients = {};
  List<Map<String, dynamic>> _staff = const [];
  List<Map<String, dynamic>> _categories = const [];
  int? _category;
  bool _deduct = false;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final id = asInt(widget.user?['id']);
    if (id != null) _recipients.add(id);
    widget.ctx.staff().then((s) {
      if (mounted) {
        setState(
          () => _staff =
              s
                  .where((u) => u['status'] == null || u['status'] == 'active')
                  .toList()
                ..sort((a, b) => personName(a).compareTo(personName(b))),
        );
      }
    });
    widget.ctx.api
        .get('/point-categories')
        .then((res) {
          if (mounted) {
            setState(
              () => _categories = ApiClient.rows(
                res,
              ).where((c) => c['is_active'] != false).toList(),
            );
          }
        })
        .catchError((_) {});
  }

  Future<void> _pickRecipients() async {
    final l = AppLocalizations.of(context);
    final picked = Set<int>.of(_recipients);
    var term = '';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (context, controller) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: l.search,
                        ),
                        onChanged: (v) =>
                            setSheet(() => term = v.toLowerCase()),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setSheet(
                        () => picked.addAll([
                          for (final u in _staff)
                            if (userRoles(u).contains('teacher'))
                              asInt(u['id'])!,
                        ]),
                      ),
                      child: Text(l.spAllTeachers),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    for (final u in _staff)
                      if (term.isEmpty ||
                          personName(u).toLowerCase().contains(term))
                        CheckboxListTile(
                          value: picked.contains(asInt(u['id'])),
                          title: Text(personName(u)),
                          onChanged: (v) => setSheet(
                            () => v == true
                                ? picked.add(asInt(u['id'])!)
                                : picked.remove(asInt(u['id'])),
                          ),
                        ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('${l.save} (${picked.length})'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    setState(
      () => _recipients
        ..clear()
        ..addAll(picked),
    );
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final amount = int.tryParse(_amount.text.trim());
    if (_recipients.isEmpty) return toast(context, l.spChooseRecipients);
    if (amount == null || amount <= 0) return toast(context, l.laPointsWhole);
    if (_note.text.trim().isEmpty) return toast(context, l.spNoteRequired);
    setState(() => _saving = true);
    var failed = 0;
    for (final id in _recipients) {
      try {
        await widget.ctx.api.post('/user-points', {
          'user_id': id,
          'points': (_deduct ? -1 : 1) * amount,
          'note': _note.text.trim(),
          'date': isoDay(_date),
          'category_id': ?_category,
        });
      } catch (_) {
        failed++;
      }
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (failed == 0) {
      toast(context, l.spSaved(_recipients.length));
      Navigator.pop(context, true);
    } else {
      toast(context, l.spSomeFailed(failed));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final names = {for (final u in _staff) asInt(u['id']): personName(u)};
    return SubPage(
      title: l.spAward,
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
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(l.spAwardShort),
                icon: const Icon(Icons.add_rounded),
              ),
              ButtonSegment(
                value: true,
                label: Text(l.spDeduct),
                icon: const Icon(Icons.remove_rounded),
              ),
            ],
            selected: {_deduct},
            onSelectionChanged: (s) => setState(() => _deduct = s.first),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.people_alt_outlined),
            title: Text(
              _recipients.isEmpty
                  ? l.spChooseRecipients
                  : _recipients
                            .map((id) => names[id] ?? personName(widget.user))
                            .take(3)
                            .join(', ') +
                        (_recipients.length > 3
                            ? ' +${_recipients.length - 3}'
                            : ''),
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _pickRecipients,
          ),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: l.laPoints),
          ),
          const SizedBox(height: 12),
          if (_categories.isNotEmpty)
            DropdownButtonFormField<int?>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l.calCategory),
              items: [
                DropdownMenuItem(value: null, child: Text(l.spNoCategory)),
                for (final c in _categories)
                  DropdownMenuItem(
                    value: asInt(c['id']),
                    child: Text(asStr(c['name']) ?? ''),
                  ),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: InputDecoration(labelText: l.cashNote),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.event_rounded),
            label: Text(isoDay(_date)),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
        ],
      ),
    );
  }
}
