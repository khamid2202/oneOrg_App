import 'dart:async';

import 'package:flutter/foundation.dart';

import '../domain/lesson_grading.dart';
import '../domain/lessons_repository.dart';
import 'lessons_outbox.dart';

enum SheetProblem { minutesMissing, attendanceFirst, commentRequired }

/// The server's rows with this lesson's saves still on the phone laid over
/// them, so the sheet shows what the teacher saved before it has uploaded.
List<SheetStudent> withWaitingSaves(
  List<SheetStudent> rows,
  List<OutboxEntry> waiting,
) {
  final byId = {for (final row in rows) row.studentId: row};
  for (final entry in waiting) {
    switch (entry.kind) {
      case UploadKind.attendance:
        for (final mark in entry.body['marks'] as List) {
          byId[mark['student_id']]?.applyMark(
            mark['status'] as String,
            mark['minutes_late'] as int?,
          );
        }
      case UploadKind.grades:
        for (final grade in entry.body['grades'] as List) {
          final row = byId[grade['student_id']];
          if (row == null) continue;
          for (final field in teacherScoreFields) {
            if ((grade as Map).containsKey(field)) {
              row.scores[field] = grade[field] as int?;
            }
          }
          if ((grade as Map).containsKey('comment')) {
            row.comment = grade['comment'] as String? ?? '';
          }
        }
      case UploadKind.behavior:
        break; // Listed through marksOf.
    }
  }
  return rows;
}

/// One lesson's sheet: the server's rows plus a local draft per student.
/// Saving never waits for the network: changes go to the [LessonsOutbox] and
/// the sheet shows them as saved at once.
class GradingSheetController extends ChangeNotifier {
  GradingSheetController({
    required LessonsRepository repository,
    required LessonsOutbox outbox,
    required this.lessonId,
    DateTime Function()? clock,
  }) : _repository = repository,
       _outbox = outbox,
       _clock = clock ?? DateTime.now {
    _outbox.addListener(_outboxChanged);
    _uploaded = _outbox.uploaded.listen((id) {
      if (id == lessonId && _outbox.waitingFor(id).isEmpty) {
        unawaited(_refreshFromServer());
      }
    });
  }

  final LessonsRepository _repository;
  final LessonsOutbox _outbox;
  final int lessonId;
  final DateTime Function() _clock;
  late final StreamSubscription<int> _uploaded;

  LessonDetail? _lesson;
  List<SheetStudent> _students = const [];
  Map<int, GradeDraft> _drafts = const {};
  bool _loading = true;
  bool _edited = false;
  bool _disposed = false;
  Object? _loadError;

  BehaviorReasons _reasons = const BehaviorReasons();
  Map<String, List<BehaviorMark>> _marksByStudent = const {};

  LessonDetail? get lesson => _lesson;
  List<SheetStudent> get students => _students;
  bool get loading => _loading;
  Object? get loadError => _loadError;
  GradeDraft? draftOf(int studentId) => _drafts[studentId];

  /// The teacher changed something since the last save. Prefilled defaults
  /// don't count, so opening and leaving a lesson doesn't warn.
  bool get hasUnsavedEdits => _edited;

  int get waitingCount => _outbox.waitingFor(lessonId).length;
  int get rejectedCount => _outbox.rejectedFor(lessonId);

  bool get canGiveBehavior =>
      !_reasons.isEmpty && !(_lesson?.isCancelled ?? false);
  BehaviorReasons get behaviorReasons => _reasons;

  /// What the server has, then marks still on their way.
  List<BehaviorMark> marksOf(int studentId) => [
    ...?_marksByStudent['$studentId'],
    for (final entry in _outbox.waitingFor(lessonId))
      if (entry.kind == UploadKind.behavior &&
          (entry.body['studentIds'] as List).contains('$studentId'))
        BehaviorMark(
          id: entry.body['requestId'] as String,
          studentId: '$studentId',
          type: entry.body['type'] as String,
          reasonLabel: _reasonLabel(entry),
          comment: entry.body['comment'] as String?,
        ),
  ];

  String? _reasonLabel(OutboxEntry entry) {
    final ids = entry.body['reasonIds'] as List;
    if (ids.isEmpty) return null;
    return _reasons
        .of(entry.body['type'] as String)
        .where((reason) => reason.id == ids.first)
        .firstOrNull
        ?.label;
  }

  bool get windowClosed {
    final closes = editWindowClosesAt(_lesson?.date, _lesson?.endTime);
    return closes != null && _clock().isAfter(closes);
  }

  bool get readOnly => (_lesson?.isCancelled ?? false) || windowClosed;

