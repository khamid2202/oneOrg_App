import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/point_report/domain/point_report_repository.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';
import 'package:one_org_staff/features/point_report/data/point_report_preferences.dart';
import 'package:one_org_staff/features/point_report/presentation/column_picker.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_table.dart';

/// Point report — a port of the web app's `features/point-report`.
///
/// Same grid as the web — `No. | ID | Ism/Familya | Pr-week | Late | Absent |
/// one column per subject | Total` — scrolled horizontally rather than shrunk,
/// because the whole point is to hand a parent the table they'd see on the web.
///
/// Selecting a class, the Mon–Sun week definition, the point categories, the
/// previous-week comparison and the sort rules all match the web, so the two
/// agree on the numbers.
class PointReportPage extends StatefulWidget {
  const PointReportPage({
    super.key,
    required this.loadAcademicYears,
    required this.loadGroups,
    required this.loadStudentsForGroup,
    required this.loadPoints,
    required this.loadTimetable,
    this.shareImage,
    this.preferences,
  });

  final Future<List<AcademicYearEntry>> Function() loadAcademicYears;
  final Future<List<GroupEntry>> Function({int? academicYearId}) loadGroups;
  final Future<List<StudentEntry>> Function(int groupId, {bool includeContacts})
  loadStudentsForGroup;
  final Future<List<StudentPoint>> Function({
    required int groupId,
    required DateTime start,
    required DateTime end,
  })
  loadPoints;

  /// The class timetable, used to list every subject taught that week — a
  /// subject with no points yet still needs a column. Scoped by academic year,
  /// without which the endpoint returns nothing.
  final Future<List<TimetableLesson>> Function({int? academicYearId})
  loadTimetable;

  /// Injected by tests; production shares through the OS share sheet.
  final Future<void> Function(Uint8List png, String fileName)? shareImage;

  /// Injected by tests so they can start from a known set of saved filters.
  final PointReportPreferences? preferences;

  @override
  State<PointReportPage> createState() => _PointReportPageState();
}

class _PointReportPageState extends State<PointReportPage> {
  late final PointReportPreferences _preferences =
      widget.preferences ?? PointReportPreferences();

  late Future<List<GroupEntry>> _groupsFuture;

  /// Resolved alongside the groups and reused for the timetable request.
  int? _academicYearId;

  GroupEntry? _selectedGroup;
  PointReportDateMode _dateMode = PointReportDateMode.weekly;
  DateTime _anchor = DateTime.now();
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  Future<_ReportData>? _reportFuture;

  final _tableKey = GlobalKey();
  PointReportSort _sort = PointReportSort.total;
  bool _descending = true;
  _ReportData? _loadedData;
  bool _sharing = false;

  /// Columns the user switched off. Stored as the *hidden* set so a subject
  /// that appears later shows up by default instead of being missing.
  Set<String> _hiddenColumns = {...PointReportColumns.hiddenByDefault};
  PointReportColumns _columns = const PointReportColumns({});

  @override
  void initState() {
    super.initState();
    _groupsFuture = _loadGroups();
    _restoreFilters();
  }

  /// Brings back the class, period and column choice from the last visit.
  Future<void> _restoreFilters() async {
    final hidden = await _preferences.loadHiddenColumns();
    final dateMode = await _preferences.loadDateMode();
    final savedGroupId = await _preferences.loadGroupId();

    if (!mounted) {
      return;
    }

    setState(() {
      _hiddenColumns = hidden;
      _dateMode = dateMode;
    });

    if (savedGroupId == null) {
      return;
    }

    // Only re-select a saved class if it is still in this year's list.
    try {
      final groups = await _groupsFuture;
      final saved = groups.where((group) => group.id == savedGroupId).toList();
      if (saved.isEmpty || !mounted) {
        return;
      }
      setState(() => _selectedGroup = saved.first);
      _reload();
    } catch (_) {
      // A failed group load already surfaces through the class picker.
    }
  }

  Future<List<GroupEntry>> _loadGroups() async {
    // The academic year is never hardcoded — a request scoped to the wrong year
    // returns nothing, and the page would look broken rather than misconfigured.
    // Prefer the year the API marks active, falling back to the first listed.
    final years = await widget.loadAcademicYears();
    if (years.isEmpty) {
      return widget.loadGroups();
    }

    final activeYear = years.firstWhere(
      (year) => year.isActive,
      orElse: () => years.first,
    );
    _academicYearId = activeYear.id;
    return widget.loadGroups(academicYearId: activeYear.id);
  }

