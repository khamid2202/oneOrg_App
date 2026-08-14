import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/point_report/domain/point_report_repository.dart';

/// Which column the table is ordered by.
enum PointReportSort { total, name }

/// The point report grid, laid out like the web app's table:
///
/// `No. | ID | Ism/Familya | Pr-week | Late | Absent | …one per subject… | Total`
///
/// The table keeps its full intrinsic width and is scrolled horizontally rather
/// than shrunk to the screen, because the export has to produce the same grid a
/// parent would see on the web. Fixed column widths (rather than flexible ones)
/// are what make the captured image line up.
class PointReportTable extends StatelessWidget {
  const PointReportTable({
    super.key,
    required this.students,
    required this.report,
    required this.classLabel,
    required this.periodLabel,
    required this.subjects,
    required this.columns,
    required this.sort,
    required this.descending,
    this.onSortChanged,
    this.forExport = false,
  });

  final List<StudentEntry> students;
  final PointReport report;
  final String classLabel;
  final String periodLabel;

  /// Every subject available this period, before the column choice is applied.
  final List<String> subjects;

  final PointReportColumns columns;

  final PointReportSort sort;
  final bool descending;

  /// Null in the exported copy — a captured image has nothing to tap.
  final void Function(PointReportSort column)? onSortChanged;

  /// Renders the plain variant that goes into the shared image: always light,
  /// no sort arrows, so the picture reads the same on any device.
  final bool forExport;

  static const _noWidth = 40.0;
  static const _nameWidth = 170.0;
  static const _metricWidth = 72.0;
  static const _subjectWidth = 88.0;
  static const _totalWidth = 68.0;

  /// Horizontal padding inside every cell, counted twice when sizing a column
  /// to its content.
  static const _cellPadding = 4.0;

  /// Person codes are `DIS` + year + order (`DIS260001`), but nothing stops the
  /// format growing, so the ID column is measured from the codes actually on
  /// screen rather than pinned to a width that happens to fit today. A truncated
  /// code is worse than a wide column: it is the one value a parent uses to
  /// identify their child.
  double get _idWidth {
    final painter = TextPainter(textDirection: TextDirection.ltr);

    var widest = 0.0;
    for (final text in ['ID', for (final s in students) s.code ?? '-']) {
      painter
        ..text = TextSpan(text: text, style: _cellTextStyle)
        ..layout();
      widest = widest > painter.width ? widest : painter.width;
    }
    painter.dispose();

    return widest + _cellPadding * 2 + 6;
  }

