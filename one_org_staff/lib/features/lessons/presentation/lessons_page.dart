import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../shared/lesson_tags.dart';
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

  /// The now line, to scroll to when today opens mid-day.
  final _nowKey = GlobalKey();
  DateTime? _scrolledFor;

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
    // Lunch duty is on the schedule but has nothing to mark.
    if (lesson.isLunchDuty) return;
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
              final layout = layoutDay(_periods, day);
              final isEmptyDay = day.lessons.isEmpty && day.meetings.isEmpty;
              final now = DateTime.now();
              final nowMinutes = _isToday ? now.hour * 60 + now.minute : null;
              // Opening today mid-day lands on the current time, not period 1.
              if (nowMinutes != null && _scrolledFor != _date) {
                _scrolledFor = _date;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  final target = _nowKey.currentContext;
                  if (target != null && target.mounted) {
                    Scrollable.ensureVisible(target, alignment: 0.4);
                  }
                });
              }
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
                    _DayTimeline(
                      layout: layout,
                      nowMinutes: nowMinutes,
                      nowKey: _nowKey,
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

/// Vertical scale of the day, as on the web: a 45-minute period is ~52 px.
const _pxPerMinute = 1.15;
const _gutter = 56.0;
const _nowRed = Color(0xFFEF4444);
const _violet = Color(0xFF7C3AED);
const _meetingAmber = Color(0xFFD97706);

/// The day on one time scale, like the web's `DaySchedule`: every bell period
/// drawn whether or not you teach it, your lessons laid over theirs, and a
/// red line at the current time.
class _DayTimeline extends StatelessWidget {
  const _DayTimeline({
    required this.layout,
    required this.nowMinutes,
    required this.nowKey,
    required this.onOpen,
    required this.outbox,
  });

  final DayLayout layout;
  final int? nowMinutes;
  final Key nowKey;
  final ValueChanged<TeacherLesson> onOpen;
  final LessonsOutbox outbox;

  double _y(int minutes) =>
      (minutes.clamp(layout.start, layout.end) - layout.start) * _pxPerMinute;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final now = nowMinutes;
    final showNow = now != null && now >= layout.start && now <= layout.end;
    const tabular = [FontFeature.tabularFigures()];

    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = constraints.maxWidth - _gutter;
        return SizedBox(
          height: _y(layout.end) + 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final period in layout.periods)
                () {
                  final past = now != null && period.end <= now;
                  final taught = layout.taught(period);
                  final timeColor = past
                      ? colors.mutedText.withValues(alpha: 0.55)
                      : colors.mutedText;
                  final top = _y(period.start);
                  return Positioned(
                    top: top,
                    height: _y(period.end) - top,
                    left: 0,
                    right: 0,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: _gutter,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 8),
                            // Shrinks rather than overflow with large fonts.
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: taught
                                  ? Alignment.topRight
                                  : Alignment.centerRight,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: taught
                                    ? MainAxisAlignment.start
                                    : MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _clock24(period.start),
                                    style: TextStyle(
                                      fontSize: taught ? 12 : 11,
                                      fontWeight: taught
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                      color: timeColor,
                                      fontFeatures: tabular,
                                    ),
                                  ),
                                  if (taught) ...[
                                    Text(
                                      _clock24(period.end),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: timeColor,
                                        fontFeatures: tabular,
                                      ),
                                    ),
                                    Text(
                                      l.periodShort(period.number),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: colors.mutedText.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: colors.line.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: taught
                                ? null
                                : Text(
                                    l.periodShort(period.number),
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
                  );
                }(),
              for (final placed in layout.items)
                () {
                  final item = placed.item;
                  final width = laneWidth / placed.columns;
                  final gap = placed.column > 0 ? 2.0 : 0.0;
                  final height = (item.end - item.start) * _pxPerMinute - 2;
                  final card = item.meeting != null
                      ? _MeetingCard(meeting: item.meeting!)
                      : _LessonCard(
                          item: item,
                          nowMinutes: now,
                          waiting: outbox
                              .waitingFor(item.lesson!.instanceId ?? -1)
                              .map((entry) => entry.kind)
                              .toSet(),
                          onTap: () => onOpen(item.lesson!),
                        );
                  return Positioned(
                    top: _y(item.start) + 1,
                    height: height,
                    left: _gutter + width * placed.column + gap,
                    width: width - gap,
                    // A short slot shows the top of its card, like the web.
                    child: height >= _cardMinHeight
                        ? card
                        : ClipRect(
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              minHeight: _cardMinHeight,
                              maxHeight: _cardMinHeight,
                              child: card,
                            ),
                          ),
                  );
                }(),
              if (showNow)
                Positioned(
                  key: nowKey,
                  top: _y(now) - 9,
                  height: 18,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        SizedBox(
                          width: _gutter - 4,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _nowRed,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _clock24(now),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  fontFeatures: tabular,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _nowRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(child: Container(height: 2, color: _nowRed)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The height a lesson card needs for its two lines.
const _cardMinHeight = 46.0;

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
    if (lesson.isLunchDuty) {
      // On the schedule but nothing to mark, so no arrow, in the web's violet.
      final past = nowMinutes != null && item.end <= nowMinutes!;
      return Opacity(
        opacity: past ? 0.62 : 1,
        child: Container(
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
          decoration: BoxDecoration(
            color: _violet.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _violet.withValues(alpha: 0.3)),
          ),
          child: Text(
            l.lunchDuty,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _violet,
            ),
          ),
        ),
      );
    }
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
      if (lesson.tags.isNotEmpty) LessonTags(tags: lesson.tags),
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
                  // A slot shorter than its text (large fonts) is clipped,
                  // not overflowed.
                  child: ClipRect(
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxHeight: double.infinity,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 5, 6, 5),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                                    lesson.isLunchDuty
                                        ? l.lunchDuty
                                        : lesson.subject.isEmpty
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
        color: _meetingAmber.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _meetingAmber.withValues(alpha: 0.35)),
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
