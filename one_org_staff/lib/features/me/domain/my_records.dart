import 'dart:typed_data';

import 'staff_records.dart';

export 'staff_records.dart';

int? _int(dynamic value) => value is num
    ? value.toInt()
    : value is String
    ? num.tryParse(value)?.toInt()
    : null;

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _instant(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '')?.toLocal();

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

/// "YYYY-MM-DD".
String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

// ---------------------------------- plan ----------------------------------

const planPending = 'pending';
const planInProgress = 'in_progress';
const planCompleted = 'completed';
const planPostponed = 'postponed';
const planCancelled = 'cancelled';

/// In the order a milestone lives through them.
const planStatuses = [
  planPending,
  planInProgress,
  planCompleted,
  planPostponed,
  planCancelled,
];
const planPriorities = ['low', 'medium', 'high', 'urgent'];
const planCategories = [
  'curriculum',
  'lesson',
  'exam',
  'meeting',
  'administrative',
  'personal',
  'general',
];

class PlanAttachment {
  const PlanAttachment({required this.key, required this.name, this.url});

  final String key;
  final String name;
  final String? url;
}

/// One milestone of a yearly plan.
class UserPlan {
  const UserPlan({
    required this.id,
    required this.agenda,
    this.notes,
    this.start,
    this.end,
    this.status = planPending,
    this.priority = 'medium',
    this.category,
    this.attachments = const [],
  });

  final int id;
  final String agenda;
  final String? notes;
  final DateTime? start;
  final DateTime? end;
  final String status;
  final String priority;
  final String? category;
  final List<PlanAttachment> attachments;

  UserPlan withStatus(String next) => UserPlan(
    id: id,
    agenda: agenda,
    notes: notes,
    start: start,
    end: end,
    status: next,
    priority: priority,
    category: category,
    attachments: attachments,
  );

  factory UserPlan.fromJson(Map<String, dynamic> json) => UserPlan(
    id: _int(json['id']) ?? 0,
    agenda: json['agenda']?.toString() ?? '',
    notes: _text(json['notes']),
    start: _instant(json['start_date']),
    end: _instant(json['end_date']),
    status: _text(json['status']) ?? planPending,
    priority: _text(json['priority']) ?? 'medium',
    category: _text(json['category']),
    attachments: [
      if (json['attachments'] is List)
        for (final file in (json['attachments'] as List).whereType<Map>())
          PlanAttachment(
            key: file['key']?.toString() ?? '',
            name: file['name']?.toString() ?? '',
            url: _text(file['url']),
          ),
    ],
  );
}

/// What the form sends.
class PlanDraft {
  const PlanDraft({
    required this.agenda,
    required this.start,
    required this.end,
    this.notes = '',
    this.status = planPending,
    this.priority = 'medium',
    this.category = 'curriculum',
  });

  final String agenda;
  final String notes;
  final DateTime start;
  final DateTime end;
  final String status;
  final String priority;
  final String category;

  Map<String, dynamic> toJson() => {
    'agenda': agenda.trim(),
    'notes': notes.trim(),
    'start_date': _day(start).toUtc().toIso8601String(),
    'end_date': _day(end).toUtc().toIso8601String(),
    'status': status,
    'priority': priority,
    'category': category.trim().isEmpty ? 'general' : category.trim(),
  };
}

