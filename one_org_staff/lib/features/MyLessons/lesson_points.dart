import 'package:flutter/material.dart';

import 'lesson_points_repository.dart';

class _StudentListData {
  final List<StudentEntry> students;
  final Map<int, double> points;

  const _StudentListData({
    required this.students,
    required this.points,
  });
}

class LessonPointsPage extends StatefulWidget {
  const LessonPointsPage({
    super.key,
    required this.groupId,
    required this.groupLabel,
    required this.lessonTitle,
    required this.date,
    this.subjectId,
    required this.loadStudents,
    required this.savePoints,
    required this.loadPoints,
  });

  final int groupId;
  final String groupLabel;
  final String lessonTitle;
  final DateTime date;
  final int? subjectId;
  final Future<List<StudentEntry>> Function(int groupId) loadStudents;
  final Future<void> Function(List<StudentPointDraft> points) savePoints;
  final Future<Map<int, double>> Function({
    required int groupId,
    required DateTime date,
    int? subjectId,
  }) loadPoints;

  @override
  State<LessonPointsPage> createState() => _LessonPointsPageState();
}

class _LessonPointsPageState extends State<LessonPointsPage> {
  late Future<_StudentListData> _dataFuture;
  final Map<int, TextEditingController> _controllers = {};
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _dataFuture = Future.wait([
      widget.loadStudents(widget.groupId),
      widget.loadPoints(
        groupId: widget.groupId,
        date: widget.date,
        subjectId: widget.subjectId,
      ),
    ]).then((results) {
      final students = results[0] as List<StudentEntry>;
      final points = results[1] as Map<int, double>;

      // Initialize/update controllers with existing points
      for (final student in students) {
        final existingPoint = points[student.id];
        final controller = _controllers.putIfAbsent(
          student.id,
          () => TextEditingController(),
        );
        if (existingPoint != null) {
          if (existingPoint == existingPoint.toInt()) {
            controller.text = existingPoint.toInt().toString();
          } else {
            controller.text = existingPoint.toString();
          }
        } else {
          controller.clear();
        }
      }

      return _StudentListData(students: students, points: points);
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: Text(widget.groupLabel)),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lessonTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              _formatDate(widget.date),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDarkMode
                    ? const Color(0xFF9DB0C1)
                    : const Color(0xFF5C738B),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<_StudentListData>(
                future: _dataFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _ErrorState(
                      message: snapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }

                  final data = snapshot.data;
                  final students = data?.students ?? const <StudentEntry>[];
                  if (students.isEmpty) {
                    return const _EmptyState();
                  }

                  return ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final controller = _controllers.putIfAbsent(
                        student.id,
                        () => TextEditingController(),
                      );

                      return _StudentPointCard(
                        student: student,
                        controller: controller,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_errorMessage != null) ...[
              Text(
                _errorMessage!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _isSaving ? null : _savePoints,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save points'),
            ),
            const SizedBox(height: 4),
            Text(
              'Only filled points will be saved.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDarkMode
                    ? const Color(0xFF9DB0C1)
                    : const Color(0xFF5C738B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  Future<void> _savePoints() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final drafts = _collectDrafts();
      if (drafts.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Enter points to save.')));
        return;
      }

      await widget.savePoints(drafts);

      if (mounted) {
        setState(() {
          _loadData();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Points saved successfully.')),
        );
      }
    } catch (error) {
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  List<StudentPointDraft> _collectDrafts() {
    final drafts = <StudentPointDraft>[];
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        continue;
      }
      final points = double.tryParse(value.replaceAll(',', '.'));
      if (points == null) {
        continue;
      }
      drafts.add(
        StudentPointDraft(
          studentId: entry.key,
          groupId: widget.groupId,
          points: points,
          date: widget.date,
          subjectId: widget.subjectId,
        ),
      );
    }
    return drafts;
  }

  static String _formatDate(DateTime date) {
    const monthNames = [
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

    return '${date.day.toString().padLeft(2, '0')} '
        '${monthNames[date.month - 1]} ${date.year}';
  }
}

class _StudentPointCard extends StatelessWidget {
  const _StudentPointCard({required this.student, required this.controller});

  final StudentEntry student;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);
    final inputBorderColor = isDarkMode
        ? const Color(0xFF3A4B5F)
        : const Color(0xFFB8C7D8);
    final focusedInputBorderColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1A2430) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF273445) : const Color(0xFFD7E1EE),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.fullName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (student.nickname != null &&
                    student.nickname!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    student.nickname!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: mutedColor),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(
            width: 86,
            child: TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: '-',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: inputBorderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: focusedInputBorderColor,
                    width: 1.6,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: inputBorderColor),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No students found for this class.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