  void _outboxChanged() {
    if (!_disposed) notifyListeners();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    _loading = true;
    _loadError = null;
    _notify();
    try {
      final sheet = await _repository.getSheet(lessonId);
      _lesson = sheet.lesson;
      // Nothing is filled in on open: the teacher marks and scores (one by
      // one, or everybody from the header checkboxes).
      _show(_overlaid(sheet.students));
    } catch (error) {
      _loadError = error;
    }
    _loading = false;
    _notify();
    await _loadBehavior();
  }

  List<SheetStudent> _overlaid(List<SheetStudent> rows) =>
      withWaitingSaves(rows, _outbox.waitingFor(lessonId));

  Future<void> _loadBehavior() async {
    try {
      _reasons = await _repository.getBehaviorReasons();
      await _reloadMarks();
    } catch (_) {
      // Without access to behavior the sheet just has no thumbs.
      _reasons = const BehaviorReasons();
    }
    _notify();
  }

  Future<void> _reloadMarks() async {
    final byStudent = <String, List<BehaviorMark>>{};
    for (final mark in await _repository.getBehaviorMarks(lessonId)) {
      byStudent.putIfAbsent(mark.studentId, () => []).add(mark);
    }
    _marksByStudent = byStudent;
  }

  /// Everything of this lesson has uploaded: take the server's own copy, unless
  /// the teacher has started changing something again.
  Future<void> _refreshFromServer() async {
    try {
      await _reloadMarks();
      if (!_edited) {
        final sheet = await _repository.getSheet(lessonId);
        if (!_edited && !_disposed) {
          _lesson = sheet.lesson;
          _show(_overlaid(sheet.students));
        }
      }
    } catch (_) {
      // What's on screen is already what the teacher saved.
    }
    _notify();
  }

  void _show(List<SheetStudent> rows) {
    _students = rows;
    _drafts = {for (final row in rows) row.studentId: row.toDraft()};
  }

  /// Changes one row. Everything on screen goes through here.
  void update(int studentId, void Function(GradeDraft draft) change) {
    final draft = _drafts[studentId];
    if (draft == null) return;
    change(draft);
    _edited = true;
    notifyListeners();
  }

  int countMarked(String status) =>
      _drafts.values.where((draft) => draft.status == status).length;

  /// Every row was created before grading v2 (version 1).
  bool get allOldGrading =>
      _drafts.isNotEmpty && _drafts.values.every((draft) => draft.version == 1);

  int get unmarkedCount =>
      _drafts.values.where((draft) => draft.status == null).length;

  void _updateEvery(
    void Function(GradeDraft draft, GradeDraft original) change,
  ) {
    for (final row in _students) {
      change(_drafts[row.studentId]!, _originalOf(row));
    }
    _edited = true;
    notifyListeners();
  }

  /// Header checkbox: everybody gets [status] (present or absent).
  void markAll(String status) => _updateEvery((draft, _) {
    if (draft.status != status) draft.mark(status);
  });

  /// Unticking it: those marked [status] go back to what the server holds,
  /// which is "not marked" unless attendance was already saved.
  void unmarkAll(String status) => _updateEvery((draft, original) {
    if (draft.status != status) return;
    if (original.status == null) {
      draft.clearMark();
    } else {
      draft.mark(
        original.status!,
        minutes: original.minutesLate,
        keepMinutes: false,
      );
    }
  });

  Iterable<GradeDraft> _gradableFor(String field) => _drafts.values.where(
    (draft) => isGradable(draft.status) && appliesTo(field, draft.version),
  );

  /// Present / late students [field] applies to.
  int gradableCount(String field) => _gradableFor(field).length;

  /// Of those, how many have the category's usual mark.
  int givenCount(String field) => _gradableFor(field)
      .where((draft) => draft.scores[field] == startFor(field, draft.version))
      .length;

  /// Header checkbox, scores: every present / late student gets the usual
  /// mark (full marks).
  void fillAll(String field) => _updateEvery((draft, _) {
    if (isGradable(draft.status) && appliesTo(field, draft.version)) {
      draft.scores[field] = startFor(field, draft.version);
    }
  });

  /// Unticking it: the category goes back to what the server holds.
  void unfillAll(String field) => _updateEvery((draft, original) {
    if (isGradable(draft.status)) draft.scores[field] = original.scores[field];
  });

  GradeDraft _originalOf(SheetStudent row) => row.toDraft();

  List<int> get _changedMarks => [
    for (final row in _students)
      if (_drafts[row.studentId]!.status != null &&
          _drafts[row.studentId]!.attendanceDiffers(_originalOf(row)))
        row.studentId,
  ];

  List<int> get _changedGrades => [
    for (final row in _students)
      if (_drafts[row.studentId]!.gradesDiffer(_originalOf(row))) row.studentId,
  ];

  Set<int> get _dirtyIds => {..._changedMarks, ..._changedGrades};