  /// The style the ID cell renders in. Measuring has to use the same weight, or
  /// the column comes out narrower than the text it has to hold.
  static const _cellTextStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );

  /// Students ordered by the active column. Ties fall back to the other
  /// column so the order is never arbitrary — same rule as the web.
  List<StudentEntry> get sortedStudents {
    final list = [...students];

    list.sort((a, b) {
      final totalA = report.totalsFor(a.personId).total;
      final totalB = report.totalsFor(b.personId).total;

      if (sort == PointReportSort.name) {
        final byName = descending
            ? b.fullName.toLowerCase().compareTo(a.fullName.toLowerCase())
            : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
        return byName != 0 ? byName : totalB.compareTo(totalA);
      }

      final byTotal = descending
          ? totalB.compareTo(totalA)
          : totalA.compareTo(totalB);
      return byTotal != 0
          ? byTotal
          : a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final palette = _TablePalette.of(context, forExport: forExport);
    final visibleSubjects = columns.visibleSubjects(subjects);
    final rows = sortedStudents;

    return Container(
      color: palette.pageBackground,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // The caption travels with the image, so a parent receiving it knows
          // which class and which week it covers.
          Text(
            classLabel,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: palette.headingText,
            ),
          ),
          Text(
            periodLabel,
            style: TextStyle(fontSize: 12, color: palette.mutedText),
          ),
          const SizedBox(height: 8),

          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: palette.grid),
                left: BorderSide(color: palette.grid),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _headerRow(context, palette, visibleSubjects),
                for (var index = 0; index < rows.length; index++)
                  _bodyRow(palette, visibleSubjects, rows[index], index + 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(
    BuildContext context,
    _TablePalette palette,
    List<String> subjects,
  ) {
    // IntrinsicHeight so every cell in the row matches the tallest one — a
    // two-line subject header must not leave the neighbouring cells short.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (columns.showsNo)
            _HeaderCell(
              width: _noWidth,
              label: 'No.',
              palette: palette,
              background: palette.accentHeader,
            ),
          if (columns.showsId)
            _HeaderCell(
              width: _idWidth,
              label: 'ID',
              palette: palette,
              background: palette.accentHeader,
            ),
          if (columns.showsName)
            _HeaderCell(
              width: _nameWidth,
              label: 'Ism/Familya',
              palette: palette,
              background: palette.accentHeader,
              alignment: Alignment.centerLeft,
              sortArrow: _arrowFor(PointReportSort.name),
              onTap: onSortChanged == null
                  ? null
                  : () => onSortChanged!(PointReportSort.name),
            ),
          if (columns.showsPreviousWeek)
            _HeaderCell(
              width: _metricWidth,
              label: 'Pr-week',
              palette: palette,
              background: palette.warnHeader,
            ),
          if (columns.showsAttendance) ...[
            _HeaderCell(
              width: _metricWidth,
              label: 'Late',
              palette: palette,
              background: palette.warnHeader,
            ),
            _HeaderCell(
              width: _metricWidth,
              label: 'Absent',
              palette: palette,
              background: palette.dangerHeader,
            ),
          ],
          for (final subject in subjects)
            _HeaderCell(
              width: _subjectWidth,
              label: formatSubjectLabel(subject),
              palette: palette,
              background: palette.subjectHeader,
            ),
          if (columns.showsTotal)
            _HeaderCell(
              width: _totalWidth,
              label: 'Total',
              palette: palette,
              background: palette.accentHeader,
              sortArrow: _arrowFor(PointReportSort.total),
              onTap: onSortChanged == null
                  ? null
                  : () => onSortChanged!(PointReportSort.total),
            ),
        ],
      ),
    );
  }

  String? _arrowFor(PointReportSort column) {
    if (forExport || sort != column) {
      return null;
    }
    return descending ? '↓' : '↑';
  }

  Widget _bodyRow(
    _TablePalette palette,
    List<String> subjects,
    StudentEntry student,
    int rowNumber,
  ) {
    final totals = report.totalsFor(student.personId);
    final late = totals.penalties[AttendancePenalty.late] ?? 0;
    final absent = totals.penalties[AttendancePenalty.absent] ?? 0;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (columns.showsNo)
            _BodyCell(width: _noWidth, text: '$rowNumber', palette: palette),
          if (columns.showsId)
            _BodyCell(
              width: _idWidth,
              text: student.code ?? '-',
              palette: palette,
              // Bold so the rendered weight matches the one _idWidth measures.
              bold: true,
            ),
          if (columns.showsName)
            _BodyCell(
              width: _nameWidth,
              text: student.fullName,
              palette: palette,
              alignment: Alignment.centerLeft,
              bold: true,
            ),
          if (columns.showsPreviousWeek)
            _BodyCell(
              width: _metricWidth,
              text: formatPoints(totals.previousWeekTotal),
              palette: palette,
              color: palette.colorFor(totals.previousWeekTotal),
            ),
          // "Good" rather than a bare 0, so a clean record reads as praise —
          // this is the wording the web uses and parents see.
          if (columns.showsAttendance) ...[
            _BodyCell(
              width: _metricWidth,
              text: late == 0 ? 'Good' : formatPoints(late),
              palette: palette,
              color: late == 0 ? palette.goodText : palette.colorFor(late),
            ),
            _BodyCell(
              width: _metricWidth,
              text: absent == 0 ? 'Good' : formatPoints(absent),
              palette: palette,
              color: absent == 0 ? palette.goodText : palette.colorFor(absent),
            ),
          ],
          for (final subject in subjects)
            _BodyCell(
              width: _subjectWidth,
              text: totals.subjects.containsKey(subject)
                  ? formatPoints(totals.subjects[subject]!.total)
                  : '',
              palette: palette,
              color: palette.colorFor(totals.subjects[subject]?.total ?? 0),
            ),
          if (columns.showsTotal)
            _BodyCell(
              width: _totalWidth,
              text: formatPoints(totals.total),
              palette: palette,
              color: palette.colorFor(totals.total),
              bold: true,
              background: palette.totalCell,
            ),
        ],
      ),
    );
  }
}