/// A file staged in the form.
class PlanFile {
  const PlanFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

int _byStart(UserPlan a, UserPlan b) =>
    (a.start ?? DateTime(0)).compareTo(b.start ?? DateTime(0));

List<UserPlan> sortedPlans(Iterable<UserPlan> plans) =>
    plans.toList()..sort(_byStart);

/// What a status is worth; cancelled work leaves the sum altogether.
double? _progressOf(String status) => switch (status) {
  planCompleted => 1,
  planInProgress => 0.5,
  planCancelled => null,
  _ => 0,
};

/// 0–100. In progress counts as half, cancelled isn't counted.
int planProgress(List<UserPlan> plans) {
  final counted = plans.map((p) => _progressOf(p.status)).nonNulls.toList();
  if (counted.isEmpty) return 0;
  return (counted.reduce((a, b) => a + b) / counted.length * 100).round();
}

/// Past its end and still open. Parked and dropped work isn't overdue.
bool isOverdue(UserPlan plan, DateTime now) {
  if (const [
    planCompleted,
    planCancelled,
    planPostponed,
  ].contains(plan.status)) {
    return false;
  }
  final end = plan.end;
  return end != null && end.isBefore(_day(now));
}

/// Where the plan has got to: what's marked in progress, else the first open
/// one. -1 when everything is finished.
int currentPlanIndex(List<UserPlan> plans) {
  final working = plans.indexWhere((p) => p.status == planInProgress);
  if (working != -1) return working;
  return plans.indexWhere(
    (p) => p.status != planCompleted && p.status != planCancelled,
  );
}

/// [months] later, clamped to the end of the month: Jan 31 → Feb 28.
DateTime addMonths(DateTime date, int months) {
  final target = DateTime(date.year, date.month + months);
  final lastDay = DateTime(target.year, target.month + 1, 0).day;
  return DateTime(
    target.year,
    target.month,
    date.day > lastDay ? lastDay : date.day,
  );
}

/// The day after the plan's latest end, else the start of the year.
DateTime nextMilestoneStart(
  List<UserPlan> plans, {
  DateTime? yearStart,
  required DateTime now,
}) {
  final ends = plans.map((p) => p.end).nonNulls.toList();
  if (ends.isEmpty) return _day(yearStart ?? now);
  final latest = ends.reduce((a, b) => a.isAfter(b) ? a : b);
  return DateTime(latest.year, latest.month, latest.day + 1);
}

// --------------------------------- periods ---------------------------------

enum PeriodPreset { all, month, last30, year }

class DateWindow {
  const DateWindow({this.from, this.to});

  /// "YYYY-MM-DD", either end may be open.
  final String? from;
  final String? to;

  bool contains(String date) =>
      (from == null || date.compareTo(from!) >= 0) &&
      (to == null || date.compareTo(to!) <= 0);
}

/// Null for all time.
DateWindow? windowOf(PeriodPreset preset, DateTime now) => switch (preset) {
  PeriodPreset.all => null,
  PeriodPreset.month => DateWindow(
    from: dateKey(DateTime(now.year, now.month)),
    to: dateKey(DateTime(now.year, now.month + 1, 0)),
  ),
  PeriodPreset.last30 => DateWindow(
    from: dateKey(DateTime(now.year, now.month, now.day - 29)),
    to: dateKey(now),
  ),
  PeriodPreset.year => DateWindow(
    from: '${now.year}-01-01',
    to: '${now.year}-12-31',
  ),
};

// --------------------------------- points ----------------------------------

class PointRecord {
  const PointRecord({
    required this.id,
    required this.points,
    required this.date,
    this.note,
    this.createdAt,
    this.createdBy,
    this.categoryId,
    this.categoryName,
    this.updatedAt,
    this.updatedBy,
  });

  final int id;
  final int points;

  /// "YYYY-MM-DD", the day the points count for.
  final String date;
  final String? note;
  final DateTime? createdAt;
  final int? createdBy;
  final int? categoryId;
  final String? categoryName;
  final DateTime? updatedAt;
  final int? updatedBy;

  /// Added on another day than the one it counts for.
  bool get backdated {
    final added = createdAt;
    return added != null && date.isNotEmpty && dateKey(added.toLocal()) != date;
  }

  /// Someone changed it after it was added.
  bool get edited =>
      updatedBy != null &&
      updatedAt != null &&
      createdAt != null &&
      updatedAt!.difference(createdAt!).inSeconds.abs() > 1;

  factory PointRecord.fromJson(Map<String, dynamic> json) => PointRecord(
    id: _int(json['id']) ?? 0,
    points: _int(json['points']) ?? 0,
    date: json['date']?.toString() ?? '',
    note: _text(json['note']),
    createdAt: _instant(json['created_at']),
    createdBy: _int(json['created_by']),
    categoryId: _int(json['category_id']),
    categoryName: _text(_map(json['category'])['name']),
    updatedAt: _instant(json['updated_at']),
    updatedBy: _int(json['updated_by']),
  );
}

/// Newest first by the day it counts for, then by when it was added.
List<PointRecord> newestPointsFirst(Iterable<PointRecord> records) =>
    records.toList()..sort((a, b) {
      final byDate = b.date.compareTo(a.date);
      if (byDate != 0) return byDate;
      final at = b.createdAt, bt = a.createdAt;
      if (at != null && bt != null) return at.compareTo(bt);
      return b.id.compareTo(a.id);
    });

int pointsTotal(Iterable<PointRecord> records) =>
    records.fold(0, (sum, record) => sum + record.points);

// -------------------------------- fundings ---------------------------------

const fundingWithdrawal = 'withdrawal';
const currencyUzs = 'UZS';

class FundingCategory {
  const FundingCategory({required this.id, required this.name});