  /// The period the report covers.
  DateRange get _range {
    switch (_dateMode) {
      case PointReportDateMode.weekly:
        return DateRange.weekOf(_anchor);
      case PointReportDateMode.single:
        return DateRange.singleDay(_anchor);
      case PointReportDateMode.range:
        final start = _rangeStart;
        final end = _rangeEnd;
        if (start == null || end == null) {
          return DateRange.weekOf(_anchor);
        }
        return start.isAfter(end)
            ? DateRange(end, start)
            : DateRange(start, end);
    }
  }

  void _reload() {
    final group = _selectedGroup;
    if (group == null) {
      setState(() => _reportFuture = null);
      return;
    }

    final range = _range;
    final future = _load(group, range);

    // FutureBuilder only subscribes on the next build, a frame away. A request
    // that fails faster than that would have no listener when it rejects and
    // Flutter would report it as an unhandled async error, so claim it now.
    // The builder still receives the error when it does subscribe.
    future.then<void>((_) {}, onError: (Object _) {});

    setState(() {
      _loadedData = null;
      _reportFuture = future;
    });
  }

  Future<_ReportData> _load(GroupEntry group, DateRange range) async {
    // One fetch spanning the previous week through the period end — the report
    // shows both, and PointReport.aggregate slices them apart.
    final previous = range.previousWeek;

    final results = await Future.wait([
      widget.loadStudentsForGroup(group.id),
      widget.loadPoints(
        groupId: group.id,
        start: previous.start,
        end: range.end,
      ),
      _timetableOrEmpty(),
    ]);

    final students = (results[0] as List<StudentEntry>)
        .where(_isEnrolled)
        .toList();
    students.sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );

    final report = PointReport.aggregate(
      points: results[1] as List<StudentPoint>,
      range: range,
    );

