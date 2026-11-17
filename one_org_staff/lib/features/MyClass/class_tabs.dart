import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../MyLessons/lesson_points_repository.dart';
import 'class_insights.dart';

const _tabular = [FontFeature.tabularFigures()];

/// Score bands for every average on the Grades tab (0–100), as on the web.
class _Band {
  const _Band(this.min, this.label, this.color);
  final double min;
  final String label;
  final Color color;
}

const _bands = [
  _Band(85, '85+', Color(0xFF10B981)),
  _Band(70, '70+', Color(0xFF0EA5E9)),
  _Band(50, '50+', Color(0xFFF59E0B)),
  _Band(double.negativeInfinity, '<50', Color(0xFFF43F5E)),
];

_Band? _bandOf(double? value) =>
    value == null ? null : _bands.firstWhere((band) => value >= band.min);

String _score(double? value) => value == null
    ? '—'
    : value >= 99.95
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(1);

/// "Abdurashidov Muhammadali" → "Abdurashidov M."
String _shortName(String full) {
  final parts = full.trim().split(RegExp(r'\s+'));
  if (parts.length < 2 || parts[1].isEmpty) return parts.first;
  return '${parts[0]} ${parts[1][0]}.';
}

/// A tinted chip in a band's colour; grey when there's no score.
BoxDecoration _tint(BuildContext context, _Band? band) => BoxDecoration(
  color: band == null
      ? appColorsOf(context).softBg
      : band.color.withValues(alpha: 0.14),
  borderRadius: BorderRadius.circular(8),
);

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.text, {this.onRetry});

  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(color: appColorsOf(context).mutedText)),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
        ],
      ),
    ),
  );
}

/// The class at a glance: its average, how many students sit in each band,
/// every subject and every student — the web's class Grades tab.
class ClassGradesView extends StatefulWidget {
  const ClassGradesView({
    super.key,
    required this.loadGrades,
    required this.students,
  });

  final Future<ClassGrades> Function() loadGrades;

  /// Current students only.
  final List<StudentEntry> students;

  @override
  State<ClassGradesView> createState() => _ClassGradesViewState();
}