  final int id;
  final String name;
}

class Funding {
  const Funding({
    required this.id,
    required this.type,
    required this.amount,
    required this.date,
    this.currency = currencyUzs,
    this.note,
    this.categoryId,
    this.categoryName,
    this.creatorName,
    this.balanceAfter = 0,
  });

  final int id;
  final String type;
  final String currency;
  final int amount;

  /// "YYYY-MM-DD".
  final String date;
  final String? note;
  final int? categoryId;
  final String? categoryName;
  final String? creatorName;

  /// In this record's own category and currency.
  final int balanceAfter;

  bool get isWithdrawal => type == fundingWithdrawal;
  int get signed => isWithdrawal ? -amount : amount;
  String get pocketKey => '${categoryId ?? ''}|$currency';

  Funding _withBalance(int balance) => Funding(
    id: id,
    type: type,
    amount: amount,
    date: date,
    currency: currency,
    note: note,
    categoryId: categoryId,
    categoryName: categoryName,
    creatorName: creatorName,
    balanceAfter: balance,
  );

  factory Funding.fromJson(Map<String, dynamic> json) {
    final creator = _map(json['creator']);
    return Funding(
      id: _int(json['id']) ?? 0,
      type: json['type']?.toString() ?? '',
      amount: _int(json['amount']) ?? 0,
      date: json['date']?.toString() ?? '',
      currency: _text(json['currency']) ?? currencyUzs,
      note: _text(json['note']),
      categoryId: _int(json['category_id']),
      categoryName: _text(_map(json['category'])['name']),
      creatorName: _text(creator['full_name']) ?? _text(creator['username']),
    );
  }
}

/// Newest first, each with the balance right after it, like a bank statement.
List<Funding> withRunningBalance(List<Funding> records) {
  final ordered = records.toList()
    ..sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.id.compareTo(b.id);
    });
  final balances = <String, int>{};
  final rows = [
    for (final record in ordered)
      record._withBalance(
        balances[record.pocketKey] =
            (balances[record.pocketKey] ?? 0) + record.signed,
      ),
  ];
  return rows.reversed.toList();
}

/// One category in one currency: the unit a balance is kept in. Different
/// pockets are never added together.
class FundingPocket {
  FundingPocket({
    required this.key,
    required this.categoryId,
    required this.name,
    required this.currency,
  });

  final String key;
  final int? categoryId;
  String name;
  final String currency;
  int deposits = 0;
  int withdrawals = 0;

  int get balance => deposits - withdrawals;
}

/// Every category in UZS even at zero, plus whatever else has records.
List<FundingPocket> pocketsOf(
  List<Funding> records,
  List<FundingCategory> categories,
) {
  final pockets = <String, FundingPocket>{};
  FundingPocket add(int? id, String name, String currency) =>
      pockets['${id ?? ''}|$currency'] ??= FundingPocket(
        key: '${id ?? ''}|$currency',
        categoryId: id,
        name: name,
        currency: currency,
      );

  for (final category in categories) {
    add(category.id, category.name, currencyUzs);
  }
  for (final record in records) {
    final pocket = add(
      record.categoryId,
      record.categoryName ?? '',
      record.currency,
    );
    if (pocket.name.isEmpty) pocket.name = record.categoryName ?? '';
    if (record.isWithdrawal) {
      pocket.withdrawals += record.amount;
    } else {
      pocket.deposits += record.amount;
    }
  }

  final order = {
    for (var i = 0; i < categories.length; i++) categories[i].id: i,
  };
  return pockets.values.toList()..sort((a, b) {
    final byOrder = (order[a.categoryId] ?? 999).compareTo(
      order[b.categoryId] ?? 999,
    );
    if (byOrder != 0) return byOrder;
    final byName = a.name.compareTo(b.name);
    if (byName != 0) return byName;
    if (a.currency == b.currency) return 0;
    return a.currency == currencyUzs ? -1 : 1;
  });
}

