import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/api_client.dart';
import '../../shared/underline_tabs.dart';

// The web's My Plans → Annual Plan (`LessonPlans.jsx`), to read on the phone:
// your week-by-week plans and the ones colleagues share with your department,
// each opening on the current week. Plans are made and edited on the web.

String? _text(Object? v) {
  final s = asStr(v)?.trim();
  return s == null || s.isEmpty ? null : s;
}

DateTime? _date(Object? v) => DateTime.tryParse('${v ?? ''}');

List<String> _lines(String? text) => [
  for (final line in (text ?? '').split('\n'))
    if (line.trim().isNotEmpty) line.trim(),
];

class PlanWeekRow {
  const PlanWeekRow({
    required this.weekNo,
    this.start,
    this.end,
    this.unit,
    this.topic,
    this.objectives = const [],
    this.homework = const [],
  });

  final int weekNo;
  final DateTime? start;
  final DateTime? end;
  final String? unit;
  final String? topic;
  final List<String> objectives;
  final List<String> homework;

  factory PlanWeekRow.fromJson(Map<String, dynamic> json) => PlanWeekRow(
    weekNo: asInt(json['week_no']) ?? 0,
    start: _date(json['start_date']),
    end: _date(json['end_date']),
    unit: _text(json['unit']),
    topic: _text(json['topic']),
    objectives: _lines(_text(json['objectives'])),
    homework: _lines(_text(json['homework'])),
  );

  /// Whether [day] falls in this week (dates only).
  bool contains(DateTime day) {
    final s = start, e = end;
    if (s == null || e == null) return false;
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(DateTime(s.year, s.month, s.day)) &&
        !d.isAfter(DateTime(e.year, e.month, e.day));
  }
}

class LessonPlan {
  const LessonPlan({
    required this.id,
    required this.title,
    this.subject,
    this.teacherId,
    this.teacher,
    this.grades = const [],
    this.groupCount = 0,
    this.shared = false,
    this.weekCount = 0,
    this.weeks = const [],
  });

  final int id;
  final String title;
  final String? subject;
  final int? teacherId;
  final String? teacher;
  final List<int> grades;
  final int groupCount;
  final bool shared;
  final int weekCount;

  /// Only from `GET /lesson-plans/:id`.
  final List<PlanWeekRow> weeks;

  factory LessonPlan.fromJson(Map<String, dynamic> json) {
    final weeks = [
      for (final w in json['weeks'] as List? ?? const [])
        if (w is Map) PlanWeekRow.fromJson(Map<String, dynamic>.from(w)),
    ]..sort((a, b) => a.weekNo.compareTo(b.weekNo));
    return LessonPlan(
      id: asInt(json['id']) ?? 0,
      title: _text(json['title']) ?? _text(json['subject']) ?? '',
      subject: _text(json['subject']),
      teacherId: asInt(json['teacher_id']),
      teacher: _text(json['teacher']),
      grades: [for (final g in json['grades'] as List? ?? const []) ?asInt(g)]
        ..sort(),
      groupCount: (json['group_ids'] as List?)?.length ?? 0,
      shared: json['shared'] == true,
      weekCount: asInt(json['week_count']) ?? weeks.length,
      weeks: weeks,
    );
  }
}

/// The two calls the reader needs.
class LessonPlansApi {
  const LessonPlansApi({required this.list, required this.load});

  final Future<List<LessonPlan>> Function() list;
  final Future<LessonPlan> Function(int id) load;

  factory LessonPlansApi.http(
    ApiClient api,
    Future<int?> Function() academicYearId,
  ) => LessonPlansApi(
    list: () async {
      final year = await academicYearId();
      final body = await api.get('/lesson-plans', {'academic_year_id': ?year});
      return ApiClient.rows(body).map(LessonPlan.fromJson).toList();
    },
    load: (id) async =>
        LessonPlan.fromJson(ApiClient.one(await api.get('/lesson-plans/$id'))),
  );
}

enum _PlansTab { annual, goals }

/// My Plan with the Annual Plan in front, for people with
/// `lesson_plans.read`; the web's `MyPlans`.
class MyPlansTabs extends StatefulWidget {
  const MyPlansTabs({
    super.key,
    required this.api,
    required this.userId,
    required this.goals,
    this.bottomInset = 0,
    this.today,
  });

  final LessonPlansApi api;
  final int userId;

  /// The personal goals page everyone has.
  final Widget goals;
  final double bottomInset;
  final DateTime? today;

  @override
  State<MyPlansTabs> createState() => _MyPlansTabsState();
}

class _MyPlansTabsState extends State<MyPlansTabs> {
  _PlansTab _tab = _PlansTab.annual;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        UnderlineTabs<_PlansTab>(
          items: [
            UnderlineTabItem(
              value: _PlansTab.annual,
              label: l.annualPlan,
              icon: Icons.calendar_view_week_rounded,
            ),
            UnderlineTabItem(
              value: _PlansTab.goals,
              label: l.planGoals,
              icon: Icons.edit_note_rounded,
            ),
          ],
          selected: _tab,
          onSelected: (tab) => setState(() => _tab = tab),
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        ),
        Expanded(
          child: IndexedStack(
            index: _tab.index,
            children: [
              AnnualPlansView(
                api: widget.api,
                userId: widget.userId,
                bottomInset: widget.bottomInset,
                today: widget.today,
              ),
              widget.goals,
            ],
          ),
        ),
      ],
    );
  }
}

