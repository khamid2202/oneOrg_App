import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

/// Turns whatever a repository threw into a line worth showing.
String examErrorMessage(Object? error, String fallback) {
  if (error is AuthFailure) {
    return error.message;
  }
  return fallback;
}

/// The `chevron + title` row every exam sub-screen opens with, mirroring the
/// web's `BackButton` sitting above each page heading.
class ExamHeader extends StatelessWidget {
  const ExamHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Back',
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ?trailing,
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.mutedText,
            ),
          ),
        ),
      ],
    );
  }
}

/// A bordered surface — the app's stand-in for the web's `rounded-2xl border
/// bg-white/90` cards.
class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.line),
      ),
      child: child,
    );
  }
}

/// The accent-tinted empty state the web shows for "no exams", "no periods"
/// and "no students".
class ExamNotice extends StatelessWidget {
  const ExamNotice({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: colors.softBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 34, color: colors.softText),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colors.softText,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 4),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Failure state with a retry, matching `_ReportError` on the point report.
class ExamErrorState extends StatelessWidget {
  const ExamErrorState({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return ExamCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: Colors.redAccent,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.mutedText),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

/// Small accent pill — the web's `rounded-full bg-accent-soft` badges.
class ExamPill extends StatelessWidget {
  const ExamPill({super.key, required this.label, this.icon, this.muted = false});

  final String label;
  final IconData? icon;

  /// Neutral instead of accent-tinted, for the "x/y graded" counter.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final background = muted
        ? colors.mutedText.withValues(alpha: 0.12)
        : colors.softBg;
    final foreground = muted ? colors.mutedText : colors.softText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// `Mar 19, 2026` — the web renders these with `toLocaleDateString()`.
String formatExamDate(DateTime? date) {
  if (date == null) {
    return '—';
  }
  const months = [
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
  final local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

/// An `id + label` pair for the pickers — a subject or a class, both of which
/// the create form derives from the teacher's timetable.
class ExamOption {
  const ExamOption({required this.id, required this.name});

  final int id;
  final String name;

  /// Homeroom is a timetable placeholder rather than an examinable subject, so
  /// the subject picker drops it — same rule as the web.
  bool get isHomeroom => name.trim().toLowerCase() == 'homeroom';
}
