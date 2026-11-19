import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/photo_viewer.dart';
import '../application/grading_sheet_controller.dart';
import '../domain/lesson_grading.dart';
import '../domain/lessons_repository.dart';
import 'attendance_step.dart' show AllCheckbox, statusColors, statusShort;
import 'grading_sheet_page.dart' show scoreColor;

const _categoryIcons = {
  materialsScore: Icons.menu_book_outlined,
  homeworkDoneScore: Icons.assignment_turned_in_outlined,
  homeworkScore: Icons.edit_note_rounded,
  activityScore: Icons.back_hand_outlined,
  notesScore: Icons.draw_outlined,
};

/// One hue per score column, so the eye finds a column by colour (the web's
/// `CATEGORY_COLORS`). The two homework columns are neighbours on the wheel;
/// amber still marks a low score and there's no green, which means done.
const _categoryHues = {
  materialsScore: Color(0xFF0284C7),
  homeworkDoneScore: Color(0xFF7C3AED),
  homeworkScore: Color(0xFFC026D3),
  activityScore: Color(0xFFE11D48),
  notesScore: Color(0xFF4F46E5),
};

const _thumbGreen = Color(0xFF059669);
const _thumbRed = Color(0xFFDC2626);
const _lowAmber = Color(0xFFB45309);

String _categoryLabel(AppLocalizations l, String field) => switch (field) {
  materialsScore => l.materials,
  homeworkDoneScore => l.homeworkDone,
  homeworkScore => l.homework,
  activityScore => l.activity,
  _ => l.notes,
};

/// The category above each score column.
class ScoresLegend extends StatelessWidget {
  const ScoresLegend({super.key, required this.sheet});

