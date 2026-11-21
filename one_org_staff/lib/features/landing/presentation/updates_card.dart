import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/api_client.dart';
import '../domain/app_items.dart';

/// One slide of the Updates card.
class UpdateItem {
  const UpdateItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.when,
    required this.sort,
    this.detail,
    this.opens,
  });

  final String id;

  /// points, points-minus, funding, funding-out, announcement, substitution,
  /// event, holiday, exams, news.
  final String kind;
  final String title;
  final String? detail;
  final String when;
  final AppItem? opens;
  final int sort;
}

/// "New in the app" slides. Add one when a feature ships; each shows for
/// [_showDays] after its date. Keep in step with the web's whatsNew.js.
class WhatsNewEntry {
  const WhatsNewEntry({
    required this.id,
    required this.date,
    required this.title,
    required this.body,
    this.opens,
  });

  final String id;

  /// "YYYY-MM-DD".
  final String date;
  final String Function(AppLocalizations l) title;
  final String Function(AppLocalizations l) body;
  final AppItem? opens;
}

final whatsNew = <WhatsNewEntry>[
  WhatsNewEntry(
    id: 'attendance-statistics',
    date: '2026-11-21',
    title: (l) => l.whatsNewAttendanceTitle,
    body: (l) => l.whatsNewAttendanceBody,
    opens: AppItem.attendanceCheck,
  ),
  WhatsNewEntry(
    id: 'passkeys',
    date: '2026-11-18',
    title: (l) => l.whatsNewPasskeysTitle,
    body: (l) => l.whatsNewPasskeysBody,
  ),
  WhatsNewEntry(
    id: 'calendar-analysis-department',
    date: '2026-11-18',
    title: (l) => l.whatsNewCalendarTitle,
    body: (l) => l.whatsNewCalendarBody,
    opens: AppItem.calendar,
  ),
  WhatsNewEntry(
    id: 'photo-zoom',
    date: '2026-11-17',
    title: (l) => l.whatsNewPhotoZoomTitle,
    body: (l) => l.whatsNewPhotoZoomBody,
  ),
  WhatsNewEntry(
    id: 'grading-v2',
    date: '2026-11-16',
    title: (l) => l.whatsNewGradingTitle,
    body: (l) => l.whatsNewGradingBody,
    opens: AppItem.lessons,
  ),
];

const _showDays = 14;
const _eventDays = 7;
const _maxItems = 12;

/// Colour per kind, like the web: the slide's tint and its title.
(Color, Color) _kindTone(String kind, bool dark) {
  final base = switch (kind) {
    'points' => const Color(0xFFD97706),
    'points-minus' || 'funding-out' || 'exams' => const Color(0xFFE11D48),
    'funding' => const Color(0xFF059669),
    'substitution' => const Color(0xFFEA580C),
    'event' => const Color(0xFF0D9488),
    'holiday' => const Color(0xFF0284C7),
    _ => const Color(0xFF4F46E5),
  };
  return (base.withValues(alpha: dark ? 0.18 : 0.08), base);
}

/// "just now", "3h ago", "yesterday", "4d ago".
String agoText(AppLocalizations l, DateTime at, DateTime now) {
  final mins = now.difference(at).inMinutes;
  if (mins < 1) return l.updJustNow;
  if (mins < 60) return l.updMinutesAgo(mins);
  final hours = (mins / 60).round();
  if (hours < 24) return l.updHoursAgo(hours);
  final days = (hours / 24).round();
  return days == 1 ? l.updYesterday : l.updDaysAgo(days);
}

