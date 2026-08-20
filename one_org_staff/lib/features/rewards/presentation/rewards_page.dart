import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

/// Rewards — a port of the web app's `features/rewards` "Points Studio".
///
/// Same job as the web: find students, select any number of them, and award or
/// deduct the same points in one go. The layout is not the same, because the
/// web's two-column "directory beside an award panel" collapses into a very
/// long scroll on a phone. Here the directory owns the screen and the award
/// controls live in a bottom sheet raised by a selection bar, so choosing
/// students and setting an amount are two separate, full-width steps instead of
/// one cramped one.
class RewardsPage extends StatefulWidget {
  const RewardsPage({
    super.key,
    required this.loadGroups,
    required this.loadStudents,
    required this.loadPointTotals,
    required this.savePoints,
  });

  final Future<List<GroupEntry>> Function({int? academicYearId}) loadGroups;

  /// The roster for one class, or every student when `groupId` is null.
  final Future<List<StudentEntry>> Function({int? groupId}) loadStudents;

  /// Net balances keyed by person id, for the same scope as [loadStudents].
  final Future<Map<int, double>> Function({int? groupId}) loadPointTotals;

  final Future<void> Function(List<StudentPointDraft> points) savePoints;

  @override
  State<RewardsPage> createState() => _RewardsPageState();
}

/// One class's students with their balances, resolved together so a row never
/// renders a name without its points.
class _Roster {
  const _Roster({required this.students, required this.totals});

  final List<StudentEntry> students;
  final Map<int, double> totals;
}

class _RewardsPageState extends State<RewardsPage> {
  /// Quick-amount presets for the award sheet — one tap instead of typing.
  /// Same set as the web.
  static const _pointPresets = [1, 5, 10, -5];

  static const _searchDebounce = Duration(milliseconds: 350);

  late Future<List<GroupEntry>> _groupsFuture;

  final _searchController = TextEditingController();
  Timer? _debounce;

  /// Null means "every class". The roster then spans the school and each row
  /// shows which class the student is in.
  GroupEntry? _selectedGroup;
  String _search = '';

  /// Rosters already fetched, keyed by group id (or `'all'`). Extra keystrokes
  /// filter in memory instead of hitting the network again. Dropped after an
  /// award so balances come back fresh.
  final Map<Object, _Roster> _cache = {};

  _Roster? _roster;
  bool _loading = false;
  String? _error;

  /// Selected students keyed by **person id** — the key `/student-points` uses.
  final Map<int, StudentEntry> _selected = {};

