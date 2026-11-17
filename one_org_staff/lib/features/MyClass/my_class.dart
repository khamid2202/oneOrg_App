import 'package:one_org_staff/shared/photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'class_insights.dart';
import 'class_tabs.dart';
import 'homeroom.dart';

import 'package:one_org_staff/app/theme.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:one_org_staff/shared/underline_tabs.dart';
import 'my_class_status_layouts.dart';
import 'student_info_view.dart';
import 'student_people_sync.dart';

/// The web's class tabs: one row per student, then the class's grades and
/// behavior.
enum ClassSection { students, grades, behavior }

/// Applied to each page *inside* the swipe-back detector so the detector itself
/// stays full-bleed and can catch a drag from the screen edge.
const EdgeInsets _pagePadding = EdgeInsets.fromLTRB(12, 10, 12, 16);

bool _hasLeft(StudentEntry student) =>
    student.status?.trim().toLowerCase() == 'left';

class MyClassPage extends StatefulWidget {
  const MyClassPage({
    super.key,
    required this.loadProfile,
    required this.loadGroups,
    required this.loadAcademicYears,
    required this.loadStudentsForGroup,
    required this.updatePersonDetails,
    required this.uploadPersonPicture,
    required this.removePersonPicture,
    required this.guardians,
    required this.documents,
    required this.peopleSync,
    this.insights,
    this.onMark,
    this.launchDial,
  });

  final Future<AppUserProfile> Function() loadProfile;
  final Future<List<GroupEntry>> Function({int? academicYearId}) loadGroups;
  final Future<List<AcademicYearEntry>> Function() loadAcademicYears;
  final Future<List<StudentEntry>> Function(int groupId, {bool includeContacts})
  loadStudentsForGroup;
  final Future<PersonDetails> Function({
    required int personId,
    required Map<String, String> changes,
  })
  updatePersonDetails;
  final Future<String?> Function({
    required int personId,
    required List<int> bytes,
    required String filename,
  })
  uploadPersonPicture;
  final Future<String?> Function({required int personId}) removePersonPicture;
  final StudentGuardiansApi guardians;
  final StudentDocumentsApi documents;
  final StudentPeopleSync peopleSync;

  /// Grades and behavior for the class. Without it only Students shows.
  final ClassInsightsRepository? insights;

  /// Opens the Behavior screen, for the Mark button.
  final VoidCallback? onMark;

  /// Hands a `tel:` link to the phone. Tests replace it.
  final Future<bool> Function(String uri)? launchDial;

  @override
  State<MyClassPage> createState() => _MyClassPageState();
}

class _MyClassPageState extends State<MyClassPage> {
  late Future<void> _loadFuture;

  AppUserProfile? _profile;
  GroupEntry? _myGroup;
  List<AcademicYearEntry> _years = const [];
  AcademicYearEntry? _selectedYear;

  Future<List<StudentEntry>>? _studentsFuture;

