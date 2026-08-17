import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';

class MyLessonsPage extends StatefulWidget {
  const MyLessonsPage({
    super.key,
    required this.loadLessons,
    required this.loadStudentsForGroup,
    required this.savePointsBulk,
    required this.loadPointsForGroupAndDate,
  });

  final Future<TimetableDaySchedule> Function(DateTime date) loadLessons;
  final Future<List<StudentEntry>> Function(int groupId) loadStudentsForGroup;
  final Future<void> Function(List<StudentPointDraft> points) savePointsBulk;
  final Future<Map<int, double>> Function({
    required int groupId,
    required DateTime date,
    int? subjectId,
  })
  loadPointsForGroupAndDate;

  @override
  State<MyLessonsPage> createState() => _MyLessonsPageState();
}

class _MyLessonsPageState extends State<MyLessonsPage> {
  late DateTime _selectedDate;
  late Future<TimetableDaySchedule> _scheduleFuture;

  @override
  void initState() {
    super.initState();
    _selectedDate = _normalizeDate(DateTime.now());
    _scheduleFuture = widget.loadLessons(_selectedDate);
  }

  @override
  void didUpdateWidget(covariant MyLessonsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadLessons != widget.loadLessons) {
      _scheduleFuture = widget.loadLessons(_selectedDate);
    }
  }

  void _reload([DateTime? nextDate]) {
    final selectedDate = nextDate == null
        ? _selectedDate
        : _normalizeDate(nextDate);
    setState(() {
      _selectedDate = selectedDate;
      _scheduleFuture = widget.loadLessons(selectedDate);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My lessons',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your lessons for the selected day.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: _mutedTextColor(context),
            ),
          ),
          const SizedBox(height: 18),
          _DateToolbar(
            selectedDate: _selectedDate,
            isDarkMode: isDarkMode,
            onPreviousDay: () =>
                _reload(_selectedDate.subtract(const Duration(days: 1))),
            onNextDay: () =>
                _reload(_selectedDate.add(const Duration(days: 1))),
          ),
          const SizedBox(height: 20),
          FutureBuilder<TimetableDaySchedule>(
            future: _scheduleFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 280,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return _MyLessonsErrorState(
                  message: 'Soon the content will appear',
                  onRetry: () => _reload(),
                );
              }

              final schedule = snapshot.data;
              if (schedule == null || schedule.lessons.isEmpty) {
                return _EmptyLessonsState(date: _selectedDate);
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${schedule.lessons.length} lesson${schedule.lessons.length == 1 ? '' : 's'} planned for this day',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final lesson in schedule.lessons) ...[
                    _LessonCard(
                      lesson: lesson,
                      onTap: () => _openPoints(context, lesson),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  void _openPoints(BuildContext context, TimetableLesson lesson) {
    final groupId = lesson.groupId;
    if (groupId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No class found for this lesson.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonPointsPage(
          groupId: groupId,
          groupLabel: lesson.groupLabel ?? 'Class',
          lessonTitle: lesson.title,
          date: _selectedDate,
          subjectId: lesson.subjectId,
          loadStudents: widget.loadStudentsForGroup,
          savePoints: widget.savePointsBulk,
          loadPoints: widget.loadPointsForGroupAndDate,
        ),
      ),
    );
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  Color _mutedTextColor(BuildContext context) {
    return appColorsOf(context).mutedText;
  }
}

class _DateToolbar extends StatelessWidget {
  const _DateToolbar({
    required this.selectedDate,
    required this.isDarkMode,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final DateTime selectedDate;
  final bool isDarkMode;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: appColorsOf(context).line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ToolbarIconButton(
                icon: Icons.chevron_left_rounded,
                onPressed: onPreviousDay,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFullDate(selectedDate),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _relativeLabel(selectedDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: appColorsOf(context).mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _ToolbarIconButton(
                icon: Icons.chevron_right_rounded,
                onPressed: onNextDay,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _relativeLabel(DateTime selectedDate) {
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedSelected = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final weekday = _weekdayName(selectedDate.weekday);
    if (normalizedSelected == normalizedToday) {
      return '$weekday (Today)';
    }
    return weekday;
  }

  static String _formatFullDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')} ${_monthName(date.month)} ${date.year}';
  }

  static String _weekdayName(int weekday) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[weekday - 1];
  }

  static String _monthName(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _ToolbarIconButton extends StatelessWidget {
  const _ToolbarIconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Ink(
      decoration: BoxDecoration(
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(onPressed: onPressed, icon: Icon(icon)),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.lesson, this.onTap});

  final TimetableLesson lesson;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final mutedColor = appColorsOf(context).mutedText;
    final classLabel = lesson.groupLabel ?? 'Class';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: appColorsOf(context).card,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: appColorsOf(context).line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: appColorsOf(context).softBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    classLabel,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: appColorsOf(context).softText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.schedule_rounded, size: 16),
                              const SizedBox(width: 4),
                              Text(
                                lesson.timeLabel,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: mutedColor,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (lesson.teacherLabel != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      lesson.teacherLabel!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: mutedColor),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (lesson.room != null)
                        _MetaBadge(
                          icon: Icons.meeting_room_outlined,
                          label: lesson.room!,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  const _MetaBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: appColorsOf(context).line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _EmptyLessonsState extends StatelessWidget {
  const _EmptyLessonsState({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.event_busy_rounded, size: 40),
          const SizedBox(height: 14),
          Text(
            'No lessons planned',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no lessons for ${_DateToolbar._formatFullDate(date)}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

class _MyLessonsErrorState extends StatelessWidget {
  const _MyLessonsErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