  @override
  void initState() {
    super.initState();
    _groupsFuture = widget.loadGroups();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Object get _scopeKey => _selectedGroup?.id ?? 'all';

  /// Nothing is fetched until there is something to fetch *for*: a chosen class
  /// scopes the request, and without one only a name search is worth the
  /// school-wide roster. Matches the web's behaviour.
  bool get _hasScope => _selectedGroup != null || _search.isNotEmpty;

  void _onSearchChanged() {
    final next = _searchController.text.trim();
    if (next == _search) {
      return;
    }

    setState(() => _search = next);

    // A cached roster filters instantly; only a scope that still has to be
    // fetched waits out the debounce.
    if (_cache.containsKey(_scopeKey)) {
      setState(() => _roster = _cache[_scopeKey]);
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, _loadRoster);
  }

  void _selectGroup(GroupEntry? group) {
    if (group?.id == _selectedGroup?.id) {
      return;
    }
    _debounce?.cancel();
    setState(() {
      _selectedGroup = group;
      _roster = null;
      _error = null;
    });
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    if (!_hasScope) {
      setState(() {
        _roster = null;
        _error = null;
        _loading = false;
      });
      return;
    }

    final scope = _scopeKey;
    final cached = _cache[scope];
    if (cached != null) {
      setState(() {
        _roster = cached;
        _error = null;
        _loading = false;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final groupId = _selectedGroup?.id;
    try {
      final results = await Future.wait([
        widget.loadStudents(groupId: groupId),
        widget.loadPointTotals(groupId: groupId),
      ]);

      if (!mounted || scope != _scopeKey) {
        return;
      }

      final roster = _Roster(
        students: results[0] as List<StudentEntry>,
        totals: results[1] as Map<int, double>,
      );
      _cache[scope] = roster;
      setState(() {
        _roster = roster;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || scope != _scopeKey) {
        return;
      }
      setState(() {
        _error = _messageFor(error);
        _roster = null;
        _loading = false;
      });
    }
  }

  /// The roster narrowed by the search box. Name, nickname and person code all
  /// match, so a teacher can paste a code straight in.
  List<StudentEntry> get _visible {
    final students = _roster?.students ?? const <StudentEntry>[];
    if (_search.isEmpty) {
      return students;
    }
    final query = _search.toLowerCase();
    return students.where((student) {
      final nickname = student.nickname?.toLowerCase() ?? '';
      final code = student.code?.toLowerCase() ?? '';
      return student.fullName.toLowerCase().contains(query) ||
          nickname.contains(query) ||
          code.contains(query);
    }).toList();
  }

  double _totalFor(StudentEntry student) =>
      _roster?.totals[student.personId] ?? 0;

  bool _isSelected(StudentEntry student) =>
      _selected.containsKey(student.personId);

  void _toggle(StudentEntry student) {
    setState(() {
      if (_selected.remove(student.personId) == null) {
        _selected[student.personId] = student;
      }
    });
    HapticFeedback.selectionClick();
  }

  void _remove(StudentEntry student) {
    setState(() => _selected.remove(student.personId));
  }

  void _toggleSelectAllShown() {
    final shown = _visible;
    final allSelected =
        shown.isNotEmpty && shown.every((student) => _isSelected(student));
    setState(() {
      for (final student in shown) {
        if (allSelected) {
          _selected.remove(student.personId);
        } else {
          _selected[student.personId] = student;
        }
      }
    });
  }

  void _clearSelection() => setState(_selected.clear);

  Future<void> _openAwardSheet() async {
    final award = await showModalBottomSheet<_Award>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _AwardSheet(
        presets: _pointPresets,
        selected: () => _selected.values.toList(),
        totalFor: _totalFor,
        onRemove: (student) {
          _remove(student);
          // Emptying the selection from inside the sheet leaves it with
          // nothing to award, so it closes itself.
          if (_selected.isEmpty) {
            Navigator.of(sheetContext).pop();
          }
        },
      ),
    );

    if (award == null || !mounted) {
      return;
    }
    await _save(award);
  }

  Future<void> _save(_Award award) async {
    final drafts = <StudentPointDraft>[];
    final awarded = <int>{};
    var skipped = 0;

    for (final student in _selected.values) {
      final groupId = student.groupId;
      // A point row is filed against a class. An enrollment that arrived
      // without one cannot be filed anywhere, so it is reported, not guessed.
      if (groupId == null) {
        skipped += 1;
        continue;
      }
      drafts.add(
        StudentPointDraft(
          personId: student.personId,
          groupId: groupId,
          points: award.points,
          date: award.date,
          reason: award.reason,
        ),
      );
      awarded.add(student.personId);
    }

    if (drafts.isEmpty) {
      _showMessage('Selected students have no class assigned.');
      return;
    }

    try {
      await widget.savePoints(drafts);
    } catch (error) {
      if (mounted) {
        _showMessage(_messageFor(error));
      }
      return;
    }

    if (!mounted) {
      return;
    }

    final verb = award.points > 0 ? 'Added' : 'Deducted';
    final amount = _formatPoints(award.points.abs());
    final count = drafts.length;
    _showMessage(
      '$verb $amount pts for $count ${count == 1 ? 'student' : 'students'}'
      '${skipped > 0 ? ' ($skipped skipped — no class)' : ''}.',
    );

    // Show the new balances straight away rather than refetching, and drop the
    // cache so the next scope change reads them back from the server.
    final roster = _roster;
    if (roster != null) {
      final totals = Map<int, double>.from(roster.totals);
      for (final personId in awarded) {
        totals[personId] = (totals[personId] ?? 0) + award.points;
      }
      setState(() => _roster = _Roster(students: roster.students, totals: totals));
    }
    _cache.clear();
    if (roster != null) {
      _cache[_scopeKey] = _roster!;
    }

    _clearSelection();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _messageFor(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final shown = _visible;

    // The nav bar floats over the page, so the list and the selection bar have
    // to keep clear of it themselves.
    final navClearance = MediaQuery.of(context).padding.bottom + 62;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          // The title and the filters scroll away with the list rather than
          // being pinned: on a phone they would otherwise eat a third of the
          // screen and leave room for four students at a time.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rewards',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap students to select, then give or deduct points.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.mutedText,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ClassPicker(
                        groupsFuture: _groupsFuture,
                        selected: _selectedGroup,
                        onSelected: _selectGroup,
                      ),
                      const SizedBox(height: 12),
                      _SearchField(
                        controller: _searchController,
                        hint: _selectedGroup == null
                            ? 'Search every class by name or code…'
                            : 'Search ${_selectedGroup!.classPair}…',
                      ),
                      if (shown.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _ListToolbar(
                          allSelected: shown.every(_isSelected),
                          shownCount: shown.length,
                          onToggleAll: _toggleSelectAllShown,
                        ),
                      ] else
                        const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              _buildListSliver(shown, navClearance),
            ],
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _selected.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, navClearance),
                  child: _SelectionBar(
                    count: _selected.length,
                    onClear: _clearSelection,
                    onAward: _openAwardSheet,
                  ),
                ),
        ),
      ],
    );
  }

  /// The roster, or whichever notice stands in for it. Every branch fills the
  /// remaining viewport so a message lands in the middle of the empty area
  /// rather than tucked under the search box.
  Widget _buildListSliver(List<StudentEntry> shown, double navClearance) {
    Widget fill(Widget child) => SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Center(child: child),
      ),
    );

    if (_loading) {
      return fill(const CircularProgressIndicator());
    }

    if (_error != null) {
      return fill(
        _Notice(
          icon: Icons.error_outline_rounded,
          text: _error!,
          action: OutlinedButton.icon(
            onPressed: _loadRoster,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ),
      );
    }

    if (!_hasScope) {
      return fill(
        const _Notice(
          icon: Icons.card_giftcard_rounded,
          text: 'Choose a class, or search by name, to list students.',
        ),
      );
    }

    if (shown.isEmpty) {
      return fill(
        _Notice(
          icon: Icons.person_search_rounded,
          text: _search.isEmpty
              ? 'No students in this class.'
              : 'No students match "$_search".',
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        // Room for the selection bar, so the last row never ends up beneath it.
        navClearance + (_selected.isEmpty ? 12 : _selectionBarHeight),
      ),
      sliver: SliverList.separated(
        itemCount: shown.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final student = shown[index];
          return _StudentRow(
            student: student,
            selected: _isSelected(student),
            total: _totalFor(student),
            showClass: _selectedGroup == null,
            onTap: () => _toggle(student),
          );
        },
      ),
    );
  }

  /// Roughly what [_SelectionBar] occupies, so the list can reserve room for it
  /// before it appears and rows never end up underneath it.
  static const _selectionBarHeight = 84.0;
}

