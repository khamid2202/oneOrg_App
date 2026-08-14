import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';

import 'my_class.dart';

class StudentRowCard extends StatelessWidget {
  const StudentRowCard({
    super.key,
    required this.student,
    required this.isDarkMode,
    required this.onTap,
    this.field = ClassField.info,
  });

  final StudentEntry student;
  final ClassField field;
  final bool isDarkMode;

  /// Null makes the row inert — used by the read-only Status field.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = appColorsOf(context).mutedText;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      // Without a destination there is nothing to press.
      canRequestFocus: onTap != null,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: appColorsOf(context).card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: appColorsOf(context).line),
        ),
        child: Row(
          children: [
            _StudentAvatar(student: student, isDarkMode: isDarkMode),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (student.nickname != null &&
                      student.nickname!.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      student.nickname!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            _FieldValue(student: student, field: field, isDarkMode: isDarkMode),
          ],
        ),
      ),
    );
  }
}

class _StudentAvatar extends StatelessWidget {
  const _StudentAvatar({required this.student, required this.isDarkMode});

  final StudentEntry student;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final pictureUrl = student.pictureUrl;
    final hasPicture = pictureUrl != null && pictureUrl.isNotEmpty;

    return CircleAvatar(
      radius: 20,
      backgroundColor: appColorsOf(context).softBg,
      backgroundImage: hasPicture ? NetworkImage(pictureUrl) : null,
      // A broken or offline photo must not take the row down with it.
      onBackgroundImageError: hasPicture ? (_, _) {} : null,
      child: hasPicture
          ? null
          : Icon(
              Icons.person_rounded,
              size: 20,
              color: appColorsOf(context).softText,
            ),
    );
  }
}

class _FieldValue extends StatelessWidget {
  const _FieldValue({
    required this.student,
    required this.field,
    required this.isDarkMode,
  });

  final StudentEntry student;
  final ClassField field;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    switch (field) {
      case ClassField.info:
        return _CodeText(code: student.code, isDarkMode: isDarkMode);
      case ClassField.status:
        return _StatusChip(status: student.status, isDarkMode: isDarkMode);
      case ClassField.contacts:
        return _ContactsSummary(
          contacts: student.contacts,
          isDarkMode: isDarkMode,
        );
    }
  }
}

class _CodeText extends StatelessWidget {
  const _CodeText({required this.code, required this.isDarkMode});

  final String? code;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final mutedColor = appColorsOf(context).mutedText;

    return Text(
      code ?? '—',
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0.4,
        color: code == null ? mutedColor : null,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.isDarkMode});

  final String? status;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final normalized = status?.trim().toLowerCase();
    final color = switch (normalized) {
      'present' || 'active' => const Color(0xFF16A34A),
      'left' || 'inactive' => const Color(0xFFFB7185),
      null => appColorsOf(context).mutedText,
      _ => const Color(0xFFFBBF24),
    };

    final label = normalized == null
        ? '—'
        : normalized[0].toUpperCase() + normalized.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDarkMode ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _ContactsSummary extends StatelessWidget {
  const _ContactsSummary({required this.contacts, required this.isDarkMode});

  final List<ContactEntry> contacts;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = appColorsOf(context).mutedText;

    if (contacts.isEmpty) {
      return Text(
        'None',
        style: theme.textTheme.labelMedium?.copyWith(color: mutedColor),
      );
    }

    final primary = contacts.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          primary.phoneNumber,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          contacts.length > 1
              ? '${primary.relationshipLabel} +${contacts.length - 1}'
              : primary.relationshipLabel,
          style: theme.textTheme.labelSmall?.copyWith(color: mutedColor),
        ),
      ],
    );
  }
}