  int get dirtyCount => _dirtyIds.length;
  bool get attendanceDirty => _changedMarks.isNotEmpty;
  bool get attendanceStored => _students.any((row) => row.status != null);

  /// A score or comment changed. Nothing touched means the teacher may skip
  /// grading; attendance is saved on its own.
  bool get scoresTouched => _students.any((row) {
    final draft = _drafts[row.studentId]!;
    final original = _originalOf(row);
    if (draft.comment.trim() != original.comment.trim()) return true;
    if (!isGradable(draft.status)) return false;
    return teacherScoreFields.any(
      (field) => draft.scores[field] != original.scores[field],
    );
  });

  /// What the server would refuse, per student, before anything is sent.
  Map<int, SheetProblem> get problems {
    final found = <int, SheetProblem>{};
    final byId = {for (final row in _students) row.studentId: row};
    for (final id in _dirtyIds) {
      final draft = _drafts[id]!;
      if (draft.status == statusLate) {
        final minutes = draft.minutesLate;
        if (minutes == null || minutes < 1 || minutes > 600) {
          found[id] = SheetProblem.minutesMissing;
          continue;
        }
      }
      final original = byId[id]!.toDraft();
      final gradedNow = teacherScoreFields.any(
        (field) => draft.scores[field] != original.scores[field],
      );
      if (gradedNow && draft.status == null) {
        found[id] = SheetProblem.attendanceFirst;
      } else if (draft.needsComment) {
        found[id] = SheetProblem.commentRequired;
      }
    }
    return found;
  }

  int get lateMissingCount => problems.values
      .where((problem) => problem == SheetProblem.minutesMissing)
      .length;

  String get _label {
    final lesson = _lesson;
    return [
      lesson?.classLabel,
      lesson?.subject,
    ].whereType<String>().join(' · ');
  }

  void _queueMarks() {
    final ids = _changedMarks;
    if (ids.isEmpty) return;
    _outbox.enqueue(
      kind: UploadKind.attendance,
      lessonId: lessonId,
      label: _label,
      body: {
        'marks': [
          for (final id in ids)
            {
              'student_id': id,
              'status': _drafts[id]!.status,
              if (_drafts[id]!.status == statusLate &&
                  _drafts[id]!.minutesLate != null)
                'minutes_late': _drafts[id]!.minutesLate,
            },
        ],
      },
    );
    for (final row in _students) {
      if (ids.contains(row.studentId)) {
        final draft = _drafts[row.studentId]!;
        row.applyMark(draft.status!, draft.minutesLate);
      }
    }
  }

  /// Step 1 on its own, so attendance is kept even if the teacher never
  /// grades. Scores already given stay as drafts for step 2.
  void saveAttendance() {
    _queueMarks();
    _edited = scoresTouched;
    notifyListeners();
  }

  /// Step 2: changed marks first, then changed scores and comments.
  void save() {
    _queueMarks();

    final savedAt = _clock().toUtc().toIso8601String();
    final grades = <Map<String, dynamic>>[];
    for (final row in _students) {
      final draft = _drafts[row.studentId]!;
      final original = _originalOf(row);
      final entry = <String, dynamic>{};
      // Absent and excused rows stay at 0; only their comment can change.
      if (isGradable(draft.status)) {
        for (final field in teacherScoreFields) {
          if (draft.scores[field] != original.scores[field]) {
            entry[field] = draft.scores[field];
            row.scores[field] = draft.scores[field];
          }
        }
      }
      final comment = draft.comment.trim();
      if (comment != original.comment.trim()) {
        entry['comment'] = comment.isEmpty ? null : comment;
        row.comment = comment;
      }
      if (entry.isNotEmpty) {
        grades.add({
          'student_id': row.studentId,
          ...entry,
          'client_saved_at': savedAt,
        });
      }
    }

    if (grades.isNotEmpty) {
      _outbox.enqueue(
        kind: UploadKind.grades,
        lessonId: lessonId,
        label: _label,
        body: {'grades': grades},
      );
    }
    _edited = false;
    notifyListeners();
  }

  /// Behavior marks are events of their own: they leave at once, outside the
  /// sheet's Save, and the grading window doesn't lock them.
  void addBehaviorMark({
    required int studentId,
    required String type,
    required List<String> reasonIds,
    required String comment,
  }) {
    _outbox.enqueue(
      kind: UploadKind.behavior,
      lessonId: lessonId,
      label: _label,
      body: {
        'studentIds': ['$studentId'],
        'type': type,
        'reasonIds': reasonIds,
        'comment': comment,
        'requestId': newRequestId(),
        'lessonInstanceId': lessonId,
      },
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _outbox.removeListener(_outboxChanged);
    _uploaded.cancel();
    super.dispose();
  }
}
