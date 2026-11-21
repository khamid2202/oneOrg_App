import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/staff_context.dart';
import '../../shared/sub_page.dart';

/// One item of the `/calendar` feed (docs/staff/calendar.md).
class CalendarItem {
  CalendarItem(this.raw);

  final Map<String, dynamic> raw;

  String get key => asStr(raw['key']) ?? '${raw['source']}:${raw['id']}';
  String get source => asStr(raw['source']) ?? 'event';
  int? get id => asInt(raw['id']);
  String get title => asStr(raw['title']) ?? '';
  String? get description => asStr(raw['description']);
  String? get category => asStr(raw['category']);
  String? get status => asStr(raw['status']);
  bool get allDay => raw['all_day'] != false;
  String get startDate =>
      (asStr(raw['start_date']) ?? '').padRight(10).substring(0, 10).trim();
  String get endDate {
    final end = asStr(raw['end_date']);
    return end == null ? startDate : end.substring(0, end.length.clamp(0, 10));
  }

  String? get startTime => asStr(raw['start_time']);
  String? get endTime => asStr(raw['end_time']);
  String? get place => asStr(raw['location']) ?? asStr(raw['room']);
  bool get editable => raw['editable'] == true;
  bool get isEvent => source == 'event';
  bool get cancelled => status == 'cancelled';
  bool get draft => status == 'draft';

  /// The filter this item answers to: terms share one.
  String get filter =>
      source == 'term_start' || source == 'term_end' ? 'term' : source;

  bool covers(String day) =>
      day.compareTo(startDate) >= 0 && day.compareTo(endDate) <= 0;

  String get timeLabel => allDay || startTime == null
      ? ''
      : [startTime, endTime]
            .whereType<String>()
            .map((t) => t.length >= 5 ? t.substring(0, 5) : t)
            .join(' – ');
}

Color calendarTone(BuildContext context, CalendarItem item) {
  if (item.cancelled || item.draft) return Colors.blueGrey;
  return switch (item.source) {
    'holiday' => const Color(0xFFF43F5E),
    'term_start' || 'term_end' => const Color(0xFF6366F1),
    'exam_period' => const Color(0xFFF59E0B),
    _ => appColorsOf(context).accent.solid,
  };
}

const calendarCategories = [
  'general',
  'ceremony',
  'parent_meeting',
  'trip',
  'sports',
  'competition',
  'deadline',
  'staff',
  'other',
];

String calendarCategoryLabel(AppLocalizations l, String? value) =>
    switch (value) {
      'ceremony' => l.calCatCeremony,
      'parent_meeting' => l.calCatParentMeeting,
      'trip' => l.calCatTrip,
      'sports' => l.calCatSports,
      'competition' => l.calCatCompetition,
      'deadline' => l.calCatDeadline,
      'staff' => l.calCatStaff,
      'other' => l.calCatOther,
      _ => l.calCatGeneral,
    };

String calendarSourceLabel(AppLocalizations l, String source) =>
    switch (source) {
      'holiday' => l.calHoliday,
      'term_start' => l.calTermStarts,
      'term_end' => l.calTermEnds,
      'exam_period' => l.calExamPeriod,
      _ => l.calEvent,
    };

