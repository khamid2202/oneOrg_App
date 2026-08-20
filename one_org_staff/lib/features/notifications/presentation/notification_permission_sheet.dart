import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../application/push_service.dart';

/// Asks the teacher, in the app's own words, before the OS dialog appears.
///
/// The OS prompt is a one-shot on iOS — decline it and only a trip to Settings
/// can undo that — so firing it cold at launch burns the single chance on a
/// user with no idea what they are agreeing to. This sheet explains what the
/// notifications are for first, and only calls
/// [PushService.requestPermission] if they say yes.
///
/// Shown once per install: [PushService.promptSeen] is persisted, and someone
/// who declines can still turn notifications on later from Profile.
Future<void> maybeAskForNotificationPermission(
  BuildContext context,
  PushService pushService,
) async {
  if (pushService.promptSeen) return;

  // A build with no Firebase config cannot ask for anything, and must not
  // spend the once-per-install flag pretending it did — otherwise dropping
  // `google-services.json` in later would find the prompt already burned and
  // push would stay off with no way back but reinstalling.
  if (pushService.permission == PushPermission.unavailable) return;

  if (pushService.permission != PushPermission.notDetermined) {
    // The OS already holds an answer, so there is genuinely nothing to ask.
    await pushService.markPromptSeen();
    return;
  }

  final accepted = await showNotificationPermissionSheet(context);
  if (accepted != true) {
    await pushService.markPromptSeen();
    return;
  }

  if (!context.mounted) return;
  final granted = await pushService.requestPermission();

  if (!granted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications stayed off. You can turn them on from the bell, '
          'any time.',
        ),
      ),
    );
  }
}

/// The explainer itself. Resolves true when the teacher opts in.
Future<bool?> showNotificationPermissionSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Deliberately not dismissible by tapping away: a stray tap would count as
    // a decline for the rest of the install.
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _NotificationPermissionSheet(),
  );
}

class _NotificationPermissionSheet extends StatelessWidget {
  const _NotificationPermissionSheet();

  static const _reasons = [
    (
      Icons.campaign_rounded,
      'Announcements',
      'School-wide notices reach you the moment they go out.',
    ),
    (
      Icons.workspace_premium_rounded,
      'Points and rewards',
      'Know when points land for the students in your classes.',
    ),
    (
      Icons.event_available_rounded,
      'Schedule changes',
      'Lesson and exam updates, without refreshing the app.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: colors.line),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: colors.accent.gradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.solid.withValues(alpha: 0.32),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Turn on notifications?',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dombit School can let you know when something needs you.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.mutedText,
              ),
            ),
            const SizedBox(height: 24),
            for (final (icon, title, subtitle) in _reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colors.softBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: colors.softText),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.mutedText,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent.solid,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Allow notifications',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: colors.mutedText,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Not now'),
            ),
          ],
        ),
      ),
    );
  }
}
