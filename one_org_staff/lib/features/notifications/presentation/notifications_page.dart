import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../application/notifications_controller.dart';
import '../application/push_service.dart';
import '../domain/notifications_repository.dart';

/// The signed-in teacher's notification inbox.
///
/// Scrolls itself — the list is paginated and builds rows lazily, so it must
/// not sit inside the landing page's shared scroll view. The nav bar's overlay
/// height arrives as [bottomInset] and pads the last row clear of it.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.controller,
    required this.pushService,
    this.bottomInset = 0,
  });

  final NotificationsController controller;
  final PushService pushService;
  final double bottomInset;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Opening the inbox is the moment the list is expected to be current, so
    // it always refetches rather than showing whatever the last visit left.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.refresh();
    });
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 320) {
      widget.controller.loadMore();
    }
  }

  Future<void> _enablePush() async {
    final push = widget.pushService;

    if (push.permission == PushPermission.denied) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Notifications are blocked'),
          content: const Text(
            'This phone is set to block notifications from Dombit School. '
            'Open Settings › Notifications › Dombit School and allow them '
            'there, then come back.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
      return;
    }

    final granted = await push.requestPermission();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications stayed off.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, widget.pushService]),
      builder: (context, _) {
        final controller = widget.controller;

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: CustomScrollView(
            controller: _scrollController,
            // Keeps pull-to-refresh working even when the list is too short
            // to scroll, which is the common case on a fresh account.
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(context)),
              if (_showEnableBanner)
                SliverToBoxAdapter(child: _buildEnableBanner(context)),
              ..._buildBody(context),
              SliverToBoxAdapter(
                child: SizedBox(height: widget.bottomInset + 16),
              ),
            ],
          ),
        );
      },
    );
  }

  /// The prompt only makes sense where turning push on is actually possible —
  /// a build with no Firebase config can't, and there is nothing the teacher
  /// could do about it.
  bool get _showEnableBanner =>
      widget.pushService.permission == PushPermission.notDetermined ||
      widget.pushService.permission == PushPermission.denied;

  Widget _buildHeader(BuildContext context) {
    final colors = appColorsOf(context);
    final controller = widget.controller;
    final hasUnread = controller.unreadCount > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasUnread
                      ? '${controller.unreadCount} unread'
                      : 'You are all caught up',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.mutedText),
                ),
              ],
            ),
          ),
          if (hasUnread)
            TextButton.icon(
              onPressed: controller.markAllAsRead,
              icon: const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all read'),
              style: TextButton.styleFrom(foregroundColor: colors.accent.solid),
            ),
        ],
      ),
    );
  }

  Widget _buildEnableBanner(BuildContext context) {
    final colors = appColorsOf(context);
    final denied = widget.pushService.permission == PushPermission.denied;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.softBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Icon(
              denied
                  ? Icons.notifications_off_rounded
                  : Icons.notifications_active_rounded,
              color: colors.softText,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                denied
                    ? 'Push notifications are blocked for this app.'
                    : 'Get these on your phone as they happen.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.softText),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _enablePush,
              style: FilledButton.styleFrom(
                backgroundColor: colors.accent.solid,
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(denied ? 'How' : 'Enable'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBody(BuildContext context) {
    final controller = widget.controller;

    if (controller.loading && controller.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
          ),
        ),
      ];
    }

    if (controller.error != null && controller.items.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Could not load notifications',
            message: controller.error!,
            action: FilledButton(
              onPressed: controller.refresh,
              child: const Text('Try again'),
            ),
          ),
        ),
      ];
    }

    if (controller.items.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'Nothing yet',
            message:
                'Announcements, points and schedule changes will show up here.',
          ),
        ),
      ];
    }

    return [
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: controller.items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = controller.items[index];
            return _NotificationTile(
              notification: item,
              onTap: () => controller.markAsRead(item.id),
            );
          },
        ),
      ),
      if (controller.loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            ),
          ),
        ),
    ];
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final theme = Theme.of(context);
    final unread = !notification.isRead;

    return Material(
      color: unread ? colors.softBg : colors.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: unread ? colors.border : colors.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: unread
                      ? colors.accent.solid.withValues(alpha: 0.16)
                      : colors.avatarPlaceholder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconFor(notification.type),
                  size: 20,
                  color: unread ? colors.accent.solid : colors.mutedText,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title.isEmpty
                                ? 'Notification'
                                : notification.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8, top: 2),
                            decoration: BoxDecoration(
                              color: colors.accent.solid,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    if (notification.body.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.mutedText,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.mutedText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Maps the server's free-form `type` onto an icon. Anything unrecognised
  /// gets the generic bell rather than no icon at all, since new types can
  /// appear server-side without an app release.
  static IconData _iconFor(String? type) {
    switch (type?.toLowerCase()) {
      case 'payment':
      case 'invoice':
        return Icons.payments_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'exam':
      case 'exam_result':
        return Icons.fact_check_rounded;
      case 'point':
      case 'points':
        return Icons.workspace_premium_rounded;
      case 'attendance':
        return Icons.how_to_reg_rounded;
      case 'timetable':
      case 'lesson':
        return Icons.event_available_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  static String _relativeTime(DateTime? time) {
    if (time == null) return '';

    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';

    final date = '${time.day}/${time.month}/${time.year}';
    return date;
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 64, 40, 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.softBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 34, color: colors.softText),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.mutedText),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );
  }
}
