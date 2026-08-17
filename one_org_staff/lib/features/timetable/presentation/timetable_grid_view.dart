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
    this.caption,
  });

  final TimetableGrid grid;

  /// Row headers, top to bottom.
  final List<TimetableHeader> rows;

  /// Column headings, left to right.
  final List<TimetableHeader> columns;

  /// Heading for the frozen first column — "Weekday" or "Period".
  final String rowHeaderLabel;

  /// Optional caption header.
  final String? caption;

  static const _rowHeaderWidth = 54.0;
  static const _columnWidth = 100.0;
  static const _cellPadding = 3.0;
  static const _cardGap = 3.0;

  /// Unscaled heights. Everything vertical derives from these, so the two
  /// halves of the table cannot drift apart.
  static const _headerHeight = 42.0;
  static const _cardHeight = 52.0;

  /// A row nobody teaches in still reads as a row, not a hairline.
  static const _emptyRowHeight = 38.0;

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
    final cardHeight = _cardHeight * scale;

    final rowHeights = [
      for (var i = 0; i < rows.length; i++)
        _rowHeight(rows[i], cardHeight, scale) +
            (i == rows.length - 1 ? 0 : _divider),
    ];

    final tableWidget = Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
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
                  _columnHeadings(context, colors, headerHeight),
                  for (var i = 0; i < rows.length; i++)
                    _bodyRow(
                      context,
                      colors,
                      rows[i],
                      height: rowHeights[i],
                      cardHeight: cardHeight,
                      last: i == rows.length - 1,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
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

  /// How tall a row has to be to hold its fullest cell.
  double _rowHeight(TimetableHeader row, double cardHeight, double scale) {
    var deepest = 0;
    for (final column in columns) {
      final count = grid.at(row.key, column.key).length;
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
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
              ),
            ),
          ),
          for (var i = 0; i < rows.length; i++)
            Container(
              height: rowHeights[i],
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    if (rows[i].secondary != null)
                      Text(
                        rows[i].secondary!,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colors.mutedText,
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
              width: _columnWidth,
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: onAccent,
                      fontWeight: FontWeight.w800,
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
              width: _columnWidth,
              padding: const EdgeInsets.all(_cellPadding),
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(left: BorderSide(color: colors.line)),
              ),
              child: _cell(grid.at(row.key, columns[i].key), cardHeight),
            ),
        ],
      ),
    );
  }

  /// The lessons in one cell, stacked. Usually there is exactly one, so only
  /// the gaps *between* cards are spaced — a lone card adds no height.
  Widget _cell(List<TimetableLesson> lessons, double cardHeight) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < lessons.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : _cardGap),
            child: _LessonCard(
              lesson: lessons[i],
              clashes: grid.clashes(lessons[i]),
              height: cardHeight,
            ),
          ),
      ],
    );
  }
}

/// One lesson in a cell: the class in the accent colour with the subject under
/// it, or a note for the free-text lessons the timetable also carries.
class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.lesson,
    required this.clashes,
    required this.height,
  });

  final TimetableLesson lesson;

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

    if (lesson.isTextLesson) {
      return _shell(
        background: clashes
            ? theme.colorScheme.errorContainer
            : const Color(0xFFECFDF5),
        border: clashes ? theme.colorScheme.error : const Color(0xFFA7F3D0),
        children: [
          Text(
            'NOTE',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF047857),
              letterSpacing: 0.5,
              height: 1.1,
            ),
          ),
          Flexible(
            child: Text(
              lesson.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF065F46),
                height: 1.2,
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
        Text(
          classLabel(lesson),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: clashes ? theme.colorScheme.error : colors.softText,
            height: 1.1,
          ),
        ),
        Flexible(
          child: Text(
            lesson.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _shell({
    required Color background,
    required Color border,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: ClipRect(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}