    return _ReportData(
      students: students,
      report: report,
      subjects: _subjectsForTable(
        report: report,
        timetable: results[2] as List<TimetableLesson>,
        group: group,
      ),
    );
  }

  /// The class timetable, or nothing if it fails to load.
  ///
  /// A timetable outage must not take the report down — the columns simply fall
  /// back to the subjects that actually have points. Written as try/catch
  /// rather than `catchError`, whose callback is bound to the future's static
  /// type and blows up on a `Future<Never>`.
  Future<List<TimetableLesson>> _timetableOrEmpty() async {
    try {
      return await widget.loadTimetable(academicYearId: _academicYearId);
    } catch (_) {
      return const [];
    }
  }

  /// Every subject the table gets a column for.
  ///
  /// The class timetable is the source, so a subject taught this week shows up
  /// even before anyone has scored a point in it — an empty column is the
  /// information that nothing was awarded. Subjects that have points but are
  /// not on the timetable are added too, so no data is ever hidden.
  List<String> _subjectsForTable({
    required PointReport report,
    required List<TimetableLesson> timetable,
    required GroupEntry group,
  }) {
    final subjects = <String>{
      for (final lesson in timetable)
        if (lesson.groupId == group.id && lesson.title.trim().isNotEmpty)
          lesson.title.trim(),
      ...report.subjects,
    };

    return subjects.toList()..sort();
  }

  /// Students who have left the class are not in the report. `/students`
  /// reports `present`/`left`; older rows use `active`/`inactive`.
  static bool _isEnrolled(StudentEntry student) {
    final status = student.status?.trim().toLowerCase();
    if (status == null || status.isEmpty) {
      return true;
    }
    return status != 'left' && status != 'inactive' && status != 'deactivated';
  }

  /// Tapping the active column flips its direction; a new column starts on the
  /// direction that reads as "best first" for it — highest total, A–Z by name.
  void _changeSort(PointReportSort column) {
    setState(() {
      if (_sort == column) {
        _descending = !_descending;
      } else {
        _sort = column;
        _descending = column == PointReportSort.total;
      }
    });
  }

  /// Recomputes the visible columns whenever the available subjects change,
  /// keeping whatever the user switched off switched off.
  void _onDataLoaded(_ReportData? data) {
    if (!mounted || _loadedData == data) {
      return;
    }
    setState(() {
      _loadedData = data;
      _columns = PointReportColumns(
        _columns.selected,
      ).reconcile(data?.subjects ?? const [], deselected: _hiddenColumns);
    });
  }

  void _setColumns(PointReportColumns columns) {
    final options = PointReportColumns.optionsFor(
      _loadedData?.subjects ?? const [],
    ).map((option) => option.key);

    setState(() {
      _columns = columns;
      _hiddenColumns = {
        for (final key in options)
          if (!columns.shows(key)) key,
      };
    });

    _preferences.saveHiddenColumns(_hiddenColumns);
  }

  void _selectGroup(GroupEntry? group) {
    setState(() => _selectedGroup = group);
    _preferences.saveGroupId(group?.id);
    _reload();
  }

  void _setDateMode(PointReportDateMode mode) {
    setState(() {
      _dateMode = mode;
      if (mode == PointReportDateMode.range) {
        _rangeStart = null;
        _rangeEnd = null;
      } else {
        _anchor = DateTime.now();
      }
    });
    _preferences.saveDateMode(mode);
    if (mode != PointReportDateMode.range) {
      _reload();
    }
  }

  void _shiftPeriod(int direction) {
    setState(() {
      _anchor = _dateMode == PointReportDateMode.weekly
          ? _anchor.add(Duration(days: 7 * direction))
          : _anchor.add(Duration(days: direction));
    });
    _reload();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _rangeStart != null && _rangeEnd != null
          ? DateTimeRange(start: _rangeStart!, end: _rangeEnd!)
          : null,
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _rangeStart = picked.start;
      _rangeEnd = picked.end;
    });
    _reload();
  }

  /// Captures the table as a PNG and hands it to the share sheet.
  ///
  /// The boundary wraps the full-width table inside the horizontal scroll view,
  /// so this yields every column — not just the part currently on screen.
  Future<void> _shareTableImage() async {
    if (_sharing || _loadedData == null) {
      return;
    }

    setState(() => _sharing = true);
    try {
      final boundary =
          _tableKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        _showMessage('The table is not ready yet.');
        return;
      }

      // 3x so the text stays sharp when a parent zooms into the picture.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (data == null) {
        _showMessage('Could not render the table image.');
        return;
      }

      final png = data.buffer.asUint8List();
      final fileName = _imageFileName();

      final share =
          widget.shareImage ??
          (Uint8List bytes, String name) async {
            await SharePlus.instance.share(
              ShareParams(
                files: [
                  XFile.fromData(bytes, mimeType: 'image/png', name: name),
                ],
                fileNameOverrides: [name],
                subject: '$_classLabel — $_periodLabel',
                text: '$_classLabel point report, $_periodLabel',
              ),
            );
          };

      await share(png, fileName);
    } catch (error) {
      _showMessage('Could not share the table image.');
    } finally {
      if (mounted) {
        setState(() => _sharing = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// `point-report-10-a-aug-10-2026-aug-16-2026.png`, mirroring the web's
  /// `buildTableImageFileName` so saved files sort together.
  String _imageFileName() {
    String slug(String value, String fallback) {
      final normalized = value
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
          .replaceAll(RegExp(r'^-+|-+\$'), '');
      return normalized.isEmpty ? fallback : normalized;
    }

    return 'point-report-'
        '${slug(_selectedGroup?.classPair ?? '', 'class')}-'
        '${slug(_periodLabel, 'report')}.png';
  }

  String get _classLabel {
    final group = _selectedGroup;
    return group == null ? 'Point report' : 'Students in ${group.classPair}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Point report',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              // Sits with the title so it is reachable without scrolling past
              // the filters to the bottom of a long table.
              FilledButton.icon(
                onPressed: _loadedData == null || _sharing
                    ? null
                    : _shareTableImage,
                icon: _sharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share_rounded, size: 18),
                label: Text(_sharing ? 'Preparing…' : 'Share'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _periodLabel,
            style: theme.textTheme.bodyLarge?.copyWith(color: colors.mutedText),
          ),
          const SizedBox(height: 16),

          _ClassPicker(
            groupsFuture: _groupsFuture,
            selected: _selectedGroup,
            onSelected: _selectGroup,
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _DateModeSelector(
                  mode: _dateMode,
                  onChanged: _setDateMode,
                ),
              ),
              const SizedBox(width: 8),
              ColumnPickerButton(
                subjects: _loadedData?.subjects ?? const [],
                columns: _columns,
                onChanged: _setColumns,
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (_dateMode == PointReportDateMode.range)
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(
                _rangeStart == null || _rangeEnd == null
                    ? 'Choose dates'
                    : _periodLabel,
              ),
            )
          else
            _PeriodStepper(
              label: _periodLabel,
              onPrevious: () => _shiftPeriod(-1),
              onNext: () => _shiftPeriod(1),
            ),
          const SizedBox(height: 18),

          if (_selectedGroup == null)
            _Notice(
              text: 'Choose a class to view the point report.',
              icon: Icons.groups_rounded,
            )
          else if (_dateMode == PointReportDateMode.range &&
              (_rangeStart == null || _rangeEnd == null))
            _Notice(
              text: 'Choose a start and end date.',
              icon: Icons.date_range_rounded,
            )
          else
            _ReportBody(
              future: _reportFuture,
              classLabel: _classLabel,
              periodLabel: _periodLabel,
              sort: _sort,
              descending: _descending,
              onSortChanged: _changeSort,
              onRetry: _reload,
              tableKey: _tableKey,
              columns: _columns,
              onDataChanged: _onDataLoaded,
            ),
        ],
      ),
    );
  }

  String get _periodLabel {
    if (_dateMode == PointReportDateMode.range &&
        (_rangeStart == null || _rangeEnd == null)) {
      return 'No dates chosen';
    }

    final range = _range;
    if (_dateMode == PointReportDateMode.single) {
      return _formatDay(range.start);
    }
    return '${_formatDay(range.start)} – ${_formatDay(range.end)}';
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

/// Students plus their aggregated totals, resolved together so the list never
/// renders half-loaded.
class _ReportData {
  const _ReportData({
    required this.students,
    required this.report,
    required this.subjects,
  });

  final List<StudentEntry> students;
  final PointReport report;

  /// Column subjects for this period, before the user's choice is applied.
  final List<String> subjects;
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
        final groups = snapshot.data ?? const <GroupEntry>[];

        final sorted = [...groups]
          ..sort((a, b) {
            final byGrade = a.grade.compareTo(b.grade);
            return byGrade != 0 ? byGrade : a.className.compareTo(b.className);
          });

        return DropdownButtonFormField<GroupEntry>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Class',
            prefixIcon: const Icon(Icons.school_rounded),
            hintText: loading
                ? 'Loading classes…'
                : snapshot.hasError
                ? 'Classes unavailable'
                : sorted.isEmpty
                ? 'No classes found'
                : 'Choose a class',
          ),
          items: [
            for (final group in sorted)
              DropdownMenuItem(value: group, child: Text(group.classPair)),
          ],
          onChanged: loading || sorted.isEmpty ? null : onSelected,
        );
      },
    );
  }
}

