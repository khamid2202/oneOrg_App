import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/tab_back.dart';
import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../lessons/application/lessons_outbox.dart';
import '../../lessons/domain/lessons_repository.dart';
import '../../../shared/app_toast.dart';
import '../../../shared/sub_page.dart' show confirmDialog, errorText;

const _emerald = Color(0xFF10B981);
const _rose = Color(0xFFF43F5E);
const _tabular = [FontFeature.tabularFigures()];

/// The server takes at most this many students in one request.
const maxStudentsPerRequest = 50;

Color _typeColor(String type) => type == behaviorPositive ? _emerald : _rose;
IconData _typeIcon(String type) =>
    type == behaviorPositive ? Icons.favorite_rounded : Icons.gpp_maybe_rounded;

const _reasonIcons = <String, IconData>{
  'cooperation': Icons.handshake_rounded,
  'helpfulness': Icons.volunteer_activism_rounded,
  'responsibility': Icons.verified_user_rounded,
  'initiative': Icons.lightbulb_rounded,
  'respect': Icons.sentiment_satisfied_rounded,
  'peacemaking': Icons.diversity_1_rounded,
  'mocking': Icons.feedback_rounded,
  'disruption': Icons.campaign_rounded,
  'fighting': Icons.sports_kabaddi_rounded,
  'disrespect': Icons.thumb_down_rounded,
  'property_damage': Icons.handyman_rounded,
  'rules': Icons.block_rounded,
  'speaking_uzbek': Icons.translate_rounded,
};

int _byClassName(String a, String b) {
  final left = int.tryParse(RegExp(r'^\d+').stringMatch(a) ?? '');
  final right = int.tryParse(RegExp(r'^\d+').stringMatch(b) ?? '');
  if (left != null && right != null && left != right) {
    return left.compareTo(right);
  }
  return a.compareTo(b);
}

enum _Section { mark, history, statistics }

/// Report Student, like the web's `BehaviorPage`: mark students in three
/// short steps, look through history, see the statistics.
class BehaviorPage extends StatefulWidget {
  const BehaviorPage({
    super.key,
    required this.repository,
    required this.outbox,
    this.bottomInset = 0,
    this.deleteMark,
  });

  final LessonsRepository repository;
  final LessonsOutbox outbox;
  final double bottomInset;

  /// Deletes a mark and its linked Dombit points; answers how many point
  /// records went with it. Null (no `behavior.delete`) hides the bin.
  final Future<int> Function(String markId)? deleteMark;

  @override
  State<BehaviorPage> createState() => _BehaviorPageState();
}

class _BehaviorPageState extends State<BehaviorPage> {
  _Section _section = _Section.mark;

