import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

/// `$5` / `−$2.50`.
String money(num? dollars) {
  final n = dollars ?? 0;
  final abs = n.abs();
  final text = abs == abs.roundToDouble()
      ? '${abs.toInt()}'
      : abs.toStringAsFixed(2);
  return '${n < 0 ? '−' : ''}\$$text';
}

int compareClass(String a, String b) {
  final na = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '') ?? 0;
  final nb = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '') ?? 0;
  return na != nb ? na - nb : a.compareTo(b);
}

/// The human part of a points row's reason ("Cashier: spend · note" → "note").
String describeReason(String reason) => reason
    .replaceFirst(
      RegExp(r'^(Cashier|Dombit|Grades|Behavior):\s*', caseSensitive: false),
      '',
    )
    .replaceFirst(
      RegExp(
        r'^(spend|add|award|credit)(\s+(T\d+|[0-9a-f]{8}))?(\s*·\s*)?',
        caseSensitive: false,
      ),
      '',
    )
    .trim();

IconData reasonIcon(String reason) {
  final r = reason.toLowerCase();
  if (r.startsWith('cashier: reset')) return Icons.restart_alt_rounded;
  if (r.startsWith('behavior:')) return Icons.sentiment_satisfied_alt_rounded;
  if (r.contains('spend') || r.contains('change to dollars')) {
    return Icons.shopping_bag_outlined;
  }
  if (r.contains('award') || r.contains('place') || r.contains('reward')) {
    return Icons.emoji_events_outlined;
  }
  if (r.startsWith('cashier: add') || r.contains('credit')) {
    return Icons.add_rounded;
  }
  return Icons.school_outlined;
}

/// Dombit dollars cashier: every class's balances, a class filter, a search
/// and a school ranking; tap a student to spend or add dollars.
class CashierPage extends StatefulWidget {
  const CashierPage({super.key, required this.ctx});
  final StaffContext ctx;

  @override
  State<CashierPage> createState() => _CashierPageState();
}

class _CashierPageState extends State<CashierPage> {
  List<Map<String, dynamic>>? _students;
  String? _syncedThrough;
  List<Map<String, dynamic>> _review = const [];
  String _query = '';
  String? _class;
  bool _rank = false;
  bool _syncing = false;
  Object? _error;

  StaffContext get ctx => widget.ctx;
  bool get _canWrite => ctx.can('cashier.create');

  @override
  void initState() {
    super.initState();
    _load();
    _loadReview();
  }

