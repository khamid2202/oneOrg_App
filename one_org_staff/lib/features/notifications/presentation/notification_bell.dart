import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../application/notifications_controller.dart';

/// Header bell with the unread badge, sitting beside the theme toggle on the
/// dashboard.
///
/// Rebuilds off [NotificationsController] alone, so the badge tracks the
/// polled count and any optimistic mark-as-read without the dashboard having
/// to rebuild around it.
class NotificationBell extends StatelessWidget {
  const NotificationBell({
    super.key,
    required this.controller,
    required this.onTap,
  });

  final NotificationsController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final count = controller.unreadCount;
        final label = count > 99 ? '99+' : '$count';

        return Container(
          decoration: BoxDecoration(
            color: colors.softBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.line, width: 1),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: onTap,
                icon: Icon(
                  count > 0
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_none_rounded,
                  color: colors.softText,
                  size: 22,
                ),
                tooltip: count > 0
                    ? '$count unread notifications'
                    : 'Notifications',
              ),
              if (count > 0)
                Positioned(
                  top: 4,
                  right: 2,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(minWidth: 18),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(9),
                        // Rings the badge in the surface colour so it reads as
                        // a separate chip rather than smudging into the icon.
                        border: Border.all(color: colors.softBg, width: 1.5),
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          height: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