  ClassSection _section = ClassSection.students;
  StudentEntry? _selectedStudent;
  StudentTab _detailTab = StudentTab.profile;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      widget.loadProfile(),
      widget.loadAcademicYears(),
    ]);

    _profile = results[0] as AppUserProfile;
    _years = results[1] as List<AcademicYearEntry>;

    // A teacher's class is the one they have now, as on the web: no picker.
    _selectedYear =
        _years.where((year) => year.isActive).firstOrNull ?? _years.firstOrNull;

    await _resolveGroupForSelectedYear();
  }

  Future<void> _resolveGroupForSelectedYear() async {
    final groups = await widget.loadGroups(academicYearId: _selectedYear?.id);

    _myGroup = homeroomOf(groups, _profile);
    _studentsFuture = _myGroup == null
        ? null
        : widget.loadStudentsForGroup(_myGroup!.id, includeContacts: true);
  }

  void _reload() {
    setState(() {
      _myGroup = null;
      _studentsFuture = null;
      _selectedStudent = null;
      _loadFuture = _loadData();
    });
  }

  void _openStudent(StudentEntry student, StudentTab tab) => setState(() {
    _selectedStudent = student;
    _detailTab = tab;
  });

  Future<void> _dial(String phone) async {
    final uri = 'tel:${phone.replaceAll(RegExp(r'[^\d+]'), '')}';
    final launch =
        widget.launchDial ??
        (String link) =>
            launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication);
    var ok = false;
    try {
      ok = await launch(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).colleaguesCantCall),
          ),
        );
    }
  }

  /// The student's contacts with a call button each, as the web's phone
  /// button opens them. Editing lives in the profile's Guardians tab.
  void _showContacts(StudentEntry student) {
    final l = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors = appColorsOf(sheetContext);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  student.fullName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  l.classContacts,
                  style: TextStyle(fontSize: 12, color: colors.mutedText),
                ),
                const SizedBox(height: 8),
                if (student.contacts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      l.classNoContacts,
                      style: TextStyle(color: colors.mutedText),
                    ),
                  )
                else
                  for (final contact in student.contacts)
                    Padding(
                      key: ValueKey('contact-${contact.id}'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.softBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              contact.relationshipLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: colors.softText,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  contact.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  contact.phoneNumber,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.mutedText,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filled(
                            tooltip: l.colleaguesCall(contact.fullName),
                            onPressed: () => _dial(contact.phoneNumber),
                            icon: const Icon(Icons.call_rounded, size: 18),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    _openStudent(student, StudentTab.guardians);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(l.classEditContacts),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<void>(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: _pagePadding,
            child: SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: _pagePadding,
            child: ErrorLayout(
              message: snapshot.error is AuthFailure
                  ? (snapshot.error as AuthFailure).message
                  : 'Soon the content will appear',
              onRetry: _reload,
            ),
          );
        }

        // The page padding goes *inside* the detector, not around it. Wrapping
        // the detector in it inset the swipe area by 20px, so a drag from the
        // real screen edge missed this detector entirely and was claimed by the
        // landing shell's — which is why going back from a student jumped all
        // the way to the dashboard instead of to the roster.
        return SwipeBackDetector(
          enabled: _selectedStudent != null,
          onSwipeBack: () => setState(() => _selectedStudent = null),
          underneathChild: Padding(
            padding: _pagePadding,
            child: _buildRoster(isDarkMode),
          ),
          child: _selectedStudent == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: _pagePadding,
                  child: _buildStudentDetail(_selectedStudent!, isDarkMode),
                ),
        );
      },
    );
  }

  /// Writes saved details back into the loaded roster, so returning to the
  /// list shows the new values without refetching.
  void _applySavedDetails(StudentEntry student, PersonDetails details) {
    final future = _studentsFuture;
    if (future == null) {
      return;
    }

    setState(() {
      _studentsFuture = future.then((students) {
        return [
          for (final entry in students)
            if (entry.personId == student.personId)
              entry.copyWithDetails(details)
            else
              entry,
        ];
      });
    });
  }

  /// Keeps the roster's thumbnail in step with a newly uploaded photo.
  void _applySavedPicture(StudentEntry student, String? pictureUrl) {
    final future = _studentsFuture;
    if (future == null) {
      return;
    }

    setState(() {
      _studentsFuture = future.then((students) {
        return [
          for (final entry in students)
            if (entry.personId == student.personId)
              entry.copyWithPictureUrl(pictureUrl)
            else
              entry,
        ];
      });
    });
  }

  /// A row opens the profile; Edit contacts opens the same view on Guardians.
  Widget _buildStudentDetail(StudentEntry student, bool isDarkMode) {
    final classPair = _myGroup?.classPair ?? '';

    return StudentInfoView(
      // Keyed so switching students rebuilds the form rather than keeping the
      // previous student's field values.
      key: ValueKey(student.personId),
      student: student,
      classPair: classPair,
      isDarkMode: isDarkMode,
      onBack: () => setState(() => _selectedStudent = null),
      updatePersonDetails: widget.updatePersonDetails,
      uploadPersonPicture:
          ({required ownerId, required bytes, required filename}) =>
              widget.uploadPersonPicture(
                personId: ownerId,
                bytes: bytes,
                filename: filename,
              ),
      removePersonPicture: ({required ownerId}) =>
          widget.removePersonPicture(personId: ownerId),
      onSaved: _applySavedDetails,
      onPictureChanged: _applySavedPicture,
      guardians: widget.guardians,
      documents: widget.documents,
      peopleSync: widget.peopleSync,
      initialTab: _detailTab,
    );
  }

  Widget _buildRoster(bool isDarkMode) {
    final l = AppLocalizations.of(context);
    final insights = widget.insights;
    final group = _myGroup;

    return FutureBuilder<List<StudentEntry>>(
      future: _studentsFuture,
      builder: (context, snapshot) {
        final loaded = snapshot.connectionState == ConnectionState.done;
        final all = snapshot.data ?? const <StudentEntry>[];
        // Current students first, then those who left, as on the web.
        final present = [
          for (final s in all)
            if (!_hasLeft(s)) s,
        ];
        final students = [
          ...present,
          for (final s in all)
            if (_hasLeft(s)) s,
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ClassHeader(
              classPair: group?.classPair,
              studentCount: loaded && !snapshot.hasError
                  ? present.length
                  : null,
            ),
            const SizedBox(height: 8),
            if (group == null)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: NoHomeroomLayout(),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: appColorsOf(context).card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: appColorsOf(context).line),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (insights != null)
                      UnderlineTabs<ClassSection>(
                        selected: _section,
                        isDarkMode: isDarkMode,
                        onSelected: (section) =>
                            setState(() => _section = section),
                        items: [
                          UnderlineTabItem(
                            value: ClassSection.students,
                            label: l.classStudentsTab,
                            icon: Icons.group_outlined,
                          ),
                          UnderlineTabItem(
                            value: ClassSection.grades,
                            label: l.classGradesTab,
                            icon: Icons.school_outlined,
                          ),
                          UnderlineTabItem(
                            value: ClassSection.behavior,
                            label: l.classBehaviorTab,
                            icon: Icons.volunteer_activism_outlined,
                          ),
                        ],
                      ),
                    if (!loaded)
                      const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (snapshot.hasError)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: ErrorLayout(
                          message: snapshot.error is AuthFailure
                              ? (snapshot.error as AuthFailure).message
                              : l.loadFailed,
                          onRetry: () => setState(() {
                            _studentsFuture = widget.loadStudentsForGroup(
                              group.id,
                              includeContacts: true,
                            );
                          }),
                        ),
                      )
                    else if (insights != null &&
                        _section == ClassSection.grades)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClassGradesView(
                          key: ValueKey('grades-${group.id}'),
                          loadGrades: () => insights.grades(group.id),
                          students: present,
                        ),
                      )
                    else if (insights != null &&
                        _section == ClassSection.behavior)
                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: ClassBehaviorView(
                          key: ValueKey('behavior-${group.id}'),
                          loadMarks: () =>
                              insights.marks(compactClassName(group.classPair)),
                          students: present,
                          onMark: widget.onMark,
                        ),
                      )
                    else if (students.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            l.classNoStudents,
                            style: TextStyle(
                              color: appColorsOf(context).mutedText,
                            ),
                          ),
                        ),
                      )
                    else
                      for (var i = 0; i < students.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: appColorsOf(context).line,
                          ),
                        _StudentRow(
                          student: students[i],
                          onTap: () =>
                              _openStudent(students[i], StudentTab.profile),
                          onContacts: () => _showContacts(students[i]),
                        ),
                      ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// One student: photo, name with the code under it, a green dot while they're
