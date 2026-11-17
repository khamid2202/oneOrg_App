import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../domain/gradebook.dart';

const _tabular = [FontFeature.tabularFigures()];
const _nameWidth = 112.0;
const _averageWidth = 34.0;
const _cellWidth = 36.0;
const _rowHeight = 30.0;
const _headerHeight = 34.0;

String _ddmm(String date) =>
    date.length >= 10 ? '${date.substring(8, 10)}.${date.substring(5, 7)}' : '';

/// Background and text of a score out of 100, from strong to weak.
(Color?, Color?) _tone(double? percent) {
  if (percent == null) return (null, null);
  final color = percent >= 85
      ? const Color(0xFF10B981)
      : percent >= 60
      ? null
      : percent >= 40
      ? const Color(0xFFF59E0B)
      : const Color(0xFFEF4444);
  return (color?.withValues(alpha: 0.16), color);
}

String _whole(double? value) => value == null ? '–' : '${value.round()}';

/// A teacher's own gradebooks: pick one of their classes, then a subject.
class GradebooksPage extends StatefulWidget {
  const GradebooksPage({
    super.key,
    required this.loadPairs,
    required this.loadGradebook,
    this.initialGroupId,
    this.initialSubjectId,
    this.bottomInset = 0,
  });

  final Future<List<GradebookPair>> Function() loadPairs;
  final Future<Gradebook> Function(int groupId, int subjectId) loadGradebook;
  final int? initialGroupId;
  final int? initialSubjectId;
  final double bottomInset;

  @override
  State<GradebooksPage> createState() => _GradebooksPageState();
}

class _Picked {
  const _Picked(this.student, this.lesson, this.grade);

  final GradebookStudent student;
  final GradebookLesson lesson;
  final GradebookGrade grade;

  bool isCell(GradebookStudent s, GradebookLesson l) =>
      s.studentId == student.studentId && l.lessonId == lesson.lessonId;
}

class _GradebooksPageState extends State<GradebooksPage> {
  List<GradebookPair>? _pairs;
  bool _pairsFailed = false;

  int? _groupId;
  int? _subjectId;

  Gradebook? _book;
  bool _bookFailed = false;
  bool _loadingBook = false;
  int _bookRequest = 0;

  String? _month;
  bool _sortByAverage = false;
  _Picked? _picked;

  @override
  void initState() {
    super.initState();
    _loadPairs();
  }

  Future<void> _loadPairs() async {
    setState(() {
      _pairs = null;
      _pairsFailed = false;
    });
    try {
      final pairs = await widget.loadPairs();
      if (!mounted) return;
      setState(() => _pairs = pairs);
      _select(widget.initialGroupId, widget.initialSubjectId);
    } catch (_) {
      if (mounted) setState(() => _pairsFailed = true);
    }
  }

  /// Falls back to the first class or subject when the wanted one isn't there.
  void _select(int? groupId, int? subjectId) {
    final classes = gradebookClasses(_pairs ?? const []);
    if (classes.isEmpty) return;
    final group = classes.any((c) => c.id == groupId)
        ? groupId!
        : classes.first.id;
    final subjects = gradebookSubjects(_pairs!, group);
    final subject = subjects.any((s) => s.subjectId == subjectId)
        ? subjectId
        : subjects.firstOrNull?.subjectId;
    setState(() {
      _groupId = group;
      _subjectId = subject;
      _picked = null;
    });
    _loadBook();
  }

