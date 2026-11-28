import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/tab_back.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../lessons/domain/lessons_repository.dart';
import '../../lessons/presentation/attendance_step.dart' show TeamMark;
import '../../me/presentation/period_bar.dart';
import '../domain/team_shuffle.dart';

const _lastClassKey = 'teaching-tools:class';
const _rolesKey = 'teaching-tools:roles';
String _historyKey(String cls) => 'teaching-tools:teams:$cls';

const _teamColors = [
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
  Color(0xFF22C55E),
  Color(0xFFEAB308),
  Color(0xFFA855F7),
  Color(0xFFF97316),
  Color(0xFFEC4899),
  Color(0xFF14B8A6),
];

const _roleIcons = <String, IconData>{
  'leader': Icons.workspace_premium_rounded,
  'timekeeper': Icons.timer_rounded,
  'recorder': Icons.edit_rounded,
  'reporter': Icons.campaign_rounded,
  'checker': Icons.done_all_rounded,
  'encourager': Icons.favorite_rounded,
  'materials': Icons.inventory_2_rounded,
  'questioner': Icons.help_rounded,
  'helper': Icons.front_hand_rounded,
};

int _byClassName(String a, String b) {
  final left = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '');
  final right = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '');
  if (left != null && right != null && left != right) {
    return left.compareTo(right);
  }
  return a.compareTo(b);
}

enum _Tool { teams, picker, timer }

/// Team Shuffle, Name Picker and Timer. Nothing here reaches the server except
/// reading the class lists and today's lessons (for the class on now).
class TeachingToolsPage extends StatefulWidget {
  const TeachingToolsPage({
    super.key,
    required this.repository,
    this.bottomInset = 0,
    this.random,
    this.clock = DateTime.now,
    this.gradeWithTeams,
  });

  final LessonsRepository repository;

  /// Opens [lesson]'s grading sheet with its students grouped and coloured by
  /// team (student id → team). Absent where grading can't open.
  final void Function(TeacherLesson lesson, Map<int, TeamMark> teams)?
  gradeWithTeams;
  final double bottomInset;
  final Random? random;
  final DateTime Function() clock;

  @override
  State<TeachingToolsPage> createState() => _TeachingToolsPageState();
}

class _TeachingToolsPageState extends State<TeachingToolsPage> {
  _Tool? _tool;
  BehaviorRoster? _roster;
  bool _failed = false;

  /// The lesson being taught right now, if any: Team Shuffle picks its class
  /// and can carry the teams into its grading sheet.
  TeacherLesson? _nowLesson;

  @override
  void initState() {
    super.initState();
    _load();
    _findNowLesson();
  }