/// Trims a trailing `.0` — points are whole numbers nearly always, and `5.0`
/// reads like a precision the school does not use.
String _formatPoints(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toString();
}

class _ClassPicker extends StatelessWidget {
  const _ClassPicker({
    required this.groupsFuture,
    required this.selected,
    required this.onSelected,
  });

  final Future<List<GroupEntry>> groupsFuture;
  final GroupEntry? selected;
  final ValueChanged<GroupEntry?> onSelected;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GroupEntry>>(
      future: groupsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;
        final groups = [...(snapshot.data ?? const <GroupEntry>[])]
          ..sort((a, b) {
            final byGrade = a.grade.compareTo(b.grade);
            return byGrade != 0 ? byGrade : a.className.compareTo(b.className);
          });

        return DropdownButtonFormField<int?>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Class',
            prefixIcon: const Icon(Icons.school_rounded),
            hintText: loading
                ? 'Loading classes…'
                : snapshot.hasError
                ? 'Classes unavailable'
                : 'All classes',
          ),
          items: [
            const DropdownMenuItem(value: null, child: Text('All classes')),
            for (final group in groups)
              DropdownMenuItem(value: group.id, child: Text(group.classPair)),
          ],
          onChanged: loading
              ? null
              : (id) => onSelected(
                  id == null
                      ? null
                      : groups.firstWhere((group) => group.id == id),
                ),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: colors.mutedText),
          prefixIcon: Icon(Icons.search_rounded, color: colors.mutedText),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: controller.clear,
                    icon: Icon(Icons.close_rounded, color: colors.mutedText),
                    tooltip: 'Clear search',
                  ),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
            horizontal: 16,
          ),
        ),
      ),
    );
  }
}

class _ListToolbar extends StatelessWidget {
  const _ListToolbar({
    required this.allSelected,
    required this.shownCount,
    required this.onToggleAll,
  });

