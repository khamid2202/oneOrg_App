class TimetableDaySchedule {
  const TimetableDaySchedule({required this.date, required this.lessons});

  final DateTime date;
  final List<TimetableLesson> lessons;
}

class TimetableLesson {
  const TimetableLesson({
    required this.title,
    required this.timeLabel,
    this.id,
    this.subtitle,
    this.groupLabel,
    this.teacherLabel,
    this.groupId,
    this.subjectId,
    this.room,
    this.dayLabel,
    this.dayIndex,
    this.timeId,
    this.startTime,
    this.endTime,
    this.isTextLesson = false,
  });

  final int? id;
  final String title;
  final String timeLabel;
  final String? subtitle;
  final String? groupLabel;
  final String? teacherLabel;
  final int? groupId;
  final int? subjectId;
  final String? room;
  final String? dayLabel;
  final int? dayIndex;
  final int? timeId;
  final String? startTime;
  final String? endTime;
  final bool isTextLesson;

  factory TimetableLesson.fromJson(Map<String, dynamic> json) {
    final parsedDayLabel = _firstString(json, const [
      'day',
      'day_name',
      'dayName',
    ]);
    final dayIndex =
        _asInt(json['day_index'] ?? json['dayIndex']) ??
        _dayIndexFromLabel(parsedDayLabel);
    final groupId = _asInt(json['group_id'] ?? json['groupId']);
    final subjectId = _asInt(json['subject_id'] ?? json['subjectId']);
    final rawTitle = _firstString(json, const [
      'text',
      'subject',
      'title',
      'lesson',
    ]);
    final title = _normalizeLessonTitle(rawTitle) ?? 'Lesson';
    final groupLabel =
        _firstString(json, const [
          'class_pair',
          'classPair',
          'class_pair_compact',
          'classPairCompact',
          'group',
          'group_name',
          'groupName',
        ]) ??
        (groupId != null ? 'Group #$groupId' : null);
    final teacherLabel = _firstString(json, const [
      'teacher',
      'teacher_name',
      'teacherName',
    ]);
    final dayLabel = parsedDayLabel ?? weekdayLabelFromIndex(dayIndex);
    final room = _firstString(json, const ['room']);
    final timeId = _asInt(json['time_id'] ?? json['timeId']);
    final startTime = _firstString(json, const ['start_time', 'startTime']);
    final endTime = _firstString(json, const ['end_time', 'endTime']);
    final timeLabel =
        _firstString(json, const ['time_slot', 'timeSlot', 'time']) ??
        _formatTimeRange(startTime, endTime) ??
        (timeId != null ? 'Slot $timeId' : null) ??
        'Time not specified';
    final lessonType =
        (_firstString(json, const ['lesson_type', 'lessonType']) ?? '')
            .toLowerCase();
    final subtitleParts = <String>[?groupLabel, ?teacherLabel];

    return TimetableLesson(
      id: _asInt(json['id']),
      title: title,
      timeLabel: timeLabel,
      subtitle: subtitleParts.isEmpty ? dayLabel : subtitleParts.join(' • '),
      groupLabel: groupLabel,
      teacherLabel: teacherLabel,
      groupId: groupId,
      subjectId: subjectId,
      room: room,
      dayLabel: dayLabel,
      dayIndex: dayIndex,
      timeId: timeId,
      startTime: startTime,
      endTime: endTime,
      isTextLesson: lessonType == 'text',
    );
  }

  static String? _normalizeLessonTitle(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.toLowerCase().startsWith('text:')) {
      return trimmed.substring(5).trim();
    }

    return trimmed.isEmpty ? null : trimmed;
  }

  static int? _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  static int? _dayIndexFromLabel(String? value) {
    if (value == null) {
      return null;
    }

    switch (value.trim().toLowerCase()) {
      case 'monday':
        return 1;
      case 'tuesday':
        return 2;
      case 'wednesday':
        return 3;
      case 'thursday':
        return 4;
      case 'friday':
        return 5;
      case 'saturday':
        return 6;
      case 'sunday':
        return 7;
      default:
        return null;
    }
  }

  static String? weekdayLabelFromIndex(int? dayIndex) {
    switch (dayIndex) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return null;
    }
  }

  static String? _firstString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final parsed = _stringValue(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static String? _stringValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    if (value is num) {
      return value.toString();
    }

    return null;
  }

  static String? _formatTimeRange(String? startTime, String? endTime) {
    final shortStart = _shortTime(startTime);
    final shortEnd = _shortTime(endTime);
    if (shortStart == null && shortEnd == null) {
      return null;
    }
    if (shortStart != null && shortEnd != null) {
      return '$shortStart-$shortEnd';
    }
    return shortStart ?? shortEnd;
  }

  static String? _shortTime(String? value) {
    if (value == null) {
      return null;
    }

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final parts = trimmed.split(':');
    if (parts.length < 2) {
      return trimmed;
    }

    return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
  }
}

abstract class TimetableRepository {
  Future<TimetableDaySchedule> getMyLessons(
    String token, {
    required DateTime date,
  });

  Future<List<TimetableLesson>> getTimetable(String token);
}
