import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/lesson_tags.dart';
import '../../lessons/domain/lessons_repository.dart';
import '../application/home_tile_order.dart';
import '../application/next_lesson_day.dart';
import '../domain/app_items.dart';

const _tabular = [FontFeature.tabularFigures()];
const _nowRed = Color(0xFFEF4444);

IconData appIcon(AppItem item) => switch (item) {
  AppItem.lessons => Icons.assignment_rounded,
  AppItem.myClass => Icons.groups_rounded,
  AppItem.grades => Icons.school_rounded,
  AppItem.behavior => Icons.warning_amber_rounded,
  AppItem.teachingTools => Icons.interests_rounded,
  AppItem.myPlan => Icons.edit_note_rounded,
  AppItem.myPoints => Icons.emoji_events_rounded,
  AppItem.myFundings => Icons.account_balance_wallet_rounded,
  AppItem.exams => Icons.description_rounded,
  AppItem.timetable => Icons.calendar_month_rounded,
  AppItem.rewards => Icons.card_giftcard_rounded,
  AppItem.colleagues => Icons.contact_phone_rounded,
  AppItem.pointReport => Icons.bar_chart_rounded,
  AppItem.calendar => Icons.event_note_rounded,
  AppItem.myLessonAnalysis => Icons.workspace_premium_rounded,
  AppItem.lessonAnalysis => Icons.fact_check_rounded,
  AppItem.myDepartment => Icons.account_tree_rounded,
  AppItem.substitutions => Icons.swap_horiz_rounded,
  AppItem.attendanceCheck => Icons.how_to_reg_rounded,
  AppItem.cashier => Icons.point_of_sale_rounded,
  AppItem.staffPoints => Icons.auto_awesome_rounded,
  AppItem.fundings => Icons.savings_rounded,
};

String appLabel(AppLocalizations l, AppItem item, {bool short = false}) =>
    switch (item) {
      AppItem.lessons => short ? l.schedule : l.mySchedule,
      AppItem.myClass => short ? l.classShort : l.myClass,
      AppItem.grades => l.grades,
      AppItem.behavior => short ? l.reportShort : l.reportStudent,
      AppItem.teachingTools => short ? l.teachingShort : l.teachingTools,
      AppItem.myPlan => l.myPlan,
      AppItem.myPoints => l.myPoints,
      AppItem.myFundings => l.myFundings,
      AppItem.exams => l.exams,
      AppItem.timetable => l.timetable,
      AppItem.rewards => l.rewards,
      AppItem.colleagues => l.colleagues,
      AppItem.pointReport => l.pointReport,
      AppItem.calendar => l.calendar,
      AppItem.myLessonAnalysis =>
        short ? l.myAnalysisShort : l.myLessonAnalysis,
      AppItem.lessonAnalysis => l.lessonAnalysis,
      AppItem.myDepartment => l.myDepartment,
      AppItem.substitutions => l.substitutions,
      AppItem.attendanceCheck => l.attendanceCheck,
      AppItem.cashier => l.cashier,
      AppItem.staffPoints => l.staffPoints,
      AppItem.fundings => l.fundings,
    };

/// One colour per app wherever its icon shows, so teachers learn "the green
/// one". The same hues as the web's `appColors.js`.
class AppHue {
  const AppHue(this.soft, this.strong);

  final Color soft;
  final Color strong;
}

