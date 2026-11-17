import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/my_records.dart';
import 'period_bar.dart';

const _mask = '••••••';
const _hiddenKey = 'my_fundings_hidden';

/// The signed-in person's savings. One card per category, never one total
/// across them. The eye hides every amount and is remembered on this phone.
class MyFundingsPage extends StatefulWidget {
  const MyFundingsPage({
    super.key,
    required this.repository,
    required this.userId,
    this.bottomInset = 0,
  });

  final MyRepository repository;
  final int userId;
  final double bottomInset;

  @override
  State<MyFundingsPage> createState() => _MyFundingsPageState();
}

class _MyFundingsPageState extends State<MyFundingsPage> {
  List<Funding>? _records;
  List<FundingCategory> _categories = const [];
  bool _failed = false;
  bool _hidden = false;
  String? _pocket;
  PeriodSelection _period = const PeriodSelection();

  @override
  void initState() {
    super.initState();
    _load();
    _loadHidden();
  }

  Future<void> _loadHidden() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _hidden = prefs.getBool(_hiddenKey) ?? false);
    } catch (_) {
      // Stays visible.
    }
  }

  Future<void> _toggleHidden() async {
    setState(() => _hidden = !_hidden);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hiddenKey, _hidden);
    } catch (_) {
      // Just not remembered.
    }
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final results = await Future.wait([
        widget.repository.getFundings(widget.userId),
        widget.repository.getFundingCategories(),
      ]);
      if (!mounted) return;
      setState(() {
        _records = results[0] as List<Funding>;
        _categories = results[1] as List<FundingCategory>;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _currency(AppLocalizations l, String code) =>
      code == currencyUzs ? l.currencySom : code;

  String _money(
    AppLocalizations l,
    int value,
    String code, {
    bool plus = true,
  }) => _hidden
      ? _mask
      : '${signedNumber(value, plus: plus)} ${_currency(l, code)}';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final records = _records;
    final statement = withRunningBalance(records ?? const []);
    final pockets = pocketsOf(records ?? const [], _categories);
    final selected = pockets.where((p) => p.key == _pocket).firstOrNull;
    final window = _period.window(DateTime.now());
    final visible = statement
        .where(
          (row) =>
              (window == null || window.contains(row.date)) &&
              (selected == null || row.pocketKey == selected.key),
        )
        .toList();
    final net = netByCurrency(visible);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.myFundings,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: _hidden ? l.showAmounts : l.hideAmounts,
                visualDensity: VisualDensity.compact,
                onPressed: _toggleHidden,
                icon: Icon(
                  _hidden
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  size: 20,
                ),
              ),
            ],
          ),
          for (final pocket in pockets)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _pocketCard(context, l, pocket),
            ),
          PeriodBar(
            value: _period,
            onChanged: (next) => setState(() => _period = next),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.historyCount(visible.length),
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ),
              if (window != null && visible.isNotEmpty && !_hidden)
                Text(
                  l.inThisPeriod(
                    net.entries
                        .map((e) => _money(l, e.value, e.key))
                        .join(' · '),
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          Expanded(
            child: _failed && records == null
                ? RetryBanner(onRetry: _load)
                : records == null
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? Center(
                    child: Text(
                      records.isEmpty ? l.noSavingsYet : l.nothingInPeriod,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.mutedText),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.only(bottom: widget.bottomInset + 8),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      color: colors.line.withValues(alpha: 0.5),
                    ),
                    itemBuilder: (context, index) => _row(
                      context,
                      l,
                      visible[index],
                      showCategory: selected == null && pockets.length > 1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _pocketCard(
    BuildContext context,
    AppLocalizations l,
    FundingPocket pocket,
  ) {
    final colors = appColorsOf(context);
    final active = pocket.key == _pocket;
    final title = pocket.currency == currencyUzs
        ? pocket.name
        : '${pocket.name} · ${pocket.currency}';
    return Material(
      color: colors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: active ? colors.accent.solid : colors.line,
          width: active ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _pocket = active ? null : pocket.key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: colors.mutedText),
                    ),
                  ),
                  Text(
                    _money(l, pocket.balance, pocket.currency, plus: false),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: !_hidden && pocket.balance < 0
                          ? negativeRed
                          : null,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: _flow(
                      l.received,
                      _money(l, pocket.deposits, pocket.currency),
                      Icons.north_east_rounded,
                      positiveGreen,
                      colors,
                    ),
                  ),
                  Expanded(
                    child: _flow(
                      l.withdrawn,
                      _money(l, -pocket.withdrawals, pocket.currency),
                      Icons.south_east_rounded,
                      negativeRed,
                      colors,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _flow(
    String label,
    String value,
    IconData icon,
    Color color,
    AppColors colors,
  ) => Row(
    children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 3),
      Flexible(
        child: Text(
          '$label $value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 11, color: colors.mutedText),
        ),
      ),
    ],
  );

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    Funding row, {
    required bool showCategory,
  }) {
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final date = DateTime.tryParse(row.date);
    final parts = [
      if (date != null) DateFormat('d MMM y', locale).format(date),
      if (showCategory && row.categoryName != null) row.categoryName!,
      ?row.creatorName,
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _money(l, row.signed, row.currency),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _hidden ? colors.mutedText : toneOf(row.signed),
                    fontFeatures: tabularFigures,
                  ),
                ),
                if (row.note != null)
                  Text(row.note!, style: const TextStyle(fontSize: 13)),
                Text(
                  parts.join(' · '),
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                l.balance,
                style: TextStyle(fontSize: 10, color: colors.mutedText),
              ),
              Text(
                _money(l, row.balanceAfter, row.currency, plus: false),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: !_hidden && row.balanceAfter < 0 ? negativeRed : null,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