/// enrolled ("Left" once they aren't), and the phone for their contacts.
class _StudentRow extends StatelessWidget {
  const _StudentRow({
    required this.student,
    required this.onTap,
    required this.onContacts,
  });

  final StudentEntry student;
  final VoidCallback onTap;
  final VoidCallback onContacts;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final left = _hasLeft(student);
    final picture = student.pictureUrl;
    final hasPicture = picture != null && picture.isNotEmpty;
    final count = student.contacts.length;

    return Material(
      color: left
          ? const Color(0xFFF43F5E).withValues(alpha: 0.08)
          : Colors.transparent,
      child: InkWell(
        key: ValueKey('student-${student.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 6, 7),
          child: Row(
            children: [
              ZoomableAvatar(
                url: picture,
                name: student.fullName,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: colors.accent.solid.withValues(alpha: 0.18),
                  backgroundImage: hasPicture ? NetworkImage(picture) : null,
                  onBackgroundImageError: hasPicture ? (_, _) {} : null,
                  child: hasPicture
                      ? null
                      : Icon(
                          Icons.person_outline_rounded,
                          size: 17,
                          color: colors.accent.solid,
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: left ? colors.mutedText : null,
                      ),
                    ),
                    if (student.code != null && student.code!.isNotEmpty)
                      Text(
                        student.code!,
                        style: TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: colors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              if (left)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colors.softBg,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    l.classLeft,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors.mutedText,
                    ),
                  ),
                )
              else
                Tooltip(
                  message: l.classPresent,
                  child: Container(
                    key: ValueKey('present-${student.id}'),
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              const SizedBox(width: 4),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    key: ValueKey('contacts-${student.id}'),
                    tooltip: l.classContacts,
                    onPressed: onContacts,
                    style: count > 0
                        ? IconButton.styleFrom(
                            backgroundColor: colors.accent.solid.withValues(
                              alpha: 0.16,
                            ),
                          )
                        : null,
                    icon: Icon(
                      Icons.call_outlined,
                      size: 18,
                      color: count > 0 ? colors.accent.solid : colors.mutedText,
                    ),
                  ),
                  if (count > 0)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 16),
                        height: 16,
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: colors.accent.solid,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
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

/// The class and how many students are in it now, in one slim card.
class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.classPair, required this.studentCount});

  final String? classPair;
  final int? studentCount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = appColorsOf(context);
    final count = studentCount;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            classPair ?? '—',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Text(
            count == null ? '…' : l.classStudentCount(count),
            style: TextStyle(fontSize: 12, color: colors.mutedText),
          ),
        ],
      ),
    );
  }
}