AppHue appHue(BuildContext context, AppItem item) {
  final (light, dark, tint) = switch (item) {
    AppItem.lessons => (0xFF0284C7, 0xFF38BDF8, 0xFFF0F9FF),
    AppItem.myClass => (0xFF7C3AED, 0xFFA78BFA, 0xFFF5F3FF),
    AppItem.grades => (0xFF059669, 0xFF34D399, 0xFFECFDF5),
    AppItem.behavior => (0xFFEA580C, 0xFFFB923C, 0xFFFFF7ED),
    AppItem.teachingTools => (0xFFC026D3, 0xFFE879F9, 0xFFFDF4FF),
    AppItem.myPlan => (0xFF2563EB, 0xFF60A5FA, 0xFFEFF6FF),
    AppItem.myFundings => (0xFF059669, 0xFF34D399, 0xFFECFDF5),
    AppItem.myPoints => (0xFFD97706, 0xFFFBBF24, 0xFFFFFBEB),
    AppItem.exams => (0xFFE11D48, 0xFFFB7185, 0xFFFFF1F2),
    AppItem.timetable => (0xFF0D9488, 0xFF2DD4BF, 0xFFF0FDFA),
    AppItem.colleagues => (0xFF4F46E5, 0xFF818CF8, 0xFFEEF2FF),
    AppItem.rewards ||
    AppItem.pointReport => (0xFFD97706, 0xFFFBBF24, 0xFFFFFBEB),
    AppItem.calendar => (0xFF0891B2, 0xFF22D3EE, 0xFFECFEFF),
    AppItem.myLessonAnalysis ||
    AppItem.lessonAnalysis => (0xFF9333EA, 0xFFC084FC, 0xFFFAF5FF),
    AppItem.myDepartment => (0xFF4F46E5, 0xFF818CF8, 0xFFEEF2FF),
    AppItem.substitutions => (0xFF0D9488, 0xFF2DD4BF, 0xFFF0FDFA),
    AppItem.attendanceCheck => (0xFF16A34A, 0xFF4ADE80, 0xFFF0FDF4),
    AppItem.cashier => (0xFF059669, 0xFF34D399, 0xFFECFDF5),
    AppItem.staffPoints => (0xFFD97706, 0xFFFBBF24, 0xFFFFFBEB),
    AppItem.fundings => (0xFF059669, 0xFF34D399, 0xFFECFDF5),
  };
  if (Theme.of(context).brightness == Brightness.dark) {
    return AppHue(Color(dark).withValues(alpha: 0.16), Color(dark));
  }
  return AppHue(Color(tint), Color(light));
}

BoxDecoration _cardDecoration(BuildContext context) {
  final colors = appColorsOf(context);
  final dark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: colors.card,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: colors.line),
    boxShadow: [
      BoxShadow(
        color: Color(dark ? 0x33000000 : 0x14000000),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

/// A teacher's landing page, like the web's `TeacherHome`: today's lessons up
/// front, their class and grades as large cards, the rest as small tiles.
class TeacherHome extends StatelessWidget {
  const TeacherHome({
    super.key,
    required this.header,
    required this.access,
    required this.onOpen,
    required this.onOpenDay,
    required this.onOpenGradebook,
    this.today,
    this.homeroom,
    this.recentGrades,
    this.updates,
    this.userId,
    this.tileOrder,
    this.scheduleKey,
    this.tilesKey,
  });

  final Widget header;
  final AppAccess access;
  final ValueChanged<AppItem> onOpen;
  final ValueChanged<DateTime> onOpenDay;

  /// Opens the gradebooks, on one class and subject when a row was tapped.
  final void Function(RecentGrade? row) onOpenGradebook;
  final NextLessonDayLoader? today;

  /// Short class name, e.g. "9B". Null for someone with no class.
  final String? homeroom;

  /// Null while loading.
  final List<RecentGrade>? recentGrades;

  /// The rolling Updates card, beside the class card.
  final Widget? updates;

  /// Whose tile order to use; null keeps the default order.
  final Object? userId;

  /// Where the tile order is kept. Tests pass their own.
  final HomeTileOrder? tileOrder;

  /// Where the product tour points for today's schedule and the tiles.
  final GlobalKey? scheduleKey;
  final GlobalKey? tilesKey;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loader = today;
    final showClass = access.allows(AppItem.myClass) && homeroom != null;
    final showGrades = access.allows(AppItem.grades) && loader != null;
    final tiles = access.smallTiles;
    final cards = <Widget>[
      if (showClass)
        _ClassCard(
          name: homeroom!,
          label: l.myClass,
          onTap: () => onOpen(AppItem.myClass),
        ),
      ?updates,
      if (showGrades)
        _GradesCard(
          label: l.grades,
          recent: recentGrades,
          onOpen: onOpenGradebook,
        ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: 12),
          if (loader != null && access.allows(AppItem.lessons)) ...[
            KeyedSubtree(
              key: scheduleKey,
              child: _TodayCard(
                loader: loader,
                label: l.mySchedule,
                onOpenDay: onOpenDay,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Class, Updates and Grades in rows of two equal halves, so
          // Updates is the size of the class card; a lone last one spans the
          // row.
          for (var i = 0; i < cards.length; i += 2) ...[
            SizedBox(
              height: 136,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: cards[i]),
                  if (i + 1 < cards.length) ...[
                    const SizedBox(width: 12),
                    Expanded(child: cards[i + 1]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          KeyedSubtree(
            key: tilesKey,
            child: _TileGrid(
              tiles: tiles,
              onOpen: onOpen,
              userId: userId,
              order: tileOrder,
            ),
          ),
        ],
      ),
    );
  }
}

/// The red "now" line, like a calendar's.
class _NowLine extends StatelessWidget {
  const _NowLine({required this.now, this.label = true});

  final String now;
  final bool label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (label)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: _nowRed,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              now,
              style: const TextStyle(
                fontSize: 10,
                height: 1.6,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontFeatures: _tabular,
              ),
            ),
          ),
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: _nowRed,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(child: Container(height: 2, color: _nowRed)),
      ],
    );
  }
}

