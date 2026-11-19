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

/// An item on the day's time scale, with its column when items overlap.
class PlacedItem {
  PlacedItem(this.item);

  final DayItem item;
  int column = 0;
  int columns = 1;
}

/// The day as the web's `DaySchedule` draws it: every bell period on one time
/// scale, whether or not you teach it, with your lessons and meetings laid
/// over them. Items that overlap in time (choice lessons, a substitution on
/// top of your own class) share the width side by side.
class DayLayout {
  const DayLayout({
    required this.periods,
    required this.items,
    required this.start,
    required this.end,
  });

  final List<BellPeriod> periods;
  final List<PlacedItem> items;

  /// The first bell to the last, stretched to fit anything outside them.
  final int start;
  final int end;

  /// Whether one of the items falls in [period].
  bool taught(BellPeriod period) => items.any(
    (placed) =>
        placed.item.start < period.end && placed.item.end > period.start,
  );
}

DayLayout layoutDay(List<BellPeriod> periods, LessonDay day) {
  final schedule = periods.isEmpty ? fallbackPeriods : periods;
  final placed =
      <PlacedItem>[
        for (final lesson in day.lessons)
          if (minutesOfDay(lesson.startTime) != null &&
              minutesOfDay(lesson.endTime) != null)
            PlacedItem(
              DayItem(
                start: minutesOfDay(lesson.startTime)!,
                end: minutesOfDay(lesson.endTime)!,
                lesson: lesson,
              ),
            ),
        for (final meeting in day.meetings)
          if (minutesOfDay(meeting.startTime) != null &&
              minutesOfDay(meeting.endTime) != null)
            PlacedItem(
              DayItem(
                start: minutesOfDay(meeting.startTime)!,
                end: minutesOfDay(meeting.endTime)!,
                meeting: meeting,
              ),
            ),
      ]..sort((a, b) {
        final byStart = a.item.start.compareTo(b.item.start);
        return byStart != 0 ? byStart : a.item.end.compareTo(b.item.end);
      });

  // Clusters of items that overlap; each gets the first free column.
  var cluster = <PlacedItem>[];
  var clusterEnd = -1;
  void finish() {
    final columnEnds = <int>[];
    for (final placedItem in cluster) {
      var column = columnEnds.indexWhere((end) => end <= placedItem.item.start);
      if (column == -1) {
        column = columnEnds.length;
        columnEnds.add(placedItem.item.end);
      } else {
        columnEnds[column] = placedItem.item.end;
      }
      placedItem.column = column;
    }
    for (final placedItem in cluster) {
      placedItem.columns = columnEnds.length;
    }
  }

  for (final placedItem in placed) {
    if (placedItem.item.start >= clusterEnd && cluster.isNotEmpty) {
      finish();
      cluster = [];
    }
    cluster.add(placedItem);
    if (placedItem.item.end > clusterEnd) clusterEnd = placedItem.item.end;
  }
  if (cluster.isNotEmpty) finish();

  var start = schedule.first.start;
  var end = schedule.last.end;
  for (final placedItem in placed) {
    if (placedItem.item.start < start) start = placedItem.item.start;
    if (placedItem.item.end > end) end = placedItem.item.end;
  }
  return DayLayout(periods: schedule, items: placed, start: start, end: end);
}
