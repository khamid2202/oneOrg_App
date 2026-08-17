import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/timetable/domain/timetable_grid.dart';
import 'package:one_org_staff/features/timetable/presentation/timetable_grid_view.dart';

/// The whole-school timetable, ported from the web's `features/timetable`.
///
/// Opens on **My week**, which is the view a teacher wants: their own week,
/// days down the side and periods across the top. There is no teacher picker —
/// the week shown is always the signed-in user's. By class swaps the axes to
/// show one day across every class, the way the timetable maker reads it.
class TimetablePage extends StatefulWidget {
  const TimetablePage({
    super.key,
    required this.loadTimetable,
    required this.loadProfile,
    required this.loadAcademicYears,
  });

  final Future<List<TimetableLesson>> Function({int? academicYearId})
  loadTimetable;

  /// The timetable is stored per academic year, so the year has to be resolved
  /// before it can be asked for — see [_load].
  final Future<List<AcademicYearEntry>> Function() loadAcademicYears;

  /// Identifies the signed-in teacher, whose week is the only one shown.
  final Future<AppUserProfile> Function() loadProfile;

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  late Future<_TimetableData> _future;

  TimetableView _view = TimetableView.byTeacher;
  int? _day;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TimetableData> _load() async {
    // The year comes first: `GET /timetable` without `academic_year_id`
    // returns nothing, so asking for the timetable before resolving the year
    // reads as "no timetable has been published" when there plainly is one.
    final activeYear = await _activeYearOrNull();

    final results = await Future.wait([
      widget.loadTimetable(academicYearId: activeYear?.id),
      _profileOrNull(),
    ]);

    final lessons = results[0] as List<TimetableLesson>;
    final profile = results[1] as AppUserProfile?;

    return _TimetableData(
      year: activeYear,
      lessons: lessons,
      classes: classesIn(lessons),
      days: daysIn(lessons),
      signedInTeacher: _teacherFor(profile, lessons),
      identityKnown: profile != null,
    );
  }

  /// The active academic year, or null if it cannot be worked out.
  ///
  /// A year outage does not black out the page — the request still goes out —
  /// but the empty state says so rather than claiming nothing was published.
  Future<AcademicYearEntry?> _activeYearOrNull() async {
    try {
      final years = await widget.loadAcademicYears();
      if (years.isEmpty) {
        return null;
      }
      return years.firstWhere(
        (year) => year.isActive,
        orElse: () => years.first,
      );
    } catch (_) {
      return null;
    }
  }

  /// A profile outage does not fail the page — the by-class view still works;
  /// only the personal week has nobody to show.
  Future<AppUserProfile?> _profileOrNull() async {
    try {
      return await widget.loadProfile();
    } catch (_) {
      return null;
    }
  }

