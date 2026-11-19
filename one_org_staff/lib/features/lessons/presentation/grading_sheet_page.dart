import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../auth/domain/auth_repository.dart';
import '../application/grading_sheet_controller.dart';
import '../application/lessons_outbox.dart';
import '../domain/lesson_grading.dart';
import '../domain/lessons_repository.dart';
import 'attendance_step.dart';
import 'scores_step.dart';
import 'uploads_sheet.dart';
import 'package:one_org_staff/shared/app_toast.dart';

enum _Step { attendance, scores }

String _shortTime(String? time) =>
    time == null || time.length < 5 ? '' : time.substring(0, 5);

/// A lesson's two steps: attendance first, then scores for those who came.
class GradingSheetPage extends StatefulWidget {
  const GradingSheetPage({
    super.key,
    required this.repository,
    required this.outbox,
    required this.lessonId,
    this.fallbackTitle,
    this.fallbackSubject,
  });

  final LessonsRepository repository;
  final LessonsOutbox outbox;
  final int lessonId;
  final String? fallbackTitle;
  final String? fallbackSubject;

  @override
  State<GradingSheetPage> createState() => _GradingSheetPageState();
}

class _GradingSheetPageState extends State<GradingSheetPage> {
  late final GradingSheetController _sheet = GradingSheetController(
    repository: widget.repository,
    outbox: widget.outbox,
    lessonId: widget.lessonId,
  )..load();

  _Step _step = _Step.attendance;
  bool _expandAll = false;

  @override
  void dispose() {
    _sheet.dispose();
    super.dispose();
  }

  void _toast(String message, ToastKind kind) =>
      showToast(context, message, kind: kind);

  String _errorText(Object error) => error is AuthFailure
      ? error.message
      : AppLocalizations.of(context).loadLessonsFailed;

  void _goToScores() {
    if (!_sheet.readOnly && _sheet.attendanceDirty) {
      _sheet.saveAttendance();
      _toast(AppLocalizations.of(context).attendanceSaved, ToastKind.success);
    }
    setState(() => _step = _Step.scores);
  }

  void _save() {
    final l = AppLocalizations.of(context);
    if (_sheet.problems.isNotEmpty) {
      _toast(l.fixHighlightedRows, ToastKind.warning);
      return;
    }
    _sheet.save();
    _toast(l.scoresSaved, ToastKind.success);
  }

