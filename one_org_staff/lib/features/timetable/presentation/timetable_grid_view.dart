import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';
import 'package:one_org_staff/features/timetable/domain/timetable_grid.dart';

/// A header cell — a row label or a column heading.
class TimetableHeader {
  const TimetableHeader({
    required this.key,
    required this.primary,
    this.secondary,
  });

  /// Matches the row/column key the grid's cells are stored under.
  final int key;
  final String primary;

  /// Second line, used for a period's time range.
  final String? secondary;
}

/// The timetable grid, laid out like the web's tables.
///
/// Both axes are supplied by the caller, because the two views transpose each
/// other: by teacher it is days-down/periods-across, by class it is
/// periods-down/classes-across.
///
/// The first column is frozen: the weekday — or the period, by class — stays
/// put while the rest of the week scrolls sideways, so a cell reached halfway
/// through the scroll still says what it belongs to. That is why rows have
/// measured heights rather than intrinsic ones: the frozen column and the
/// scrolling half are separate widget trees and have to agree on where each
/// row ends.
class TimetableGridView extends StatelessWidget {
  const TimetableGridView({
    super.key,
    required this.grid,
    required this.rows,
    required this.columns,
    required this.rowHeaderLabel,
    this.showClass = true,
    this.transposed = false,
    this.caption,
  });

  final TimetableGrid grid;

  /// Row headers, top to bottom.
  final List<TimetableHeader> rows;

  /// Column headings, left to right.
  final List<TimetableHeader> columns;

  /// Heading for the frozen first column — "Weekday" or "Period".
  final String rowHeaderLabel;

  /// Whether cards name their class. Off by class, where the column heading
  /// already says it, so the cards drop a line and get shorter.
  final bool showClass;

  /// The grid stores cells as (column, row) rather than (row, column) — My
  /// week keeps the grid's day-by-period cells but lays days across the top.
  final bool transposed;

  /// Optional caption header.
  final String? caption;

  static const _rowHeaderWidth = 40.0;

  /// The narrowest a column gets; a few columns stretch to fill the width.
  static const _minColumnWidth = 64.0;
  static const _cellPadding = 3.0;
  static const _cardGap = 2.0;

  /// Unscaled heights. Everything vertical derives from these, so the two
  /// halves of the table cannot drift apart.
  static const _headerHeight = 38.0;
  static const _cardHeight = 44.0;
  static const _subjectOnlyHeight = 38.0;

  /// A row nobody teaches in still reads as a row, not a hairline.
  static const _emptyRowHeight = 40.0;

  /// Row dividers are drawn as borders, which sit *inside* the row's height,
  /// so the height has to pay for them or the cards overflow by a hair.
  static const _divider = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    // Larger system text needs taller rows, but a huge setting must not turn
    // one lesson into a screenful — the cards ellipsize past this.
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    final headerHeight = _headerHeight * scale;
    final cardHeight = (showClass ? _cardHeight : _subjectOnlyHeight) * scale;

    final rowHeights = [
      for (var i = 0; i < rows.length; i++)
        _rowHeight(rows[i], cardHeight, scale) +
            (i == rows.length - 1 ? 0 : _divider),
    ];