/// Builds the slides from my points, fundings, notifications and the next
/// week of the calendar — the web's `useUpdatesFeed`. Each source can fail on
/// its own.
Future<List<UpdateItem>> loadUpdates(
  ApiClient api,
  int userId,
  AppLocalizations l,
  String locale, {
  DateTime? clock,
  List<WhatsNewEntry>? news,
}) async {
  final now = clock ?? DateTime.now();
  final today = isoDay(now);
  final since = now.subtract(const Duration(days: _showDays));
  final recentQuery = {
    'user_id': userId,
    'date_from': isoDay(since),
    'sort_by': 'created_at',
    'order': 'desc',
    'limit': 10,
  };
  Future<List<Map<String, dynamic>>> safe(Future<dynamic> f) async {
    try {
      return ApiClient.rows(await f);
    } catch (_) {
      return const [];
    }
  }

  final results = await Future.wait([
    safe(api.get('/user-points', recentQuery)),
    safe(api.get('/fundings', recentQuery)),
    safe(api.get('/notifications', {'page': 1, 'limit': 10, 'is_read': false})),
    safe(
      api.get('/calendar', {
        'from': today,
        'to': isoDay(now.add(const Duration(days: _eventDays))),
        'sources': 'event,holiday,exam_period',
      }),
    ),
  ]);
  DateTime? at(Object? v) => DateTime.tryParse('${v ?? ''}')?.toLocal();
  final items = <UpdateItem>[];
  String number(num n) =>
      NumberFormat('#,##0', 'en').format(n).replaceAll(',', ' ');

  for (final p in results[0]) {
    final t = at(p['created_at']) ?? at(p['date']);
    if (t == null || t.isBefore(since)) continue;
    final n = asDouble(p['points']) ?? 0;
    final category = p['category'] is Map ? asStr(p['category']['name']) : null;
    items.add(
      UpdateItem(
        id: 'point-${p['id']}',
        kind: n >= 0 ? 'points' : 'points-minus',
        title: l.updPoints('${n >= 0 ? '+' : '−'}${number(n.abs())}'),
        detail: category ?? asStr(p['note']) ?? l.staffPoints,
        when: agoText(l, t, now),
        opens: AppItem.myPoints,
        sort: t.millisecondsSinceEpoch,
      ),
    );
  }
  for (final f in results[1]) {
    final t = at(f['created_at']) ?? at(f['date']);
    if (t == null || t.isBefore(since)) continue;
    final out = f['type'] == 'withdrawal';
    final category = f['category'] is Map ? asStr(f['category']['name']) : null;
    items.add(
      UpdateItem(
        id: 'funding-${f['id']}',
        kind: out ? 'funding-out' : 'funding',
        title:
            '${out ? '−' : '+'}${number(asDouble(f['amount']) ?? 0)} ${asStr(f['currency']) ?? 'UZS'}',
        detail: out
            ? l.updTakenFrom(category ?? l.myFundings)
            : l.updAddedTo(category ?? l.myFundings),
        when: agoText(l, t, now),
        opens: AppItem.myFundings,
        sort: t.millisecondsSinceEpoch,
      ),
    );
  }
  // Events show as their own slides, so their notifications would repeat them.
  final eventIds = {
    for (final e in results[3])
      if ((asStr(e['source']) ?? 'event') == 'event') '${e['id']}',
  };
  for (final n in results[2]) {
    if (n['is_read'] != false) continue;
    final t = at(n['created_at']);
    if (t == null || t.isBefore(since)) continue;
    final data = n['data'];
    final eventId = data is Map && data['event_id'] != null
        ? '${data['event_id']}'
        : null;
    if (eventId != null && eventIds.contains(eventId)) continue;
    items.add(
      UpdateItem(
        id: 'notification-${n['id']}',
        kind: n['type'] == 'substitution'
            ? 'substitution'
            : n['type'] == 'calendar_event'
            ? 'event'
            : 'announcement',
        title: asStr(n['title']) ?? '',
        detail: asStr(n['body']),
        when: agoText(l, t, now),
        opens: eventId != null ? AppItem.calendar : null,
        sort: t.millisecondsSinceEpoch,
      ),
    );
  }
  final midnight = DateTime(now.year, now.month, now.day);
  for (final e in results[3]) {
    final status = asStr(e['status']);
    if (status != null && status != 'published') continue;
    final start = DateTime.tryParse('${e['start_date']}');
    final end = asStr(e['end_date']) ?? asStr(e['start_date']) ?? '';
    if (start == null || end.compareTo(today) < 0) continue;
    final daysAway = start.difference(midnight).inDays.clamp(0, 99);
    final source = asStr(e['source']) ?? 'event';
    final time = e['all_day'] != true && asStr(e['start_time']) != null
        ? ' ${asStr(e['start_time'])!.padRight(5).substring(0, 5)}'
        : '';
    items.add(
      UpdateItem(
        id: 'event-${e['key'] ?? e['id']}',
        kind: source == 'holiday'
            ? 'holiday'
            : source == 'exam_period'
            ? 'exams'
            : 'event',
        title: asStr(e['title']) ?? '',
        detail: source == 'holiday'
            ? l.calHoliday
            : source == 'exam_period'
            ? l.calExamPeriod
            : asStr(e['location']) ?? l.updUpcomingEvent,
        when:
            (daysAway == 0
                ? l.calToday
                : daysAway == 1
                ? l.updTomorrow
                : DateFormat.MMMEd(locale).format(start)) +
            time,
        opens: AppItem.calendar,
        sort: now.millisecondsSinceEpoch - daysAway * 3600000,
      ),
    );
  }
  for (final n in news ?? whatsNew) {
    final day = DateTime.tryParse(n.date);
    if (day == null) continue;
    // A day, not a time: count it from midday.
    final t = day.add(const Duration(hours: 12));
    if (t.isBefore(since)) continue;
    items.add(
      UpdateItem(
        id: 'news-${n.id}',
        kind: 'news',
        title: n.title(l),
        detail: n.body(l),
        when: t.isAfter(now) ? l.calToday : agoText(l, t, now),
        opens: n.opens,
        sort: (t.isAfter(now) ? now : t).millisecondsSinceEpoch,
      ),
    );
  }
  items.sort((a, b) => b.sort.compareTo(a.sort));
  return items.take(_maxItems).toList();
}

