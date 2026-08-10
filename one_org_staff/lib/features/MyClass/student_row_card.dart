import 'package:flutter/material.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

class StudentRowCard extends StatelessWidget {
  const StudentRowCard({
    super.key,
    required this.student,
    required this.isDarkMode,
    required this.onTap,
  });

  final StudentEntry student;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode ? const Color(0xFF9DB0C1) : const Color(0xFF5C738B);
    final initial = student.fullName.isNotEmpty ? student.fullName[0].toUpperCase() : 'S';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
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
            CircleAvatar(
              radius: 22,
              backgroundColor: isDarkMode ? const Color(0xFF223042) : const Color(0xFFE8F0FA),
              child: Text(
                initial,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDarkMode ? const Color(0xFF64AFFF) : const Color(0xFF1F5E89),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (student.nickname != null && student.nickname!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      student.nickname!,
                      style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: mutedColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}
