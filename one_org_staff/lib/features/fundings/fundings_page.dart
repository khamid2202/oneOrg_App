import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';
import '../me/domain/my_records.dart';
import '../me/presentation/my_fundings_page.dart';

String _amount(num v, String currency) {
  final f = NumberFormat('#,##0.##', 'en').format(v.abs()).replaceAll(',', ' ');
  return '${v < 0 ? '−' : ''}$f $currency';
}

/// Everyone's savings: balances per person and currency, totals, and new
/// deposits or withdrawals — the guarded counterpart of My Fundings.
class FundingsPage extends StatefulWidget {
  const FundingsPage({super.key, required this.ctx, required this.me});
  final StaffContext ctx;
  final MyRepository? me;

  @override
  State<FundingsPage> createState() => _FundingsPageState();
}

class _FundingsPageState extends State<FundingsPage> {
  String _currency = 'UZS';
  List<Map<String, dynamic>>? _balances;
  List<Map<String, dynamic>> _summary = const [];
  String _search = '';
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
      final results = await Future.wait([
        ctx.api.all('/fundings/balances', {
          'currency': _currency,
          'sort_by': 'balance',
          'order': 'desc',
        }),
        ctx.api.get('/fundings/summary'),
      ]);
      if (!mounted) return;
      setState(() {
        _balances = results[0] as List<Map<String, dynamic>>;
        _summary = ApiClient.rows(results[1]);
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final term = _search.trim().toLowerCase();
    final rows = (_balances ?? const <Map<String, dynamic>>[])
        .where(
          (r) =>
              term.isEmpty ||
              personName(
                Map<String, dynamic>.from(r['user'] as Map? ?? {}),
              ).toLowerCase().contains(term),
        )
        .toList();
    final total = _summary.where((s) => s['currency'] == _currency).firstOrNull;

    return SubPage(
      title: l.fundings,
      floatingActionButton: ctx.can('fundings.create')
          ? FloatingActionButton.extended(
              onPressed: () => _newFunding(null),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.fundNew),
            )
          : null,
      body: _error != null && _balances == null
          ? ErrorState(error: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'UZS', label: Text('UZS')),
                      ButtonSegment(value: 'USD', label: Text('USD')),
                    ],
                    selected: {_currency},
                    onSelectionChanged: (s) {
                      setState(() {
                        _currency = s.first;
                        _balances = null;
                      });
                      _load();
                    },
                  ),
                  if (total != null) ...[
                    const SizedBox(height: 10),
                    AppCard(
                      color: colors.softBg,
                      child: Row(
                        children: [
                          _fig(
                            l.fundDeposits,
                            _amount(
                              asDouble(total['total_deposits']) ?? 0,
                              _currency,
                            ),
                            const Color(0xFF10B981),
                          ),
                          _fig(
                            l.fundWithdrawals,
                            _amount(
                              asDouble(total['total_withdrawals']) ?? 0,
                              _currency,
                            ),
                            const Color(0xFFF43F5E),
                          ),
                          _fig(
                            l.fundBalance,
                            _amount(asDouble(total['balance']) ?? 0, _currency),
                            null,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    decoration: InputDecoration(
                      isDense: true,
                      prefixIcon: const Icon(Icons.search_rounded),
                      hintText: l.search,
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 6),
                  if (_balances == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  if (_balances != null && rows.isEmpty)
                    EmptyState(
                      icon: Icons.savings_outlined,
                      message: l.fundNone,
                    ),
                  for (final r in rows)
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      title: Text(
                        personName(
                          Map<String, dynamic>.from(r['user'] as Map? ?? {}),
                        ),
                      ),
                      subtitle: Text(
                        [
                          l.historyCount(asInt(r['records']) ?? 0),
                          ?asStr(r['last_date']),
                        ].join(' · '),
                      ),
                      trailing: Text(
                        _amount(asDouble(r['balance']) ?? 0, _currency),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: (asDouble(r['balance']) ?? 0) < 0
                              ? const Color(0xFFF43F5E)
                              : null,
                        ),
                      ),
                      onTap: () => _openUser(
                        Map<String, dynamic>.from(r['user'] as Map? ?? {}),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _fig(String label, String value, Color? tone) => Expanded(
    child: Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: tone,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: appColorsOf(context).mutedText),
        ),
      ],
    ),
  );

  Future<void> _newFunding(Map<String, dynamic>? user) async {
    final saved = await SubPage.push<bool>(
      context,
      FundingFormPage(ctx: ctx, user: user),
    );
    if (saved == true) _load();
  }

  Future<void> _openUser(Map<String, dynamic> user) async {
    final me = widget.me;
    final id = asInt(user['id']);
    if (me == null || id == null) return;
    await SubPage.push(
      context,
      SubPage(
        title: personName(user),
        floatingActionButton: ctx.can('fundings.create')
            ? FloatingActionButton.extended(
                onPressed: () => _newFunding(user),
                icon: const Icon(Icons.add_rounded),
                label: Text(AppLocalizations.of(context).fundNew),
              )
            : null,
        body: MyFundingsPage(repository: me, userId: id, bottomInset: 80),
      ),
    );
    _load();
  }
}

/// A deposit or withdrawal on someone's savings.
class FundingFormPage extends StatefulWidget {
  const FundingFormPage({super.key, required this.ctx, this.user});
  final StaffContext ctx;
  final Map<String, dynamic>? user;

  @override
  State<FundingFormPage> createState() => _FundingFormPageState();
}

class _FundingFormPageState extends State<FundingFormPage> {
  int? _user;
  List<Map<String, dynamic>> _staff = const [];
  List<Map<String, dynamic>> _categories = const [];
  int? _category;
  String _type = 'deposit';
  String _currency = 'UZS';
  final _amountCtl = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _user = asInt(widget.user?['id']);
    widget.ctx.staff().then((s) {
      if (mounted) {
        setState(
          () =>
              _staff = [...s]
                ..sort((a, b) => personName(a).compareTo(personName(b))),
        );
      }
    });
    widget.ctx.api
        .get('/funding-categories')
        .then((res) {
          if (!mounted) return;
          setState(() {
            _categories = ApiClient.rows(res);
            _category = asInt(_categories.firstOrNull?['id']);
          });
        })
        .catchError((_) {});
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final amount = double.tryParse(_amountCtl.text.trim().replaceAll(' ', ''));
    if (_user == null) return toast(context, l.spChooseRecipients);
    if (amount == null || amount <= 0) {
      return toast(context, l.fundAmountPositive);
    }
    setState(() => _saving = true);
    try {
      await widget.ctx.api.post('/fundings', {
        'user_id': _user,
        'category_id': ?_category,
        'type': _type,
        'currency': _currency,
        'amount': amount,
        'date': isoDay(_date),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SubPage(
      title: l.fundNew,
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
          DropdownButtonFormField<int>(
            initialValue: _staff.any((u) => asInt(u['id']) == _user)
                ? _user
                : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: l.fundPerson),
            items: [
              for (final u in _staff)
                DropdownMenuItem(
                  value: asInt(u['id']),
                  child: Text(personName(u)),
                ),
            ],
            onChanged: widget.user != null
                ? null
                : (v) => setState(() => _user = v),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'deposit', label: Text(l.fundDeposit)),
              ButtonSegment(value: 'withdrawal', label: Text(l.fundWithdrawal)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountCtl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(labelText: l.cashAmount),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: _currency,
                items: const [
                  DropdownMenuItem(value: 'UZS', child: Text('UZS')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'UZS'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_categories.isNotEmpty)
            DropdownButtonFormField<int>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l.calCategory),
              items: [
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
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
        ],
      ),
    );
  }
}