  Future<void> _load() async {
    try {
      final body = await ctx.api.get('/cashier/students');
      if (!mounted) return;
      setState(() {
        _error = null;
        _students = ApiClient.rows({
          'result': body is Map ? body['students'] : null,
        });
        _syncedThrough = body is Map ? asStr(body['synced_through']) : null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadReview() async {
    try {
      final body = await ctx.api.get('/cashier/behavior-review');
      if (mounted) {
        setState(
          () => _review = ApiClient.rows({
            'result': body is Map ? body['marks'] : null,
          }),
        );
      }
    } catch (_) {}
  }

  Future<void> _sync() async {
    final l = AppLocalizations.of(context);
    setState(() => _syncing = true);
    try {
      final res = await ctx.api.post('/cashier/sync-grades');
      final n = asInt(res is Map ? res['students'] : null) ?? 0;
      final dollars = asDouble(res is Map ? res['dollars'] : null) ?? 0;
      final behavior = res is Map && res['behavior'] is Map
          ? res['behavior'] as Map
          : const {};
      final parts = [
        if (n > 0) '🎓 +${money(dollars.round())} · $n',
        if ((asInt(behavior['marks']) ?? 0) > 0)
          '🙂 +${money(asDouble(behavior['plus']))} ${money(asDouble(behavior['minus']))} · ${behavior['marks']}',
        if ((asInt(behavior['unlinked']) ?? 0) > 0) '? ${behavior['unlinked']}',
      ];
      if (mounted) toast(context, parts.isEmpty ? '✓' : parts.join('  '));
      _syncedThrough = res is Map
          ? asStr(res['synced_through'])
          : _syncedThrough;
      await _load();
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.cashSyncFailed));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final students = _students;
    final classes = {
      for (final s in students ?? const []) '${s['class_name'] ?? ''}',
    }.toList()..sort(compareClass);
    final q = _query.trim().toLowerCase();
    final visible = (students ?? const <Map<String, dynamic>>[])
        .where(
          (s) => q.isNotEmpty
              ? '${s['full_name']}'.toLowerCase().contains(q)
              : _class == null || s['class_name'] == _class,
        )
        .toList();
    final total = visible.fold<num>(
      0,
      (s, x) => s + (asDouble(x['balance_dollars']) ?? 0),
    );

    return SubPage(
      title: l.cashier,
      actions: [
        if (_canWrite && _review.isNotEmpty)
          IconButton(
            tooltip: l.cashReview,
            icon: Badge(
              label: Text('${_review.length}'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            onPressed: _openReview,
          ),
        if (_canWrite)
          IconButton(
            tooltip: l.cashSync,
            onPressed: _syncing ? null : _sync,
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        IconButton(
          tooltip: _rank ? l.cashClasses : l.cashRanking,
          icon: Icon(
            _rank ? Icons.view_list_rounded : Icons.leaderboard_rounded,
          ),
          onPressed: () => setState(() => _rank = !_rank),
        ),
      ],
      body: _error != null && students == null
          ? ErrorState(error: _error!, onRetry: _load)
          : students == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l.cashSearch,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: 8),
                  if (!_rank)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(l.all),
                              selected: _class == null,
                              onSelected: (_) => setState(() => _class = null),
                            ),
                          ),
                          for (final c in classes)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(c),
                                selected: _class == c,
                                onSelected: (_) => setState(() => _class = c),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _syncedThrough == null
                                ? ''
                                : l.cashSyncedThrough(
                                    _syncedThrough!.substring(
                                      0,
                                      _syncedThrough!.length.clamp(0, 10),
                                    ),
                                  ),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedText,
                            ),
                          ),
                        ),
                        Text(
                          money(total.round()),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  if (_rank)
                    ..._ranking(context, students, q)
                  else
                    ..._byClass(context, visible),
                ],
              ),
            ),
    );
  }

  List<Widget> _byClass(
    BuildContext context,
    List<Map<String, dynamic>> visible,
  ) {
    final colors = appColorsOf(context);
    final groups = <String, List<Map<String, dynamic>>>{};
    for (final s in visible) {
      groups.putIfAbsent('${s['class_name'] ?? ''}', () => []).add(s);
    }
    final keys = groups.keys.toList()..sort(compareClass);
    return [
      for (final k in keys) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  k,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                money(
                  groups[k]!
                      .fold<num>(
                        0,
                        (s, x) => s + (asDouble(x['balance_dollars']) ?? 0),
                      )
                      .round(),
                ),
                style: TextStyle(
                  color: colors.mutedText,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        for (final s
            in groups[k]!..sort(
              (a, b) => '${a['full_name']}'.compareTo('${b['full_name']}'),
            ))
          _studentTile(context, s),
      ],
    ];
  }

  List<Widget> _ranking(
    BuildContext context,
    List<Map<String, dynamic>> students,
    String q,
  ) {
    final sorted = [...students]
      ..sort(
        (a, b) => (asDouble(b['balance_dollars']) ?? 0).compareTo(
          asDouble(a['balance_dollars']) ?? 0,
        ),
      );
    return [
      for (var i = 0; i < sorted.length; i++)
        if (q.isEmpty || '${sorted[i]['full_name']}'.toLowerCase().contains(q))
          _studentTile(context, sorted[i], rank: i + 1),
    ];
  }

  Widget _studentTile(
    BuildContext context,
    Map<String, dynamic> s, {
    int? rank,
  }) {
    final colors = appColorsOf(context);
    final balance = asDouble(s['balance_dollars']) ?? 0;
    final pic = asStr(s['picture_url']);
    final name = '${s['full_name'] ?? ''}';
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank != null)
            SizedBox(
              width: 28,
              child: Text('$rank', style: TextStyle(color: colors.mutedText)),
            ),
          CircleAvatar(
            radius: 18,
            backgroundColor: colors.avatarPlaceholder,
            backgroundImage: pic == null ? null : NetworkImage(pic),
            child: pic == null
                ? Text(
                    _initials(name),
                    style: TextStyle(fontSize: 12, color: colors.softText),
                  )
                : null,
          ),
        ],
      ),
      title: Text(name),
      subtitle: rank != null ? Text('${s['class_name'] ?? ''}') : null,
      trailing: Text(
        money(balance),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: balance < 0 ? const Color(0xFFF43F5E) : null,
        ),
      ),
      onTap: () => _openStudent(asInt(s['person_id'])!),
    );
  }

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0])
      .join()
      .toUpperCase();

  Future<void> _openStudent(int personId) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _StudentSheet(
        ctx: ctx,
        personId: personId,
        canWrite: _canWrite,
        onBalance: (student) {
          setState(() {
            _students = [
              for (final s in _students!)
                s['person_id'] == student['person_id']
                    ? {
                        ...s,
                        'balance_points': student['balance_points'],
                        'balance_dollars': student['balance_dollars'],
                      }
                    : s,
            ];
          });
        },
      ),
    );
  }

  Future<void> _openReview() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BehaviorReview(
        ctx: ctx,
        marks: _review,
        onDone: (mark) {
          setState(
            () =>
                _review = _review.where((m) => m['id'] != mark['id']).toList(),
          );
          _loadReview();
          _load();
        },
      ),
    );
  }
}