  /// Matches the signed-in user to a teacher in the timetable — by id first,
  /// falling back to name, the same identity rule the grid groups by.
  String? _teacherFor(AppUserProfile? profile, List<TimetableLesson> lessons) {
    if (profile == null) {
      return null;
    }

    for (final lesson in lessons) {
      if (lesson.teacherId == profile.id) {
        return teacherKey(lesson);
      }
    }

    final name = profile.fullName.trim().toLowerCase();
    if (name.isEmpty) {
      return null;
    }
    for (final lesson in lessons) {
      if (lesson.teacherLabel?.trim().toLowerCase() == name) {
        return teacherKey(lesson);
      }
    }
    return null;
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  /// Opens on today, because that is the day being taught right now.
  ///
  /// Falls back to the first day with lessons at the weekend, or when today
  /// happens to be a day the school does not teach — an empty grid would
  /// otherwise be the first thing a teacher sees on a Saturday.
  int? _defaultDay(List<int> days) {
    if (days.isEmpty) {
      return null;
    }
    final today = DateTime.now().weekday;
    return days.contains(today) ? today : days.first;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    // Tighter side padding than the other pages: every point taken here is a
    // point the grid cannot use, and the grid is already scrolling sideways.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 20),
      child: FutureBuilder<_TimetableData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return _TimetableError(
              message: snapshot.error is AuthFailure
                  ? (snapshot.error as AuthFailure).message
                  : 'Unable to load the timetable right now.',
              onRetry: _reload,
            );
          }

          final data = snapshot.data ?? _TimetableData.empty();

          _day ??= _defaultDay(data.days);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title and subtitle on one line each, side by side, instead of
              // a stacked block that pushed the grid down the screen.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      'Timetable',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _view == TimetableView.byTeacher
                            ? 'your week'
                            : 'one day, every class',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              SegmentedButton<TimetableView>(
                segments: const [
                  ButtonSegment(
                    value: TimetableView.byTeacher,
                    label: Text('My week'),
                    icon: Icon(Icons.person_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: TimetableView.byClass,
                    label: Text('By class'),
                    icon: Icon(Icons.school_rounded, size: 18),
                  ),
                ],
                selected: {_view},
                showSelectedIcon: false,
                style: const ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onSelectionChanged: (selection) =>
                    setState(() => _view = selection.first),
              ),
              const SizedBox(height: 10),

              // Only the day needs choosing: the teacher is always the signed-in
              // user, so there is nothing to pick in the personal week.
              if (_view == TimetableView.byClass) ...[
                _DayStepper(
                  days: data.days,
                  selected: _day,
                  onSelected: (value) => setState(() => _day = value),
                ),
                const SizedBox(height: 10),
              ],

              // No Expanded: the landing shell already scrolls this page
              // vertically, so the grid sizes to its rows instead of trying to
              // fill an unbounded height.
              _buildGrid(data),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGrid(_TimetableData data) {
    if (data.lessons.isEmpty) {
      // Naming the cause matters: an unresolved academic year and a genuinely
      // empty timetable look identical on screen but need different fixes.
      return _TimetableNotice(
        icon: data.year == null
            ? Icons.event_busy_rounded
            : Icons.calendar_month_rounded,
        text: data.year == null
            ? 'Could not work out the academic year, so the timetable could '
                  'not be loaded.'
            : 'No timetable published for ${data.year!.name}.',
      );
    }

    if (_view == TimetableView.byTeacher && data.signedInTeacher == null) {
      // Two different problems: the timetable has no lessons under your name,
      // or we never learned your name to look it up with.
      return _TimetableNotice(
        icon: data.identityKnown
            ? Icons.event_available_rounded
            : Icons.person_off_rounded,
        text: data.identityKnown
            ? 'You have no lessons in this timetable.'
            : 'Could not work out who is signed in, so your week could not '
                  'be shown.',
      );
    }

    final grid = buildTimetableGrid(
      all: data.lessons,
      view: _view,
      teacher: data.signedInTeacher,
      dayIndex: _day,
    );

    if (grid.isEmpty) {
      return const _TimetableNotice(
        icon: Icons.schedule_rounded,
        text: 'There are no time slots to show.',
      );
    }

    // The two views transpose each other, so each supplies its own axes.
    final (rows, columns, rowHeaderLabel) = switch (_view) {
      TimetableView.byTeacher => (
        [
          for (final day in kWeekdayIndexes)
            TimetableHeader(key: day, primary: kWeekdayLabels[day]!),
        ],
        [
          for (final slot in grid.slots)
            TimetableHeader(
              key: slot.id,
              primary: slot.primaryLabel,
              secondary: slot.secondaryLabel,
            ),
        ],
        'Weekday',
      ),
      TimetableView.byClass => (
        [
          for (final slot in grid.slots)
            TimetableHeader(
              key: slot.id,
              primary: slot.primaryLabel,
              secondary: slot.secondaryLabel,
            ),
        ],
        [
          for (final group in data.classes)
            TimetableHeader(key: group.id, primary: group.label),
        ],
        'Period',
      ),
    };

    // No caption above the grid: it repeated what the page subtitle and the
    // day stepper already say, and cost a line of height.
    return TimetableGridView(
      grid: grid,
      rows: rows,
      columns: columns,
      rowHeaderLabel: rowHeaderLabel,
    );
  }
}

/// Everything the page needs, resolved together so it never half-renders.
class _TimetableData {
  const _TimetableData({
    required this.year,
    required this.lessons,
    required this.classes,
    required this.days,
    required this.signedInTeacher,
    required this.identityKnown,
  });

  const _TimetableData.empty()
    : year = null,
      lessons = const [],
      classes = const [],
      days = const [],
      signedInTeacher = null,
      identityKnown = false;

  /// The year the lessons were requested for; null when it could not be
  /// resolved, which is why the grid may be empty.
  final AcademicYearEntry? year;

  final List<TimetableLesson> lessons;
  final List<TimetableClass> classes;
  final List<int> days;

  /// The signed-in user's teacher key, when they appear in the timetable.
  final String? signedInTeacher;

  /// Whether the profile loaded at all, which separates "you teach nothing"
  /// from "we do not know who you are".
  final bool identityKnown;
}

/// Steps through the days with arrows, rather than making the reader open a
/// dropdown to move one day. Stops at each end: a timetable has a first and a
/// last day, and wrapping from Friday to Monday would read as a glitch.
class _DayStepper extends StatelessWidget {
  const _DayStepper({
    required this.days,
    required this.selected,
    required this.onSelected,
  });

  final List<int> days;
  final int? selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    final index = selected == null ? -1 : days.indexOf(selected!);
    final hasPrevious = index > 0;
    final hasNext = index >= 0 && index < days.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: hasPrevious ? () => onSelected(days[index - 1]) : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous day',
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  selected == null ? '—' : (kWeekdayLabels[selected!] ?? '—'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (selected != null && selected == DateTime.now().weekday)
                  Text(
                    'Today',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colors.softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: hasNext ? () => onSelected(days[index + 1]) : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next day',
          ),
        ],
      ),
    );
  }
}

class _TimetableNotice extends StatelessWidget {
  const _TimetableNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.softBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: colors.softText),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.softText),
          ),
        ],
      ),
    );
  }
}

class _TimetableError extends StatelessWidget {
  const _TimetableError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.mutedText),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