int _minutes(String clock) =>
    (int.tryParse(clock.substring(0, 2)) ?? 0) * 60 +
    (int.tryParse(clock.substring(3, 5)) ?? 0);

/// The day's lessons, compact: the current one stands out, past ones fade. On
/// a day off it shows the next day that has lessons.
class _TodayCard extends StatefulWidget {
  const _TodayCard({
    required this.loader,
    required this.label,
    required this.onOpenDay,
  });

  final NextLessonDayLoader loader;
  final String label;
  final ValueChanged<DateTime> onOpenDay;

  @override
  State<_TodayCard> createState() => _TodayCardState();
}

class _TodayCardState extends State<_TodayCard> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    widget.loader.refreshIfStale();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      widget.loader.refreshIfStale();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.loader,
      builder: (context, _) => _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    final colors = appColorsOf(context);
    final locale = Localizations.localeOf(context).toString();
    final hue = appHue(context, AppItem.lessons);
    final result = widget.loader.result;
    final current = widget.loader.now;
    final now = clockText(current);
    final day =
        result?.day ?? DateTime(current.year, current.month, current.day);
    final isToday = day == DateTime(current.year, current.month, current.day);
    final items = result?.items;
    final done = items != null && isToday
        ? items.where((item) => item.end.compareTo(now) <= 0).length
        : 0;

    var nowIndex = -1;
    if (items != null && items.isNotEmpty && isToday) {
      nowIndex = items.indexWhere((item) => now.compareTo(item.end) < 0);
      if (nowIndex == -1) nowIndex = items.length;
    }

    return Container(
      decoration: _cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => widget.onOpenDay(day),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    _IconBadge(hue: hue, icon: Icons.event_available_rounded),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            DateFormat('EEE, d MMM', locale).format(day),
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.mutedText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (items != null && items.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.softBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          isToday ? '$done/${items.length}' : '${items.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            fontFeatures: _tabular,
                          ),
                        ),
                      ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.mutedText,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (items == null)
                  for (var i = 0; i < 3; i++)
                    Container(
                      height: 30,
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: colors.softBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Icon(
                      Icons.coffee_rounded,
                      size: 28,
                      color: colors.mutedText,
                    ),
                  )
                else ...[
                  for (var i = 0; i < items.length; i++)
                    _lessonRow(context, items[i], i, nowIndex, isToday, now),
                  if (nowIndex == items.length) _NowLine(now: now),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _lessonRow(
    BuildContext context,
    TodayItem item,
    int index,
    int nowIndex,
    bool isToday,
    String now,
  ) {
    final colors = appColorsOf(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final current =
        isToday &&
        item.start.compareTo(now) <= 0 &&
        now.compareTo(item.end) < 0;
    final past = isToday && item.end.compareTo(now) <= 0;
    final text = current
        ? Colors.white
        : past
        ? colors.mutedText.withValues(alpha: 0.7)
        : onSurface;

    final row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: current ? colors.accent.solid : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              item.start,
              style: TextStyle(
                fontSize: 13,
                color: text,
                fontWeight: current ? FontWeight.w600 : FontWeight.w400,
                fontFeatures: _tabular,
              ),
            ),
          ),
          if (item.classLabel.isNotEmpty) ...[
            ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 38, maxWidth: 104),
              child: Text(
                item.classLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              item.isLunchDuty
                  ? AppLocalizations.of(context).lunchDuty
                  : item.subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: text),
            ),
          ),
          LessonTags(tags: item.tags, onDark: current),
          if (item.room != null && item.room!.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              item.room!,
              style: TextStyle(
                fontSize: 12,
                color: current
                    ? Colors.white.withValues(alpha: 0.8)
                    : colors.mutedText,
              ),
            ),
          ],
        ],
      ),
    );

    final hasTimes = item.start.length == 5 && item.end.length == 5;
    final progress = current && hasTimes
        ? ((_minutes(now) - _minutes(item.start)) /
                  (_minutes(item.end) - _minutes(item.start)).clamp(1, 1440))
              .clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (index == nowIndex && !current)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: _NowLine(now: now),
            ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              row,
              if (current)
                Positioned.fill(
                  left: -4,
                  child: IgnorePointer(
                    child: Align(
                      alignment: Alignment(0, progress * 2 - 1),
                      child: _NowLine(now: now, label: false),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.hue, required this.icon, this.size = 34});

  final AppHue hue;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: hue.soft,
        borderRadius: BorderRadius.circular(size * 0.35),
      ),
      child: Icon(icon, size: size * 0.56, color: hue.strong),
    );
  }
}

