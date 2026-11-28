import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../domain/lessons_repository.dart';

/// "W6 Adding fractions": the lesson plan week a lesson falls in, as the web
/// shows it next to the subject. Long-press shows the unit too.
class PlanWeekBadge extends StatelessWidget {
  const PlanWeekBadge({
    super.key,
    required this.week,
    this.onDark = false,
    this.showUnit = false,
    this.fontSize = 12,
  });

  final PlanWeek week;

  /// On the accent-filled row of the current lesson.
  final bool onDark;

  /// Adds " · unit" after the topic, for the grading header.
  final bool showUnit;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final topic = week.topic ?? '';
    final unit = week.unit;
    return Tooltip(
      message: [?unit, topic].where((t) => t.isNotEmpty).join(' · '),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: onDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : colors.softBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'W${week.weekNo}',
              style: TextStyle(
                fontSize: fontSize - 1,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: onDark ? Colors.white : colors.accent.solid,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text.rich(
              TextSpan(
                text: topic,
                children: [
                  if (showUnit && unit != null && unit.isNotEmpty)
                    TextSpan(
                      text: ' · $unit',
                      style: TextStyle(color: colors.mutedText),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                color: onDark
                    ? Colors.white.withValues(alpha: 0.8)
                    : showUnit
                    ? null
                    : colors.mutedText,
                fontWeight: showUnit ? FontWeight.w500 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
