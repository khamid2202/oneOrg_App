import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../application/grading_sheet_controller.dart';
import '../domain/lesson_grading.dart';
import '../domain/lessons_repository.dart';

/// A student's team from Team Shuffle: its colour and its place in the list.
typedef TeamMark = ({Color color, int order});

/// The sheet's students grouped by team (team order, then their sheet order);
/// anyone without a team goes last.
List<SheetStudent> orderByTeam(
  List<SheetStudent> students,
  Map<int, TeamMark> teams,
) {
  if (teams.isEmpty) return students;
  final indexed = students.indexed.toList()
    ..sort((a, b) {
      final byTeam = (teams[a.$2.studentId]?.order ?? 1 << 30).compareTo(
        teams[b.$2.studentId]?.order ?? 1 << 30,
      );
      return byTeam != 0 ? byTeam : a.$1.compareTo(b.$1);
    });
  return [for (final (_, student) in indexed) student];
}

/// The team's colour down a row's left edge.
Widget teamEdge(TeamMark? team, Widget child) => team == null
    ? child
    : DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: team.color, width: 4)),
        ),
        child: child,
      );

const statusColors = {
  statusPresent: Color(0xFF059669),
  statusLate: Color(0xFFF59E0B),
  statusAbsent: Color(0xFFDC2626),
  statusExcused: Color(0xFF0284C7),
};

/// Teachers mark three states. "Excused" stays valid data but has no button.
const _marks = [statusPresent, statusLate, statusAbsent];
const _lateShortcuts = [5, 10, 15];

double _buttonWidth(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 380 ? 50 : 60;

String statusLabel(AppLocalizations l, String status) => switch (status) {
  statusPresent => l.present,
  statusLate => l.late,
  statusAbsent => l.absent,
  _ => l.excused,
};

String statusShort(AppLocalizations l, String status) => switch (status) {
  statusPresent => l.presentShort,
  statusLate => l.lateShort,
  statusAbsent => l.absentShort,
  _ => l.excusedShort,
};

/// A small header checkbox: ticked when everybody has it, a dash when some
/// do. Tapping it gives it to everybody, or (when ticked) undoes that.
class AllCheckbox extends StatelessWidget {
  const AllCheckbox({
    super.key,
    required this.count,
    required this.total,
    required this.onAll,
    required this.onNone,
    this.enabled = true,
  });

  final int count;
  final int total;
  final VoidCallback onAll;
  final VoidCallback onNone;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final all = total > 0 && count == total;
    return SizedBox(
      width: 22,
      height: 22,
      child: Checkbox(
        tristate: true,
        value: all ? true : (count > 0 ? null : false),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        onChanged: enabled && total > 0
            ? (_) => all ? onNone() : onAll()
            : null,
      ),
    );
  }
}

/// Present and Absent can be given to everybody at once; Late needs minutes
/// per student, so it only counts.
const _markAll = {statusPresent, statusAbsent};

/// Counts above each attendance button column, with a checkbox that marks
/// everybody with that column's mark.
class AttendanceHeader extends StatelessWidget {
  const AttendanceHeader({super.key, required this.sheet});

