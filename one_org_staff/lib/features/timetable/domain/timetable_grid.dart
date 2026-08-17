// Timetable grid building, ported from the web app's `timetableUtils.js` so
// both apps lay the week out identically. Pure Dart, so the bucketing and the
// clash detection are tested without pumping a widget.

import 'package:one_org_staff/features/timetable/time_table_repository.dart';

/// Which axis the grid is built around.
enum TimetableView {
  /// One teacher's week: rows are days, columns are time slots.
  byTeacher,

  /// One day at a time: rows are classes, columns are time slots.
  byClass,
}

/// The teaching week. Mon–Fri, matching the web's `DAYS`.
const List<int> kWeekdayIndexes = [1, 2, 3, 4, 5];

const Map<int, String> kWeekdayLabels = {
  1: 'Mon',
  2: 'Tues',
  3: 'Wed',
  4: 'Thu',
  5: 'Fri',
};

/// A column of the grid — one period in the day.
class TimetableSlot {
  const TimetableSlot({required this.id, this.label, this.start, this.end});

  final int id;

  /// The school's own name for the period, e.g. "2nd lesson".
  final String? label;
  final String? start;
  final String? end;

  /// Heading text: the slot name if there is one, else the time range.
  String get primaryLabel {
    final name = label?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }
    return timeRange ?? 'Slot $id';
  }

  /// Sub-heading: the time range, but only when it adds to [primaryLabel].
  String? get secondaryLabel {
    final range = timeRange;
    if (range == null || range == primaryLabel) {
      return null;
    }
    return range;
  }

  /// `08:30 - 09:15`, dropping the seconds the API sends.
  String? get timeRange {
    final from = _compact(start);
    final to = _compact(end);
    if (from == null && to == null) {
      return null;
    }
    if (from != null && to != null) {
      return '$from - $to';
    }
    return from ?? to;
  }

  static String? _compact(String? value) {
    final time = value?.trim();
    if (time == null || time.isEmpty) {
      return null;
    }
    final match = RegExp(r'^(\d{2}:\d{2})').firstMatch(time);
    return match?.group(1) ?? time;
  }
}

/// A teacher who appears in the timetable.
class TimetableTeacher {
  const TimetableTeacher({required this.key, required this.label});

  /// `id:12` when the API gives a teacher id, otherwise `name:<lowercased>` —
  /// the same fallback the web uses so a nameless id still groups correctly.
  final String key;
  final String label;
}

/// A class (group) that appears in the timetable.
class TimetableClass {
  const TimetableClass({required this.id, required this.label});

  final int id;
  final String label;
}

/// The laid-out week, ready to render.
class TimetableGrid {
  const TimetableGrid({
    required this.slots,
    required this.cells,
    required this.clashingLessons,
  });

  /// Columns, ordered by start time.
  final List<TimetableSlot> slots;

  /// Cell contents, keyed by [cellKey]. What "row" and "column" mean depends
  /// on the view: days × periods by teacher, periods × classes by class.
  final Map<String, List<TimetableLesson>> cells;

  /// Lessons that collide — the same teacher booked twice in one slot. Held as
  /// identity keys rather than objects so lookup is by value, not reference.
  final Set<String> clashingLessons;

  List<TimetableLesson> at(int rowKey, int columnKey) =>
      cells[cellKey(rowKey, columnKey)] ?? const [];

  bool clashes(TimetableLesson lesson) {
    final key = lessonKey(lesson);
    return key != null && clashingLessons.contains(key);
  }

  static String cellKey(int rowKey, int columnKey) => '${rowKey}_$columnKey';

  bool get isEmpty => slots.isEmpty;
}

/// Identity for a lesson, preferring the row id and falling back to its slot.
String? lessonKey(TimetableLesson lesson) {
  if (lesson.id != null) {
    return 'id:${lesson.id}';
  }
  if (lesson.dayIndex != null &&
      lesson.timeId != null &&
      lesson.groupId != null) {
    return 'slot:${lesson.dayIndex}_${lesson.timeId}_${lesson.groupId}';
  }
  return null;
}

/// Stable teacher identity — the id when present, else the normalised name.
String? teacherKey(TimetableLesson lesson) {
  if (lesson.teacherId != null) {
    return 'id:${lesson.teacherId}';
  }
  final name = lesson.teacherLabel?.trim().toLowerCase();
  if (name == null || name.isEmpty) {
    return null;
  }
  return 'name:$name';
}

/// The class label shown on a lesson card, e.g. `10-A`.
String classLabel(TimetableLesson lesson) {
  final label = lesson.groupLabel?.trim();
  if (label != null && label.isNotEmpty) {
    return label;
  }
  return lesson.groupId == null ? 'Class' : 'Group ${lesson.groupId}';
}