class _ClassGradesViewState extends State<ClassGradesView> {
  late Future<ClassGrades> _future = widget.loadGrades();
  _Band? _filter;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<ClassGrades>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Loading();
        }
        final grades = snapshot.data;
        if (snapshot.hasError || grades == null) {
          return _Message(
            l.classGradesFailed,
            onRetry: () => setState(() => _future = widget.loadGrades()),
          );
        }
        if (grades.isEmpty) return _Message(l.classGradesNone);
        return _body(context, l, grades);
      },
    );
  }

  Widget _body(BuildContext context, AppLocalizations l, ClassGrades grades) {
    final colors = appColorsOf(context);
    final rows =
        [
          for (final student in widget.students)
            (name: student.fullName, score: grades.scoreOf(student.personId)),
        ]..sort((a, b) {
          final byScore = (b.score ?? -1).compareTo(a.score ?? -1);
          return byScore != 0 ? byScore : a.name.compareTo(b.name);
        });
    final counts = {for (final band in _bands) band: 0};
    for (final row in rows) {
      final band = _bandOf(row.score);
      if (band != null) counts[band] = counts[band]! + 1;
    }
    final scored = counts.values.fold(0, (a, b) => a + b);
    final visible = _filter == null
        ? rows
        : rows.where((row) => _bandOf(row.score) == _filter).toList();
    final average = grades.classAverage;
    final labelStyle = TextStyle(fontSize: 10, color: colors.mutedText);

    Widget stat(IconData icon, String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: colors.line),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: colors.mutedText),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontFeatures: _tabular,
              ),
            ),
            Text(label, style: labelStyle, maxLines: 1),
          ],
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              key: const ValueKey('class-average'),
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: _tint(context, _bandOf(average)),
              child: Text(
                _score(average),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: _bandOf(average)?.color,
                  fontFeatures: _tabular,
                ),
              ),
            ),
            const SizedBox(width: 10),
            stat(
              Icons.table_chart_outlined,
              _score(grades.importedAverage),
              'Edupage',
            ),
            const SizedBox(width: 6),
            stat(
              Icons.event_available_outlined,
              _score(grades.dailyAverage),
              l.classDaily,
            ),
            const SizedBox(width: 6),
            stat(
              Icons.group_outlined,
              '$scored/${widget.students.length}',
              l.classGraded,
            ),
          ],
        ),
        if (scored > 0) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 8,
              child: Row(
                // Without stretch the empty segments collapse to no height.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final band in _bands)
                    if (counts[band]! > 0)
                      Expanded(
                        flex: counts[band]!,
                        child: ColoredBox(color: band.color),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              for (final band in _bands)
                Expanded(
                  child: InkWell(
                    key: ValueKey('band-${band.label}'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () =>
                        setState(() => _filter = _filter == band ? null : band),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: _filter == band ? _tint(context, band) : null,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: band.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${band.label} ',
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedText,
                            ),
                          ),
                          Text(
                            '${counts[band]}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontFeatures: _tabular,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (grades.subjects.isNotEmpty) ...[
          const SizedBox(height: 10),
          _SectionIcon(Icons.menu_book_outlined),
          _Grid(
            columns: 3,
            children: [
              for (final subject in grades.subjects)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 5,
                  ),
                  decoration: _tint(context, _bandOf(subject.average)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          subject.subject,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, height: 1.1),
                        ),
                      ),
                      Text(
                        _score(subject.average),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _bandOf(subject.average)?.color,
                          fontFeatures: _tabular,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        if (grades.dailyLessons > 0) ...[
          const SizedBox(height: 10),
          _SectionIcon(Icons.event_available_outlined),
          Row(
            children: [
              for (final (key, label) in [
                ('average_attendance', l.classCatAttend),
                ('average_materials', l.classCatBooks),
                ('average_homework', l.classCatHomework),
                ('average_activity', l.classCatActive),
                ('average_notes', l.classCatNotes),
              ])
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: _tint(
                      context,
                      _bandOf((grades.categories[key] ?? 0) * 5),
                    ),
                    child: Column(
                      children: [
                        Text(
                          _score(grades.categories[key]),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFeatures: _tabular,
                          ),
                        ),
                        Text(label, style: labelStyle, maxLines: 1),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 10),
        _SectionIcon(Icons.group_outlined),
        _Grid(
          columns: 2,
          children: [
            for (final row in visible)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.line),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _shortName(row.name),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _score(row.score),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _bandOf(row.score)?.color ?? colors.mutedText,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Icon(icon, size: 14, color: appColorsOf(context).mutedText),
  );
}

/// Equal-width cells, [columns] to a row, without a scrolling GridView.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var start = 0; start < children.length; start += columns)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                for (var i = start; i < start + columns; i++) ...[
                  if (i > start) const SizedBox(width: 4),
                  Expanded(
                    child: i < children.length
                        ? children[i]
                        : const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// The class's behavior on one screen: totals with the Mark button, the
/// students who have marks, and the last three — the web's class Behavior tab.
class ClassBehaviorView extends StatefulWidget {
  const ClassBehaviorView({
    super.key,
    required this.loadMarks,
    required this.students,
    this.onMark,
  });

  final Future<List<ClassMark>> Function() loadMarks;
  final List<StudentEntry> students;

  /// Opens the Behavior screen. Absent when this person can't mark.
  final VoidCallback? onMark;

  @override
  State<ClassBehaviorView> createState() => _ClassBehaviorViewState();
}

class _ClassBehaviorViewState extends State<ClassBehaviorView> {
  late Future<List<ClassMark>> _future = widget.loadMarks();
  bool _showAll = false;

  static String _normal(String value) => value.trim().toLowerCase();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FutureBuilder<List<ClassMark>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Loading();
        }
        final marks = snapshot.data;
        if (snapshot.hasError || marks == null) {
          return _Message(
            l.classBehaviorFailed,
            onRetry: () => setState(() => _future = widget.loadMarks()),
          );
        }
        return _body(context, l, marks);
      },
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations l,
    List<ClassMark> marks,
  ) {
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    const green = Color(0xFF10B981);
    const red = Color(0xFFF43F5E);

    // A mark belongs to a roster student by id, else by name (older bot
    // marks). Marks matching nobody still count, under the mark's own name.
    final byId = {for (final s in widget.students) s.id: s};
    final byName = {for (final s in widget.students) _normal(s.fullName): s};
    final rows = <String, ({String name, int positive, int negative})>{};
    for (final mark in marks) {
      final student = byId[mark.studentId] ?? byName[_normal(mark.studentName)];
      final key = student != null
          ? 's:${student.id}'
          : 'n:${_normal(mark.studentName)}';
      final row =
          rows[key] ??
          (
            name: student?.fullName ?? mark.studentName,
            positive: 0,
            negative: 0,
          );
      rows[key] = mark.positive
          ? (name: row.name, positive: row.positive + 1, negative: row.negative)
          : (
              name: row.name,
              positive: row.positive,
              negative: row.negative + 1,
            );
    }
    final marked = rows.values.toList()
      ..sort((a, b) {
        final byNegative = b.negative.compareTo(a.negative);
        if (byNegative != 0) return byNegative;
        final byPositive = b.positive.compareTo(a.positive);
        return byPositive != 0 ? byPositive : a.name.compareTo(b.name);
      });
    final positive = marks.where((m) => m.positive).length;
    final recent = _showAll ? marks : marks.take(3).toList();

    Widget count(IconData icon, int value, Color color, String label) =>
        Tooltip(
          message: label,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  '$value',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontFeatures: _tabular,
                  ),
                ),
              ],
            ),
          ),
        );

    Widget pill(IconData icon, int value, Color color) => Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 2),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: _tabular,
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            count(Icons.favorite_rounded, positive, green, l.classPositive),
            const SizedBox(width: 8),
            count(
              Icons.shield_outlined,
              marks.length - positive,
              red,
              l.classNeedsAttention,
            ),
            const Spacer(),
            if (widget.onMark != null)
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent.solid,
                  foregroundColor: Colors.white,
                ),
                onPressed: widget.onMark,
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: Text(l.classMark),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (marked.isEmpty)
          _Message(l.classNoMarks)
        else
          for (final row in marked)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: colors.line),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (row.positive > 0)
                    pill(Icons.favorite_rounded, row.positive, green),
                  if (row.negative > 0)
                    pill(Icons.shield_outlined, row.negative, red),
                ],
              ),
            ),
        if (marks.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: colors.line),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                for (var i = 0; i < recent.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: colors.line.withValues(alpha: 0.6),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          recent[i].positive
                              ? Icons.favorite_rounded
                              : Icons.shield_outlined,
                          size: 14,
                          color: recent[i].positive ? green : red,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _shortName(recent[i].studentName),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            recent[i].reason ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.mutedText,
                            ),
                          ),
                        ),
                        if (recent[i].createdAt != null)
                          Text(
                            DateFormat(
                              'd MMM',
                              locale,
                            ).format(recent[i].createdAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedText,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (!_showAll && marks.length > 3)
                  InkWell(
                    onTap: () => setState(() => _showAll = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      child: Center(
                        child: Text(
                          l.classAllMarks(marks.length),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.accent.solid,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
