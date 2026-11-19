import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/my_records.dart';
import 'period_bar.dart';
import 'package:one_org_staff/shared/app_toast.dart';

/// Points awarded to or deducted from the signed-in person. The balance is
/// all-time; the period only narrows the history under it.
class MyPointsPage extends StatefulWidget {
  const MyPointsPage({
    super.key,
    required this.repository,
    required this.userId,
    this.loadNames,
    this.bottomInset = 0,
  });

  final MyRepository repository;
  final int userId;

  /// Staff id → name, for who awarded what. Optional: rows just leave it out.
  final Future<Map<int, String>> Function()? loadNames;
  final double bottomInset;

  @override
  State<MyPointsPage> createState() => _MyPointsPageState();
}

class _MyPointsPageState extends State<MyPointsPage> {
  List<PointRecord>? _records;
  bool _failed = false;
  Map<int, String> _names = const {};
  PeriodSelection _period = const PeriodSelection();
  int? _category;

  @override
  void initState() {
    super.initState();
    _load();
    _loadNames();
  }

  /// A pull keeps what's on screen; only a first load that fails shows retry.
  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final records = await widget.repository.getPoints(widget.userId);
      if (mounted) setState(() => _records = newestPointsFirst(records));
    } catch (_) {
      if (!mounted) return;
      if (_records == null) {
        setState(() => _failed = true);
      } else {
        showToast(
          context,
          AppLocalizations.of(context).pointsRefreshFailed,
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _loadNames() async {
    try {
      final names = await widget.loadNames?.call();
      if (mounted && names != null) setState(() => _names = names);
    } catch (_) {
      // Rows simply don't say who.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final records = _records;
    final categories = <int, String>{
      for (final record in records ?? const <PointRecord>[])
        if (record.categoryId != null && record.categoryName != null)
          record.categoryId!: record.categoryName!,
    };
    final window = _period.window(DateTime.now());
    final visible = (records ?? const <PointRecord>[])
        .where(
          (r) =>
              (window == null || window.contains(r.date)) &&
              (_category == null || r.categoryId == _category),
        )
        .toList();
    final narrowed = _period.preset != PeriodPreset.all || _category != null;
    final balance = pointsTotal(records ?? const []);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l.myPoints,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(
                Icons.emoji_events_rounded,
                size: 20,
                color: Color(0xFFF59E0B),
              ),
              const SizedBox(width: 6),
              Text(
                records == null ? '…' : signedNumber(balance, plus: false),
                key: const ValueKey('points-balance'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: balance < 0 ? negativeRed : null,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          PeriodBar(
            value: _period,
            onChanged: (next) => setState(() => _period = next),
            onReset: () => setState(() => _category = null),
            extraActive: _category != null,
            extra: categories.isEmpty
                ? null
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        PillChip(
                          label: l.allCategories,
                          selected: _category == null,
                          onTap: () => setState(() => _category = null),
                        ),
                        for (final entry in categories.entries)
                          PillChip(
                            label: entry.value,
                            selected: _category == entry.key,
                            onTap: () => setState(() => _category = entry.key),
                          ),
                      ],
                    ),
                  ),
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
              if (narrowed && records != null)
                Text(
                  l.inThisPeriod(signedNumber(pointsTotal(visible))),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: toneOf(pointsTotal(visible)),
                  ),
                ),
            ],
          ),
          Expanded(
            child: _failed && records == null
                ? RetryBanner(onRetry: _load)
                : records == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: _history(context, l, records, visible),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _history(
    BuildContext context,
    AppLocalizations l,
    List<PointRecord> records,
    List<PointRecord> visible,
  ) {
    final colors = appColorsOf(context);
    const physics = AlwaysScrollableScrollPhysics();
    if (visible.isEmpty) {
      return CustomScrollView(
        physics: physics,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomInset),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 32,
                      color: colors.mutedText,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      records.isEmpty ? l.noPointsYet : l.nothingInPeriod,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.mutedText),
                    ),
                    if (records.isNotEmpty)
                      Text(
                        l.pointsWiderPeriod,
                        style: TextStyle(fontSize: 12, color: colors.mutedText),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Grouped by the month the points count for, each with its own net.
    final locale = Localizations.localeOf(context).toString();
    final months = <String, List<PointRecord>>{};
    for (final record in visible) {
      final month = record.date.length >= 7 ? record.date.substring(0, 7) : '';
      months.putIfAbsent(month, () => []).add(record);
    }
    final rows = <Widget>[
      for (final entry in months.entries) ...[
        _monthHeader(context, locale, entry.key, entry.value),
        for (var i = 0; i < entry.value.length; i++) ...[
          if (i > 0)
            Divider(height: 1, color: colors.line.withValues(alpha: 0.5)),
          _row(context, l, locale, entry.value[i]),
        ],
      ],
    ];
    return ListView(
      physics: physics,
      padding: EdgeInsets.only(bottom: widget.bottomInset + 8),
      children: rows,
    );
  }

  Widget _monthHeader(
    BuildContext context,
    String locale,
    String month,
    List<PointRecord> records,
  ) {
    final colors = appColorsOf(context);
    final day = DateTime.tryParse('$month-01');
    final total = pointsTotal(records);
    final style = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
      color: colors.mutedText,
    );
    return Padding(
      key: ValueKey('points-month-$month'),
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              day == null
                  ? '—'
                  : DateFormat.yMMMM(locale).format(day).toUpperCase(),
              style: style,
            ),
          ),
          Text(
            signedNumber(total),
            style: style.copyWith(
              color: toneOf(total) ?? colors.mutedText,
              fontFeatures: tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    AppLocalizations l,
    String locale,
    PointRecord record,
  ) {
    final colors = appColorsOf(context);
    final when = record.createdAt != null
        ? DateFormat('d MMM, HH:mm', locale).format(record.createdAt!)
        : record.date;
    final countsFor = DateTime.tryParse(record.date);
    final by = record.createdBy == null ? null : _names[record.createdBy];
    return Padding(
      key: ValueKey('point-${record.id}'),
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              signedNumber(record.points),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: toneOf(record.points),
                fontFeatures: tabularFigures,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (record.note != null || record.categoryName != null)
                  Text(
                    record.note ?? record.categoryName!,
                    style: const TextStyle(fontSize: 14),
                  ),
                Text(
                  [
                    if (record.backdated && countsFor != null)
                      l.pointsFor(
                        DateFormat('d MMM', locale).format(countsFor),
                      ),
                    when,
                    if (record.note != null && record.categoryName != null)
                      record.categoryName!,
                    ?by,
                    if (record.edited) l.pointsEdited,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