    final tableWidget = LayoutBuilder(
      builder: (context, constraints) {
        // Border on both sides, plus the frozen column.
        final room = constraints.maxWidth - 2 - _rowHeaderWidth;
        final columnWidth = columns.isEmpty
            ? _minColumnWidth
            : (room / columns.length).clamp(_minColumnWidth, double.infinity);
        return Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.line),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _frozenColumn(context, colors, headerHeight, rowHeights),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _columnHeadings(
                        context,
                        colors,
                        headerHeight,
                        columnWidth,
                      ),
                      for (var i = 0; i < rows.length; i++)
                        _bodyRow(
                          context,
                          colors,
                          rows[i],
                          height: rowHeights[i],
                          cardHeight: cardHeight,
                          columnWidth: columnWidth,
                          last: i == rows.length - 1,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (caption == null) {
      return tableWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
          child: Text(
            caption!,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colors.softText,
            ),
          ),
        ),
        tableWidget,
      ],
    );
  }

  List<TimetableLesson> _at(TimetableHeader row, TimetableHeader column) =>
      transposed ? grid.at(column.key, row.key) : grid.at(row.key, column.key);

  /// How tall a row has to be to hold its fullest cell.
  double _rowHeight(TimetableHeader row, double cardHeight, double scale) {
    var deepest = 0;
    for (final column in columns) {
      final count = _merged(_at(row, column)).length;
      if (count > deepest) {
        deepest = count;
      }
    }

    if (deepest == 0) {
      return _emptyRowHeight * scale;
    }
    return deepest * cardHeight + (deepest - 1) * _cardGap + _cellPadding * 2;
  }

  /// The pinned left edge: the corner cell, then every row's label.
  Widget _frozenColumn(
    BuildContext context,
    AppColors colors,
    double headerHeight,
    List<double> rowHeights,
  ) {
    final theme = Theme.of(context);

    return Container(
      width: _rowHeaderWidth,
      decoration: BoxDecoration(
        // A firmer line than the inner grid lines, so the frozen edge reads as
        // the thing the rest of the table slides under.
        border: Border(right: BorderSide(color: colors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: headerHeight,
            width: double.infinity,
            color: colors.accent.solid,
            alignment: Alignment.center,
            child: Text(
              rowHeaderLabel,
              textAlign: TextAlign.center,
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              height: rowHeights[i],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: colors.softBg,
                border: i == rows.length - 1
                    ? null
                    : Border(bottom: BorderSide(color: colors.line)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      rows[i].primary,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    if (rows[i].secondary != null)
                      Text(
                        // Start time only: the range does not fit the narrow
                        // frozen column, and the end is the next row's start.
                        rows[i].secondary!.split(' - ').first,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.mutedText,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _columnHeadings(
    BuildContext context,
    AppColors colors,
    double height,
    double columnWidth,
  ) {
    final theme = Theme.of(context);
    const onAccent = Colors.white;

    return Container(
      height: height,
      color: colors.accent.solid,
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Container(
              width: columnWidth,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : const Border(left: BorderSide(color: Color(0x40FFFFFF))),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    columns[i].primary,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      height: 1.1,
                    ),
                  ),
                  if (columns[i].secondary != null)
                    Text(
                      columns[i].secondary!,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onAccent.withValues(alpha: 0.85),
                        fontSize: 9,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bodyRow(
    BuildContext context,
    AppColors colors,
    TimetableHeader row, {
    required double height,
    required double cardHeight,
    required double columnWidth,
    required bool last,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++)
            Container(
              width: columnWidth,
              padding: const EdgeInsets.all(_cellPadding),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(left: BorderSide(color: colors.line)),
              ),
              child: _cell(context, _at(row, columns[i]), cardHeight),
            ),
        ],
      ),
    );
  }

  /// The lessons in one cell, stacked. Usually there is exactly one, so only
  /// the gaps *between* cards are spaced — a lone card adds no height.
  Widget _cell(
    BuildContext context,
    List<TimetableLesson> lessons,
    double cardHeight,
  ) {
    final cards = _merged(lessons);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < cards.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _cardGap),
            child: _LessonCard(
              lesson: cards[i].lesson,
              classes: showClass ? cards[i].classes : const [],
              clashes: cards[i].clashes,
              choice: cards[i].choice,
              height: cardHeight,
              onTap: () => _showDetails(context, cards[i]),
            ),
          ),
      ],
    );
  }

  /// The full story behind a card: subject, class, teacher, room and time
  /// for every lesson merged into it.
  void _showDetails(BuildContext context, _CardData card) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _LessonDetails(
        lessons: card.lessons,
        clashes: card.clashes,
        choice: card.choice,
      ),
    );
  }

  /// One card per subject in a cell: two classes taught the same subject in
  /// the same slot read as "10-A+10-B" on one card instead of two stacked
  /// cards, which doubled the row's height.
  List<_CardData> _merged(List<TimetableLesson> lessons) {
    final byKey = <String, _CardData>{};
    for (final lesson in lessons) {
      // By class, a choice block is one card however many options it has —
      // the class takes "Choice 1", each student their own subject. A
      // teacher's week keeps the real subject, which is what they teach.
      final asChoice = lesson.isChoice && !showClass;
      final clashes = asChoice ? false : grid.clashes(lesson);
      final key = asChoice
          ? 'choice|${lesson.divisionId ?? lesson.divisionName}'
          : '${lesson.isTextLesson}|${lesson.title}|$clashes';
      final card = byKey.putIfAbsent(
        key,
        () => _CardData(lesson: lesson, clashes: clashes, choice: asChoice),
      );
      card.lessons.add(lesson);
      final label = classLabel(lesson);
      if (!card.classes.contains(label)) {
        card.classes.add(label);
      }
    }
    return byKey.values.toList();
  }
}

class _CardData {
  _CardData({
    required this.lesson,
    required this.clashes,
    required this.choice,
  });

  final TimetableLesson lesson;
  final bool clashes;

  /// Stands for a whole choice block; its lessons are the options.
  final bool choice;
  final List<String> classes = [];

  /// Every lesson merged into the card, for the details sheet.
  final List<TimetableLesson> lessons = [];
}