/// The list of plans; one opens on its current week.
class AnnualPlansView extends StatefulWidget {
  const AnnualPlansView({
    super.key,
    required this.api,
    required this.userId,
    this.bottomInset = 0,
    this.today,
  });

  final LessonPlansApi api;
  final int userId;
  final double bottomInset;
  final DateTime? today;

  @override
  State<AnnualPlansView> createState() => _AnnualPlansViewState();
}

class _AnnualPlansViewState extends State<AnnualPlansView> {
  late Future<List<LessonPlan>> _plans = widget.api.list();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return FutureBuilder<List<LessonPlan>>(
      future: _plans,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final plans = snapshot.data;
        if (snapshot.hasError || plans == null) {
          return _Centered(
            text: l.annualPlansFailed,
            action: OutlinedButton(
              onPressed: () => setState(() => _plans = widget.api.list()),
              child: Text(l.retry),
            ),
          );
        }
        if (plans.isEmpty) return _Centered(text: l.annualPlansNone);
        return RefreshIndicator(
          onRefresh: () async {
            final next = widget.api.list();
            setState(() => _plans = next);
            await next;
          },
          child: ListView.separated(
            padding: EdgeInsets.fromLTRB(16, 12, 16, widget.bottomInset + 12),
            itemCount: plans.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final plan = plans[index];
              final fromColleague =
                  plan.teacherId != null && plan.teacherId != widget.userId;
              final scope = plan.groupCount > 0
                  ? l.annualPlanClasses(plan.groupCount)
                  : plan.grades.isEmpty
                  ? null
                  : l.annualPlanGrades(plan.grades.join(', '));
              return Material(
                color: colors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: colors.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => PlanWeeksPage(
                        api: widget.api,
                        plan: plan,
                        today: widget.today,
                      ),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  ?plan.subject,
                                  ?scope,
                                  l.annualPlanWeeks(plan.weekCount),
                                ].join(' · '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.mutedText,
                                ),
                              ),
                              if (fromColleague)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.group_rounded,
                                        size: 14,
                                        color: colors.accent.solid,
                                      ),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          l.annualPlanSharedBy(
                                            plan.teacher ?? '',
                                          ),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: colors.accent.solid,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (plan.shared)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    l.annualPlanShared,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colors.mutedText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: colors.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// One plan, week by week, scrolled to the current week.
class PlanWeeksPage extends StatefulWidget {
  const PlanWeeksPage({
    super.key,
    required this.api,
    required this.plan,
    this.today,
  });

  final LessonPlansApi api;
  final LessonPlan plan;
  final DateTime? today;

  @override
  State<PlanWeeksPage> createState() => _PlanWeeksPageState();
}

class _PlanWeeksPageState extends State<PlanWeeksPage> {
  late Future<LessonPlan> _plan = widget.api.load(widget.plan.id);
  final _currentKey = GlobalKey();
  bool _scrolled = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final today = widget.today ?? DateTime.now();
    final dates = DateFormat('d MMM', locale);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.plan.title),
        backgroundColor: colors.card,
        surfaceTintColor: Colors.transparent,
      ),
      body: FutureBuilder<LessonPlan>(
        future: _plan,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final plan = snapshot.data;
          if (snapshot.hasError || plan == null) {
            return _Centered(
              text: l.annualPlansFailed,
              action: OutlinedButton(
                onPressed: () =>
                    setState(() => _plan = widget.api.load(widget.plan.id)),
                child: Text(l.retry),
              ),
            );
          }
          if (plan.weeks.isEmpty) return _Centered(text: l.annualPlanNoWeeks);
          final current = plan.weeks.indexWhere((w) => w.contains(today));
          if (current >= 0 && !_scrolled) {
            _scrolled = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final target = _currentKey.currentContext;
              if (target != null && target.mounted) {
                Scrollable.ensureVisible(target, alignment: 0.05);
              }
            });
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < plan.weeks.length; i++)
                  _WeekCard(
                    key: i == current ? _currentKey : null,
                    week: plan.weeks[i],
                    current: i == current,
                    dates: dates,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({
    super.key,
    required this.week,
    required this.current,
    required this.dates,
  });

  final PlanWeekRow week;
  final bool current;
  final DateFormat dates;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final range = [
      if (week.start != null) dates.format(week.start!),
      if (week.end != null) dates.format(week.end!),
    ].join(' – ');

    Widget list(String label, List<String> items) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: colors.mutedText,
            ),
          ),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('• $item', style: const TextStyle(fontSize: 13)),
            ),
        ],
      ),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: current ? colors.softBg : colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: current ? colors.accent.solid : colors.line,
          width: current ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: current ? colors.accent.solid : colors.softBg,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'W${week.weekNo}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: current ? Colors.white : colors.accent.solid,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  range,
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ),
              if (current)
                Text(
                  l.annualPlanThisWeek,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: colors.accent.solid,
                  ),
                ),
            ],
          ),
          if (week.topic != null) ...[
            const SizedBox(height: 6),
            Text(
              week.topic!,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ],
          if (week.unit != null)
            Text(
              week.unit!,
              style: TextStyle(fontSize: 12, color: colors.mutedText),
            ),
          if (week.objectives.isNotEmpty)
            list(l.annualPlanObjectives, week.objectives),
          if (week.homework.isNotEmpty)
            list(l.annualPlanHomework, week.homework),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  const _Centered({required this.text, this.action});

  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: appColorsOf(context).mutedText),
          ),
          if (action != null) ...[const SizedBox(height: 10), action!],
        ],
      ),
    ),
  );
}
