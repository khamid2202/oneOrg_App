import 'package:flutter/foundation.dart';

import '../../lessons/domain/lessons_repository.dart';

/// One row of the Today card: a lesson or a staff meeting.
class TodayItem {
  const TodayItem({
    required this.start,
    required this.end,
    required this.classLabel,
    required this.subject,
    this.room,
  });

  /// "HH:mm"; these compare correctly as strings.
  final String start;
  final String end;
  final String classLabel;
  final String subject;
  final String? room;
}

class NextLessonDay {
  const NextLessonDay({required this.day, required this.items});

  final DateTime day;
  final List<TodayItem> items;
}

String clockText(DateTime time) =>
    '${time.hour.toString().padLeft(2, '0')}:'
    '${time.minute.toString().padLeft(2, '0')}';

String _hhmm(String? value) {
  final text = value ?? '';
  return text.length >= 5 ? text.substring(0, 5) : text;
}

List<TodayItem> _itemsOf(LessonDay day) {
  final items = [
    for (final lesson in day.lessons)
      if (!lesson.isCancelled)
        TodayItem(
          start: _hhmm(lesson.startTime),
          end: _hhmm(lesson.endTime),
          classLabel: lesson.classLabel,
          subject: lesson.subject,
          room: lesson.room,
        ),
    for (final meeting in day.meetings)
      TodayItem(
        start: _hhmm(meeting.startTime),
        end: _hhmm(meeting.endTime),
        classLabel: '',
        subject: meeting.title,
        room: meeting.room,
      ),
  ]..sort((a, b) => a.start.compareTo(b.start));
  return items;
}

/// Finds the first day from today, within a week, that has lessons. From 16:30
/// today counts only if something on it is still to come. Like the web's
/// `nextLessonDay.js`, a day's answer is searched for once and a failed lookup
/// is tried again.
class NextLessonDayLoader extends ChangeNotifier {
  NextLessonDayLoader({
    required Future<LessonDay> Function(DateTime date) getDay,
    DateTime Function()? clock,
  }) : _getDay = getDay,
       _clock = clock ?? DateTime.now;

  static const _dayOverAt = '16:30';

  final Future<LessonDay> Function(DateTime date) _getDay;
  final DateTime Function() _clock;

  NextLessonDay? _result;
  String? _loadedKey;
  bool _loading = false;
  bool _disposed = false;

  /// Null until the first lookup has finished.
  NextLessonDay? get result => _result;

  DateTime get now => _clock();

  String _keyAt(DateTime now) =>
      '${now.year}-${now.month}-${now.day}:'
      '${clockText(now).compareTo(_dayOverAt) >= 0}';

  Future<void> refreshIfStale() async {
    final now = _clock();
    final key = _keyAt(now);
    if (_loading || key == _loadedKey) return;
    _loading = true;
    try {
      _result = await _find(now);
      _loadedKey = key;
    } catch (_) {
      _result ??= NextLessonDay(
        day: DateTime(now.year, now.month, now.day),
        items: const [],
      );
    } finally {
      _loading = false;
    }
    if (!_disposed) notifyListeners();
  }

  Future<NextLessonDay> _find(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final clock = clockText(now);
    final late = clock.compareTo(_dayOverAt) >= 0;
    NextLessonDay? first;
    for (var offset = 0; offset < 7; offset++) {
      final day = DateTime(today.year, today.month, today.day + offset);
      final List<TodayItem> items;
      try {
        items = _itemsOf(await _getDay(day));
      } catch (_) {
        // Offline, later days aren't kept on the phone; today still is.
        if (first != null) return first;
        rethrow;
      }
      final found = NextLessonDay(day: day, items: items);
      first ??= found;
      final over =
          offset == 0 &&
          late &&
          items.every((item) => item.end.compareTo(clock) <= 0);
      if ((items.isNotEmpty && !over) || offset == 6) return found;
    }
    return first!;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