class _ClassCard extends StatelessWidget {
  const _ClassCard({
    required this.name,
    required this.label,
    required this.onTap,
  });

  final String name;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _IconBadge(
                  hue: appHue(context, AppItem.myClass),
                  icon: appIcon(AppItem.myClass),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 28,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: appColorsOf(context).mutedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The latest graded lessons with their class average. A row opens that class
/// and subject's gradebook.
class _GradesCard extends StatelessWidget {
  const _GradesCard({
    required this.label,
    required this.recent,
    required this.onOpen,
  });

  final String label;
  final List<RecentGrade>? recent;
  final void Function(RecentGrade? row) onOpen;

  (Color, Color) _tone(BuildContext context, double average) {
    final colors = appColorsOf(context);
    final color = average >= 85
        ? const Color(0xFF10B981)
        : average >= 60
        ? null
        : average >= 40
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);
    if (color == null) {
      return (colors.softBg, Theme.of(context).colorScheme.onSurface);
    }
    return (color.withValues(alpha: 0.16), color);
  }

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final rows = recent;
    final card = Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconBadge(
                hue: appHue(context, AppItem.grades),
                icon: appIcon(AppItem.grades),
                size: 30,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (rows == null)
            for (var i = 0; i < 3; i++)
              Container(
                height: 20,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: colors.softBg,
                  borderRadius: BorderRadius.circular(6),
                ),
              )
          else
            for (final row in rows.take(3))
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onOpen(row),
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Row(
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          maxWidth: 70,
                        ),
                        child: Text(
                          row.classLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          row.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.mutedText,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Builder(
                        builder: (context) {
                          final (soft, strong) = _tone(context, row.average);
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5),
                            decoration: BoxDecoration(
                              color: soft,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '${row.average.round()}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: strong,
                                fontFeatures: _tabular,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onOpen(null),
      child: card,
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({required this.item, this.onTap});

  final AppItem item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      decoration: _cardDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _IconBadge(hue: appHue(context, item), icon: appIcon(item)),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    appLabel(l, item, short: true),
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: appColorsOf(context).mutedText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The small tiles. Holding one (like a phone's home screen) makes them all
/// wiggle and lifts it into a drag; dropping it over another tile moves it
/// there. Done ends it, Reset goes back to the default order. The order is
/// saved per user on this phone (see [HomeTileOrder]).
class _TileGrid extends StatefulWidget {
  const _TileGrid({
    required this.tiles,
    required this.onOpen,
    this.userId,
    this.order,
  });

  final List<AppItem> tiles;
  final ValueChanged<AppItem> onOpen;
  final Object? userId;
  final HomeTileOrder? order;

  @override
  State<_TileGrid> createState() => _TileGridState();
}

class _TileGridState extends State<_TileGrid>
    with SingleTickerProviderStateMixin {
  late final HomeTileOrder _order = widget.order ?? HomeTileOrder();
  late final AnimationController _jiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  List<String>? _saved;
  List<AppItem>? _draft;
  bool _editing = false;

  List<AppItem> get _shown => _draft ?? sortTiles(widget.tiles, _saved);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TileGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _load();
  }

  @override
  void dispose() {
    _jiggle.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = widget.userId;
    if (user == null) return;
    List<String>? saved;
    try {
      saved = await _order.load(user);
    } catch (_) {
      return; // No storage (some tests): keep the default order.
    }
    if (!mounted || user != widget.userId) return;
    setState(() => _saved = saved);
  }

  Future<void> _save(List<AppItem>? order) async {
    final user = widget.userId;
    if (user == null) return;
    try {
      await _order.save(user, order);
    } catch (_) {
      // Not saved: the order still holds until the app restarts.
    }
  }

  void _startEditing() {
    if (_editing) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _editing = true;
      _draft = List.of(_shown);
    });
    _jiggle.repeat(reverse: true);
  }

  void _finish() {
    _jiggle
      ..stop()
      ..value = 0.5;
    setState(() {
      _editing = false;
      if (_draft != null) _saved = [for (final i in _draft!) i.name];
      _draft = null;
    });
  }

  void _reset() {
    unawaited(_save(null));
    setState(() {
      _saved = null;
      _draft = List.of(widget.tiles);
    });
  }

  void _move(AppItem dragged, AppItem over) {
    final list = _draft;
    if (list == null || dragged == over) return;
    final from = list.indexOf(dragged);
    final to = list.indexOf(over);
    if (from < 0 || to < 0) return;
    setState(() {
      list
        ..removeAt(from)
        ..insert(to, dragged);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tiles = _shown;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 100,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            final item = tiles[index];
            return LayoutBuilder(
              builder: (context, box) {
                final tile = _SmallTile(
                  item: item,
                  // While rearranging a tap opens nothing.
                  onTap: _editing ? null : () => widget.onOpen(item),
                );
                // Neighbours wiggle in opposite directions, like a phone's.
                final turns = Tween<double>(
                  begin: index.isEven ? -0.006 : 0.006,
                  end: index.isEven ? 0.006 : -0.006,
                ).animate(_jiggle);
                return DragTarget<AppItem>(
                  onWillAcceptWithDetails: (details) {
                    _move(details.data, item);
                    return true;
                  },
                  onAcceptWithDetails: (_) =>
                      unawaited(_save(List.of(_draft ?? tiles))),
                  builder: (context, _, _) => LongPressDraggable<AppItem>(
                    key: ValueKey('tile-${item.name}'),
                    data: item,
                    // Held to start; once rearranging, a short press drags.
                    delay: Duration(milliseconds: _editing ? 120 : 400),
                    onDragStarted: _startEditing,
                    onDraggableCanceled: (_, _) =>
                        unawaited(_save(List.of(_draft ?? tiles))),
                    feedback: SizedBox(
                      width: box.maxWidth,
                      height: box.maxHeight,
                      child: Transform.scale(
                        scale: 1.08,
                        child: Material(
                          type: MaterialType.transparency,
                          child: _SmallTile(item: item),
                        ),
                      ),
                    ),
                    childWhenDragging: Opacity(opacity: 0, child: tile),
                    child: _editing
                        ? RotationTransition(turns: turns, child: tile)
                        : tile,
                  ),
                );
              },
            );
          },
        ),
        // Below the tiles, so they don't jump while one is held.
        if (_editing)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  key: const ValueKey('tiles-reset'),
                  onPressed: _reset,
                  child: Text(l.reset),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  key: const ValueKey('tiles-done'),
                  onPressed: _finish,
                  child: Text(l.done),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