  final bool allSelected;
  final int shownCount;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            '$shownCount ${shownCount == 1 ? 'student' : 'students'}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.mutedText,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onToggleAll,
          icon: Icon(
            allSelected
                ? Icons.remove_done_rounded
                : Icons.done_all_rounded,
            size: 18,
          ),
          label: Text(allSelected ? 'Clear all' : 'Select all ($shownCount)'),
        ),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.selected,
    required this.total,
    required this.showClass,
    required this.onTap,
  });

  final StudentEntry student;
  final bool selected;
  final double total;
  final bool showClass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    final subtitle = showClass
        ? (student.classPair ?? 'No class')
        : (student.nickname?.trim().isNotEmpty == true
              ? student.nickname!.trim()
              : student.code ?? '');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? colors.softBg : colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? colors.border : colors.line,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _SelectableAvatar(student: student, selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.mutedText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _PointsBadge(total: total),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectableAvatar extends StatelessWidget {
  const _SelectableAvatar({required this.student, required this.selected});

  final StudentEntry student;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final picture = student.pictureUrl;
    final initial = student.fullName.isNotEmpty
        ? student.fullName[0].toUpperCase()
        : '?';

    return SizedBox(
      width: 42,
      height: 42,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: colors.avatarPlaceholder,
            backgroundImage: picture != null && picture.isNotEmpty
                ? NetworkImage(picture)
                : null,
            child: picture != null && picture.isNotEmpty
                ? null
                : Text(
                    initial,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: colors.softText,
                    ),
                  ),
          ),
          if (selected)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colors.accent.solid,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.card, width: 2),
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PointsBadge extends StatelessWidget {
  const _PointsBadge({required this.total});

  final double total;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color tint;
    if (total > 0) {
      tint = isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    } else if (total < 0) {
      tint = isDark ? const Color(0xFFFB7185) : const Color(0xFFBE123C);
    } else {
      tint = colors.mutedText;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            _formatPoints(total),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: tint,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            'pts',
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tint),
          ),
        ],
      ),
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({
    required this.count,
    required this.onClear,
    required this.onAward,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onAward;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Clear selection',
          ),
          Expanded(
            child: Text(
              '$count selected',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: onAward,
            icon: const Icon(Icons.card_giftcard_rounded, size: 18),
            label: const Text('Give points'),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colors.softBg,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: colors.softText, size: 26),
            ),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.mutedText),
            ),
            if (action != null) ...[const SizedBox(height: 14), action!],
          ],
        ),
      ),
    );
  }
}

/// What the award sheet hands back: one amount, reason and date, applied to
/// every selected student.
class _Award {
  const _Award({
    required this.points,
    required this.date,
    required this.reason,
  });

  final double points;
  final DateTime date;
  final String reason;
}

/// The award controls. On the web these sit in a column beside the directory;
/// on a phone they are a sheet, so the amount, date and reason get the full
/// width and the keyboard has somewhere to go.
class _AwardSheet extends StatefulWidget {
  const _AwardSheet({
    required this.presets,
    required this.selected,
    required this.totalFor,
    required this.onRemove,
  });

  final List<int> presets;

  /// Read fresh on every build — the page owns the selection, the sheet only
  /// displays it and asks for removals through [onRemove].
  final List<StudentEntry> Function() selected;
  final double Function(StudentEntry) totalFor;
  final ValueChanged<StudentEntry> onRemove;

  @override
  State<_AwardSheet> createState() => _AwardSheetState();
}

class _AwardSheetState extends State<_AwardSheet> {
  final _pointsController = TextEditingController();
  final _reasonController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pointsController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pointsController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  double? get _points {
    final value = double.tryParse(
      _pointsController.text.trim().replaceAll(',', '.'),
    );
    if (value == null || value == 0) {
      return null;
    }
    return value;
  }

