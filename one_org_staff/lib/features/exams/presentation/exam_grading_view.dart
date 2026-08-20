import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/exams/domain/exams_repository.dart';

import 'exam_common.dart';
import 'exams_page.dart';

/// The score sheet for one class sitting one exam — a port of the web's
/// `ExamGradingView`.
///
/// Everything is edited against a draft and written on Save, exactly like the
/// web: new scores go out as one bulk create, changed ones as individual
/// patches (`PATCH /exam-results/bulk` rejects the array payload), and cleared
/// ones as deletes. Missing scores start at 0 so an untouched student is still
/// included on the first save.
class ExamGradingView extends StatefulWidget {
  const ExamGradingView({
    super.key,
    required this.api,
    required this.exam,
    required this.groupId,
    required this.className,
    required this.subjectName,
    required this.onBack,
    required this.onDirtyChanged,
  });

  final ExamsApi api;
  final Exam exam;
  final int groupId;
  final String className;
  final String subjectName;
  final VoidCallback onBack;

  /// Reports whether the sheet holds unsaved edits, so the screens above can
  /// warn before a back swipe throws them away.
  final ValueChanged<bool> onDirtyChanged;

  @override
  State<ExamGradingView> createState() => ExamGradingViewState();
}

class ExamGradingViewState extends State<ExamGradingView> {
  late Future<List<StudentEntry>> _loadFuture;

  /// Scores already in the database, keyed by enrollment id.
  Map<int, ExamResult> _saved = const {};

  /// The edited values. A `null` entry is a score the teacher cleared.
  Map<int, double?> _drafts = {};

  List<StudentEntry> _students = const [];
  bool _saving = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    // The sheet is going away, so nothing above it should still be guarding
    // against its unsaved edits.
    widget.onDirtyChanged(false);
    super.dispose();
  }

  Future<List<StudentEntry>> _load() async {
    final results = await Future.wait([
      widget.api.loadStudentsForGroup(widget.groupId),
      widget.api.loadExamResults(widget.exam.id),
    ]);

    final students = (results[0] as List<StudentEntry>)
        .where(_isEnrolled)
        .toList()
      ..sort(
        (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
      );

    _applyResults(students, results[1] as List<ExamResult>);
    return students;
  }

  /// Rebuilds the saved map and the drafts from a fresh read of the results.
  void _applyResults(List<StudentEntry> students, List<ExamResult> results) {
    final saved = <int, ExamResult>{};
    final drafts = <int, double?>{};

    for (final result in results) {
      saved[result.studentId] = result;
      drafts[result.studentId] = result.score;
    }

    // Default the rest to 0 so an untouched student is saved as a zero rather
    // than silently skipped — the same default the web writes.
    for (final student in students) {
      drafts.putIfAbsent(student.id, () => 0);
    }

    _students = students;
    _saved = saved;
    _drafts = drafts;
    _setDirty(false);
  }

  static bool _isEnrolled(StudentEntry student) {
    final status = student.status?.trim().toLowerCase();
    if (status == null || status.isEmpty) {
      return true;
    }
    return status != 'left' && status != 'inactive' && status != 'deactivated';
  }

  void _setDirty(bool dirty) {
    if (_dirty == dirty) {
      return;
    }
    _dirty = dirty;
    widget.onDirtyChanged(dirty);
  }

  /// True when any draft differs from what the database holds.
  void _recomputeDirty() {
    var dirty = false;
    for (final student in _students) {
      final saved = _saved[student.id]?.score;
      final draft = _drafts[student.id];
      if (draft != saved) {
        dirty = true;
        break;
      }
    }
    _setDirty(dirty);
  }

  void _onScoreChanged(int studentId, double? score) {
    setState(() => _drafts[studentId] = score);
    _recomputeDirty();
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Asks before losing edits. Returns true when it is safe to leave.
  Future<bool> confirmDiscard() async {
    if (!_dirty) {
      return true;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved changes that will be lost. Are you sure you want '
          'to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    return leave == true;
  }

  Future<void> _handleBack() async {
    if (await confirmDiscard()) {
      widget.onBack();
    }
  }

  Future<void> _save() async {
    // Any field still holding a rejected entry reverts on blur, so the diff
    // below never sees a number the exam would not accept.
    FocusScope.of(context).unfocus();

    final toCreate = <ExamResultDraft>[];
    final toUpdate = <MapEntry<int, double>>[];
    final toDelete = <int>[];

    for (final student in _students) {
      final saved = _saved[student.id];
      final draft = _drafts[student.id];

      if (saved == null) {
        if (draft != null) {
          toCreate.add(
            ExamResultDraft(
              studentId: student.id,
              examId: widget.exam.id,
              score: draft,
            ),
          );
        }
      } else if (draft == null) {
        toDelete.add(saved.id);
      } else if (saved.score != draft) {
        toUpdate.add(MapEntry(saved.id, draft));
      }
    }

    if (toCreate.isEmpty && toUpdate.isEmpty && toDelete.isEmpty) {
      _showMessage('No changes to save');
      return;
    }

    setState(() => _saving = true);
    try {
      await Future.wait([
        if (toCreate.isNotEmpty) widget.api.createExamResultsBulk(toCreate),
        for (final entry in toUpdate)
          widget.api.updateExamResult(resultId: entry.key, score: entry.value),
        for (final id in toDelete) widget.api.deleteExamResult(id),
      ]);

      // Re-read so the rows carry their real database ids and a second save in
      // a row patches instead of trying to create duplicates.
      final refreshed = await widget.api.loadExamResults(widget.exam.id);
      if (!mounted) {
        return;
      }
      setState(() => _applyResults(_students, refreshed));
      _showMessage('All grades saved successfully');
    } catch (error) {
      _showMessage(examErrorMessage(error, 'Failed to save grades'));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  int get _gradedCount =>
      _students.where((student) => _drafts[student.id] != null).length;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<StudentEntry>>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState != ConnectionState.done;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: _handleBack,
                  icon: const Icon(Icons.chevron_left_rounded),
                  tooltip: 'Back to exams',
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: loading || _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_rounded, size: 18),
                  label: Text(_saving ? 'Saving…' : 'Save changes'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoCard(),
            const SizedBox(height: 12),

            if (loading)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (snapshot.hasError)
              ExamErrorState(
                message: examErrorMessage(snapshot.error, 'Failed to load data'),
                onRetry: () => setState(() {
                  _loadFuture = _load();
                }),
              )
            else if (_students.isEmpty)
              const ExamNotice(
                icon: Icons.person_off_rounded,
                title: 'No active students',
                detail: 'No active students found for this class.',
              )
            else
              _buildSheet(),
          ],
        );
      },
    );
  }

  Widget _buildInfoCard() {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return ExamCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.softBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: colors.softText,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.className} — ${widget.subjectName}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ExamPill(
                      icon: Icons.emoji_events_rounded,
                      label: 'Max: ${widget.exam.maxScore}',
                    ),
                    ExamPill(
                      icon: Icons.groups_rounded,
                      muted: true,
                      label: '$_gradedCount/${_students.length} graded',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet() {
    final colors = appColorsOf(context);

    return ExamCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _students.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, thickness: 1, color: colors.line),
        itemBuilder: (context, index) {
          final student = _students[index];
          return _ScoreRow(
            // Keyed by student so a rebuild keeps each field's own text.
            key: ValueKey(student.id),
            position: index + 1,
            name: student.fullName,
            value: _drafts[student.id],
            maxScore: widget.exam.maxScore,
            enabled: !_saving,
            onChanged: (score) => _onScoreChanged(student.id, score),
            onOutOfRange: () => _showMessage(
              'Score must be between 0 and ${widget.exam.maxScore}',
            ),
          );
        },
      ),
    );
  }
}