  Future<void> _loadBook() async {
    final group = _groupId;
    final subject = _subjectId;
    if (group == null || subject == null) return;
    final request = ++_bookRequest;
    setState(() {
      _loadingBook = true;
      _bookFailed = false;
    });
    try {
      final book = await widget.loadGradebook(group, subject);
      if (!mounted || request != _bookRequest) return;
      setState(() {
        _book = book;
        _loadingBook = false;
        if (_month != null && !book.months.contains(_month)) _month = null;
      });
    } catch (_) {
      if (!mounted || request != _bookRequest) return;
      setState(() {
        _book = null;
        _bookFailed = true;
        _loadingBook = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final book = _book;
    final view = book?.view(month: _month, sortByAverage: _sortByAverage);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.grades,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (view != null && !book!.isEmpty)
                  Text(
                    l.lessonsExamsCount(view.lessons.length, view.exams.length),
                    style: TextStyle(
                      fontSize: 12,
                      color: appColorsOf(context).mutedText,
                      fontFeatures: _tabular,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(child: _buildBody(l, book, view)),
        ],
      ),
    );
  }

  Widget _message(String text, {VoidCallback? retry}) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, widget.bottomInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: appColorsOf(context).mutedText),
            ),
            if (retry != null)
              TextButton(onPressed: retry, child: Text(l.retry)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l, Gradebook? book, GradebookView? view) {
    if (_pairsFailed) return _message(l.loadFailed, retry: _loadPairs);
    final pairs = _pairs;
    if (pairs == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (pairs.isEmpty) return _message(l.noClassesYet);

    final classes = gradebookClasses(pairs);
    final subjects = _groupId == null
        ? const <GradebookPair>[]
        : gradebookSubjects(pairs, _groupId!);
    final locale = Localizations.localeOf(context).toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ChipRow(
          children: [
            for (final item in classes)
              _Chip(
                label: item.name,
                icon: item.homeroom ? Icons.home_rounded : null,
                selected: item.id == _groupId,
                onTap: () => _select(item.id, _subjectId),
              ),
          ],
        ),
        const SizedBox(height: 6),
        _ChipRow(
          children: [
            for (final item in subjects)
              _Chip(
                label: item.subject,
                small: true,
                dot: item.teaches,
                selected: item.subjectId == _subjectId,
                onTap: () => _select(_groupId, item.subjectId),
              ),
          ],
        ),
        if (book != null && !book.isEmpty) ...[
          const SizedBox(height: 6),
          _ChipRow(
            children: [
              _Chip(
                label: l.all,
                small: true,
                selected: _month == null,
                onTap: () => setState(() {
                  _month = null;
                  _picked = null;
                }),
              ),
              for (final month in book.months)
                _Chip(
                  label: DateFormat.MMM(
                    locale,
                  ).format(DateTime.parse('$month-01')),
                  small: true,
                  selected: _month == month,
                  onTap: () => setState(() {
                    _month = month;
                    _picked = null;
                  }),
                ),
            ],
          ),
        ],
        const SizedBox(height: 6),
        Expanded(
          child: _bookFailed
              ? _message(l.loadFailed, retry: _loadBook)
              : book == null
              ? const Center(child: CircularProgressIndicator())
              : book.isEmpty
              ? _message(l.noGradesYet)
              : Opacity(
                  opacity: _loadingBook ? 0.6 : 1,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _GradebookTable(
                          // A new class or month starts scrolled to the left.
                          key: ValueKey('$_groupId:$_subjectId:$_month'),
                          view: view!,
                          bottomInset: widget.bottomInset,
                          sorted: _sortByAverage,
                          picked: _picked,
                          onSort: () =>
                              setState(() => _sortByAverage = !_sortByAverage),
                          onPick: (student, lesson, grade) => setState(() {
                            _picked = _picked?.isCell(student, lesson) == true
                                ? null
                                : _Picked(student, lesson, grade);
                          }),
                        ),
                      ),
                      if (_picked != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: widget.bottomInset - 16,
                          child: _PickedPanel(picked: _picked!),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _PickedPanel extends StatelessWidget {
  const _PickedPanel({required this.picked});

  final _Picked picked;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final grade = picked.grade;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  picked.student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_ddmm(picked.lesson.date)} · ${grade.score % 1 == 0 ? grade.score.toInt() : grade.score}',
                style: TextStyle(
                  fontSize: 13,
                  color: colors.mutedText,
                  fontFeatures: _tabular,
                ),
              ),
              if (grade.imported) ...[
                const SizedBox(width: 6),
                Text(
                  'EduPage',
                  style: TextStyle(fontSize: 11, color: colors.mutedText),
                ),
              ],
            ],
          ),
          if (grade.comment != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(grade.comment!, style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final child in children)
            Padding(padding: const EdgeInsets.only(right: 6), child: child),
        ],
      ),
    );
  }
}

class _Chip extends StatefulWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.small = false,
    this.dot = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool small;
  final bool dot;

  @override
  State<_Chip> createState() => _ChipState();
}

class _ChipState extends State<_Chip> {
  @override
  void initState() {
    super.initState();
    _revealIfSelected();
  }

  @override
  void didUpdateWidget(_Chip old) {
    super.didUpdateWidget(old);
    if (!old.selected) _revealIfSelected();
  }

  /// A long row can start with the chosen chip off screen.
  void _revealIfSelected() {
    if (!widget.selected) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Scrollable.ensureVisible(context, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final selected = widget.selected;
    final onTap = widget.onTap;
    final icon = widget.icon;
    final small = widget.small;
    final dot = widget.dot;
    final label = widget.label;
    final text = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Material(
      color: selected ? colors.accent.solid : colors.softBg,
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 12,
            vertical: small ? 4 : 6,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 13, color: text),
                const SizedBox(width: 3),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: small ? 12 : 14,
                  fontWeight: FontWeight.w600,
                  color: text,
                ),
              ),
              if (dot) ...[
                const SizedBox(width: 4),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : colors.accent.solid,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Names stay pinned on the left and dates on top; only the marks scroll.
class _GradebookTable extends StatefulWidget {
  const _GradebookTable({
    super.key,
    required this.view,
    required this.bottomInset,
    required this.sorted,
    required this.picked,
    required this.onSort,
    required this.onPick,
  });

  final GradebookView view;
  final double bottomInset;
  final bool sorted;
  final _Picked? picked;
  final VoidCallback onSort;
  final void Function(GradebookStudent, GradebookLesson, GradebookGrade) onPick;

  @override
  State<_GradebookTable> createState() => _GradebookTableState();
}

class _GradebookTableState extends State<_GradebookTable> {
  final _headerScroll = ScrollController();
  final _bodyScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _bodyScroll.addListener(() {
      if (_headerScroll.hasClients) _headerScroll.jumpTo(_bodyScroll.offset);
    });
  }

  @override
  void dispose() {
    _headerScroll.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }

  Widget _cell(
    String text, {
    double width = _cellWidth,
    double? percent,
    bool bold = false,
    bool dot = false,
    bool picked = false,
    VoidCallback? onTap,
  }) {
    final colors = appColorsOf(context);
    final (background, foreground) = _tone(percent);
    final cell = Container(
      width: width,
      height: _rowHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        border: picked
            ? Border.all(color: colors.accent.ring, width: 2)
            : Border(
                left: BorderSide(color: colors.line.withValues(alpha: 0.5)),
                top: BorderSide(color: colors.line.withValues(alpha: 0.5)),
              ),
      ),
      child: SizedBox.expand(
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: foreground,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                fontFeatures: _tabular,
              ),
            ),
            if (dot)
              Positioned(
                right: 2,
                top: 2,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFF818CF8),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return onTap == null ? cell : GestureDetector(onTap: onTap, child: cell);
  }