class _DateModeSelector extends StatelessWidget {
  const _DateModeSelector({required this.mode, required this.onChanged});

  final PointReportDateMode mode;
  final ValueChanged<PointReportDateMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<PointReportDateMode>(
      segments: const [
        ButtonSegment(value: PointReportDateMode.weekly, label: Text('Weekly')),
        ButtonSegment(value: PointReportDateMode.single, label: Text('Day')),
        ButtonSegment(value: PointReportDateMode.range, label: Text('Range')),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _PeriodStepper extends StatelessWidget {
  const _PeriodStepper({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous',
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({
    required this.future,
    required this.classLabel,
    required this.periodLabel,
    required this.sort,
    required this.descending,
    required this.onSortChanged,
    required this.onRetry,
    required this.tableKey,
    required this.columns,
    required this.onDataChanged,
  });

  final Future<_ReportData>? future;
  final String classLabel;
  final String periodLabel;
  final PointReportSort sort;
  final bool descending;
  final void Function(PointReportSort column) onSortChanged;
  final VoidCallback onRetry;

  /// Wraps the full-width table so the export can capture it.
  final GlobalKey tableKey;

  final PointReportColumns columns;

  /// Reports the resolved data upward so the share button knows whether there
  /// is anything to capture.
  final ValueChanged<_ReportData?> onDataChanged;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_ReportData>(
      future: future,
      builder: (context, snapshot) {
        if (future == null ||
            snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 220,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onDataChanged(null),
          );
          return _ReportError(
            message: snapshot.error is AuthFailure
                ? (snapshot.error as AuthFailure).message
                : 'Unable to load the point report right now.',
            onRetry: onRetry,
          );
        }

        final data = snapshot.data;
        if (data == null || data.students.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => onDataChanged(null),
          );
          return _Notice(
            text: 'No students found for this class.',
            icon: Icons.person_off_rounded,
          );
        }

        WidgetsBinding.instance.addPostFrameCallback(
          (_) => onDataChanged(data),
        );

        // The RepaintBoundary sits *inside* the scroll view, wrapping the
        // full-width table. Its own layer therefore covers every column, so a
        // capture yields the whole grid even though the screen only shows the
        // part scrolled into view — the ancestor's clip does not apply.
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: RepaintBoundary(
            key: tableKey,
            child: PointReportTable(
              students: data.students,
              report: data.report,
              subjects: data.subjects,
              columns: columns,
              classLabel: classLabel,
              periodLabel: periodLabel,
              sort: sort,
              descending: descending,
              onSortChanged: onSortChanged,
            ),
          ),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.softBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: colors.softText),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.softText),
          ),
        ],
      ),
    );
  }
}

class _ReportError extends StatelessWidget {
  const _ReportError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.mutedText),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
