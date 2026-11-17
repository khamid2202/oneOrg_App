import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../MyLessons/lesson_points_repository.dart';
import '../application/lessons_outbox.dart';
import '../domain/day_rows.dart';
import '../domain/lessons_repository.dart';
import 'grading_sheet_page.dart';

const _emerald = Color(0xFF059669);
const _amber = Color(0xFFB45309);

class LessonsPage extends StatefulWidget {
  const LessonsPage({
    super.key,
    required this.repository,
    required this.outbox,
    required this.loadAcademicYears,
    this.bottomInset = 0,
    this.initialDate,
  });

  /// The day to open on; today when null.
  final DateTime? initialDate;
  final LessonsRepository repository;
  final LessonsOutbox outbox;
  final Future<List<AcademicYearEntry>> Function() loadAcademicYears;
  final double bottomInset;

  @override
  State<LessonsPage> createState() => _LessonsPageState();
}

class _LessonsPageState extends State<LessonsPage> {
  late DateTime _date = _dayOf(widget.initialDate ?? DateTime.now());
  late Future<LessonDay> _day = widget.repository.getDay(_date);
  List<BellPeriod> _periods = const [];
  Timer? _clock;
  late final StreamSubscription<int> _uploaded;

  static DateTime _dayOf(DateTime time) =>
      DateTime(time.year, time.month, time.day);