/// Builds the grid for [view] from [all] lessons.
///
/// The columns always come from the *whole* timetable, not just the filtered
/// rows: a teacher who never teaches during period 6 should still see period 6
/// as an empty column, otherwise their week silently changes shape.
TimetableGrid buildTimetableGrid({
  required List<TimetableLesson> all,
  required TimetableView view,
  String? teacher,
  int? dayIndex,
}) {
  final slots = _slotsFrom(all);

  final visible = all.where((lesson) {
    switch (view) {
      case TimetableView.byTeacher:
        return teacher != null && teacherKey(lesson) == teacher;
      case TimetableView.byClass:
        return dayIndex != null && lesson.dayIndex == dayIndex;
    }
  });

  final cells = <String, List<TimetableLesson>>{};
  for (final lesson in visible) {
    final slotId = lesson.timeId;
    if (slotId == null) {
      continue;
    }

    // By teacher the week runs days-down/periods-across; by class it is
    // periods-down/classes-across, which is how the web lays out each and how
    // a timetable is read on paper.
    final (rowKey, columnKey) = view == TimetableView.byTeacher
        ? (lesson.dayIndex, slotId)
        : (slotId, lesson.groupId);
    if (rowKey == null || columnKey == null) {
      continue;
    }

    cells
        .putIfAbsent(TimetableGrid.cellKey(rowKey, columnKey), () => [])
        .add(lesson);
  }

  // Several classes can land in one teacher cell when the timetable clashes;
  // ordering by class keeps the stack stable between rebuilds.
  for (final lessons in cells.values) {
    lessons.sort((a, b) => classLabel(a).compareTo(classLabel(b)));
  }

  return TimetableGrid(
    slots: slots,
    cells: cells,
    // Clashes are computed over the whole timetable, not the filtered view —
    // the other half of a double-booking usually belongs to another class.
    clashingLessons: findClashes(all),
  );
}

/// Time slots present anywhere in [lessons], ordered by start time.
List<TimetableSlot> _slotsFrom(List<TimetableLesson> lessons) {
  final byId = <int, TimetableSlot>{};

  for (final lesson in lessons) {
    final id = lesson.timeId;
    if (id == null || byId.containsKey(id)) {
      continue;
    }
    byId[id] = TimetableSlot(
      id: id,
      label: lesson.timeLabel,
      start: lesson.startTime,
      end: lesson.endTime,
    );
  }

  return byId.values.toList()
    ..sort((a, b) => (a.start ?? '').compareTo(b.start ?? ''));
}

/// Lessons that put one teacher in two places at once.
Set<String> findClashes(List<TimetableLesson> lessons) {
  final bySlot = <String, List<String>>{};

  for (final lesson in lessons) {
    final key = lessonKey(lesson);
    final teacher = teacherKey(lesson);
    if (key == null ||
        teacher == null ||
        lesson.dayIndex == null ||
        lesson.timeId == null) {
      continue;
    }

    bySlot
        .putIfAbsent('${lesson.dayIndex}_${lesson.timeId}_$teacher', () => [])
        .add(key);
  }

  return {
    for (final keys in bySlot.values)
      if (keys.length > 1) ...keys,
  };
}

/// Every teacher in the timetable, sorted by name.
List<TimetableTeacher> teachersIn(List<TimetableLesson> lessons) {
  final byKey = <String, String>{};

  for (final lesson in lessons) {
    final key = teacherKey(lesson);
    if (key == null || byKey.containsKey(key)) {
      continue;
    }
    final label = lesson.teacherLabel?.trim();
    byKey[key] = label != null && label.isNotEmpty
        ? label
        : 'Teacher ${lesson.teacherId ?? ''}'.trim();
  }

  final teachers = [
    for (final entry in byKey.entries)
      TimetableTeacher(key: entry.key, label: entry.value),
  ];

  return teachers
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
}

/// Every class in the timetable, ordered by grade then class letter.
List<TimetableClass> classesIn(List<TimetableLesson> lessons) {
  final byId = <int, String>{};

  for (final lesson in lessons) {
    final id = lesson.groupId;
    if (id == null || byId.containsKey(id)) {
      continue;
    }
    byId[id] = classLabel(lesson);
  }

  final classes = [
    for (final entry in byId.entries)
      TimetableClass(id: entry.key, label: entry.value),
  ];

  return classes..sort((a, b) => _compareClassLabels(a.label, b.label));
}

/// `9-B` before `10-A`: the grade is a number, so a plain string compare would
/// file 10 before 9.
int _compareClassLabels(String a, String b) {
  final gradeA = int.tryParse(a.split('-').first);
  final gradeB = int.tryParse(b.split('-').first);

  if (gradeA != null && gradeB != null && gradeA != gradeB) {
    return gradeA.compareTo(gradeB);
  }
  return a.compareTo(b);
}

/// Days that actually have lessons, in weekday order.
List<int> daysIn(List<TimetableLesson> lessons) {
  final present = {
    for (final lesson in lessons)
      if (lesson.dayIndex != null) lesson.dayIndex!,
  };
  return [
    for (final day in kWeekdayIndexes)
      if (present.contains(day)) day,
  ];
}