  BehaviorRoster? _roster;
  BehaviorReasons _reasons = const BehaviorReasons();
  List<BehaviorHistoryEntry>? _history;
  BehaviorStatistics _statistics = const BehaviorStatistics();
  String? _from;
  String? _to;
  bool _failed = false;
  int _statisticsRequest = 0;
  late final StreamSubscription<int> _uploaded;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // History and statistics come from the server once the marks reach it.
    _uploaded = widget.outbox.uploaded.listen((id) {
      if (mounted &&
          id == LessonsOutbox.noLesson &&
          widget.outbox.waitingFor(id).isEmpty) {
        _loadHistory();
        _loadStatistics();
      }
    });
  }

  @override
  void dispose() {
    _uploaded.cancel();
    super.dispose();
  }

  void _loadAll() {
    setState(() => _failed = false);
    _loadRoster();
    _loadHistory();
    _loadStatistics();
  }

  Future<void> _loadRoster() async {
    try {
      final results = await Future.wait([
        widget.repository.getBehaviorRoster(),
        widget.repository.getBehaviorReasons(),
      ]);
      if (!mounted) return;
      setState(() {
        _roster = results[0] as BehaviorRoster;
        _reasons = results[1] as BehaviorReasons;
      });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.repository.getBehaviorHistory();
      if (mounted) setState(() => _history = history);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  /// The web's history bin: asks, deletes, then drops the row and refreshes
  /// the statistics the mark counted in.
  Future<void> _deleteMark(BehaviorHistoryEntry mark) async {
    final l = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.behaviorDeleteTitle,
      message: l.behaviorDeleteBody(mark.studentName),
      confirmLabel: l.behaviorDeleteConfirm,
      destructive: true,
    );
    if (!ok || !mounted) return;
    try {
      final points = await widget.deleteMark!(mark.id);
      if (!mounted) return;
      setState(
        () => _history = [
          for (final entry in _history ?? const <BehaviorHistoryEntry>[])
            if (entry.id != mark.id) entry,
        ],
      );
      _loadStatistics();
      showToast(
        context,
        points > 0 ? l.behaviorDeletedWithPoints(points) : l.behaviorDeleted,
        kind: ToastKind.success,
      );
    } catch (error) {
      if (mounted) {
        showToast(
          context,
          errorText(error, l.behaviorDeleteFailed),
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _loadStatistics() async {
    final request = ++_statisticsRequest;
    try {
      final statistics = await widget.repository.getBehaviorStatistics(
        from: _from,
        to: _to,
      );
      if (mounted && request == _statisticsRequest) {
        setState(() => _statistics = statistics);
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.reportStudent,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Sections(
                selected: _section,
                onSelected: (next) {
                  FocusScope.of(context).unfocus();
                  setState(() => _section = next);
                },
              ),
            ],
          ),
        ),
        if (_failed)
          Material(
            color: _rose.withValues(alpha: 0.14),
            child: InkWell(
              onTap: _loadAll,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.loadFailed,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      l.retry,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.accent.ring,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          // Stacked so a half-finished mark survives a look at History.
          child: IndexedStack(
            index: _section.index,
            children: [
              _MarkSection(
                roster: _roster,
                reasons: _reasons,
                outbox: widget.outbox,
                bottomInset: widget.bottomInset,
                onShowHistory: () =>
                    setState(() => _section = _Section.history),
              ),
              _HistorySection(
                history: _history,
                bottomInset: widget.bottomInset,
                onDelete: widget.deleteMark == null ? null : _deleteMark,
              ),
              _StatisticsSection(
                statistics: _statistics,
                reasons: _reasons,
                from: _from,
                to: _to,
                bottomInset: widget.bottomInset,
                onDates: (from, to) {
                  setState(() {
                    _from = from;
                    _to = to;
                  });
                  _loadStatistics();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Sections extends StatelessWidget {
  const _Sections({required this.selected, required this.onSelected});

  final _Section selected;
  final ValueChanged<_Section> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final labels = {
      _Section.mark: l.markTab,
      _Section.history: l.historyTab,
      _Section.statistics: l.statisticsTab,
    };
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: colors.softBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in labels.entries)
            GestureDetector(
              onTap: () => onSelected(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: entry.key == selected
                      ? colors.card
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  entry.value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _Step { who, type, why, done }

class _MarkSection extends StatefulWidget {
  const _MarkSection({
    required this.roster,
    required this.reasons,
    required this.outbox,
    required this.bottomInset,
    required this.onShowHistory,
  });

  /// Null while loading.
  final BehaviorRoster? roster;
  final BehaviorReasons reasons;
  final LessonsOutbox outbox;
  final double bottomInset;
  final VoidCallback onShowHistory;

  @override
  State<_MarkSection> createState() => _MarkSectionState();
}

class _MarkSectionState extends State<_MarkSection> {
  _Step _step = _Step.who;
  String _activeClass = '';
  bool _pickedClass = false;
  final _search = TextEditingController();
  final _comment = TextEditingController();
  final List<String> _selectedIds = [];
  String? _type;
  final List<String> _reasonIds = [];
  List<BehaviorStudent> _savedFor = const [];

  @override
  void dispose() {
    _search.dispose();
    _comment.dispose();
    super.dispose();
  }

  List<BehaviorStudent> get _students => widget.roster?.students ?? const [];

  List<String> get _classes =>
      _students.map((s) => s.className).toSet().toList()..sort(_byClassName);

  List<String> get _ownClasses {
    final classes = _classes.toSet();
    return (widget.roster?.myClasses ?? const <String>[])
        .where(classes.contains)
        .toList();
  }

  List<String> get _chips => _ownClasses.isNotEmpty ? _ownClasses : _classes;

  List<String> get _otherClasses {
    final own = _ownClasses.toSet();
    return own.isEmpty
        ? const []
        : _classes.where((name) => !own.contains(name)).toList();
  }

  /// Homeroom class, else the first own class, until the teacher picks one.
  String get _shownClass {
    if (_pickedClass) return _activeClass;
    final homeroom = widget.roster?.homeroomClass;
    if (homeroom != null && _classes.contains(homeroom)) return homeroom;
    return _chips.firstOrNull ?? '';
  }

  String get _query => _search.text.trim().toLowerCase();

  /// Typing searches the whole school; otherwise the chosen class is shown.
  List<BehaviorStudent> get _visible {
    final query = _query;
    final shown = _shownClass;
    return _students
        .where(
          (s) => query.isNotEmpty
              ? s.fullName.toLowerCase().contains(query)
              : s.className == shown,
        )
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  List<BehaviorStudent> get _selected =>
      _students.where((s) => _selectedIds.contains(s.id)).toList();

  bool get _canSave =>
      _selectedIds.isNotEmpty &&
      _type != null &&
      (_reasonIds.isNotEmpty || _comment.text.trim().isNotEmpty);

  void _go(_Step step) {
    FocusScope.of(context).unfocus();
    setState(() => _step = step);
  }

  void _toggle(List<String> list, String id) {
    setState(() => list.contains(id) ? list.remove(id) : list.add(id));
  }

  void _toggleAllVisible(List<BehaviorStudent> visible) {
    final ids = visible.map((s) => s.id).toList();
    final all = ids.every(_selectedIds.contains);
    setState(() {
      _selectedIds.removeWhere(ids.contains);
      if (!all) _selectedIds.addAll(ids);
    });
  }

  void _chooseType(String type) {
    if (type != _type) _reasonIds.clear();
    _type = type;
    _go(_Step.why);
  }

  String _who(AppLocalizations l, List<BehaviorStudent> students) =>
      students.length == 1
      ? students.first.fullName
      : l.studentsCount(students.length);

  void _save(AppLocalizations l) {
    if (!_canSave) return;
    final selected = _selected;
    final ids = List.of(_selectedIds);
    for (var start = 0; start < ids.length; start += maxStudentsPerRequest) {
      widget.outbox.enqueue(
        kind: UploadKind.behavior,
        lessonId: LessonsOutbox.noLesson,
        label: _who(l, selected),
        body: {
          'studentIds': ids.sublist(
            start,
            math.min(start + maxStudentsPerRequest, ids.length),
          ),
          'type': _type,
          'reasonIds': List.of(_reasonIds),
          'comment': _comment.text,
          'requestId': newRequestId(),
        },
      );
    }
    setState(() {
      _savedFor = selected;
      _selectedIds.clear();
      _reasonIds.clear();
      _comment.clear();
      _type = null;
    });
    _go(_Step.done);
  }

  void _pickOtherClass() {
    final colors = appColorsOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.6,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final name in _otherClasses)
                ListTile(
                  dense: true,
                  title: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  trailing: name == _shownClass
                      ? Icon(Icons.check_rounded, color: colors.accent.ring)
                      : null,
                  onTap: () {
                    Navigator.pop(sheet);
                    _pickClass(name);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _pickClass(String name) {
    setState(() {
      _activeClass = name;
      _pickedClass = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final type = _type;
    final colors = appColorsOf(context);

    final (String label, VoidCallback? run) = switch (_step) {
      _Step.who =>
        _selectedIds.isNotEmpty
            ? (l.nextWho(_who(l, _selected)), () => _go(_Step.type))
            : (l.tapStudentsFirst, null),
      _Step.type =>
        type != null ? (l.next, () => _go(_Step.why)) : (l.pickOneAbove, null),
      _Step.why =>
        _canSave
            ? (l.saveForWho(_who(l, _selected)), () => _save(l))
            : (l.pickReasonOrComment, null),
      _Step.done => (
        _shownClass.isEmpty ? l.markMore : l.markMoreIn(_shownClass),
        () => _go(_Step.who),
      ),
    };

    return TabBackHandler(
      // Same as the Back button under the wizard.
      onBack: () {
        if (_step != _Step.type && _step != _Step.why) return false;
        _go(_step == _Step.why ? _Step.type : _Step.who);
        return true;
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step != _Step.done) _progress(l),
          Expanded(
            child: switch (_step) {
              _Step.who => _whoStep(l),
              _Step.type => _typeStep(l),
              _Step.why => _whyStep(l),
              _Step.done => _doneStep(l),
            },
          ),
          Container(
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + widget.bottomInset),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: colors.line)),
            ),
            child: Row(
              children: [
                if (_step == _Step.type || _step == _Step.why)
                  TextButton.icon(
                    onPressed: () =>
                        _go(_step == _Step.why ? _Step.type : _Step.who),
                    icon: const Icon(Icons.arrow_back_rounded, size: 17),
                    label: Text(l.back),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: FilledButton(
                      onPressed: run,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.accent.solid,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _progress(AppLocalizations l) {
    final colors = appColorsOf(context);
    final steps = [
      (_Step.who, l.stepWho),
      (_Step.type, l.stepWhatKind),
      (_Step.why, l.stepWhy),
    ];
    final index = steps.indexWhere((s) => s.$1 == _step);
    final selected = _selected;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: i < index ? () => _go(steps[i].$1) : null,
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: i <= index
                              ? colors.accent.solid
                              : colors.softBg,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        steps[i].$2,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: i == index ? null : colors.mutedText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_step != _Step.who && selected.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 130),
              child: GestureDetector(
                onTap: () => _go(_Step.who),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: colors.softBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.people_alt_rounded, size: 13),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _who(l, selected),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _whoStep(AppLocalizations l) {
    final colors = appColorsOf(context);
    final visible = _visible;
    final query = _query;
    final shown = _shownClass;
    final allSelected =
        visible.isNotEmpty && visible.every((s) => _selectedIds.contains(s.id));
    final others = _otherClasses;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 40,
            child: _SearchField(
              controller: _search,
              hint: l.searchAnyStudent,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        if (query.isEmpty) ...[
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                for (final name in _chips)
                  _ClassChip(
                    label: name == widget.roster?.homeroomClass
                        ? '$name · ${l.mine}'
                        : name,
                    selected: name == shown,
                    onTap: () => _pickClass(name),
                  ),
                if (others.isNotEmpty)
                  _ClassChip(
                    label: others.contains(shown) ? shown : l.otherClass,
                    selected: others.contains(shown),
                    trailing: Icons.expand_more_rounded,
                    onTap: _pickOtherClass,
                  ),
              ],
            ),
          ),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  query.isNotEmpty
                      ? l.acrossSchool(visible.length)
                      : '$shown · ${l.studentsCount(visible.length)}',
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
              ),
              if (visible.isNotEmpty)
                GestureDetector(
                  onTap: () => _toggleAllVisible(visible),
                  child: Text(
                    allSelected ? l.unselectAll : l.selectAll,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colors.accent.ring,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? Center(
                  child: Text(
                    widget.roster == null
                        ? l.loadingStudents
                        : query.isNotEmpty
                        ? l.noStudentNamed
                        : l.noStudentsInClass,
                    style: TextStyle(color: colors.mutedText),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: visible.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: colors.line.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final student = visible[index];
                    final on = _selectedIds.contains(student.id);
                    return InkWell(
                      onTap: () => _toggle(_selectedIds, student.id),
                      child: Container(
                        color: on ? colors.softBg : null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: on
                                    ? colors.accent.solid
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: on
                                      ? colors.accent.solid
                                      : colors.mutedText,
                                ),
                              ),
                              child: on
                                  ? const Icon(
                                      Icons.check_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                student.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: on
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                              ),
                            ),
                            if (query.isNotEmpty)
                              Text(
                                student.className,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colors.mutedText,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _typeStep(AppLocalizations l) {
    final colors = appColorsOf(context);
    Widget option(String type, String title, String detail) {
      final color = _typeColor(type);
      final on = _type == type;
      return Material(
        color: on ? color.withValues(alpha: 0.14) : colors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: on ? color : colors.line, width: on ? 2 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _chooseType(type),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_typeIcon(type), size: 22, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        detail,
                        style: TextStyle(fontSize: 13, color: colors.mutedText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          option(behaviorPositive, l.positive, l.positiveDetail),
          const SizedBox(height: 10),
          option(behaviorNegative, l.needsAttention, l.negativeDetail),
        ],
      ),
    );
  }

  Widget _whyStep(AppLocalizations l) {
    final colors = appColorsOf(context);
    final type = _type!;
    final color = _typeColor(type);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
      children: [
        for (final reason in widget.reasons.of(type))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: () {
              final on = _reasonIds.contains(reason.id);
              return Material(
                color: on ? color.withValues(alpha: 0.14) : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: on ? color : colors.line),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _toggle(_reasonIds, reason.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _reasonIcons[reason.id] ?? _typeIcon(type),
                          size: 18,
                          color: color,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            reason.label,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (on)
                          Icon(Icons.check_rounded, size: 17, color: color),
                      ],
                    ),
                  ),
                ),
              );
            }(),
          ),
        TextField(
          controller: _comment,
          maxLength: 1000,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: l.addCommentOptional,
            counterText: '',
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _doneStep(AppLocalizations l) {
    final colors = appColorsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _emerald.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_outline_rounded,
              size: 30,
              color: _emerald,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.savedForWho(_who(l, _savedFor)),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            _savedFor.map((s) => s.fullName).join(', '),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: colors.mutedText),
          ),
          TextButton(
            onPressed: widget.onShowHistory,
            child: Text(l.seeInHistory),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        contentPadding: EdgeInsets.zero,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: colors.mutedText,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 16),
                onPressed: () {
                  controller.clear();
                  onChanged();
                },
              ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final text = selected
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? colors.accent.solid : colors.softBg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: text,
                    fontFeatures: _tabular,
                  ),
                ),
                if (trailing != null) Icon(trailing, size: 16, color: text),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistorySection extends StatefulWidget {
  const _HistorySection({
    required this.history,
    required this.bottomInset,
    this.onDelete,
  });

  /// Null while loading.
  final List<BehaviorHistoryEntry>? history;
  final double bottomInset;

  /// Null for people without `behavior.delete`.
  final ValueChanged<BehaviorHistoryEntry>? onDelete;

  @override
  State<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<_HistorySection> {
  String? _type;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _when(BuildContext context, AppLocalizations l, DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final time = DateFormat('HH:mm').format(date);
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return '${l.today} $time';
    }
    final locale = Localizations.localeOf(context).toString();
    return '${DateFormat('d MMM', locale).format(date)} $time';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final history = widget.history;
    final query = _search.text.trim().toLowerCase();
    final rows = (history ?? const <BehaviorHistoryEntry>[])
        .where(
          (mark) =>
              (_type == null || mark.type == _type) &&
              (query.isEmpty ||
                  mark.studentName.toLowerCase().contains(query) ||
                  mark.className.toLowerCase() == query),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SizedBox(
            height: 40,
            child: _SearchField(
              controller: _search,
              hint: l.studentOrClass,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              for (final (type, label) in [
                (null, l.all),
                (behaviorPositive, l.positive),
                (behaviorNegative, l.needsAttention),
              ])
                _ClassChip(
                  label: label,
                  selected: _type == type,
                  onTap: () => setState(() => _type = type),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: history == null
              ? const Center(child: CircularProgressIndicator())
              : rows.isEmpty
              ? Center(
                  child: Text(
                    history.isEmpty ? l.noBehaviorMarks : l.noFilterMatches,
                    style: TextStyle(color: colors.mutedText),
                  ),
                )
              : ListView.separated(
                  padding: EdgeInsets.only(bottom: widget.bottomInset + 8),
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: colors.line.withValues(alpha: 0.5),
                  ),
                  itemBuilder: (context, index) {
                    final mark = rows[index];
                    final detail = [
                      mark.reasonLabel,
                      mark.comment,
                    ].whereType<String>().join(' · ');
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6, right: 10),
                            decoration: BoxDecoration(
                              color: _typeColor(mark.type),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: mark.studentName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextSpan(
                                        text: '  ${mark.className}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.mutedText,
                                        ),
                                      ),
                                    ],
                                  ),
                                  style: const TextStyle(fontSize: 14),
                                ),
                                if (detail.isNotEmpty)
                                  Text(
                                    detail,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 104),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _when(context, l, mark.createdAt),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: colors.mutedText,
                                    fontFeatures: _tabular,
                                  ),
                                ),
                                if (mark.authorName != null)
                                  Text(
                                    mark.authorName!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: colors.mutedText,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (widget.onDelete != null)
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              tooltip: l.behaviorDeleteTooltip,
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                                color: colors.mutedText,
                              ),
                              onPressed: () => widget.onDelete!(mark),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _StatisticsSection extends StatelessWidget {
  const _StatisticsSection({
    required this.statistics,
    required this.reasons,
    required this.from,
    required this.to,
    required this.bottomInset,
    required this.onDates,
  });

  final BehaviorStatistics statistics;
  final BehaviorReasons reasons;
  final String? from;
  final String? to;
  final double bottomInset;
  final void Function(String? from, String? to) onDates;

  Future<String?> _pick(BuildContext context, String? current) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(current ?? '') ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
    );
    return picked == null ? null : DateFormat('yyyy-MM-dd').format(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final maxWeekly = statistics.byWeek.fold<int>(
      1,
      (most, week) => math.max(most, week.total),
    );
    final all = [...reasons.positive, ...reasons.negative];
    String reasonLabel(String id) =>
        all.where((r) => r.id == id).firstOrNull?.label ?? id;

    Widget summary(String label, int value, Color? color) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.mutedText),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: color,
                fontFeatures: _tabular,
              ),
            ),
          ],
        ),
      ),
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 8),
      children: [
        Row(
          children: [
            _DateChip(
              label: l.from,
              value: from,
              onTap: () async {
                final picked = await _pick(context, from);
                if (picked != null) onDates(picked, to);
              },
              onClear: () => onDates(null, to),
            ),
            const SizedBox(width: 6),
            _DateChip(
              label: l.to,
              value: to,
              onTap: () async {
                final picked = await _pick(context, to);
                if (picked != null) onDates(from, picked);
              },
              onClear: () => onDates(from, null),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            summary(l.total, statistics.total, null),
            const SizedBox(width: 6),
            summary(l.positive, statistics.positive, _emerald),
            const SizedBox(width: 6),
            summary(l.needsAttention, statistics.negative, _rose),
          ],
        ),
        const SizedBox(height: 8),
        _Panel(
          title: l.byClass,
          empty: statistics.byClass.isEmpty,
          children: [
            for (final row in statistics.byClass)
              _Bar(row: row, max: math.max(row.total, 1)),
          ],
        ),
        _Panel(
          title: l.byWeek,
          empty: statistics.byWeek.isEmpty,
          children: [
            for (final row in statistics.byWeek) _Bar(row: row, max: maxWeekly),
          ],
        ),
        _Panel(
          title: l.commonReasons,
          empty: statistics.byReason.isEmpty,
          children: [
            for (final item in statistics.byReason)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: _typeColor(item.type),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        reasonLabel(item.id),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    Text(
                      '${item.total}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.mutedText,
                        fontFeatures: _tabular,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Material(
      color: colors.softBg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value == null ? label : '$label $value',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  fontFeatures: _tabular,
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(Icons.close_rounded, size: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final bool empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l.noMarksForPeriod,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.mutedText),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.row, required this.max});

  final BehaviorStatRow row;
  final int max;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final rest = math.max(max - row.positive - row.negative, 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          SizedBox(
            width: 66,
            child: Text(
              row.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: SizedBox(
                height: 8,
                child: ColoredBox(
                  color: colors.softBg,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (row.positive > 0)
                        Expanded(
                          flex: row.positive,
                          child: const ColoredBox(color: _emerald),
                        ),
                      if (row.negative > 0)
                        Expanded(
                          flex: row.negative,
                          child: const ColoredBox(color: _rose),
                        ),
                      if (rest > 0) Spacer(flex: rest),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '${row.total}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                color: colors.mutedText,
                fontFeatures: _tabular,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
