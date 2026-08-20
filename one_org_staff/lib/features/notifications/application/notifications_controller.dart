import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../auth/domain/auth_repository.dart';
import '../domain/notifications_repository.dart';

/// Inbox state for the bell badge and the notifications page.
///
/// There is no realtime transport on this API — no websocket, no SSE — so the
/// unread badge is polled. That is cheap (`/notifications/unread-count`
/// returns a single integer) and the timer only ticks while the app is in the
/// foreground, so a backgrounded app costs nothing. A push landing in the
/// foreground refreshes the count immediately via [refreshUnreadCount], which
/// is what [PushService.onForegroundMessage] is wired to.
class NotificationsController extends ChangeNotifier {
  NotificationsController({
    required Future<NotificationPage> Function({
      int page,
      int limit,
      bool? isRead,
    })
    loadNotifications,
    required Future<int> Function() loadUnreadCount,
    required Future<void> Function(int id) markRead,
    required Future<void> Function() markAllRead,
  }) : _loadNotifications = loadNotifications,
       _loadUnreadCount = loadUnreadCount,
       _markRead = markRead,
       _markAllRead = markAllRead;

  final Future<NotificationPage> Function({int page, int limit, bool? isRead})
  _loadNotifications;
  final Future<int> Function() _loadUnreadCount;
  final Future<void> Function(int id) _markRead;
  final Future<void> Function() _markAllRead;

  static const _pollInterval = Duration(seconds: 60);
  static const _pageSize = 20;

  List<AppNotification> _items = const [];
  List<AppNotification> get items => _items;

  int _unreadCount = 0;
  int get unreadCount => _unreadCount;

  bool _loading = false;
  bool get loading => _loading;

  bool _loadingMore = false;
  bool get loadingMore => _loadingMore;

  String? _error;
  String? get error => _error;

  int _page = 1;
  int _pages = 1;
  bool get hasMore => _page < _pages;

  Timer? _poll;
  AppLifecycleListener? _lifecycle;
  bool _disposed = false;

  /// Begins polling the badge and refreshes it once immediately. Called when
  /// the signed-in shell mounts.
  void start() {
    if (_poll != null) return;

    unawaited(refreshUnreadCount());
    _poll = Timer.periodic(_pollInterval, (_) => refreshUnreadCount());
    // Someone coming back to the app expects an accurate badge right away
    // rather than up to a minute later.
    _lifecycle = AppLifecycleListener(onResume: () => refreshUnreadCount());
  }

  void stop() {
    _poll?.cancel();
    _poll = null;
    _lifecycle?.dispose();
    _lifecycle = null;
  }

  Future<void> refreshUnreadCount() async {
    try {
      final count = await _loadUnreadCount();
      if (_disposed || count == _unreadCount) return;
      _unreadCount = count;
      notifyListeners();
    } catch (_) {
      // A failed count check is not worth surfacing — the next tick retries.
    }
  }

  /// Loads the newest page. Called when the inbox opens and on pull-to-refresh.
  Future<void> refresh() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final page = await _loadNotifications(page: 1, limit: _pageSize);
      if (_disposed) return;
      _items = page.items;
      _page = page.page;
      _pages = page.pages;
      _unreadCount = page.unreadCount;
    } catch (error) {
      if (_disposed) return;
      _error = _messageFor(error);
      _items = const [];
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMore() async {
    if (_loadingMore || _loading || !hasMore) return;

    _loadingMore = true;
    notifyListeners();

    try {
      final next = await _loadNotifications(page: _page + 1, limit: _pageSize);
      if (_disposed) return;
      _items = [..._items, ...next.items];
      _page = next.page;
      _pages = next.pages;
    } catch (_) {
      // Leave the list as it stands; the footer stops showing a spinner and
      // scrolling again retries.
    } finally {
      if (!_disposed) {
        _loadingMore = false;
        notifyListeners();
      }
    }
  }

  /// Marks one row read, optimistically. A failed call just leaves the server
  /// as the source of truth for the next poll.
  Future<void> markAsRead(int id) async {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0 || _items[index].isRead) return;

    _items = [..._items]
      ..[index] = _items[index].copyWith(isRead: true, readAt: DateTime.now());
    _unreadCount = _unreadCount > 0 ? _unreadCount - 1 : 0;
    notifyListeners();

    try {
      await _markRead(id);
    } catch (_) {
      await refreshUnreadCount();
    }
  }

  Future<void> markAllAsRead() async {
    if (_unreadCount == 0 && _items.every((item) => item.isRead)) return;

    final now = DateTime.now();
    _items = _items
        .map(
          (item) =>
              item.isRead ? item : item.copyWith(isRead: true, readAt: now),
        )
        .toList();
    _unreadCount = 0;
    notifyListeners();

    try {
      await _markAllRead();
    } catch (_) {
      await refreshUnreadCount();
    }
  }

  /// Wipes inbox state on sign-out so the next user on this phone does not see
  /// the previous one's notifications flash before the first load lands.
  void clear() {
    _items = const [];
    _unreadCount = 0;
    _page = 1;
    _pages = 1;
    _error = null;
    notifyListeners();
  }

  /// Repositories throw [AuthFailure] carrying a message meant for the user;
  /// anything else would put a stack-shaped string on screen, so it does not
  /// get shown.
  String _messageFor(Object error) {
    if (error is AuthFailure && error.message.trim().isNotEmpty) {
      return error.message;
    }
    return 'Unable to load notifications.';
  }

  @override
  void dispose() {
    _disposed = true;
    stop();
    super.dispose();
  }
}