  bool get _isToday => _date == _dayOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    _loadPeriods();
    // Keeps the "Now" highlight moving while the page stays open.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _isToday) setState(() {});
    });
    widget.outbox.addListener(_outboxChanged);
    // Done marks come from the server once a lesson's saves have reached it.
    _uploaded = widget.outbox.uploaded.listen((id) {
      if (mounted && widget.outbox.waitingFor(id).isEmpty) _refresh();
    });
  }

  void _outboxChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _clock?.cancel();
    _uploaded.cancel();
    widget.outbox.removeListener(_outboxChanged);
    super.dispose();
  }

  Future<void> _loadPeriods() async {
    final date = _date;
    int? yearId;
    try {
      final years = await widget.loadAcademicYears();
      if (years.isNotEmpty) {
        yearId = years
            .firstWhere((entry) => entry.isActive, orElse: () => years.first)
            .id;
      }
    } catch (_) {
      // Offline: the bell schedule kept on the phone is used.
    }
    try {
      final periods = await widget.repository.getPeriods(
        academicYearId: yearId,
        date: date,
      );
      if (mounted && date == _date) setState(() => _periods = periods);
    } catch (_) {
      // The standard school day stands in for an unreadable bell schedule.
    }
  }

  void _goTo(DateTime date) {
    setState(() {
      _date = _dayOf(date);
      _day = widget.repository.getDay(_date);
    });
    _loadPeriods();
  }

  Future<void> _refresh() {
    final next = widget.repository.getDay(_date);
    setState(() {
      _day = next;
    });
    return next.then((_) {}, onError: (_) {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) _goTo(picked);
  }

  Future<void> _open(TeacherLesson lesson) async {
    final instanceId = lesson.instanceId;
    if (instanceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).noLessonRecord)),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GradingSheetPage(
          repository: widget.repository,
          outbox: widget.outbox,
          lessonId: instanceId,
          fallbackTitle: lesson.fullClassLabel ?? lesson.classLabel,
          fallbackSubject: lesson.subject,
        ),
      ),
    );
    // The done marks on the row come from what was just saved.
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final dateLabel = DateFormat.MMMEd(locale).format(_date);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.mySchedule,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!_isToday)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  onPressed: () => _goTo(DateTime.now()),
                  child: Text(l.today),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () =>
                    _goTo(DateTime(_date.year, _date.month, _date.day - 1)),
              ),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                    vertical: 6,
                  ),
                  child: Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () =>
                    _goTo(DateTime(_date.year, _date.month, _date.day + 1)),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<LessonDay>(
            key: ValueKey(_date),
            future: _day,
            builder: (context, snapshot) {
              // A reload of the same day keeps its lessons on screen.
              if (snapshot.connectionState != ConnectionState.done &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.connectionState == ConnectionState.done &&
                  snapshot.hasError) {
                return _Message(
                  text: l.loadLessonsFailed,
                  action: OutlinedButton(
                    onPressed: _refresh,
                    child: Text(l.retry),
                  ),
                );
              }
              final day = snapshot.data!;
              final rows = buildDayRows(_periods, day);
              final isEmptyDay = day.lessons.isEmpty && day.meetings.isEmpty;
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    8,
                    2,
                    10,
                    widget.bottomInset + 8,
                  ),
                  children: [
                    if (isEmptyDay)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 4, 0, 8),
                        child: Text(
                          l.noLessonsOn(dateLabel),
                          style: TextStyle(
                            fontSize: 13,
                            color: appColorsOf(context).mutedText,
                          ),
                        ),
                      ),
                    for (final row in rows)
                      _Row(
                        row: row,
                        nowMinutes: _isToday
                            ? DateTime.now().hour * 60 + DateTime.now().minute
                            : null,
                        onOpen: _open,
                        outbox: widget.outbox,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

String _clock24(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:'
    '${(minutes % 60).toString().padLeft(2, '0')}';

class _Row extends StatelessWidget {
  const _Row({
    required this.row,
    required this.nowMinutes,
    required this.onOpen,
    required this.outbox,
  });

  final DayRow row;
  final int? nowMinutes;
  final ValueChanged<TeacherLesson> onOpen;
  final LessonsOutbox outbox;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final now = nowMinutes;
    final past = now != null && row.end <= now;
    final timeColor = past
        ? colors.mutedText.withValues(alpha: 0.55)
        : colors.mutedText;
    final period = row.period;

    if (row.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: SizedBox(
          height: 24,
          child: Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(
                  _clock24(row.start),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    color: timeColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: colors.line.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    period == null ? '' : l.periodShort(period.number),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: timeColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const SizedBox(height: 4),
                  Text(
                    _clock24(row.start),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: timeColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    _clock24(row.end),
                    style: TextStyle(
                      fontSize: 11,
                      color: timeColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            for (var index = 0; index < row.items.length; index += 1) ...[
              if (index > 0) const SizedBox(width: 3),
              Expanded(
                child: row.items[index].meeting != null
                    ? _MeetingCard(meeting: row.items[index].meeting!)
                    : _LessonCard(
                        item: row.items[index],
                        nowMinutes: now,
                        waiting: outbox
                            .waitingFor(
                              row.items[index].lesson!.instanceId ?? -1,
                            )
                            .map((entry) => entry.kind)
                            .toSet(),
                        onTap: () => onOpen(row.items[index].lesson!),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _duration(AppLocalizations l, int minutes) {
  if (minutes < 60) return l.durationMinutes(minutes);
  final rest = minutes % 60;
  return rest == 0
      ? l.durationHours(minutes ~/ 60)
      : l.durationHoursMinutes(minutes ~/ 60, rest);
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({
    required this.item,
    required this.nowMinutes,
    required this.waiting,
    required this.onTap,
  });

  final DayItem item;
  final int? nowMinutes;

  /// What of this lesson is still on the phone.
  final Set<UploadKind> waiting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final lesson = item.lesson!;
    final cancelled = lesson.isCancelled;
    final now = nowMinutes;
    final isNow =
        now != null && !cancelled && item.start <= now && now < item.end;
    final past = now != null && item.end <= now;
    final scorable = lesson.instanceId != null;
    final attendanceDone =
        lesson.attendanceTaken || waiting.contains(UploadKind.attendance);
    final gradesDone =
        lesson.gradesEntered > 0 || waiting.contains(UploadKind.grades);
    final showMarks =
        scorable &&
        !cancelled &&
        (past || isNow || attendanceDone || gradesDone);
    final muted = colors.mutedText;

    final chips = <Widget>[
      if (lesson.room != null)
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.place_outlined, size: 12, color: muted),
            const SizedBox(width: 1),
            Text(lesson.room!, style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      // The server often names a subject's subgroup after the subject itself.
      if (lesson.subgroup != null &&
          lesson.subgroup!.toLowerCase() != lesson.subject.toLowerCase())
        Text(lesson.subgroup!, style: TextStyle(fontSize: 12, color: muted)),
      if (lesson.isSubstitution) _Tag(text: l.substitution, color: _amber),
      if (cancelled) _Tag(text: l.cancelled, color: muted),
    ];

    return Opacity(
      opacity: past || cancelled ? 0.62 : 1,
      child: Material(
        color: isNow ? colors.softBg : colors.card,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isNow ? colors.accent.solid : colors.border,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: double.infinity,
                  constraints: const BoxConstraints(minHeight: 46),
                  decoration: BoxDecoration(
                    color: isNow ? colors.accent.solid : colors.ring,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(8),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Text(
                              lesson.classLabel,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                decoration: cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                lesson.subject.isEmpty
                                    ? l.untitled
                                    : lesson.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            if (isNow)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.solid,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l.nowFor(_duration(l, item.end - now)),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (chips.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: chips,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (waiting.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Icon(
                      Icons.cloud_upload_outlined,
                      size: 15,
                      color: _amber,
                    ),
                  ),
                if (showMarks) ...[
                  Icon(
                    Icons.how_to_reg_rounded,
                    size: 15,
                    color: attendanceDone ? _emerald : colors.line,
                  ),
                  const SizedBox(width: 3),
                  Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 15,
                    color: gradesDone ? _emerald : colors.line,
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 4),
                  child: Icon(
                    scorable
                        ? Icons.chevron_right_rounded
                        : Icons.edit_off_outlined,
                    size: scorable ? 18 : 14,
                    color: colors.line,
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

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting});

  final TeacherMeeting meeting;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            meeting.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          Text(
            meeting.room == null ? l.meeting : '${l.meeting} · ${meeting.room}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: colors.mutedText),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}
