import 'package:flutter/material.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/shared/underline_tabs.dart';
import 'my_class_status_layouts.dart';
import 'student_info_view.dart';
import 'student_people_sync.dart';
import 'student_row_card.dart';

/// The field shown alongside each student. The teacher switches between them
/// from the row of chips under the class header.
enum ClassField { info, status, contacts }

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
  });

  final Future<AppUserProfile> Function() loadProfile;
  final Future<List<GroupEntry>> Function({int? academicYearId}) loadGroups;
  final Future<List<AcademicYearEntry>> Function() loadAcademicYears;
  final Future<List<StudentEntry>> Function(
    int groupId, {
    bool includeContacts,
  })
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
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  ClassField _field = ClassField.info;
  StudentEntry? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final results = await Future.wait([
      widget.loadProfile(),
      widget.loadAcademicYears(),
    ]);

    _profile = results[0] as AppUserProfile;
    _years = results[1] as List<AcademicYearEntry>;

    // Default to the active year, which is what a teacher almost always wants.
    _selectedYear =
        _years.where((year) => year.isActive).firstOrNull ?? _years.firstOrNull;

    await _resolveGroupForSelectedYear();
  }

  Future<void> _resolveGroupForSelectedYear() async {
    final groups = await widget.loadGroups(academicYearId: _selectedYear?.id);
    final profile = _profile;

    final mine = groups.where((group) {
      final matchesId = profile != null && group.teacherIds.contains(profile.id);
      final matchesName =
          group.teacherName != null &&
          profile != null &&
          group.teacherName!.trim().toLowerCase() ==
              profile.fullName.trim().toLowerCase();
      return matchesId || matchesName;
    }).toList();

    _myGroup = mine.firstOrNull;
    _studentsFuture = _myGroup == null
        ? null
        : widget.loadStudentsForGroup(_myGroup!.id, includeContacts: true);
  }

  void _reload() {
    setState(() {
      _myGroup = null;
      _studentsFuture = null;
      _selectedStudent = null;
      _searchController.clear();
      _searchQuery = '';
      _loadFuture = _loadData();
    });
  }

  void _onYearChanged(AcademicYearEntry? year) {
    if (year == null || year.id == _selectedYear?.id) {
      return;
    }
    setState(() {
      _selectedYear = year;
      _myGroup = null;
      _studentsFuture = null;
      _selectedStudent = null;
      _loadFuture = _resolveGroupForSelectedYear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: FutureBuilder<void>(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError) {
            return ErrorLayout(
              message: snapshot.error is AuthFailure
                  ? (snapshot.error as AuthFailure).message
                  : 'Soon the content will appear',
              onRetry: _reload,
            );
          }

          return SwipeBackDetector(
            enabled: _selectedStudent != null,
            onSwipeBack: () => setState(() => _selectedStudent = null),
            underneathChild: _buildRoster(isDarkMode),
            child: _selectedStudent == null
                ? const SizedBox.shrink()
                : _buildStudentDetail(_selectedStudent!, isDarkMode),
          );
        },
      ),
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

  /// Both Info and Contacts open the same student modal — Info on Profile,
  /// Contacts on Guardians. Status never gets here.
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
      // Contacts on the roster is about the family, so land on Guardians.
      initialTab: _field == ClassField.contacts
          ? StudentTab.guardians
          : StudentTab.profile,
    );
  }

  Widget _buildRoster(bool isDarkMode) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FutureBuilder<List<StudentEntry>>(
          future: _studentsFuture,
          builder: (context, snapshot) {
            final students = snapshot.data ?? const <StudentEntry>[];
            return _ClassHeader(
              classPair: _myGroup?.classPair,
              studentCount: snapshot.connectionState == ConnectionState.done
                  ? students.length
                  : null,
              years: _years,
              selectedYear: _selectedYear,
              onYearChanged: _onYearChanged,
              isDarkMode: isDarkMode,
            );
          },
        ),
        const SizedBox(height: 16),
        if (_myGroup == null)
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: NoHomeroomLayout(),
          )
        else ...[
          UnderlineTabs<ClassField>(
            selected: _field,
            isDarkMode: isDarkMode,
            onSelected: (field) => setState(() => _field = field),
            items: const [
              UnderlineTabItem(
                value: ClassField.info,
                label: 'Info',
                icon: Icons.person_outline_rounded,
              ),
              UnderlineTabItem(
                value: ClassField.status,
                label: 'Status',
                icon: Icons.monitor_heart_outlined,
              ),
              UnderlineTabItem(
                value: ClassField.contacts,
                label: 'Contacts',
                icon: Icons.phone_outlined,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF19202A) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF273445)
                    : const Color(0xFFD7E1EE),
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search student by name...',
                hintStyle: TextStyle(color: mutedColor),
                prefixIcon: Icon(Icons.search_rounded, color: mutedColor),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                  horizontal: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _ColumnHeadings(field: _field, isDarkMode: isDarkMode),
          const SizedBox(height: 8),
          FutureBuilder<List<StudentEntry>>(
            future: _studentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return ErrorLayout(
                  message: snapshot.error is AuthFailure
                      ? (snapshot.error as AuthFailure).message
                      : 'Soon the content will appear',
                  onRetry: () {
                    setState(() {
                      _studentsFuture = widget.loadStudentsForGroup(
                        _myGroup!.id,
                        includeContacts: true,
                      );
                    });
                  },
                );
              }

              final students = snapshot.data ?? const <StudentEntry>[];
              if (students.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No students in this class.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ),
                );
              }

              final filtered = students.where((student) {
                if (_searchQuery.isEmpty) {
                  return true;
                }
                final name = student.fullName.toLowerCase();
                final nickname = student.nickname?.toLowerCase() ?? '';
                final code = student.code?.toLowerCase() ?? '';
                return name.contains(_searchQuery) ||
                    nickname.contains(_searchQuery) ||
                    code.contains(_searchQuery);
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(
                      'No students match "$_searchQuery".',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final student = filtered[index];
                  return StudentRowCard(
                    student: student,
                    field: _field,
                    isDarkMode: isDarkMode,
                    // Status is read-only: nothing to drill into.
                    onTap: _field == ClassField.status
                        ? null
                        : () => setState(() => _selectedStudent = student),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }
}

class _ClassHeader extends StatelessWidget {
  const _ClassHeader({
    required this.classPair,
    required this.studentCount,
    required this.years,
    required this.selectedYear,
    required this.onYearChanged,
    required this.isDarkMode,
  });

  final String? classPair;
  final int? studentCount;
  final List<AcademicYearEntry> years;
  final AcademicYearEntry? selectedYear;
  final ValueChanged<AcademicYearEntry?> onYearChanged;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(
              alpha: isDarkMode ? 0.2 : 0.12,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Icons.groups_rounded,
            color: theme.colorScheme.primary,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                classPair ?? '—',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                studentCount == null
                    ? 'Loading…'
                    : '$studentCount student${studentCount == 1 ? '' : 's'}',
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
            ],
          ),
        ),
        if (years.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF19202A) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDarkMode
                    ? const Color(0xFF273445)
                    : const Color(0xFFD7E1EE),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AcademicYearEntry>(
                value: selectedYear,
                isDense: true,
                borderRadius: BorderRadius.circular(14),
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.textTheme.bodyLarge?.color,
                ),
                items: [
                  for (final year in years)
                    DropdownMenuItem(value: year, child: Text(year.label)),
                ],
                onChanged: onYearChanged,
              ),
            ),
          ),
      ],
    );
  }
}

class _ColumnHeadings extends StatelessWidget {
  const _ColumnHeadings({required this.field, required this.isDarkMode});

  final ClassField field;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: mutedColor,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text('STUDENT', style: style)),
          Text(
            switch (field) {
              ClassField.info => 'CODE',
              ClassField.status => 'STATUS',
              ClassField.contacts => 'CONTACT',
            },
            style: style,
          ),
        ],
      ),
    );
  }
}