/// Updates: a rolling stack like a phone's widget stack — my latest points,
/// fundings, notifications and the week's calendar, one at a time. It moves
/// on every 5 seconds, waits after a touch, and can be swiped sideways.
class UpdatesCard extends StatefulWidget {
  const UpdatesCard({
    super.key,
    required this.api,
    required this.userId,
    required this.onOpen,
    required this.canOpen,
  });

  final ApiClient api;
  final int userId;
  final ValueChanged<AppItem> onOpen;
  final bool Function(AppItem) canOpen;

  @override
  State<UpdatesCard> createState() => _UpdatesCardState();
}

/// The last answer per user, so coming back home shows it at once.
final Map<int, List<UpdateItem>> _remembered = {};

class _UpdatesCardState extends State<UpdatesCard> {
  List<UpdateItem>? _items;
  int _index = 0;
  bool _forward = true;
  Timer? _timer;
  DateTime _touchedAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _items = _remembered[widget.userId];
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      final count = _items?.length ?? 0;
      if (count < 2 || !mounted) return;
      if (DateTime.now().difference(_touchedAt).inSeconds < 8) return;
      setState(() {
        _forward = true;
        _index = (_index + 1) % count;
      });
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final items = (await loadUpdates(widget.api, widget.userId, l, locale))
        .where((item) => item.opens == null || widget.canOpen(item.opens!))
        .toList();
    _remembered[widget.userId] = items;
    if (mounted) {
      setState(() {
        _items = items;
        _index = 0;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go(int step) {
    final count = _items?.length ?? 0;
    if (count < 2) return;
    setState(() {
      _touchedAt = DateTime.now();
      _forward = step > 0;
      _index = ((_index + step) % count + count) % count;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final items = _items;
    final count = items?.length ?? 0;
    final item = count == 0 ? null : items![_index % count];
    final (bg, fg) = item == null
        ? (colors.card, colors.accent.solid)
        : _kindTone(item.kind, dark);

    return GestureDetector(
      // Sideways only, so up and down still scroll the Home page.
      onHorizontalDragEnd: (d) => _go((d.primaryVelocity ?? 0) < 0 ? 1 : -1),
      onTap: item?.opens == null ? null : () => widget.onOpen(item!.opens!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: Color.alphaBlend(bg, colors.card),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, size: 18, color: fg),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l.updTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (count > 1)
                  Text(
                    '${_index % count + 1}/$count',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.mutedText,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 64,
              child: items == null
                  ? const Center(child: LinearProgressIndicator(minHeight: 2))
                  : item == null
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          size: 18,
                          color: colors.mutedText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          l.updNothingNew,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedText,
                          ),
                        ),
                      ],
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      transitionBuilder: (child, animation) {
                        final incoming = child.key == ValueKey(item.id);
                        final dy = (incoming == _forward) ? 0.4 : -0.4;
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: Offset(0, dy),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        );
                      },
                      child: Column(
                        key: ValueKey(item.id),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          if (item.detail != null)
                            // One line: the card shares its row with
                            // My Class, so two would overflow the slide.
                            Text(
                              item.detail!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          Text(
                            item.when,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