  final GradingSheetController sheet;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final width = _buttonWidth(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              sheet.unmarkedCount > 0
                  ? l.notMarkedCount(sheet.unmarkedCount)
                  : l.allMarked,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sheet.unmarkedCount > 0
                    ? const Color(0xFFB45309)
                    : colors.mutedText,
              ),
            ),
          ),
          for (final status in _marks)
            Container(
              width: width,
              margin: const EdgeInsets.only(left: 5),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_markAll.contains(status)) ...[
                        AllCheckbox(
                          count: sheet.countMarked(status),
                          total: sheet.students.length,
                          enabled: !sheet.readOnly,
                          onAll: () => sheet.markAll(status),
                          onNone: () => sheet.unmarkAll(status),
                        ),
                        const SizedBox(width: 2),
                      ],
                      Text(
                        '${sheet.countMarked(status)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    statusLabel(l, status),
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: TextStyle(
                      fontSize: 10,
                      color: statusColors[status],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class AttendanceStep extends StatefulWidget {
  const AttendanceStep({super.key, required this.sheet, this.teams = const {}});

  final GradingSheetController sheet;

  /// Student id → team, when the class came from Team Shuffle.
  final Map<int, TeamMark> teams;

  @override
  State<AttendanceStep> createState() => _AttendanceStepState();
}

class _AttendanceStepState extends State<AttendanceStep> {
  /// Students whose minutes picker is open. It opens on Late and closes once
  /// minutes are picked; the Late button then shows them and reopens it.
  final Set<int> _lateOpen = {};

  void _tapMark(int id, GradeDraft draft, String status) {
    if (status == statusLate && draft.status == statusLate) {
      setState(() {
        _lateOpen.contains(id) ? _lateOpen.remove(id) : _lateOpen.add(id);
      });
      return;
    }
    widget.sheet.update(id, (row) => row.mark(status));
    setState(() {
      status == statusLate ? _lateOpen.add(id) : _lateOpen.remove(id);
    });
  }

  void _setMinutes(int id, int? minutes, {bool close = false}) {
    widget.sheet.update(
      id,
      (row) => row.mark(statusLate, minutes: minutes, keepMinutes: false),
    );
    if (close) setState(() => _lateOpen.remove(id));
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.sheet;
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final readOnly = sheet.readOnly;
    final problems = sheet.problems;
    final width = _buttonWidth(context);
    final students = orderByTeam(sheet.students, widget.teams);

    return ListView.separated(
      padding: EdgeInsets.zero,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      itemCount: students.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: colors.line),
      itemBuilder: (context, index) {
        final student = students[index];
        final id = student.studentId;
        final draft = sheet.draftOf(id)!;
        final missing = problems[id] == SheetProblem.minutesMissing;
        final showPicker =
            draft.status == statusLate &&
            (_lateOpen.contains(id) || draft.minutesLate == null || missing);

        return teamEdge(
          widget.teams[id],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.right,
                        style: TextStyle(fontSize: 12, color: colors.mutedText),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        student.fullName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                      ),
                    ),
                    for (final status in _marks)
                      Padding(
                        padding: const EdgeInsets.only(left: 5),
                        child: _MarkButton(
                          width: width,
                          selected: draft.status == status,
                          color: statusColors[status]!,
                          semanticLabel: statusLabel(l, status),
                          label:
                              status == statusLate &&
                                  draft.status == statusLate &&
                                  draft.minutesLate != null
                              ? l.minutesShort(draft.minutesLate!)
                              : statusShort(l, status),
                          onTap: readOnly
                              ? null
                              : () => _tapMark(id, draft, status),
                        ),
                      ),
                  ],
                ),
                if (showPicker)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        for (final minutes in _lateShortcuts)
                          Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: _LateChip(
                              label: l.minutesShort(minutes),
                              selected: draft.minutesLate == minutes,
                              onTap: readOnly
                                  ? null
                                  : () => _setMinutes(id, minutes, close: true),
                            ),
                          ),
                        const SizedBox(width: 5),
                        SizedBox(
                          width: 64,
                          height: 32,
                          child: TextFormField(
                            key: ValueKey('minutes-$id'),
                            initialValue: draft.minutesLate?.toString() ?? '',
                            enabled: !readOnly,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(3),
                            ],
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: l.minutesHint,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 8,
                              ),
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: missing
                                      ? statusColors[statusAbsent]!
                                      : colors.line,
                                ),
                              ),
                            ),
                            onChanged: (text) =>
                                _setMinutes(id, int.tryParse(text)),
                            onFieldSubmitted: (text) {
                              if (int.tryParse(text) != null) {
                                setState(() => _lateOpen.remove(id));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MarkButton extends StatelessWidget {
  const _MarkButton({
    required this.width,
    required this.selected,
    required this.color,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final double width;
  final bool selected;
  final Color color;
  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Semantics(
      label: semanticLabel,
      selected: selected,
      button: true,
      child: Opacity(
        opacity: onTap == null ? 0.6 : 1,
        child: Material(
          color: selected ? color : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? color : colors.line),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: SizedBox(
              width: width,
              height: 42,
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : colors.mutedText,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LateChip extends StatelessWidget {
  const _LateChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final amber = statusColors[statusLate]!;
    return Material(
      color: selected ? amber : amber.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(color: amber.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : const Color(0xFFB45309),
            ),
          ),
        ),
      ),
    );
  }
}
