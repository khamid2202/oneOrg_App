import 'package:flutter/material.dart';

import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'my_class_status_layouts.dart';
import 'student_detail_view.dart';
import 'student_row_card.dart';

class MyClassPage extends StatefulWidget {
  const MyClassPage({
    super.key,
    required this.loadProfile,
    required this.loadGroups,
    required this.loadStudentsForGroup,
    required this.loadContactsForStudent,
    required this.createContact,
    required this.updateContact,
    required this.deleteContact,
  });

  final Future<AppUserProfile> Function() loadProfile;
  final Future<List<GroupEntry>> Function() loadGroups;
  final Future<List<StudentEntry>> Function(int groupId) loadStudentsForGroup;
  final Future<List<ContactEntry>> Function(int studentId) loadContactsForStudent;
  final Future<ContactEntry> Function({
    required int studentId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
  }) createContact;
  final Future<ContactEntry> Function({
    required int contactId,
    String? fullName,
    String? relationship,
    String? phoneNumber,
  }) updateContact;
  final Future<void> Function(int contactId) deleteContact;

  @override
  State<MyClassPage> createState() => _MyClassPageState();
}

class _MyClassPageState extends State<MyClassPage> {
  late Future<List<dynamic>> _loadFuture;
  AppUserProfile? _profile;
  GroupEntry? _myGroup;

  Future<List<StudentEntry>>? _studentsFuture;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Student detail state
  StudentEntry? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _loadData();
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

  void _loadData() {
    _loadFuture = Future.wait([
      widget.loadProfile(),
      widget.loadGroups(),
    ]).then((results) {
      _profile = results[0] as AppUserProfile;
      final allGroups = results[1] as List<GroupEntry>;
      final matchingGroups = allGroups.where((group) {
        final matchesId = group.teacherIds.contains(_profile?.id);
        final matchesName = group.teacherName != null &&
            _profile != null &&
            group.teacherName!.trim().toLowerCase() == _profile!.fullName.trim().toLowerCase();
        return matchesId || matchesName;
      }).toList();

      if (matchingGroups.isNotEmpty) {
        _myGroup = matchingGroups.first;
        _studentsFuture = widget.loadStudentsForGroup(_myGroup!.id);
      }

      return results;
    });
  }

  void _reload() {
    setState(() {
      _myGroup = null;
      _studentsFuture = null;
      _selectedStudent = null;
      _searchController.clear();
      _searchQuery = '';
      _loadData();
    });
  }

  void _selectStudent(StudentEntry student) {
    setState(() {
      _selectedStudent = student;
    });
  }

  void _deselectStudent() {
    setState(() {
      _selectedStudent = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: FutureBuilder<List<dynamic>>(
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
              message: 'Soon the content will appear',
              onRetry: _reload,
            );
          }

          if (_myGroup == null) {
            return const NoHomeroomLayout();
          }

          return SwipeBackDetector(
            enabled: _selectedStudent != null,
            onSwipeBack: _deselectStudent,
            underneathChild: _buildStudentListLayout(isDarkMode),
            child: _selectedStudent == null
                ? const SizedBox.shrink()
                : StudentDetailView(
                    student: _selectedStudent!,
                    classPair: _myGroup!.classPair,
                    isDarkMode: isDarkMode,
                    loadContacts: widget.loadContactsForStudent,
                    createContact: widget.createContact,
                    updateContact: widget.updateContact,
                    deleteContact: widget.deleteContact,
                    onBack: _deselectStudent,
                  ),
          );
        },
      ),
    );
  }

  Widget _buildStudentListLayout(bool isDarkMode) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode ? const Color(0xFF9DB0C1) : const Color(0xFF5C738B);
    final searchBgColor = isDarkMode ? const Color(0xFF19202A) : Colors.white;
    final searchBorderColor = isDarkMode ? const Color(0xFF273445) : const Color(0xFFD7E1EE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Class ${_myGroup!.classPair}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Homeroom Student Roster',
                    style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          decoration: BoxDecoration(
            color: searchBgColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: searchBorderColor),
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
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 18),
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
                message: 'Soon the content will appear',
                onRetry: () {
                  setState(() {
                    _studentsFuture = widget.loadStudentsForGroup(_myGroup!.id);
                  });
                },
              );
            }

            final students = snapshot.data ?? const <StudentEntry>[];
            final filteredStudents = students.where((s) {
              final nameMatches = s.fullName.toLowerCase().contains(_searchQuery);
              final nicknameMatches = s.nickname?.toLowerCase().contains(_searchQuery) ?? false;
              return nameMatches || nicknameMatches;
            }).toList();

            if (students.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No students in this class.',
                    style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                  ),
                ),
              );
            }

            if (filteredStudents.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'No students match "$_searchQuery".',
                    style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
                  ),
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final student = filteredStudents[index];
                return StudentRowCard(
                  student: student,
                  isDarkMode: isDarkMode,
                  onTap: () => _selectStudent(student),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