  void _setPoints(num value) {
    final text = _formatPoints(value.toDouble());
    _pointsController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Nudges the amount by one, crossing zero rather than stopping at it — a
  /// deduction is reached by stepping down past 0, the same as typing `-1`.
  void _step(int delta) {
    final current = double.tryParse(
          _pointsController.text.trim().replaceAll(',', '.'),
        ) ??
        0;
    _setPoints(current + delta);
    HapticFeedback.selectionClick();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(_date.year - 2),
      lastDate: DateTime(_date.year + 2),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  void _submit() {
    final points = _points;
    if (points == null) {
      return;
    }
    final reason = _reasonController.text.trim();
    Navigator.of(context).pop(
      _Award(
        points: points,
        date: _date,
        // The web files an unlabelled award under a default rather than
        // leaving the reason blank, so the two apps' histories read alike.
        reason: reason.isNotEmpty
            ? reason
            : (points > 0 ? 'Reward points' : 'Penalty'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final students = widget.selected();
    final points = _points;
    final positive = (points ?? 0) > 0;
    final sole = students.length == 1 ? students.single : null;

    final positiveColor = const Color(0xFF16A34A);
    final negativeColor = const Color(0xFFE11D48);

    return Padding(
      // Lifts the sheet clear of the keyboard while the amount or reason is
      // being typed.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.line,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  sole != null
                      ? sole.fullName
                      : '${students.length} students selected',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sole != null
                      ? '${sole.classPair ?? 'No class'} · '
                            '${_formatPoints(widget.totalFor(sole))} pts now'
                      : 'The same amount goes to everyone below.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.mutedText,
                  ),
                ),

                if (sole == null) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 108),
                    child: SingleChildScrollView(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final student in students)
                            InputChip(
                              label: Text(student.fullName),
                              onDeleted: () {
                                widget.onRemove(student);
                                setState(() {});
                              },
                              deleteIcon: const Icon(Icons.close_rounded, size: 16),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                _FieldLabel('Quick amount'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in widget.presets)
                      _PresetChip(
                        key: ValueKey('reward-preset-$preset'),
                        preset: preset,
                        active: points == preset.toDouble(),
                        onTap: () => _setPoints(preset),
                      ),
                  ],
                ),

                const SizedBox(height: 18),
                _FieldLabel('Points'),
                const SizedBox(height: 8),
                _PointsStepper(
                  controller: _pointsController,
                  onStep: _step,
                ),

                const SizedBox(height: 16),
                _FieldLabel('Date'),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month_rounded, size: 18),
                  label: Text(_formatDay(_date)),
                ),

                const SizedBox(height: 16),
                _FieldLabel('Reason (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Why the points were given or taken',
                  ),
                ),

                const SizedBox(height: 18),
                if (points != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: (positive ? positiveColor : negativeColor)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          positive
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 18,
                          color: positive ? positiveColor : negativeColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${positive ? 'Adding' : 'Deducting'} '
                            '${_formatPoints(points.abs())} pts × '
                            '${students.length} '
                            '${students.length == 1 ? 'student' : 'students'}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: positive ? positiveColor : negativeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text(
                    'A positive amount rewards, a negative one deducts.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.mutedText,
                    ),
                  ),

                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: points == null
                        ? null
                        : FilledButton.styleFrom(
                            backgroundColor: positive
                                ? positiveColor
                                : negativeColor,
                            foregroundColor: Colors.white,
                          ),
                    onPressed: points == null || students.isEmpty
                        ? null
                        : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        points == null
                            ? 'Enter an amount'
                            : '${positive ? 'Give' : 'Deduct'} '
                                  '${_formatPoints(points.abs())} pts',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
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

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _formatDay(DateTime date) =>
      '${_months[date.month - 1]} ${date.day}, ${date.year}';
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: appColorsOf(context).mutedText,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    super.key,
    required this.preset,
    required this.active,
    required this.onTap,
  });

  final int preset;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final positive = preset > 0;
    final tint = positive ? const Color(0xFF16A34A) : const Color(0xFFE11D48);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: active ? tint : tint.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? tint : tint.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                positive ? Icons.add_rounded : Icons.remove_rounded,
                size: 16,
                color: active ? Colors.white : tint,
              ),
              const SizedBox(width: 2),
              Text(
                '${preset.abs()}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: active ? Colors.white : tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsStepper extends StatelessWidget {
  const _PointsStepper({required this.controller, required this.onStep});

  final TextEditingController controller;
  final ValueChanged<int> onStep;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Row(
      children: [
        _StepButton(icon: Icons.remove_rounded, onTap: () => onStep(-1)),
        const SizedBox(width: 10),
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: TextStyle(color: colors.mutedText),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
        const SizedBox(width: 10),
        _StepButton(icon: Icons.add_rounded, onTap: () => onStep(1)),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Material(
      color: colors.softBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 52,
          height: 52,
          child: Icon(icon, color: colors.softText, size: 24),
        ),
      ),
    );
  }
}
