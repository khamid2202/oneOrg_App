import 'lessons_repository.dart';

/// Used when the bell schedule can't be read: the school's standard day of ten
/// 45-minute periods from 08:00 with 5-minute breaks.
final List<BellPeriod> fallbackPeriods = List.generate(10, (index) {
  final start = 8 * 60 + index * 50;
  return BellPeriod(number: index + 1, start: start, end: start + 45);
});

class DayItem {
  const DayItem({
    required this.start,
    required this.end,
    this.lesson,
    this.meeting,
  });

  final int start;
  final int end;
  final TeacherLesson? lesson;
  final TeacherMeeting? meeting;
}

/// One line of the day: a period and what happens in it. Items that overlap
/// (choice lessons, a substitution on top of your own class) share the line.
class DayRow {
  DayRow({required this.start, required this.end, this.period});

  final BellPeriod? period;
  final int start;
  int end;
  final List<DayItem> items = [];

  bool get isEmpty => items.isEmpty;
}

/// Lays the day over its periods. A period with nothing in it stays as a thin
/// line, so the shape of the school day is still visible.
List<DayRow> buildDayRows(List<BellPeriod> periods, LessonDay day) {
  final schedule = periods.isEmpty ? fallbackPeriods : periods;
  final items = <DayItem>[
    for (final lesson in day.lessons)
      if (minutesOfDay(lesson.startTime) != null &&
          minutesOfDay(lesson.endTime) != null)
        DayItem(
          start: minutesOfDay(lesson.startTime)!,
          end: minutesOfDay(lesson.endTime)!,
          lesson: lesson,
        ),
    for (final meeting in day.meetings)
      if (minutesOfDay(meeting.startTime) != null &&
          minutesOfDay(meeting.endTime) != null)
        DayItem(
          start: minutesOfDay(meeting.startTime)!,
          end: minutesOfDay(meeting.endTime)!,
          meeting: meeting,
        ),
  ]..sort((a, b) => a.start.compareTo(b.start));

  final rows = [
    for (final period in schedule)
      DayRow(period: period, start: period.start, end: period.end),
  ];
  final offSchedule = <DayRow>[];

  for (final item in items) {
    final row = rows
        .where((row) => item.start < row.end && item.end > row.start)
        .firstOrNull;
    if (row != null) {
      row.items.add(item);
      if (item.end > row.end) row.end = item.end;
      continue;
    }
    final existing = offSchedule
        .where((row) => item.start < row.end && item.end > row.start)
        .firstOrNull;
    if (existing != null) {
      existing.items.add(item);
      if (item.end > existing.end) existing.end = item.end;
    } else {
      offSchedule.add(
        DayRow(start: item.start, end: item.end)..items.add(item),
      );
    }
  }

  // An empty period that a longer lesson already runs through has no line.
  final shown = <DayRow>[];
  for (final row in rows) {
    final covered =
        row.isEmpty &&
        shown.any((other) => !other.isEmpty && other.end >= row.end);
    if (!covered) shown.add(row);
  }
  return [...shown, ...offSchedule]..sort((a, b) => a.start.compareTo(b.start));
}