  final GradingSheetController sheet;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    // A lesson marked before grading v2 is all v1 rows: show its own maxes
    // (every category /20, no "homework brought").
    final version = sheet.allOldGrading ? 1 : gradingVersion;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          for (final field in teacherScoreFields)
            Expanded(
              // The checkbox gives every present / late student the usual
              // mark (full marks); unticking undoes it.
              child: Tooltip(
                message: appliesTo(field, version)
                    ? '${_categoryLabel(l, field)} /${maxFor(field, version)}'
                    : '${_categoryLabel(l, field)}: ${l.oldGradingLesson}',
                child: Opacity(
                  opacity: appliesTo(field, version) ? 1 : 0.4,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AllCheckbox(
                        count: sheet.givenCount(field),
                        total: sheet.gradableCount(field),
                        enabled: !sheet.readOnly,
                        onAll: () => sheet.fillAll(field),
                        onNone: () => sheet.unfillAll(field),
                      ),
                      Icon(
                        _categoryIcons[field],
                        size: 13,
                        color: _categoryHues[field],
                      ),
                      Flexible(
                        child: Text(
                          appliesTo(field, version)
                              ? '/${maxFor(field, version)}'
                              : '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.mutedText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ScoresStep extends StatefulWidget {
  const ScoresStep({super.key, required this.sheet, required this.expandAll});

  final GradingSheetController sheet;
  final bool expandAll;

  @override
  State<ScoresStep> createState() => _ScoresStepState();
}

class _ScoresStepState extends State<ScoresStep> {
  int? _expanded;
  String? _openPicker; // "studentId:category"
  final Set<int> _commentOpen = {};

  void _toggle(int id) {
    if (widget.expandAll) return;
    setState(() {
      _expanded = _expanded == id ? null : id;
      _openPicker = null;
      _commentOpen.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    final colors = appColorsOf(context);
    final problems = sheet.problems;

    return ListView.separated(
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: sheet.students.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.line),
      itemBuilder: (context, index) {
        final student = sheet.students[index];
        final id = student.studentId;
        final focused = widget.expandAll || _expanded == id;
        final needs = problems[id] == SheetProblem.commentRequired;
        final comment = sheet.draftOf(id)!.comment.trim();
        return _ScoreRow(
          key: ValueKey(id),
          sheet: sheet,
          student: student,
          focused: focused,
          needsComment: needs,
          showComment: _commentOpen.contains(id) || (needs && comment.isEmpty),
          openPicker: _openPicker?.startsWith('$id:') == true
              ? _openPicker!.substring('$id:'.length)
              : null,
          onToggle: () => _toggle(id),
          onPickerChanged: (field) =>
              setState(() => _openPicker = field == null ? null : '$id:$field'),
          onCommentChanged: (open) => setState(() {
            open ? _commentOpen.add(id) : _commentOpen.remove(id);
          }),
        );
      },
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({
    super.key,
    required this.sheet,
    required this.student,
    required this.focused,
    required this.needsComment,
    required this.showComment,
    required this.openPicker,
    required this.onToggle,
    required this.onPickerChanged,
    required this.onCommentChanged,
  });

  final GradingSheetController sheet;
  final SheetStudent student;
  final bool focused;
  final bool needsComment;
  final bool showComment;
  final String? openPicker;
  final VoidCallback onToggle;
  final ValueChanged<String?> onPickerChanged;
  final ValueChanged<bool> onCommentChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final id = student.studentId;
    final draft = sheet.draftOf(id)!;
    final away = !isGradable(draft.status);
    final total = draft.total;
    final comment = draft.comment.trim();
    final readOnly = sheet.readOnly;
    // Nobody marked or graded this student: there is no score to colour.
    // Nothing given yet: no total to show (an absence is a real 0).
    final hasResult =
        (away && draft.status != null) ||
        draft.hasTeacherScores ||
        draft.importedScore != null;
    final tone = hasResult ? scoreColor(total) : colors.mutedText;
    final marks = sheet.marksOf(id);

    final trailingScores = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (comment.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 12,
              color: colors.softText,
            ),
          ),
        for (final field in teacherScoreFields)
          SizedBox(
            width: 21,
            child: Text(
              draft.scores[field]?.toString() ?? '–',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight:
                    !away &&
                        appliesTo(field, draft.version) &&
                        draft.scores[field] != null &&
                        draft.scores[field]! < startFor(field, draft.version)
                    ? FontWeight.w700
                    : FontWeight.w400,
                color:
                    !away &&
                        appliesTo(field, draft.version) &&
                        draft.scores[field] != null &&
                        draft.scores[field]! < startFor(field, draft.version)
                    ? _lowAmber
                    : away
                    ? colors.mutedText
                    : _categoryHues[field],
              ),
            ),
          ),
      ],
    );

    final subline = <InlineSpan>[
      if (draft.status == statusLate)
        TextSpan(
          text:
              '+${l.minutesShort(draft.minutesLate ?? 0)}'
              '${draft.version != 1 && (draft.minutesLate ?? 0) > 0 ? ' (${formatScore(lateDeduction(statusLate, draft.minutesLate)!)})' : ''}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: statusColors[statusLate],
          ),
        ),
      if (away && draft.status != null)
        TextSpan(
          text: statusShort(l, draft.status!),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: statusColors[draft.status],
          ),
        ),
      if (draft.status == null)
        TextSpan(
          text: l.notMarked,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB45309),
          ),
        ),
      if (away && student.makeupScore != null)
        TextSpan(
          text: '${formatScore(student.makeupScore!)}*',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0369A1),
          ),
        ),
      ..._behaviorCounts(marks),
    ];

    return Container(
      color: needsComment ? _thumbRed.withValues(alpha: 0.07) : null,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: focused ? 7 : 2),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 34),
                child: Row(
                  children: [
                    ZoomableAvatar(
                      url: student.pictureUrl,
                      name: student.fullName,
                      child: CircleAvatar(
                        radius: 14,
                        backgroundColor: colors.avatarPlaceholder,
                        backgroundImage: student.pictureUrl == null
                            ? null
                            : NetworkImage(student.pictureUrl!),
                        child: student.pictureUrl == null
                            ? Text(
                                _initials(student.fullName),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: colors.softText,
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // The name has its own line so a status never pushes it
                    // out; the status and behaviour counts sit under it.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            student.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: focused
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: away && !focused ? colors.mutedText : null,
                            ),
                          ),
                          if (subline.isNotEmpty)
                            Text.rich(
                              TextSpan(
                                children: [
                                  for (final (i, span) in subline.indexed) ...[
                                    if (i > 0) const TextSpan(text: '  '),
                                    span,
                                  ],
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                        ],
                      ),
                    ),
                    if (focused) ...[
                      if (comment.isNotEmpty && !showComment)
                        Flexible(
                          child: GestureDetector(
                            onTap: () => onCommentChanged(true),
                            child: Text(
                              comment,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: colors.mutedText,
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 32,
                          height: 32,
                        ),
                        padding: EdgeInsets.zero,
                        tooltip: l.commentHint,
                        icon: Icon(
                          Icons.chat_bubble_outline,
                          size: 16,
                          color: comment.isNotEmpty
                              ? colors.softText
                              : colors.mutedText,
                        ),
                        onPressed: () => onCommentChanged(!showComment),
                      ),
                    ] else
                      trailingScores,
                    const SizedBox(width: 4),
                    Container(
                      constraints: BoxConstraints(minWidth: focused ? 46 : 34),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: tone.withValues(alpha: 0.1),
                        border: Border.all(color: tone.withValues(alpha: 0.35)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hasResult ? formatScore(total) : '–',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: focused ? 14 : 12,
                          fontWeight: FontWeight.w800,
                          color: tone,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (focused) ...[
              const SizedBox(height: 5),
              Row(
                children: [
                  for (
                    var index = 0;
                    index < teacherScoreFields.length;
                    index += 1
                  ) ...[
                    if (index > 0) const SizedBox(width: 5),
                    Expanded(
                      child: _CategoryButton(
                        field: teacherScoreFields[index],
                        value: draft.scores[teacherScoreFields[index]],
                        open: openPicker == teacherScoreFields[index],
                        away: away,
                        start: startFor(
                          teacherScoreFields[index],
                          draft.version,
                        ),
                        onTap:
                            readOnly ||
                                away ||
                                !appliesTo(
                                  teacherScoreFields[index],
                                  draft.version,
                                )
                            ? null
                            : () => onPickerChanged(
                                openPicker == teacherScoreFields[index]
                                    ? null
                                    : teacherScoreFields[index],
                              ),
                      ),
                    ),
                  ],
                ],
              ),
              if (openPicker != null) ...[
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (final (index, value) in quickValuesFor(
                      openPicker!,
                      draft.version,
                    ).indexed) ...[
                      if (index > 0) const SizedBox(width: 5),
                      Expanded(
                        child: _QuickValue(
                          hue: _categoryHues[openPicker],
                          value: value,
                          selected: draft.scores[openPicker] == value,
                          onTap: () {
                            final field = openPicker!;
                            sheet.update(
                              id,
                              (row) => row.scores[field] = value,
                            );
                            onPickerChanged(null);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ],
              if (showComment)
                _CommentBox(
                  sheet: sheet,
                  studentId: id,
                  // Not for absent students, and the window doesn't lock them.
                  canGiveBehavior:
                      sheet.canGiveBehavior &&
                      draft.status != statusAbsent &&
                      draft.status != statusExcused,
                  locked: readOnly,
                  required: needsComment,
                  onClose: () => onCommentChanged(false),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _initials(String name) => name
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();

  List<InlineSpan> _behaviorCounts(List<BehaviorMark> marks) {
    if (marks.isEmpty) return const [];
    final up = marks.where((m) => m.type == behaviorPositive).length;
    final down = marks.length - up;
    WidgetSpan thumb(IconData icon, Color color, int count) => WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 2),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
    return [
      if (up > 0) thumb(Icons.thumb_up_alt_rounded, _thumbGreen, up),
      if (down > 0) thumb(Icons.thumb_down_alt_rounded, _thumbRed, down),
    ];
  }
}

class _CategoryButton extends StatelessWidget {
  const _CategoryButton({
    required this.field,
    required this.value,
    required this.open,
    required this.away,
    required this.start,
    required this.onTap,
  });

  final String field;

  /// What a fresh sheet fills in; anything below it is flagged.
  final int start;
  final int? value;
  final bool open;

  /// Absent students are fixed at 0, which isn't a low score to flag.
  final bool away;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final low = !away && value != null && value! < start;
    final hue = _categoryHues[field] ?? colors.accent.solid;
    final foreground = low ? _lowAmber : hue;
    return Opacity(
      opacity: onTap == null ? 0.6 : 1,
      child: Material(
        color: low
            ? _lowAmber.withValues(alpha: 0.1)
            : hue.withValues(alpha: open ? 0.14 : 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: open
                ? hue
                : low
                ? _lowAmber.withValues(alpha: 0.45)
                : hue.withValues(alpha: 0.3),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: SizedBox(
            height: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_categoryIcons[field], size: 15, color: foreground),
                const SizedBox(width: 5),
                Text(
                  value?.toString() ?? '–',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickValue extends StatelessWidget {
  const _QuickValue({
    this.hue,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final Color? hue;
  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final pick = hue ?? colors.accent.solid;
    return Material(
      color: selected ? pick : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: selected ? pick : colors.line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              '$value',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : hue,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The row's comment box, with behavior built in: a thumb in front of the text
/// turns it into a behavior mark too, saved when the box is closed with ✓.
/// Without a thumb it is the grade comment, kept for the sheet's Save. When the
/// grades are locked the text is only the behavior note.
class _CommentBox extends StatefulWidget {
  const _CommentBox({
    required this.sheet,
    required this.studentId,
    required this.canGiveBehavior,
    required this.locked,
    required this.required,
    required this.onClose,
  });

  final GradingSheetController sheet;
  final int studentId;
  final bool canGiveBehavior;
  final bool locked;
  final bool required;
  final VoidCallback onClose;

  @override
  State<_CommentBox> createState() => _CommentBoxState();
}

class _CommentBoxState extends State<_CommentBox> {
  late final TextEditingController _text = TextEditingController(
    text: widget.locked
        ? ''
        : widget.sheet.draftOf(widget.studentId)?.comment ?? '',
  );
  String? _type;
  final List<String> _reasonIds = [];

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  bool get _missing => widget.required && _text.text.trim().isEmpty;

  bool get _canClose =>
      !_missing &&
      (_type == null || _reasonIds.isNotEmpty || _text.text.trim().isNotEmpty);

  void _done() {
    if (!_canClose) return;
    final type = _type;
    if (type != null) {
      widget.sheet.addBehaviorMark(
        studentId: widget.studentId,
        type: type,
        reasonIds: List.of(_reasonIds),
        comment: _text.text.trim(),
      );
    }
    widget.onClose();
  }

  void _pick(String type) {
    setState(() {
      _type = _type == type ? null : type;
      _reasonIds.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final sheet = widget.sheet;
    final id = widget.studentId;
    final type = _type;
    final marks = widget.canGiveBehavior
        ? sheet.marksOf(id)
        : const <BehaviorMark>[];
    final activeColor = type == behaviorPositive ? _thumbGreen : _thumbRed;

    Widget thumb(String value, IconData icon, Color color) {
      final on = type == value;
      return Padding(
        padding: const EdgeInsets.only(right: 5),
        child: Material(
          color: on ? color : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: on ? color : color.withValues(alpha: 0.4)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _pick(value),
            child: SizedBox(
              width: 36,
              height: 36,
              child: Icon(icon, size: 16, color: on ? Colors.white : color),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (widget.canGiveBehavior) ...[
                thumb(
                  behaviorPositive,
                  Icons.thumb_up_alt_outlined,
                  _thumbGreen,
                ),
                thumb(
                  behaviorNegative,
                  Icons.thumb_down_alt_outlined,
                  _thumbRed,
                ),
              ],
              Expanded(
                child: SizedBox(
                  height: 36,
                  child: TextField(
                    controller: _text,
                    enabled: !widget.locked || widget.canGiveBehavior,
                    autofocus: !widget.required,
                    maxLength: widget.locked ? 1000 : 255,
                    style: const TextStyle(fontSize: 14),
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      counterText: '',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 9,
                      ),
                      hintText: widget.required
                          ? l.whyBelow40
                          : type != null
                          ? l.noteOptional
                          : l.commentHint,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: _missing
                              ? _thumbRed.withValues(alpha: 0.5)
                              : colors.line,
                        ),
                      ),
                    ),
                    onChanged: (text) {
                      if (!widget.locked) {
                        sheet.update(id, (row) => row.comment = text);
                      }
                      setState(() {});
                    },
                    onSubmitted: (_) => _done(),
                  ),
                ),
              ),
              const SizedBox(width: 5),
              Material(
                color: _canClose
                    ? colors.accent.solid
                    : colors.accent.solid.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _canClose ? _done : null,
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (type != null) ...[
            const SizedBox(height: 5),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: [
                for (final reason in sheet.behaviorReasons.of(type))
                  _ReasonChip(
                    label: reason.label,
                    selected: _reasonIds.contains(reason.id),
                    color: activeColor,
                    onTap: () => setState(() {
                      _reasonIds.contains(reason.id)
                          ? _reasonIds.remove(reason.id)
                          : _reasonIds.add(reason.id);
                    }),
                  ),
              ],
            ),
          ],
          if (marks.isNotEmpty) ...[
            const SizedBox(height: 5),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final mark in marks)
                    Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      constraints: const BoxConstraints(maxWidth: 200),
                      decoration: BoxDecoration(
                        color:
                            (mark.type == behaviorPositive
                                    ? _thumbGreen
                                    : _thumbRed)
                                .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        mark.reasonLabel ?? mark.comment ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: mark.type == behaviorPositive
                              ? _thumbGreen
                              : _thumbRed,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Material(
      color: selected ? color.withValues(alpha: 0.14) : Colors.transparent,
      shape: StadiumBorder(
        side: BorderSide(color: selected ? color : colors.line),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: selected ? color : colors.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}
