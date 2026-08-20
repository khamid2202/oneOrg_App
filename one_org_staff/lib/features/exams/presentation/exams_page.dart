import 'package:flutter/material.dart';

import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/colleagues/domain/colleagues_repository.dart';
import 'package:one_org_staff/features/exams/domain/exams_repository.dart';
import 'package:one_org_staff/features/timetable/time_table_repository.dart';

import 'create_exam_view.dart';
import 'score_exam_view.dart';

/// Every call the Exams screens make, bundled so the landing page wires the
/// feature up once instead of threading fifteen callbacks through each view.
class ExamsApi {
  const ExamsApi({
    required this.loadProfile,
    required this.loadAcademicYears,
    required this.loadExamPeriods,
    required this.loadExams,
    required this.createExam,
    required this.deleteExam,
    required this.loadSubjects,
    required this.loadGroups,
    required this.loadColleagues,
    required this.loadTimetable,
    required this.loadStudentsForGroup,
    required this.loadExamResults,
    required this.createExamResultsBulk,
    required this.updateExamResult,
    required this.deleteExamResult,
  });

  final Future<AppUserProfile> Function() loadProfile;
  final Future<List<AcademicYearEntry>> Function() loadAcademicYears;
  final Future<List<ExamPeriod>> Function({bool? isActive, int? academicYearId})
  loadExamPeriods;
  final Future<List<Exam>> Function({int? examPeriodId}) loadExams;
  final Future<Exam> Function({
    required int examPeriodId,
    required int subjectId,
    required List<int> groupIds,
    required int maxScore,
  })
  createExam;
  final Future<void> Function(int examId) deleteExam;
  final Future<List<SubjectEntry>> Function() loadSubjects;
  final Future<List<GroupEntry>> Function({int? academicYearId}) loadGroups;
  final Future<List<Colleague>> Function() loadColleagues;
  final Future<List<TimetableLesson>> Function({int? academicYearId})
  loadTimetable;
  final Future<List<StudentEntry>> Function(int groupId, {bool includeContacts})
  loadStudentsForGroup;
  final Future<List<ExamResult>> Function(int examId) loadExamResults;
  final Future<void> Function(List<ExamResultDraft> drafts)
  createExamResultsBulk;
  final Future<void> Function({required int resultId, required double score})
  updateExamResult;
  final Future<void> Function(int resultId) deleteExamResult;

  /// The academic year the API marks active, falling back to the first listed.
  ///
  /// Never hardcoded: a request scoped to the wrong year comes back empty and
  /// the page looks broken rather than misconfigured.
  Future<int?> resolveAcademicYearId() async {
    try {
      final years = await loadAcademicYears();
      if (years.isEmpty) {
        return null;
      }
      return years
          .firstWhere((year) => year.isActive, orElse: () => years.first)
          .id;
    } catch (_) {
      return null;
    }
  }
}

/// Which of the two exam workflows is showing.
enum ExamsSection { hub, create, score }

/// Exams — a port of the web app's `features/exams`.
///
/// The web splits the feature across an `ExamsHub` chooser and two routed
/// pages. There is no router in this shell, so the same three screens live
/// here as one page with an internal section, back-swipeable like My Class.
class ExamsPage extends StatefulWidget {
  const ExamsPage({super.key, required this.api, this.initialSection});

  final ExamsApi api;

  /// Injected by tests so they can start on a workflow directly.
  final ExamsSection? initialSection;

  @override
  State<ExamsPage> createState() => _ExamsPageState();
}

class _ExamsPageState extends State<ExamsPage> {
  static const _pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 24);

  late ExamsSection _section = widget.initialSection ?? ExamsSection.hub;

  /// Set by the scoring view while a grading sheet has unsaved edits, so a
  /// back swipe out of the section asks before discarding them.
  Future<bool> Function()? _confirmLeave;

  Future<void> _goToHub() async {
    final confirm = _confirmLeave;
    if (confirm != null && !await confirm()) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _confirmLeave = null;
      _section = ExamsSection.hub;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SwipeBackDetector(
      enabled: _section != ExamsSection.hub,
      onSwipeBack: _goToHub,
      underneathChild: Padding(padding: _pagePadding, child: _buildHub(context)),
      child: _section == ExamsSection.hub
          ? const SizedBox.shrink()
          : Padding(padding: _pagePadding, child: _buildSection()),
    );
  }

  Widget _buildSection() {
    switch (_section) {
      case ExamsSection.create:
        return CreateExamView(api: widget.api, onBack: _goToHub);
      case ExamsSection.score:
        return ScoreExamView(
          api: widget.api,
          onBack: _goToHub,
          onUnsavedGuardChanged: (confirm) => _confirmLeave = confirm,
        );
      case ExamsSection.hub:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHub(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Exams',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Choose what you want to do.',
          style: theme.textTheme.bodyLarge?.copyWith(color: colors.mutedText),
        ),
        const SizedBox(height: 20),
        _HubCard(
          title: 'Create a new exam',
          description:
              'Set up an exam for a subject and class within an exam period.',
          icon: Icons.note_add_rounded,
          onTap: () => setState(() => _section = ExamsSection.create),
        ),
        const SizedBox(height: 12),
        _HubCard(
          title: 'Score the exam',
          description:
              "Open a class exam and enter each student's result, question by "
              'question.',
          icon: Icons.fact_check_rounded,
          onTap: () => setState(() => _section = ExamsSection.score),
        ),
      ],
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: colors.gradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.mutedText,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Open',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.softText,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: colors.softText,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
