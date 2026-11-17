import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/my_records.dart';

const tabularFigures = [FontFeature.tabularFigures()];

/// A rounded choice, used for periods, classes and form options.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.soft = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Tinted while unselected: one of the teacher's own classes.
  final bool soft;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected
            ? colors.accent.solid
            : soft
            ? colors.accent.solid.withValues(alpha: 0.5)
            : colors.softBg,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The chosen period: a preset, or a from/to range when [preset] is null.
class PeriodSelection {
  const PeriodSelection({this.preset = PeriodPreset.all, this.from, this.to});

  final PeriodPreset? preset;
  final DateTime? from;
  final DateTime? to;

  DateWindow? window(DateTime now) {
    final chosen = preset;
    if (chosen != null) return windowOf(chosen, now);
    if (from == null && to == null) return null;
    return DateWindow(
      from: from == null ? null : dateKey(from!),
      to: to == null ? null : dateKey(to!),
    );
  }
}

/// All / This month / Last 30 days / This year, and a custom range behind the
/// sliders button. [extra] joins the range row (a category filter).
class PeriodBar extends StatefulWidget {
  const PeriodBar({
    super.key,
    required this.value,
    required this.onChanged,
    this.extra,
    this.extraActive = false,
    this.onReset,
  });

  final PeriodSelection value;
  final ValueChanged<PeriodSelection> onChanged;
  final Widget? extra;
  final bool extraActive;

  /// Clears [extra] too. Without it, reset only goes back to "All".
  final VoidCallback? onReset;

  @override
  State<PeriodBar> createState() => _PeriodBarState();
}

class _PeriodBarState extends State<PeriodBar> {
  bool _open = false;

  Future<void> _pick({required bool from}) async {
    final value = widget.value;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: (from ? value.from : value.to) ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    widget.onChanged(
      PeriodSelection(
        preset: null,
        from: from ? picked : value.from,
        to: from ? value.to : picked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final value = widget.value;
    final labels = {
      PeriodPreset.all: l.all,
      PeriodPreset.month: l.thisMonth,
      PeriodPreset.last30: l.last30Days,
      PeriodPreset.year: l.thisYear,
    };
    // Hidden behind the sliders button, so the button says so.
    final narrowed = value.preset == null || widget.extraActive;
    final resettable = value.preset != PeriodPreset.all || widget.extraActive;
    String show(String label, DateTime? date) =>
        date == null ? label : '$label ${DateFormat('dd.MM.yy').format(date)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in labels.entries)
                      PillChip(
                        label: entry.value,
                        selected: value.preset == entry.key,
                        onTap: () => widget.onChanged(
                          PeriodSelection(preset: entry.key),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              tooltip: l.moreFilters,
              visualDensity: VisualDensity.compact,
              onPressed: () => setState(() => _open = !_open),
              icon: Icon(
                Icons.tune_rounded,
                size: 19,
                color: _open || narrowed ? colors.accent.ring : null,
              ),
            ),
          ],
        ),
        if (_open) ...[
          const SizedBox(height: 4),
          Wrap(
            runSpacing: 6,
            children: [
              PillChip(
                label: show(l.from, value.from),
                selected: value.from != null,
                onTap: () => _pick(from: true),
              ),
              PillChip(
                label: show(l.to, value.to),
                selected: value.to != null,
                onTap: () => _pick(from: false),
              ),
            ],
          ),
          if (widget.extra != null) ...[
            const SizedBox(height: 6),
            widget.extra!,
          ],
          if (resettable)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('period-reset'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.mutedText,
                ),
                onPressed: () {
                  widget.onReset?.call();
                  widget.onChanged(const PeriodSelection());
                },
                icon: const Icon(Icons.close_rounded, size: 15),
                label: Text(l.resetFilters),
              ),
            ),
        ],
      ],
    );
  }
}

/// The wording shared by a page that failed to load.
class RetryBanner extends StatelessWidget {
  const RetryBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.loadFailed, style: TextStyle(color: colors.mutedText)),
          TextButton(onPressed: onRetry, child: Text(l.retry)),
        ],
      ),
    );
  }
}

/// `+5` / `−5`, with a true minus.
String signedNumber(int value, {bool plus = true}) {
  final digits = NumberFormat('#,##0', 'en').format(value.abs());
  final grouped = digits.replaceAll(',', ' ');
  return value < 0
      ? '−$grouped'
      : value > 0 && plus
      ? '+$grouped'
      : grouped;
}

const positiveGreen = Color(0xFF10B981);
const negativeRed = Color(0xFFF43F5E);

Color? toneOf(int value) => value > 0
    ? positiveGreen
    : value < 0
    ? negativeRed
    : null;
