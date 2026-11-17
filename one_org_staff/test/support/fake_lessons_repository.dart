import 'package:one_org_staff/features/grades/domain/gradebook.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';

/// An in-memory teaching day that records what the app sends.
class FakeLessonsRepository implements LessonsRepository {
  FakeLessonsRepository({
    this.day = const LessonDay(lessons: []),
    this.periods = const [],
    GradingSheet? sheet,
    this.reasons = const BehaviorReasons(),
  }) : sheet =
           sheet ??
           GradingSheet(lesson: const LessonDetail(id: 1), students: const []);

  LessonDay day;
  List<BellPeriod> periods;
  GradingSheet sheet;
  BehaviorReasons reasons;
  List<RecentGrade> recentGrades = const [];
  List<GradebookPair> gradebookPairs = const [];
  Gradebook gradebook = const Gradebook();
  final List<(int, int)> gradebookLoads = [];
  BehaviorRoster roster = const BehaviorRoster();
  List<BehaviorHistoryEntry> history = const [];
  BehaviorStatistics statistics = const BehaviorStatistics();
  int historyLoads = 0;

  /// Thrown by [upload] while set: stands in for no connection or a refusal.
  Exception? uploadError;

  int dayLoads = 0;
  bool cleared = false;
  final List<UploadKind> uploadOrder = [];
  final List<List<Map<String, dynamic>>> attendanceSaves = [];
  final List<List<Map<String, dynamic>>> gradeSaves = [];
  final List<Map<String, dynamic>> behaviorSaves = [];
  final List<BehaviorMark> behaviorMarks = [];

  @override
  Future<LessonDay> getDay(DateTime date) async {
    dayLoads += 1;
    return day;
  }

  @override
  Future<List<BellPeriod>> getPeriods({
    int? academicYearId,
    required DateTime date,
  }) async => periods;

  @override
  Future<GradingSheet> getSheet(int lessonId) async => sheet;

  @override
  Future<List<RecentGrade>> getRecentGrades({int limit = 3}) async =>
      recentGrades;

  @override
  Future<void> upload(
    UploadKind kind,
    int lessonId,
    Map<String, dynamic> body,
  ) async {
    final error = uploadError;
    if (error != null) throw error;
    uploadOrder.add(kind);
    List<Map<String, dynamic>> rows(String field) =>
        (body[field] as List).cast<Map<String, dynamic>>().toList();
    switch (kind) {
      case UploadKind.attendance:
        attendanceSaves.add(rows('marks'));
      case UploadKind.grades:
        gradeSaves.add(rows('grades'));
      case UploadKind.behavior:
        behaviorSaves.add(body);
        behaviorMarks.add(
          BehaviorMark(
            id: body['requestId'] as String,
            studentId: (body['studentIds'] as List).first as String,
            type: body['type'] as String,
          ),
        );
    }
  }

  @override
  Future<void> clearOffline() async => cleared = true;

  @override
  Future<List<GradebookPair>> getMyGradebooks({int? academicYearId}) async =>
      gradebookPairs;

  @override
  Future<Gradebook> getGradebook(int groupId, int subjectId) async {
    gradebookLoads.add((groupId, subjectId));
    return gradebook;
  }

  @override
  Future<BehaviorReasons> getBehaviorReasons() async => reasons;

  @override
  Future<BehaviorRoster> getBehaviorRoster() async => roster;

  @override
  Future<List<BehaviorHistoryEntry>> getBehaviorHistory() async {
    historyLoads += 1;
    return history;
  }

  @override
  Future<BehaviorStatistics> getBehaviorStatistics({
    String? from,
    String? to,
  }) async => statistics;

  @override
  Future<List<BehaviorMark>> getBehaviorMarks(int lessonId) async =>
      behaviorMarks;
}