  Future<void> _confirmLeave() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.unsavedTitle),
        content: Text(l.unsavedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l.stay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l.leave),
          ),
        ],
      ),
    );
    if (leave == true && mounted) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _sheet,
      builder: (context, _) {
        return PopScope(
          canPop: !_sheet.hasUnsavedEdits,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  _tabs(context),
                  ..._columnHeader(),
                  ..._banners(context),
                  Expanded(child: _body(context)),
                  if (_hasRoster) _bottomBar(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  bool get _hasRoster =>
      !_sheet.loading && _sheet.loadError == null && _sheet.students.isNotEmpty;

  Widget _header(BuildContext context) {
    final lesson = _sheet.lesson;
    final colors = appColorsOf(context);
    final title = lesson?.classLabel ?? widget.fallbackTitle ?? '';
    final subject = lesson?.subject ?? widget.fallbackSubject;
    final locale = Localizations.localeOf(context).toString();
    final dateLine = [
      if (lesson?.date != null) DateFormat.MMMEd(locale).format(lesson!.date!),
      if (lesson?.room != null) lesson!.room!,
    ].join(' · ');
    final hasTime = lesson?.startTime != null;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: Text(
              subject == null || subject.isEmpty ? title : '$title · $subject',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8, right: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (hasTime)
                  Text(
                    '${_shortTime(lesson!.startTime)}–${_shortTime(lesson.endTime)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (dateLine.isNotEmpty)
                  Text(
                    dateLine,
                    style: TextStyle(fontSize: 12, color: colors.mutedText),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabs(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);

    Widget tab(_Step step, String number, String label) {
      final active = _step == step;
      final blocked =
          step == _Step.scores && _sheet.lateMissingCount > 0 && !active;
      return Expanded(
        child: InkWell(
          onTap: blocked
              ? null
              : () {
                  if (step == _Step.scores && _step != _Step.scores) {
                    _goToScores();
                  } else {
                    setState(() => _step = step);
                  }
                },
          child: Opacity(
            opacity: blocked ? 0.4 : 1,
            child: Container(
              height: 38,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    width: 2.5,
                    color: active ? colors.accent.solid : Colors.transparent,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: active ? colors.accent.solid : colors.line,
                    child: Text(
                      number,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: active ? Colors.white : colors.mutedText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: active ? colors.softText : colors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.line)),
      ),
      child: Row(
        children: [
          tab(_Step.attendance, '1', l.attendance),
          tab(_Step.scores, '2', l.scores),
        ],
      ),
    );
  }

  List<Widget> _columnHeader() {
    if (!_hasRoster) return const [];
    return [
      _step == _Step.attendance
          ? AttendanceHeader(sheet: _sheet)
          : ScoresLegend(sheet: _sheet),
    ];
  }

  List<Widget> _banners(BuildContext context) {
    final lesson = _sheet.lesson;
    if (lesson == null) return const [];
    final l = AppLocalizations.of(context);
    if (lesson.isCancelled) {
      return [
        _Banner(
          text: lesson.cancelReason == null
              ? l.lessonCancelledBanner
              : l.lessonCancelledReasonBanner(lesson.cancelReason!),
        ),
      ];
    }
    if (_sheet.windowClosed) return [_Banner(text: l.windowClosedBanner)];
    return const [];
  }

  Widget _body(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_sheet.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _sheet.loadError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorText(error), textAlign: TextAlign.center),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: _sheet.load, child: Text(l.retry)),
            ],
          ),
        ),
      );
    }
    if (_sheet.students.isEmpty) {
      return Center(child: Text(l.noStudents, textAlign: TextAlign.center));
    }
    return _step == _Step.attendance
        ? AttendanceStep(sheet: _sheet)
        : ScoresStep(sheet: _sheet, expandAll: _expandAll);
  }

  Widget _bottomBar(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    const red = Color(0xFFDC2626);

    Widget primary(String label, VoidCallback? onPressed, IconData icon) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent.solid,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 44),
          padding: const EdgeInsets.symmetric(horizontal: 18),
        ),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }

    Widget round(IconData icon, String tooltip, VoidCallback onPressed) {
      return IconButton.outlined(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
      );
    }

    final upload = _uploadStatus(l);
    final List<Widget> children;
    if (_step == _Step.attendance) {
      final lateMissing = _sheet.lateMissingCount;
      children = [
        Expanded(
          child: lateMissing > 0
              ? _status(l.addMinutesForLate(lateMissing), color: red)
              : upload ??
                    (!_sheet.attendanceDirty && _sheet.attendanceStored
                        ? _status(
                            '✓ ${l.attendanceSaved}',
                            color: const Color(0xFF047857),
                          )
                        : _status(l.studentsCount(_sheet.students.length))),
        ),
        primary(
          _sheet.attendanceDirty && !_sheet.readOnly ? l.saveAndNext : l.next,
          lateMissing > 0 ? null : _goToScores,
          Icons.arrow_forward_rounded,
        ),
      ];
    } else {
      final problemCount = _sheet.problems.length;
      final dirty = _sheet.dirtyCount;
      children = [
        round(
          Icons.arrow_back_rounded,
          l.attendance,
          () => setState(() => _step = _Step.attendance),
        ),
        round(
          _expandAll ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
          _expandAll ? l.foldAll : l.unfoldAll,
          () => setState(() => _expandAll = !_expandAll),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: dirty == 0
              ? upload ??
                    (_sheet.readOnly
                        ? const SizedBox.shrink()
                        : _status(l.saved))
              : !_sheet.scoresTouched && !_sheet.readOnly
              ? const SizedBox.shrink()
              : problemCount > 0
              ? _status(l.needFixing(problemCount), color: red)
              : _status(l.toSave(dirty)),
        ),
        if (!_sheet.readOnly) ...[
          if (!_sheet.scoresTouched)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
                onPressed: () => Navigator.maybePop(context),
                child: Text(l.skip),
              ),
            ),
          primary(l.save, dirty == 0 ? null : _save, Icons.save_rounded),
        ],
      ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colors.line)),
      ),
      child: Row(children: children),
    );
  }

  /// Saves of this lesson still on the phone, or refused: tap for the list.
  Widget? _uploadStatus(AppLocalizations l) {
    final refused = _sheet.rejectedCount;
    final waiting = _sheet.waitingCount;
    if (refused == 0 && waiting == 0) return null;
    final color = refused > 0
        ? const Color(0xFFDC2626)
        : const Color(0xFFB45309);
    return InkWell(
      onTap: () => showUploadsSheet(context, widget.outbox),
      child: Row(
        children: [
          Icon(
            refused > 0
                ? Icons.warning_amber_rounded
                : Icons.cloud_upload_outlined,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: _status(
              refused > 0
                  ? l.notAcceptedCount(refused)
                  : l.waitingToUpload(waiting),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _status(String text, {Color? color}) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        height: 1.15,
        fontWeight: color == null ? FontWeight.w400 : FontWeight.w600,
        color: color ?? appColorsOf(context).mutedText,
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.softBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: colors.mutedText),
          const SizedBox(width: 7),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// The colour of a score: green from 80, amber from 40, red below.
Color scoreColor(double score) {
  if (score >= 80) return const Color(0xFF047857);
  if (score >= lowScoreThreshold) return const Color(0xFFB45309);
  return const Color(0xFFB91C1C);
}