/// Right and bottom only, so neighbouring cells share a single line instead of
/// drawing two abutting ones. The table's own container supplies the top and
/// left edges — this is `border-collapse: collapse` by hand.
Border _gridBorder(_TablePalette palette) => Border(
  right: BorderSide(color: palette.grid),
  bottom: BorderSide(color: palette.grid),
);

class _HeaderCell extends StatelessWidget {
  const _HeaderCell({
    required this.width,
    required this.label,
    required this.palette,
    required this.background,
    this.alignment = Alignment.center,
    this.sortArrow,
    this.onTap,
  });

  final double width;
  final String label;
  final _TablePalette palette;
  final Color background;
  final Alignment alignment;
  final String? sortArrow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Fill and gridline share one decoration. Painting the border on a parent
    // and the fill on the child hides the border completely — the child covers
    // the whole box, including the inset the border occupies.
    final content = Container(
      width: width,
      decoration: BoxDecoration(
        color: background,
        border: _gridBorder(palette),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      alignment: alignment,
      child: Row(
        mainAxisAlignment: alignment == Alignment.centerLeft
            ? MainAxisAlignment.spaceBetween
            : MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              textAlign: alignment == Alignment.centerLeft
                  ? TextAlign.left
                  : TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: palette.headingText,
              ),
            ),
          ),
          if (sortArrow != null)
            Text(
              sortArrow!,
              style: TextStyle(fontSize: 11, color: palette.headingText),
            ),
        ],
      ),
    );

    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class _BodyCell extends StatelessWidget {
  const _BodyCell({
    required this.width,
    required this.text,
    required this.palette,
    this.alignment = Alignment.center,
    this.color,
    this.bold = false,
    this.background,
  });

  final double width;
  final String text;
  final _TablePalette palette;
  final Alignment alignment;
  final Color? color;
  final bool bold;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: background ?? palette.cell,
        border: _gridBorder(palette),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignment == Alignment.centerLeft
            ? TextAlign.left
            : TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          color: color ?? palette.bodyText,
        ),
      ),
    );
  }
}

/// The table's colours. The on-screen copy follows the app accent; the export
/// copy is pinned to a light palette so the shared picture is legible whatever
/// theme the sender happens to be using.
class _TablePalette {
  const _TablePalette({
    required this.pageBackground,
    required this.cell,
    required this.grid,
    required this.accentHeader,
    required this.subjectHeader,
    required this.warnHeader,
    required this.dangerHeader,
    required this.totalCell,
    required this.headingText,
    required this.bodyText,
    required this.mutedText,
  });

  final Color pageBackground;
  final Color cell;
  final Color grid;
  final Color accentHeader;
  final Color subjectHeader;
  final Color warnHeader;
  final Color dangerHeader;
  final Color totalCell;
  final Color headingText;
  final Color bodyText;
  final Color mutedText;

  static const _positive = Color(0xFF15803D);
  static const _negative = Color(0xFFB91C1C);

  Color get goodText => _positive;

  Color colorFor(double value) {
    if (value > 0) return _positive;
    if (value < 0) return _negative;
    return mutedText;
  }

  factory _TablePalette.of(BuildContext context, {required bool forExport}) {
    final colors = appColorsOf(context);

    if (forExport) {
      return _TablePalette(
        pageBackground: Colors.white,
        cell: Colors.white,
        grid: const Color(0xFF94A3B8),
        accentHeader: colors.accent.softBg,
        subjectHeader: const Color(0xFFF1F5F9),
        warnHeader: const Color(0xFFFEF3C7),
        dangerHeader: const Color(0xFFFFE4E6),
        totalCell: const Color(0xFFF8FAFC),
        headingText: const Color(0xFF0F172A),
        bodyText: const Color(0xFF334155),
        mutedText: const Color(0xFF64748B),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return _TablePalette(
      pageBackground: colors.card,
      cell: colors.card,
      grid: colors.line,
      accentHeader: colors.softBg,
      subjectHeader: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : const Color(0xFFF1F5F9),
      warnHeader: isDark ? const Color(0xFF3D2F14) : const Color(0xFFFEF3C7),
      dangerHeader: isDark ? const Color(0xFF44181D) : const Color(0xFFFFE4E6),
      totalCell: colors.softBg,
      headingText: Theme.of(context).colorScheme.onSurface,
      bodyText: Theme.of(context).colorScheme.onSurface,
      mutedText: colors.mutedText,
    );
  }
}