/// The net of [records] per currency, UZS first.
Map<String, int> netByCurrency(Iterable<Funding> records) {
  final totals = <String, int>{};
  for (final record in records) {
    totals[record.currency] = (totals[record.currency] ?? 0) + record.signed;
  }
  final keys = totals.keys.toList()
    ..sort((a, b) {
      if (a == b) return 0;
      return a == currencyUzs ? -1 : 1;
    });
  return {for (final key in keys) key: totals[key]!};
}

// -------------------------------- repository --------------------------------

/// The signed-in person's own plan, points and savings. Every read names them
/// explicitly: without a `user_id`, anyone allowed to see everyone's records
/// would get the whole school's added up as "mine".
/// One item of `GET /calendar` (mine only): a calendar event meant for me,
/// a holiday or an exam period.
class CalendarEntry {
  const CalendarEntry({
    required this.key,
    required this.source,
    required this.id,
    required this.title,
    required this.startDate,
    this.endDate,
    this.startTime,
    this.allDay = true,
    this.status,
    this.location,
    this.endTime,
    this.description,
    this.category,
  });

  factory CalendarEntry.fromJson(Map<String, dynamic> json) {
    final source = json['source']?.toString() ?? 'event';
    final id = _int(json['id']) ?? 0;
    return CalendarEntry(
      key: json['key']?.toString() ?? '$source:$id',
      source: source,
      id: id,
      title: json['title']?.toString() ?? '',
      startDate: json['start_date']?.toString() ?? '',
      endDate: json['end_date']?.toString(),
      startTime: json['start_time']?.toString(),
      allDay: json['all_day'] != false,
      status: json['status']?.toString(),
      location: json['location']?.toString(),
      endTime: json['end_time']?.toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString(),
    );
  }

  final String key;

  /// `event`, `holiday`, `term_start`, `term_end` or `exam_period`.
  final String source;
  final int id;
  final String title;

  /// "YYYY-MM-DD".
  final String startDate;
  final String? endDate;

  /// "HH:MM" or null for all-day items.
  final String? startTime;
  final bool allDay;
  final String? status;
  final String? location;

  /// "HH:MM", for timed items.
  final String? endTime;
  final String? description;

  /// An event's kind: `sports`, `parent_meeting`, `staff`…
  final String? category;
}

abstract class MyRepository {
  Future<List<UserPlan>> getPlans({
    required int userId,
    String? from,
    String? to,
  });

  Future<void> savePlan(
    PlanDraft draft, {
    int? id,
    List<PlanFile> files = const [],
    List<String> removeAttachmentKeys = const [],
  });

  Future<void> setPlanStatus(int id, String status);

  Future<void> deletePlan(int id);

  Future<List<PointRecord>> getPoints(int userId);

  Future<List<Funding>> getFundings(int userId);

  Future<List<FundingCategory>> getFundingCategories();

  /// My newest points added since [from] ("YYYY-MM-DD"), one short page.
  Future<List<PointRecord>> getRecentPoints(int userId, {required String from});

  /// My newest fundings since [from] ("YYYY-MM-DD"), one short page.
  Future<List<Funding>> getRecentFundings(int userId, {required String from});

  /// My calendar between [from] and [to]: events meant for me, holidays and
  /// exam periods. Open to every staff member.
  Future<List<CalendarEntry>> getCalendar({
    required String from,
    required String to,
  });

  /// Everything on my calendar between [from] and [to] (at most 93 days
  /// apart), terms included, for the Calendar page.
  Future<List<CalendarEntry>> getFullCalendar({
    required String from,
    required String to,
  });

  /// Every analysis of my lessons, newest lesson first.
  Future<List<LessonObservation>> getMyObservations(int userId);

  /// The departments I'm in, with my role in each.
  Future<List<MyDepartmentEntry>> getMyDepartments();

  /// One department's figures over the active academic year, or one class.
  Future<DepartmentStats> getDepartmentStats(int departmentId, {int? groupId});
}
