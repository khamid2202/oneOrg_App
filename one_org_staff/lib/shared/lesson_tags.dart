import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// A timetable entry's tags as small tinted chips, like the web's
/// `LessonTags`: "Lab" with a flask, "+" for "+ after the lesson", any other
/// tag as plain text.
class LessonTags extends StatelessWidget {
  const LessonTags({super.key, required this.tags, this.onDark = false});

  final List<String> tags;

  /// On a filled (accent) row, where tints would vanish.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final tag in tags)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Tooltip(
              message: switch (tag) {
                'lab' => l.tagLab,
                'after' => l.tagAfter,
                _ => tag,
              },
              child: _chip(tag),
            ),
          ),
      ],
    );
  }

  Widget _chip(String tag) {
    final (icon, text, color) = switch (tag) {
      'lab' => (Icons.science_outlined, 'Lab', const Color(0xFF0F766E)),
      'after' => (Icons.schedule_rounded, '+', const Color(0xFFB45309)),
      _ => (null, tag, const Color(0xFF475569)),
    };
    final fg = onDark ? Colors.white : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.2)
            : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: fg),
            const SizedBox(width: 2),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