/// The school calendar: events meant for the user, holidays, term starts and
/// ends, and exam periods — the web's `/calendar`. Whoever holds the
/// `calendar_events.*` keys adds, cancels and deletes events here too.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.ctx});

  final StaffContext ctx;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late String _selected = isoDay(DateTime.now());
  final Map<String, List<CalendarItem>> _cache = {};
  final Set<String> _hidden = {};
  bool _showAll = false;
  bool _scheduleView = false;
  bool _loading = false;
  Object? _error;
  int _epoch = 0;

  StaffContext get ctx => widget.ctx;
  bool get _canRead => ctx.can('calendar_events.read');
  bool get _canCreate => ctx.can('calendar_events.create');
  bool get _canUpdate => ctx.can('calendar_events.update');
  bool get _canDelete => ctx.can('calendar_events.delete');

  String get _monthKey =>
      '${_month.year}-${_month.month.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  Future<void> _ensure({bool force = false}) async {
    final key = _monthKey;
    if (!force && _cache.containsKey(key)) return;
    final epoch = _epoch;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final last = DateTime(_month.year, _month.month + 1, 0);
      final body = await ctx.api.get('/calendar', {
        'from': '$key-01',
        'to': isoDay(last),
        if (_showAll) 'mine': 'false',
      });
      if (!mounted || epoch != _epoch) return;
      setState(
        () => _cache[key] = ApiClient.rows(body).map(CalendarItem.new).toList(),
      );
    } catch (e) {
      if (mounted && epoch == _epoch) setState(() => _error = e);
    } finally {
      if (mounted && epoch == _epoch) setState(() => _loading = false);
    }
  }

  Future<void> _reload() async {
    _epoch++;
    _cache.clear();
    await _ensure(force: true);
  }

  void _moveMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      final now = DateTime.now();
      _selected = now.year == _month.year && now.month == _month.month
          ? isoDay(now)
          : isoDay(_month);
    });
    _ensure();
  }

  void _selectDay(String day) {
    final selected = DateTime.parse(day);
    setState(() {
      _selected = day;
      if (selected.year != _month.year || selected.month != _month.month) {
        _month = DateTime(selected.year, selected.month);
      }
    });
    _ensure();
  }

  List<CalendarItem> get _visible {
    final seen = <String, CalendarItem>{};
    for (final list in _cache.values) {
      for (final item in list) {
        if (!_hidden.contains(item.filter)) seen[item.key] = item;
      }
    }
    return seen.values.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final items = _visible;
    final dayItems = items.where((i) => i.covers(_selected)).toList()
      ..sort((a, b) {
        if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
        return (a.startTime ?? '').compareTo(b.startTime ?? '');
      });

    return SubPage(
      title: l.calendar,
      actions: [
        IconButton(
          tooltip: l.calToday,
          icon: const Icon(Icons.today_rounded),
          onPressed: () {
            final now = DateTime.now();
            setState(() {
              _month = DateTime(now.year, now.month);
              _selected = isoDay(now);
            });
            _ensure();
          },
        ),
      ],
      floatingActionButton: _canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(date: _selected),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.calNewEvent),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => _moveMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    DateFormat.yMMMM(locale).format(_month),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _moveMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final (value, label) in [
                    ('event', l.calEvents),
                    ('holiday', l.calHolidays),
                    ('term', l.calTerms),
                    ('exam_period', l.calExams),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(label),
                        selected: !_hidden.contains(value),
                        onSelected: (on) => setState(
                          () => on ? _hidden.remove(value) : _hidden.add(value),
                        ),
                      ),
                    ),
                  if (_canRead)
                    FilterChip(
                      avatar: const Icon(Icons.public_rounded, size: 16),
                      label: Text(l.calAllEvents),
                      selected: _showAll,
                      onSelected: (on) {
                        setState(() => _showAll = on);
                        _reload();
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: false, label: Text(l.calMonthView)),
                ButtonSegment(value: true, label: Text(l.calScheduleView)),
              ],
              selected: {_scheduleView},
              onSelectionChanged: (values) =>
                  setState(() => _scheduleView = values.first),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ErrorState(error: _error!, onRetry: _reload),
              ),
            if (_scheduleView)
              _ScheduleList(month: _month, items: items, onTap: _openDetails)
            else ...[
              _MonthGrid(
                month: _month,
                selected: _selected,
                items: items,
                onSelect: _selectDay,
              ),
              const SizedBox(height: 14),
              Text(
                DateFormat.MMMMEEEEd(locale).format(DateTime.parse(_selected)),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(height: 6),
              if (dayItems.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    l.calNothingOnDay,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.mutedText),
                  ),
                )
              else
                for (final item in dayItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _ItemCard(
                      item: item,
                      onTap: () => _openDetails(item),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openDetails(CalendarItem item) async {
    final l = AppLocalizations.of(context);
    Map<String, dynamic>? full;
    if (item.isEvent && _canRead && item.id != null) {
      try {
        full = ApiClient.one(await ctx.api.get('/calendar-events/${item.id}'));
      } catch (_) {}
    }
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DetailsSheet(
        item: item,
        full: full,
        canEdit: item.isEvent && item.editable && _canUpdate,
        canCancel:
            item.isEvent && item.editable && _canUpdate && !item.cancelled,
        canDelete: item.isEvent && _canDelete,
      ),
    );
    if (!mounted || action == null) return;
    try {
      if (action == 'edit') {
        await _openForm(event: full ?? item.raw);
        return;
      }
      if (action == 'cancel') {
        final ok = await confirmDialog(
          context,
          title: l.calCancelEventQ,
          message: item.title,
          confirmLabel: l.calCancelEvent,
          destructive: true,
        );
        if (!ok) return;
        await ctx.api.post('/calendar-events/${item.id}/cancel', {
          'notify': true,
        });
        if (mounted) toast(context, l.calEventCancelled);
      } else if (action == 'delete') {
        final ok = await confirmDialog(
          context,
          title: l.calDeleteEventQ,
          message: item.title,
          confirmLabel: l.delete,
          destructive: true,
        );
        if (!ok) return;
        await ctx.api.delete('/calendar-events/${item.id}');
        if (mounted) toast(context, l.calEventDeleted);
      }
      await _reload();
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    }
  }

  Future<void> _openForm({String? date, Map<String, dynamic>? event}) async {
    final saved = await SubPage.push<bool>(
      context,
      EventFormPage(ctx: ctx, date: date, event: event),
    );
    if (saved == true) await _reload();
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.items,
    required this.onSelect,
  });

  final DateTime month;
  final String selected;
  final List<CalendarItem> items;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final first = DateTime(month.year, month.month, 1);
    final lead = (first.weekday + 6) % 7;
    final days = DateTime(month.year, month.month + 1, 0).day;
    final rows = ((lead + days) / 7).ceil();
    final today = isoDay(DateTime.now());
    final weekdays = [
      for (var i = 0; i < 7; i++)
        DateFormat.E(locale).format(DateTime(2024, 1, 1 + i)),
    ];

    return Column(
      children: [
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Text(
                  w,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: colors.mutedText),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: _dayCell(
                    context,
                    DateTime(month.year, month.month, 1 - lead + r * 7 + c),
                    today,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _dayCell(BuildContext context, DateTime date, String today) {
    final colors = appColorsOf(context);
    final iso = isoDay(date);
    final inMonth = date.month == month.month;
    final isSelected = iso == selected;
    final isToday = iso == today;
    final on = items.where((i) => i.covers(iso)).toList();
    final holiday = on.any((i) => i.source == 'holiday');
    return GestureDetector(
      onTap: () => onSelect(iso),
      child: Container(
        height: 46,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.accent.solid
              : holiday
              ? const Color(0xFFF43F5E).withValues(alpha: 0.08)
              : null,
          borderRadius: BorderRadius.circular(10),
          border: isToday && !isSelected
              ? Border.all(color: colors.accent.solid, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? Colors.white
                    : inMonth
                    ? null
                    : colors.mutedText.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final item in on.take(3))
                  Container(
                    width: 5,
                    height: 5,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white
                          : calendarTone(context, item),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleList extends StatelessWidget {
  const _ScheduleList({
    required this.month,
    required this.items,
    required this.onTap,
  });

  final DateTime month;
  final List<CalendarItem> items;
  final ValueChanged<CalendarItem> onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    final groups = <(DateTime, List<CalendarItem>)>[];
    for (var day = 1; day <= lastDay; day++) {
      final date = DateTime(month.year, month.month, day);
      final key = isoDay(date);
      final on =
          items
              .where(
                (item) =>
                    item.covers(key) &&
                    (item.startDate == key ||
                        day == 1 && item.startDate.compareTo(key) < 0),
              )
              .toList()
            ..sort((a, b) {
              if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
              return (a.startTime ?? '').compareTo(b.startTime ?? '');
            });
      if (on.isNotEmpty) groups.add((date, on));
    }
    if (groups.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(l.calNothingOnDay)),
      );
    }
    return Column(
      children: [
        for (final (date, dayItems) in groups)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.MMMEd(locale).format(date),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                for (final item in dayItems)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _ItemCard(item: item, onTap: () => onTap(item)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.item, required this.onTap});

  final CalendarItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final tone = calendarTone(context, item);
    final time = item.timeLabel;
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: item.cancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    item.isEvent
                        ? calendarCategoryLabel(l, item.category)
                        : calendarSourceLabel(l, item.source),
                    time.isEmpty ? l.calAllDay : time,
                    ?item.place,
                    if (item.cancelled) l.calCancelled,
                    if (item.draft) l.calDraft,
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  const _DetailsSheet({
    required this.item,
    required this.full,
    required this.canEdit,
    required this.canCancel,
    required this.canDelete,
  });

  final CalendarItem item;
  final Map<String, dynamic>? full;
  final bool canEdit;
  final bool canCancel;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    String day(String iso) {
      final d = DateTime.tryParse(iso);
      return d == null ? iso : DateFormat.yMMMEd(locale).format(d);
    }

    final dates = item.endDate == item.startDate
        ? day(item.startDate)
        : '${day(item.startDate)} – ${day(item.endDate)}';
    final audiences = full?['audiences'];
    final description = asStr(full?['description']) ?? item.description;

    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: colors.mutedText),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tag(
              item.isEvent
                  ? calendarCategoryLabel(l, item.category)
                  : calendarSourceLabel(l, item.source),
              color: calendarTone(context, item),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            line(Icons.event_rounded, dates),
            line(
              Icons.schedule_rounded,
              item.timeLabel.isEmpty ? l.calAllDay : item.timeLabel,
            ),
            if (item.place != null) line(Icons.place_outlined, item.place!),
            if (audiences is List && audiences.isNotEmpty)
              line(
                Icons.groups_outlined,
                audiences
                    .whereType<Map>()
                    .map(
                      (a) => asStr(a['name']) ?? asStr(a['target_type']) ?? '',
                    )
                    .join(', '),
              ),
            if (description != null) ...[
              const SizedBox(height: 10),
              Text(description),
            ],
            if (canEdit || canCancel || canDelete) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: [
                  if (canEdit)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'edit'),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: Text(l.edit),
                    ),
                  if (canCancel)
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, 'cancel'),
                      icon: const Icon(Icons.block_rounded, size: 18),
                      label: Text(l.calCancelEvent),
                    ),
                  if (canDelete)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade600,
                      ),
                      onPressed: () => Navigator.pop(context, 'delete'),
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                      label: Text(l.delete),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// New or edited calendar event. Audiences: all staff, all students, or the
/// branch's roles / departments / grades / classes.
class EventFormPage extends StatefulWidget {
  const EventFormPage({super.key, required this.ctx, this.date, this.event});

  final StaffContext ctx;
  final String? date;
  final Map<String, dynamic>? event;

  @override
  State<EventFormPage> createState() => _EventFormPageState();
}

class _EventFormPageState extends State<EventFormPage> {
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _description = TextEditingController();
  String _category = 'general';
  bool _allDay = true;
  late String _start;
  late String _end;
  TimeOfDay _from = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _to = const TimeOfDay(hour: 10, minute: 0);
  bool _draft = false;
  bool _notify = true;
  final Set<String> _audiences = {'all_staff:'};
  List<(String, String)> _options = const [];
  bool _saving = false;

  bool get _isEdit => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    _start = widget.date ?? isoDay(DateTime.now());
    _end = _start;
    if (e != null) {
      _title.text = asStr(e['title']) ?? '';
      _location.text = asStr(e['location']) ?? '';
      _description.text = asStr(e['description']) ?? '';
      _category = asStr(e['category']) ?? 'general';
      _allDay = e['all_day'] != false;
      _start = asStr(e['start_date'])?.substring(0, 10) ?? _start;
      _end = asStr(e['end_date'])?.substring(0, 10) ?? _start;
      _from = _parseTime(asStr(e['start_time'])) ?? _from;
      _to = _parseTime(asStr(e['end_time'])) ?? _to;
      _draft = e['status'] == 'draft';
      final list = e['audiences'];
      if (list is List) {
        _audiences
          ..clear()
          ..addAll(
            list.whereType<Map>().map(
              (a) => '${a['target_type']}:${a['target_id'] ?? ''}',
            ),
          );
      }
    }
    _loadOptions();
  }

  static TimeOfDay? _parseTime(String? v) {
    if (v == null) return null;
    final parts = v.split(':');
    final h = int.tryParse(parts.first);
    final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
    return h == null ? null : TimeOfDay(hour: h, minute: m ?? 0);
  }

  static String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _loadOptions() async {
    final api = widget.ctx.api;
    final year = await widget.ctx.academicYearId();
    Future<List<Map<String, dynamic>>> safe(Future<dynamic> f) async {
      try {
        final body = await f;
        if (body is Map) {
          for (final k in ['roles', 'groups']) {
            if (body[k] is List) return ApiClient.rows({'result': body[k]});
          }
        }
        return ApiClient.rows(body);
      } catch (_) {
        return const [];
      }
    }

    final results = await Future.wait([
      safe(api.get('/grade-levels', {'is_active': 'true'})),
      safe(
        year == null
            ? Future.value(null)
            : api.get('/groups', {'academic_year_id': year}),
      ),
      safe(api.get('/roles')),
      safe(api.get('/departments')),
    ]);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _options = [
        for (final g in results[0])
          (
            'grade:${g['id']}',
            '${l.calGrade}: ${asStr(g['name']) ?? g['level']}',
          ),
        for (final g in results[1])
          (
            'group:${g['id']}',
            '${l.calClass}: ${asStr(g['class_pair']) ?? asStr(g['name']) ?? '#${g['id']}'}',
          ),
        for (final r in results[2])
          (
            'role:${r['id']}',
            '${l.calRole}: ${asStr(r['label']) ?? asStr(r['name']) ?? ''}',
          ),
        for (final d in results[3])
          if (d['is_active'] != false)
            (
              'department:${d['id']}',
              '${l.calDepartment}: ${asStr(d['name']) ?? ''}',
            ),
      ];
    });
  }

  Future<void> _pickDate(bool start) async {
    final initial = DateTime.parse(start ? _start : _end);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = isoDay(picked);
        if (_end.compareTo(_start) < 0) _end = _start;
      } else {
        _end = isoDay(picked);
        if (_end.compareTo(_start) < 0) _start = _end;
      }
    });
  }

  Future<void> _pickTime(bool from) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: from ? _from : _to,
    );
    if (picked != null) setState(() => from ? _from = picked : _to = picked);
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_title.text.trim().isEmpty) {
      toast(context, l.calTitleRequired);
      return;
    }
    setState(() => _saving = true);
    try {
      final body = <String, dynamic>{
        'title': _title.text.trim(),
        'category': _category,
        'all_day': _allDay,
        'start_date': _start,
        'end_date': _end,
        if (!_allDay) 'start_time': _fmt(_from),
        if (!_allDay) 'end_time': _fmt(_to),
        'location': _location.text.trim().isEmpty
            ? null
            : _location.text.trim(),
        'description': _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        'status': _draft ? 'draft' : 'published',
        'audiences': [
          for (final key in _audiences)
            {
              'target_type': key.split(':').first,
              if (key.split(':').last.isNotEmpty)
                'target_id': int.parse(key.split(':').last),
            },
        ],
        'notify': _notify && !_draft,
      };
      if (_isEdit) {
        await widget.ctx.api.patch(
          '/calendar-events/${widget.event!['id']}',
          body,
        );
      } else {
        final year = await widget.ctx.academicYearId();
        await widget.ctx.api.post('/calendar-events', {
          ...body,
          'academic_year_id': ?year,
        });
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) toast(context, errorText(e, l.calChangeFailed));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    String day(String iso) =>
        DateFormat.yMMMd(locale).format(DateTime.parse(iso));
    final broad = [
      ('all_staff:', l.calAllStaff),
      ('all_students:', l.calAllStudents),
    ];
    final labelOf = {
      for (final o in [...broad, ..._options]) o.$1: o.$2,
    };

    return SubPage(
      title: _isEdit ? l.calEditEvent : l.calNewEvent,
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.save),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(labelText: l.calTitle),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: InputDecoration(labelText: l.calCategory),
            items: [
              for (final c in calendarCategories)
                DropdownMenuItem(
                  value: c,
                  child: Text(calendarCategoryLabel(l, c)),
                ),
            ],
            onChanged: (v) => setState(() => _category = v ?? 'general'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(day(_start)),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('–'),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(day(_end)),
                ),
              ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.calAllDay),
            value: _allDay,
            onChanged: (v) => setState(() => _allDay = v),
          ),
          if (!_allDay)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(true),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_fmt(_from)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(false),
                    icon: const Icon(Icons.schedule_rounded, size: 18),
                    label: Text(_fmt(_to)),
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _location,
            decoration: InputDecoration(labelText: l.calLocation),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _description,
            minLines: 2,
            maxLines: 5,
            decoration: InputDecoration(labelText: l.calDescription),
          ),
          const SizedBox(height: 16),
          Text(
            l.calAudience,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final key in _audiences)
                InputChip(
                  label: Text(labelOf[key] ?? key),
                  onDeleted: () => setState(() => _audiences.remove(key)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(l.calAddAudience),
                onPressed: () async {
                  final picked = await showModalBottomSheet<String>(
                    context: context,
                    showDragHandle: true,
                    isScrollControlled: true,
                    builder: (context) => DraggableScrollableSheet(
                      expand: false,
                      initialChildSize: 0.6,
                      builder: (context, controller) => ListView(
                        controller: controller,
                        children: [
                          for (final o in [...broad, ..._options])
                            if (!_audiences.contains(o.$1))
                              ListTile(
                                title: Text(o.$2),
                                onTap: () => Navigator.pop(context, o.$1),
                              ),
                        ],
                      ),
                    ),
                  );
                  if (picked != null) setState(() => _audiences.add(picked));
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.calSaveAsDraft),
            value: _draft,
            onChanged: (v) => setState(() => _draft = v),
          ),
          if (!_draft)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.calNotify),
              value: _notify,
              onChanged: (v) => setState(() => _notify = v),
            ),
        ],
      ),
    );
  }
}