/// One lesson in a cell: the class in the accent colour with the subject under
/// it, or a note for the free-text lessons the timetable also carries.
class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.classes,
    required this.clashes,
    required this.height,
    required this.onTap,
    this.choice = false,
  });

  /// A whole choice block, shown by its name ("Choice 1").
  final bool choice;

  final TimetableLesson lesson;
  final VoidCallback onTap;

  /// Every class this card stands for — usually one.
  final List<String> classes;

  /// The same teacher is booked elsewhere this period — worth shouting about,
  /// since it is the error the timetable maker is looking for.
  final bool clashes;

  /// Fixed, because the frozen column has to know how tall a row is before the
  /// cards inside it are laid out. Text that does not fit ellipsizes.
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    if (choice) {
      return _shell(
        background: colors.accent.softBg,
        border: colors.accent.border,
        children: [
          // Shrinks to fit rather than cutting "Choice 1" to "Choic…".
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              lesson.divisionName ?? 'Choice',
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: colors.accent.softText,
                height: 1.1,
              ),
            ),
          ),
        ],
      );
    }

    if (lesson.isTextLesson) {
      return _shell(
        background: clashes
            ? theme.colorScheme.errorContainer
            : const Color(0xFFECFDF5),
        border: clashes ? theme.colorScheme.error : const Color(0xFFA7F3D0),
        children: [
          // No "NOTE" label: the green already marks a free-text slot.
          Flexible(
            child: Text(
              lesson.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: const Color(0xFF065F46),
                height: 1.1,
              ),
            ),
          ),
        ],
      );
    }

    return _shell(
      background: clashes ? theme.colorScheme.errorContainer : colors.card,
      border: clashes ? theme.colorScheme.error : colors.line,
      children: [
        if (classes.isNotEmpty)
          // Shrinks to fit rather than cutting "10A+10B" to "10A+1…".
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _classesLabel(classes),
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: clashes ? theme.colorScheme.error : colors.softText,
                height: 1.1,
              ),
            ),
          ),
        Text(
          shortSubjectName(lesson.title),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 15,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  /// "10A+10B", as on Home: the hyphens cost the width that keeps two
  /// classes on one line. Three or more read "10A +3"; the sheet lists them.
  static String _classesLabel(List<String> classes) {
    final short = [for (final c in classes) c.replaceAll('-', '')];
    if (short.length <= 2) return short.join('+');
    return '${short.first} +${short.length - 1}';
  }

  Widget _shell({
    required Color background,
    required Color border,
    required List<Widget> children,
  }) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _LessonDetails extends StatelessWidget {
  const _LessonDetails({
    required this.lessons,
    required this.clashes,
    required this.choice,
  });

  final List<TimetableLesson> lessons;
  final bool clashes;

  /// A choice block: titled by its name, one row per option.
  final bool choice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final first = lessons.first;

    final day = kWeekdayLabels[first.dayIndex] ?? first.dayLabel;
    final start = _hhmm(first.startTime);
    final end = _hhmm(first.endTime);
    final time = [
      ?day,
      if (start != null) end == null ? start : '$start – $end',
      // A teacher's own choice lesson still says which choice it belongs to.
      if (!choice && first.isChoice) ?first.divisionName,
    ].join(' · ');

    // Each option once, even when the API repeats it for several classes.
    final seen = <String>{};
    final rows = [
      for (final lesson in lessons)
        if (seen.add(
          choice
              ? '${lesson.title}|${lesson.teacherLabel}|${lesson.room}'
              : '${lesson.id}|${classLabel(lesson)}',
        ))
          lesson,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              choice ? (first.divisionName ?? 'Choice') : first.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (time.isNotEmpty)
              Text(
                time,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.mutedText,
                ),
              ),
            if (clashes) ...[
              const SizedBox(height: 6),
              Text(
                'The teacher is booked elsewhere at this time.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            for (final lesson in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: choice ? 130 : 56,
                      child: Text(
                        choice ? _optionLabel(lesson) : classLabel(lesson),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: colors.softText,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        lesson.teacherLabel ?? '—',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    if (lesson.room != null && lesson.room!.trim().isNotEmpty)
                      Text(
                        lesson.room!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// "Boys · PE" when the option has a name of its own, else the subject.
  static String _optionLabel(TimetableLesson lesson) {
    final option = lesson.optionName?.trim();
    if (option == null ||
        option.isEmpty ||
        option.toLowerCase() == lesson.title.toLowerCase()) {
      return lesson.title;
    }
    return '$option · ${lesson.title}';
  }

  /// "08:30:00" → "08:30".
  static String? _hhmm(String? time) {
    final value = time?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length > 5 ? value.substring(0, 5) : value;
  }
}