  Future<void> _findNowLesson() async {
    try {
      final now = widget.clock();
      final day = await widget.repository.getDay(now);
      final lesson = currentLesson(day.lessons, now);
      if (mounted && lesson != null) setState(() => _nowLesson = lesson);
    } catch (_) {
      // No class marked as now.
    }
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final roster = await widget.repository.getBehaviorRoster();
      if (mounted) setState(() => _roster = roster);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  String _toolLabel(AppLocalizations l, _Tool tool) => switch (tool) {
    _Tool.teams => l.teamShuffle,
    _Tool.picker => l.namePicker,
    _Tool.timer => l.timer,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final tool = _tool;
    return TabBackHandler(
      onBack: () {
        if (_tool == null) return false;
        setState(() => _tool = null);
        return true;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 6, 16, 2),
            child: Row(
              children: [
                if (tool != null)
                  IconButton(
                    tooltip: l.back,
                    onPressed: () => setState(() => _tool = null),
                    icon: const Icon(Icons.arrow_back_rounded, size: 20),
                  )
                else
                  const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tool == null ? l.teachingTools : _toolLabel(l, tool),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: switch (tool) {
              null => _hub(context, l),
              _Tool.timer => ClassTimerTool(
                clock: widget.clock,
                bottomInset: widget.bottomInset,
              ),
              _ when _failed && _roster == null => RetryBanner(onRetry: _load),
              _ when _roster == null => const Center(
                child: CircularProgressIndicator(),
              ),
              _Tool.teams => _TeamShuffleTool(
                roster: _roster!,
                random: widget.random,
                bottomInset: widget.bottomInset,
                nowLesson: _nowLesson,
                gradeWithTeams: widget.gradeWithTeams,
              ),
              _Tool.picker => _NamePickerTool(
                roster: _roster!,
                random: widget.random,
                bottomInset: widget.bottomInset,
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _hub(BuildContext context, AppLocalizations l) {
    final tiles = <(String, IconData, _Tool?)>[
      (l.teamShuffle, Icons.shuffle_rounded, _Tool.teams),
      (l.namePicker, Icons.casino_rounded, _Tool.picker),
      (l.timer, Icons.timer_rounded, _Tool.timer),
      (l.participation, Icons.front_hand_rounded, null),
      (l.homeworkCheck, Icons.edit_note_rounded, null),
      (l.balancedTeams, Icons.balance_rounded, null),
      (l.seatingPlan, Icons.grid_view_rounded, null),
    ];
    final colors = appColorsOf(context);
    return GridView.builder(
      padding: EdgeInsets.fromLTRB(16, 6, 16, widget.bottomInset + 8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 124,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, index) {
        final (label, icon, tool) = tiles[index];
        return Opacity(
          opacity: tool == null ? 0.5 : 1,
          child: Material(
            color: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: colors.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: tool == null ? null : () => setState(() => _tool = tool),
              child: Stack(
                children: [
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 28, color: colors.accent.ring),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (tool == null)
                    Positioned(
                      top: 6,
                      right: 8,
                      child: Text(
                        l.soon,
                        style: TextStyle(fontSize: 10, color: colors.mutedText),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The class chosen for a tool, remembered between visits, and who is away.
mixin _ClassChoice<T extends StatefulWidget> on State<T> {
  BehaviorRoster get roster;

  /// The class on now: listed first with a dot. Only Team Shuffle sets it.
  String? get nowClass => null;

  String _picked = '';
  final Set<String> absent = {};

  late final Map<String, List<ToolStudent>> byClass = () {
    final map = <String, List<ToolStudent>>{};
    for (final student in roster.students) {
      (map[student.className] ??= []).add(
        ToolStudent(id: student.id, name: student.fullName),
      );
    }
    for (final list in map.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }
    return map;
  }();

  List<String> get ownClasses =>
      roster.myClasses.where(byClass.containsKey).toList();

  /// The class on now, then their own classes, then the rest.
  List<String> get classes {
    final own = ownClasses;
    final now = byClass.containsKey(nowClass) ? nowClass : null;
    return [
      ?now,
      ...own.where((name) => name != now),
      ...byClass.keys
          .where((name) => !own.contains(name) && name != now)
          .toList()
        ..sort(_byClassName),
    ];
  }

  String get className =>
      byClass.containsKey(_picked) ? _picked : (classes.firstOrNull ?? '');

  List<ToolStudent> get students => byClass[className] ?? const [];

  List<ToolStudent> get present =>
      students.where((s) => !absent.contains(s.id)).toList();

  Future<void> restoreClass() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_lastClassKey);
      if (mounted && saved != null) setState(() => _picked = saved);
    } catch (_) {
      // Falls back to their first class.
    }
  }

  void pickClass(String name) {
    _picked = name;
    absent.clear();
    unawaited(_remember(name));
  }

  Future<void> _remember(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastClassKey, name);
    } catch (_) {
      // Just not remembered.
    }
  }

  Widget classChips(ValueChanged<String> onPick) {
    final own = ownClasses;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final name in classes)
            PillChip(
              label: name,
              selected: name == className,
              soft: own.contains(name),
              onTap: () => onPick(name),
              leading: name == nowClass
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

/// Who's here: tap a name to mark them away.
class _PresenceList extends StatelessWidget {
  const _PresenceList({
    required this.students,
    required this.absent,
    required this.onToggle,
    required this.open,
    required this.onOpenChanged,
  });

  final List<ToolStudent> students;
  final Set<String> absent;
  final ValueChanged<String> onToggle;
  final bool open;
  final ValueChanged<bool> onOpenChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => onOpenChanged(!open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.person_off_rounded,
                  size: 16,
                  color: colors.mutedText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${students.length - absent.length}/${students.length}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabularFigures,
                    ),
                  ),
                ),
                Text(
                  open ? l.done : l.absentQuestion,
                  style: TextStyle(fontSize: 12, color: colors.accent.ring),
                ),
              ],
            ),
          ),
        ),
        if (open)
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final student in students)
                _name(student, absent.contains(student.id), colors),
            ],
          ),
      ],
    );
  }

  Widget _name(ToolStudent student, bool away, AppColors colors) {
    return GestureDetector(
      onTap: () => onToggle(student.id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: away ? negativeRed.withValues(alpha: 0.16) : colors.softBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          student.name,
          style: TextStyle(
            fontSize: 12,
            color: away ? negativeRed : null,
            decoration: away ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

class _NamePickerTool extends StatefulWidget {
  const _NamePickerTool({
    required this.roster,
    required this.bottomInset,
    this.random,
  });

  final BehaviorRoster roster;
  final double bottomInset;
  final Random? random;

  @override
  State<_NamePickerTool> createState() => _NamePickerToolState();
}

class _NamePickerToolState extends State<_NamePickerTool>
    with _ClassChoice<_NamePickerTool> {
  static const _spin = Duration(milliseconds: 1400);

  @override
  BehaviorRoster get roster => widget.roster;

  late final Random _dice = widget.random ?? Random();
  List<String> _pickedIds = const [];
  String? _shown;
  bool _spinning = false;
  bool _presenceOpen = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    restoreClass();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _reset() {
    _timer?.cancel();
    _pickedIds = const [];
    _shown = null;
    _spinning = false;
  }

  void _pick() {
    final people = present;
    final next = pickNext(people, _pickedIds, random: _dice);
    if (next == null) return;
    final (winner, picked) = next;
    setState(() {
      _spinning = true;
      _presenceOpen = false;
    });
    var elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 70), (timer) {
      elapsed += const Duration(milliseconds: 70);
      if (elapsed >= _spin) {
        timer.cancel();
        HapticFeedback.mediumImpact();
        setState(() {
          _shown = winner.name;
          _pickedIds = picked;
          _spinning = false;
        });
      } else {
        setState(() => _shown = people[_dice.nextInt(people.length)].name);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final people = present;
    final left = people.where((s) => !_pickedIds.contains(s.id)).length;
    final names = {for (final s in students) s.id: s.name};

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, widget.bottomInset + 8),
      children: [
        classChips(
          (name) => setState(() {
            pickClass(name);
            _reset();
          }),
        ),
        if (className.isNotEmpty)
          _PresenceList(
            students: students,
            absent: absent,
            open: _presenceOpen,
            onOpenChanged: (open) => setState(() => _presenceOpen = open),
            onToggle: (id) => setState(
              () => absent.contains(id) ? absent.remove(id) : absent.add(id),
            ),
          ),
        const SizedBox(height: 4),
        Material(
          color: colors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: colors.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _spinning || people.isEmpty ? null : _pick,
            child: SizedBox(
              height: 220,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_shown == null)
                      Icon(
                        Icons.casino_rounded,
                        size: 56,
                        color: colors.accent.ring,
                      )
                    else
                      Text(
                        _shown!,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        style: TextStyle(
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: _spinning
                              ? colors.mutedText
                              : colors.accent.ring,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      '$left/${people.length}',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.mutedText,
                        fontFeatures: tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_pickedIds.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (var i = 0; i < _pickedIds.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.softBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '${i + 1}  ${names[_pickedIds[i]] ?? ''}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.startOver,
                visualDensity: VisualDensity.compact,
                onPressed: () => setState(_reset),
                icon: const Icon(Icons.replay_rounded, size: 18),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TeamShuffleTool extends StatefulWidget {
  const _TeamShuffleTool({
    required this.roster,
    required this.bottomInset,
    this.random,
    this.nowLesson,
    this.gradeWithTeams,
  });

  final BehaviorRoster roster;
  final double bottomInset;
  final Random? random;
  final TeacherLesson? nowLesson;
  final void Function(TeacherLesson lesson, Map<int, TeamMark> teams)?
  gradeWithTeams;

  @override
  State<_TeamShuffleTool> createState() => _TeamShuffleToolState();
}

class _TeamShuffleToolState extends State<_TeamShuffleTool>
    with _ClassChoice<_TeamShuffleTool> {
  @override
  BehaviorRoster get roster => widget.roster;

  @override
  String? get nowClass => widget.nowLesson?.classLabel;

  int _count = 4;
  List<Team>? _teams;
  bool _presenceOpen = true;
  bool _rolesOn = true;

  /// The class on now is picked once, over the remembered one, as on the web.
  bool _restored = false;
  bool _nowApplied = false;

  @override
  void initState() {
    super.initState();
    restoreClass().whenComplete(() {
      _restored = true;
      _applyNow();
    });
    _restoreRoles();
  }

  @override
  void didUpdateWidget(_TeamShuffleTool old) {
    super.didUpdateWidget(old);
    if (old.nowLesson != widget.nowLesson) _applyNow();
  }

  void _applyNow() {
    final now = nowClass;
    if (!mounted || !_restored || _nowApplied) return;
    if (now == null || !byClass.containsKey(now)) return;
    _nowApplied = true;
    setState(() => pickClass(now));
  }

  void _gradeWithTeams(List<Team> teams) {
    final lesson = widget.nowLesson!;
    final marks = <int, TeamMark>{
      for (var i = 0; i < teams.length; i++)
        for (final member in teams[i].members)
          ?int.tryParse(member.id): (color: _teamColors[i], order: i),
    };
    widget.gradeWithTeams!(lesson, marks);
  }

  Future<void> _restoreRoles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _rolesOn = prefs.getString(_rolesKey) != 'off');
      }
    } catch (_) {
      // Roles stay on.
    }
  }

  Future<void> _toggleRoles() async {
    setState(() => _rolesOn = !_rolesOn);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_rolesKey, _rolesOn ? 'on' : 'off');
    } catch (_) {
      // Just not remembered.
    }
  }

  int get _max => max(2, min(maxTeams, present.length));
  int get _teamCount => min(_count, _max);

  Future<void> _shuffle() async {
    final people = present;
    if (people.length < 2) return;
    final cls = className;
    final count = _teamCount;
    final rolesOn = _rolesOn;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Shuffles without remembering who was together.
    }
    final history = TeamHistory.decode(prefs?.getString(_historyKey(cls)));
    final teams = makeTeams(people, count, history, random: widget.random);
    if (!mounted) return;
    setState(() {
      _teams = teams;
      _presenceOpen = false;
    });
    try {
      await prefs?.setString(
        _historyKey(cls),
        afterShuffle(history, teams, rolesShown: rolesOn).encode(),
      );
    } catch (_) {
      // Just not remembered.
    }
  }

  String _roleLabel(AppLocalizations l, String role) => switch (role) {
    'leader' => l.roleLeader,
    'timekeeper' => l.roleTimekeeper,
    'recorder' => l.roleRecorder,
    'reporter' => l.roleReporter,
    'checker' => l.roleChecker,
    'encourager' => l.roleEncourager,
    'materials' => l.roleMaterials,
    'questioner' => l.roleQuestioner,
    _ => l.roleHelper,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final teams = _teams;
    final count = _teamCount;
    final teamNames = [
      l.teamRed,
      l.teamBlue,
      l.teamGreen,
      l.teamYellow,
      l.teamPurple,
      l.teamOrange,
      l.teamPink,
      l.teamTeal,
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, widget.bottomInset + 8),
      children: [
        classChips(
          (name) => setState(() {
            pickClass(name);
            _teams = null;
            _presenceOpen = true;
          }),
        ),
        if (className.isNotEmpty)
          _PresenceList(
            students: students,
            absent: absent,
            open: _presenceOpen,
            onOpenChanged: (open) => setState(() => _presenceOpen = open),
            onToggle: (id) => setState(() {
              absent.contains(id) ? absent.remove(id) : absent.add(id);
              _teams = null;
            }),
          ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton.filledTonal(
              tooltip: l.fewerTeams,
              onPressed: () => setState(() => _count = max(2, count - 1)),
              icon: const Icon(Icons.remove_rounded, size: 18),
            ),
            SizedBox(
              width: 30,
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  fontFeatures: tabularFigures,
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: l.moreTeams,
              onPressed: () => setState(() => _count = min(_max, count + 1)),
              icon: const Icon(Icons.add_rounded, size: 18),
            ),
            IconButton(
              tooltip: l.roles,
              onPressed: _toggleRoles,
              icon: Icon(
                Icons.workspace_premium_rounded,
                color: _rolesOn ? const Color(0xFFF59E0B) : colors.mutedText,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: SizedBox(
                height: 42,
                child: FilledButton.icon(
                  onPressed: present.length < 2 ? null : _shuffle,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.accent.solid,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.shuffle_rounded, size: 18),
                  label: Text(teams == null ? l.shuffle : l.again),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (teams != null)
          for (var i = 0; i < teams.length; i++)
            _teamCard(context, l, teams[i], teamNames[i], _teamColors[i]),
        if (teams != null &&
            widget.gradeWithTeams != null &&
            widget.nowLesson?.instanceId != null &&
            className == nowClass)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: colors.accent.solid,
                side: BorderSide(color: colors.accent.border),
                shape: const StadiumBorder(),
              ),
              onPressed: () => _gradeWithTeams(teams),
              icon: const Icon(Icons.fact_check_rounded, size: 18),
              label: Text(l.gradeWithTeams(className)),
            ),
          ),
      ],
    );
  }

  Widget _teamCard(
    BuildContext context,
    AppLocalizations l,
    Team team,
    String name,
    Color color,
  ) {
    final colors = appColorsOf(context);
    final members = _rolesOn ? team.byRole : team.members;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: color.withValues(alpha: 0.14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '${team.members.length}',
                  style: TextStyle(fontSize: 13, color: colors.mutedText),
                ),
              ],
            ),
          ),
          for (final student in members)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Row(
                children: [
                  if (_rolesOn) ...[
                    Icon(
                      _roleIcons[team.roles[student.id]],
                      size: 14,
                      color: team.roles[student.id] == 'leader'
                          ? const Color(0xFFF59E0B)
                          : colors.accent.ring,
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      student.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  if (_rolesOn)
                    Text(
                      _roleLabel(l, team.roles[student.id] ?? helperRole),
                      style: TextStyle(fontSize: 11, color: colors.mutedText),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

String formatClock(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
    '${(seconds % 60).toString().padLeft(2, '0')}';

/// A countdown for the board. It reads the clock instead of counting ticks, so
/// a phone that dozes off doesn't lose time.
class ClassTimerTool extends StatefulWidget {
  const ClassTimerTool({
    super.key,
    this.clock = DateTime.now,
    this.bottomInset = 0,
  });

  final DateTime Function() clock;
  final double bottomInset;

  @override
  State<ClassTimerTool> createState() => _ClassTimerToolState();
}

class _ClassTimerToolState extends State<ClassTimerTool> {
  static const _presets = [1, 2, 3, 5, 10, 15];

  int _total = 5 * 60;
  int _left = 5 * 60;
  bool _running = false;
  DateTime? _endsAt;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _set(int seconds) {
    final clamped = seconds.clamp(10, 99 * 60);
    _ticker?.cancel();
    setState(() {
      _running = false;
      _total = clamped;
      _left = clamped;
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _start() {
    final from = _left == 0 ? _total : _left;
    _endsAt = widget.clock().add(Duration(seconds: from));
    setState(() {
      _left = from;
      _running = true;
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
  }

  void _tick() {
    final remaining =
        (_endsAt!.difference(widget.clock()).inMilliseconds / 1000)
            .round()
            .clamp(0, 99 * 60);
    if (remaining == 0) {
      _ticker?.cancel();
      SystemSound.play(SystemSoundType.alert);
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _left = remaining;
      if (remaining == 0) _running = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final done = _left == 0;
    final share = _total == 0 ? 0.0 : _left / _total;

    Widget round(IconData icon, String tip, VoidCallback onTap) =>
        IconButton.filledTonal(
          tooltip: tip,
          iconSize: 22,
          onPressed: onTap,
          icon: Icon(icon),
        );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 4, 16, widget.bottomInset + 8),
      children: [
        Container(
          height: 240,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: done ? negativeRed.withValues(alpha: 0.14) : colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.line),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 250),
                    heightFactor: share,
                    widthFactor: 1,
                    child: ColoredBox(
                      color: colors.accent.solid.withValues(alpha: 0.22),
                    ),
                  ),
                ),
              ),
              Text(
                formatClock(_left),
                style: TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w700,
                  color: done ? negativeRed : null,
                  fontFeatures: tabularFigures,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_running) ...[
              round(
                Icons.remove_rounded,
                l.oneMinuteLess,
                () => _set(_total - 60),
              ),
              const SizedBox(width: 10),
            ],
            IconButton.filled(
              tooltip: _running ? l.pause : l.start,
              iconSize: 34,
              style: IconButton.styleFrom(
                backgroundColor: colors.accent.solid,
                foregroundColor: Colors.white,
              ),
              onPressed: _running ? _pause : _start,
              icon: Icon(
                _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              ),
            ),
            if (!_running) ...[
              const SizedBox(width: 10),
              round(
                Icons.add_rounded,
                l.oneMinuteMore,
                () => _set(_total + 60),
              ),
            ],
            const SizedBox(width: 10),
            round(Icons.replay_rounded, l.reset, () => _set(_total)),
          ],
        ),
        if (!_running) ...[
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            runSpacing: 6,
            children: [
              for (final minutes in _presets)
                PillChip(
                  label: l.minutesShort(minutes),
                  selected: _total == minutes * 60,
                  onTap: () => _set(minutes * 60),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