/// One student's row: position, name and the score box.
class _ScoreRow extends StatefulWidget {
  const _ScoreRow({
    super.key,
    required this.position,
    required this.name,
    required this.value,
    required this.maxScore,
    required this.enabled,
    required this.onChanged,
    required this.onOutOfRange,
  });

  final int position;
  final String name;
  final double? value;
  final int maxScore;
  final bool enabled;
  final ValueChanged<double?> onChanged;
  final VoidCallback onOutOfRange;

  @override
  State<_ScoreRow> createState() => _ScoreRowState();
}

class _ScoreRowState extends State<_ScoreRow> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );
  late final FocusNode _focusNode = FocusNode();

  /// The text currently typed is not a score this exam accepts.
  bool _invalid = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_ScoreRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A save refreshes the values from the server; adopt them unless the field
    // is being typed in, where overwriting would fight the keyboard.
    if (widget.value != oldWidget.value && !_focusNode.hasFocus) {
      _controller.text = _format(widget.value);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Whole numbers render without a trailing `.0`, since that is what a score
  /// out of 100 looks like on paper.
  static String _format(double? value) {
    if (value == null) {
      return '';
    }
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toString();
  }

  /// Commits as the teacher types, so a score typed and then saved straight
  /// away is not lost — tapping a button does not blur a Flutter text field,
  /// and the web's blur-only commit would drop that last edit here.
  ///
  /// A value outside `0..maxScore` is never committed; the field just marks
  /// itself invalid until it is corrected or blurred.
  void _onTextChanged(String raw) {
    final text = raw.trim();

    if (text.isEmpty) {
      setState(() => _invalid = false);
      if (widget.value != null) {
        widget.onChanged(null);
      }
      return;
    }

    final parsed = double.tryParse(text);
    if (parsed == null || parsed < 0 || parsed > widget.maxScore) {
      setState(() => _invalid = true);
      return;
    }

    setState(() => _invalid = false);
    if (parsed != widget.value) {
      widget.onChanged(parsed);
    }
  }

  /// Blur is where an uncommitted, out-of-range entry is rejected — the same
  /// moment the web validates. The field snaps back to the last accepted value.
  void _onFocusChanged() {
    if (_focusNode.hasFocus || !_invalid) {
      return;
    }

    widget.onOutOfRange();
    setState(() {
      _invalid = false;
      _controller.text = _format(widget.value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final filled = _controller.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.softBg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              '${widget.position}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.softText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) => _focusNode.unfocus(),
              onChanged: _onTextChanged,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: filled ? colors.softText : null,
              ),
              decoration: InputDecoration(
                isDense: true,
                hintText: '--',
                filled: true,
                fillColor: filled ? colors.softBg : colors.card,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _invalid ? Colors.red : colors.border,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: _invalid ? Colors.red : colors.border,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