  Widget _headerCell(
    String top, {
    String? bottom,
    double width = _cellWidth,
    Color? color,
    VoidCallback? onTap,
  }) {
    final muted = appColorsOf(context).mutedText;
    final cell = Container(
      width: width,
      height: _headerHeight,
      color: color,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            top,
            maxLines: 1,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: muted,
              fontFeatures: _tabular,
            ),
          ),
          if (bottom != null)
            Text(
              bottom,
              maxLines: 1,
              style: TextStyle(
                fontSize: 9,
                color: muted.withValues(alpha: 0.8),
                fontFeatures: _tabular,
              ),
            ),
        ],
      ),
    );
    return onTap == null ? cell : GestureDetector(onTap: onTap, child: cell);
  }

  Widget _nameCell(String text, {bool bold = false}) {
    final colors = appColorsOf(context);
    return Container(
      width: _nameWidth,
      height: _rowHeight,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: colors.line.withValues(alpha: 0.5)),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final view = widget.view;

    final sameDay = <String, int>{};
    for (final lesson in view.lessons) {
      sameDay[lesson.date] = (sameDay[lesson.date] ?? 0) + 1;
    }

    return Column(
      children: [
        Row(
          children: [
            Container(
              width: _nameWidth,
              height: _headerHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 16),
              child: Text(
                l.student,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colors.mutedText,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: _headerScroll,
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  children: [
                    _headerCell(
                      '${l.averageShort}${widget.sorted ? ' ↓' : ''}',
                      width: _averageWidth,
                      onTap: widget.onSort,
                    ),
                    _headerCell(l.examsShort, width: _averageWidth),
                    for (final exam in view.exams)
                      _headerCell(
                        exam.shortPeriod,
                        bottom: _ddmm(exam.date),
                        color: colors.softBg,
                      ),
                    for (final lesson in view.lessons)
                      _headerCell(
                        _ddmm(lesson.date),
                        bottom: (sameDay[lesson.date] ?? 0) > 1
                            ? lesson.startTime.substring(
                                0,
                                lesson.startTime.length.clamp(0, 5),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: widget.bottomInset),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    for (final row in view.rows)
                      _nameCell(row.student.shortName),
                    _nameCell(l.classShort, bold: true),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _bodyScroll,
                    scrollDirection: Axis.horizontal,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final row in view.rows)
                          Row(
                            children: [
                              _cell(
                                _whole(row.dailyAverage),
                                width: _averageWidth,
                                percent: row.dailyAverage,
                                bold: true,
                              ),
                              _cell(
                                _whole(row.examAverage),
                                width: _averageWidth,
                                percent: row.examAverage,
                                bold: true,
                              ),
                              for (final exam in row.exams)
                                _cell(
                                  exam == null ? '' : _whole(exam.percent),
                                  percent: exam?.percent,
                                ),
                              for (var i = 0; i < row.daily.length; i++)
                                _gradeCell(row, view.lessons[i], row.daily[i]),
                            ],
                          ),
                        Row(
                          children: [
                            _cell(
                              _whole(view.classDailyAverage),
                              width: _averageWidth,
                              bold: true,
                            ),
                            _cell(
                              _whole(view.classExamAverage),
                              width: _averageWidth,
                              bold: true,
                            ),
                            for (final value in view.classExams)
                              _cell(
                                value == null ? '' : _whole(value),
                                bold: true,
                              ),
                            for (final value in view.classDaily)
                              _cell(
                                value == null ? '' : _whole(value),
                                bold: true,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradeCell(
    GradebookRow row,
    GradebookLesson lesson,
    GradebookGrade? grade,
  ) {
    if (grade == null) return _cell('');
    return _cell(
      _whole(grade.score),
      percent: grade.score,
      dot: grade.comment != null,
      picked: widget.picked?.isCell(row.student, lesson) == true,
      onTap: () => widget.onPick(row.student, lesson, grade),
    );
  }
}