class _StudentSheet extends StatefulWidget {
  const _StudentSheet({
    required this.ctx,
    required this.personId,
    required this.canWrite,
    required this.onBalance,
  });

  final StaffContext ctx;
  final int personId;
  final bool canWrite;
  final ValueChanged<Map<String, dynamic>> onBalance;

  @override
  State<_StudentSheet> createState() => _StudentSheetState();
}

class _StudentSheetState extends State<_StudentSheet> {
  Map<String, dynamic>? _data;
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String? _saving;

  @override
  void initState() {
    super.initState();
    widget.ctx.api
        .get('/cashier/students/${widget.personId}')
        .then((res) {
          if (mounted) {
            setState(() => _data = Map<String, dynamic>.from(res as Map));
          }
        })
        .catchError((Object e) {
          if (mounted) {
            toast(
              context,
              errorText(e, AppLocalizations.of(context).loadFailed),
            );
            Navigator.pop(context);
          }
        });
  }

  bool get _valid {
    final t = _amount.text.trim();
    return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t) &&
        (double.tryParse(t) ?? 0) > 0;
  }

  void _apply(dynamic res) {
    final data = Map<String, dynamic>.from(res as Map);
    setState(() => _data = data);
    if (data['student'] is Map) {
      widget.onBalance(Map<String, dynamic>.from(data['student']));
    }
  }

  Future<void> _submit(String type) async {
    if (!_valid) return;
    final l = AppLocalizations.of(context);
    final dollars = double.parse(_amount.text.trim());
    setState(() => _saving = type);
    try {
      final res = await widget.ctx.api.post('/cashier/transactions', {
        'person_id': widget.personId,
        'type': type,
        'dollars': dollars,
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      _apply(res);
      _amount.clear();
      _note.clear();
      if (mounted) {
        toast(context, '${type == 'spend' ? '−' : '+'}${money(dollars)}');
      }
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  Future<void> _reset() async {
    final l = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.cashResetQ,
      confirmLabel: '\$0',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _saving = 'reset');
    try {
      _apply(
        await widget.ctx.api.post('/cashier/students/${widget.personId}/reset'),
      );
      if (mounted) toast(context, '\$0');
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final data = _data;
    if (data == null) {
      return const SizedBox(
        height: 240,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final student = Map<String, dynamic>.from(
      data['student'] as Map? ?? const {},
    );
    final balance = asDouble(student['balance_dollars']) ?? 0;
    final history = (data['history'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        children: [
          Text(
            '${student['full_name'] ?? ''}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            '${student['class_name'] ?? ''}',
            style: TextStyle(color: colors.mutedText),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              money(balance),
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                color: balance < 0 ? const Color(0xFFF43F5E) : null,
              ),
            ),
          ),
          Center(
            child: Text(
              '${student['balance_points'] ?? 0} pts',
              style: TextStyle(color: colors.mutedText),
            ),
          ),
          if (widget.canWrite) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              children: [
                for (final a in const [1, 5, 10, 20, 50])
                  ActionChip(
                    label: Text('\$$a'),
                    onPressed: () => setState(() => _amount.text = '$a'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.cashAmount,
                prefixText: '\$',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _note,
              decoration: InputDecoration(labelText: l.cashNote),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF43F5E),
                    ),
                    onPressed: _valid && _saving == null
                        ? () => _submit('spend')
                        : null,
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: Text(l.cashSpend),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    onPressed: _valid && _saving == null
                        ? () => _submit('add')
                        : null,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.cashAdd),
                  ),
                ),
              ],
            ),
            if (balance != 0)
              TextButton.icon(
                onPressed: _saving == null ? _reset : null,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(l.cashResetZero),
              ),
          ],
          const Divider(height: 24),
          Text(
            l.cashHistory,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (history.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l.cashNoHistory,
                textAlign: TextAlign.center,
                style: TextStyle(color: colors.mutedText),
              ),
            ),
          for (final h in history)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                reasonIcon('${h['reason'] ?? ''}'),
                color: colors.mutedText,
              ),
              title: Text(
                describeReason('${h['reason'] ?? ''}').isEmpty
                    ? '—'
                    : describeReason('${h['reason']}'),
              ),
              subtitle: Text(
                [
                  if (asStr(h['comment']) != null &&
                      h['comment'] != describeReason('${h['reason'] ?? ''}'))
                    '${h['comment']}',
                  '${h['date'] ?? ''}'.padRight(10).substring(0, 10).trim(),
                  ?asStr(h['author_name']),
                ].join(' · '),
              ),
              trailing: Text(
                '${(asDouble(h['dollars']) ?? 0) >= 0 ? '+' : ''}${money(asDouble(h['dollars']))}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: (asDouble(h['dollars']) ?? 0) >= 0
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF43F5E),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Behaviour marks with no reason: the cashier picks the dollars, or none.
/// Good marks can't go past the student's weekly cap (`room`).
class _BehaviorReview extends StatefulWidget {
  const _BehaviorReview({
    required this.ctx,
    required this.marks,
    required this.onDone,
  });
  final StaffContext ctx;
  final List<Map<String, dynamic>> marks;
  final ValueChanged<Map<String, dynamic>> onDone;

  @override
  State<_BehaviorReview> createState() => _BehaviorReviewState();
}

class _BehaviorReviewState extends State<_BehaviorReview> {
  late List<Map<String, dynamic>> _marks = widget.marks;
  Object? _busy;

  Future<void> _allocate(Map<String, dynamic> m, int dollars) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = m['id']);
    try {
      await widget.ctx.api.post(
        '/cashier/behavior-review/${Uri.encodeComponent('${m['id']}')}',
        {'dollars': dollars},
      );
      if (mounted) {
        toast(
          context,
          dollars == 0
              ? '✓'
              : '${m['type'] == 'positive' ? '+' : '−'}${money(dollars)}',
        );
        setState(
          () => _marks = _marks.where((x) => x['id'] != m['id']).toList(),
        );
      }
      widget.onDone(m);
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            l.cashReview,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (_marks.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('✓', style: TextStyle(color: colors.mutedText)),
              ),
            ),
          for (final m in _marks)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          m['type'] == 'positive'
                              ? Icons.thumb_up_alt_outlined
                              : Icons.thumb_down_alt_outlined,
                          color: m['type'] == 'positive'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF43F5E),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${m['full_name'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        '${m['class_name'] ?? ''}',
                        '${m['date'] ?? ''}'
                            .padRight(10)
                            .substring(0, 10)
                            .trim(),
                        ?asStr(m['author_name']),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final d
                            in m['type'] == 'positive'
                                ? const [1, 2, 3]
                                : const [1, 2, 3, 5, 8])
                          ActionChip(
                            label: Text(
                              '${m['type'] == 'positive' ? '+' : '−'}\$$d',
                            ),
                            onPressed:
                                _busy == m['id'] ||
                                    (m['type'] == 'positive' &&
                                        d > (asDouble(m['room']) ?? 999))
                                ? null
                                : () => _allocate(m, d),
                          ),
                        ActionChip(
                          label: const Text('✕'),
                          onPressed: _busy == m['id']
                              ? null
                              : () => _allocate(m, 0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
