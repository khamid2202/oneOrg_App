/// One row in the signed-in user's notification inbox.
///
/// Mirrors the notification shape from `docs/staff/notifications.md` — the
/// same `GET /notifications` response the web app's notification bell reads.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.isRead,
    this.type,
    this.data = const {},
    this.readAt,
    this.createdAt,
  });

  final int id;
  final String title;
  final String body;
  final bool isRead;

  /// Free-form category the server tags the row with (`payment`,
  /// `announcement`, …). Drives the leading icon; unknown values fall back to
  /// a generic bell rather than dropping the row.
  final String? type;

  /// Opaque payload the sender attached — e.g. `{ "invoice_id": 12 }`. Kept as
  /// raw JSON because nothing in this app routes on it yet.
  final Map<String, dynamic> data;

  final DateTime? readAt;
  final DateTime? createdAt;

  AppNotification copyWith({bool? isRead, DateTime? readAt}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      isRead: isRead ?? this.isRead,
      type: type,
      data: data,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt,
    );
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: _asInt(json['id']) ?? 0,
      title: _asString(json['title']) ?? '',
      body: _asString(json['body']) ?? '',
      isRead: json['is_read'] == true,
      type: _asString(json['type']),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : const {},
      readAt: _asDate(json['read_at']),
      createdAt: _asDate(json['created_at']),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  static String? _asString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  /// The API sends UTC ISO-8601 strings; everything downstream renders in the
  /// device's zone, so the parse converts rather than leaving a UTC clock.
  static DateTime? _asDate(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return DateTime.tryParse(value.trim())?.toLocal();
  }
}

/// One page of the inbox, plus the unread badge the list response carries.
class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
    required this.unreadCount,
  });

  final List<AppNotification> items;
  final int total;
  final int page;
  final int pages;
  final int unreadCount;

  bool get hasMore => page < pages;

  static const empty = NotificationPage(
    items: [],
    total: 0,
    page: 1,
    pages: 1,
    unreadCount: 0,
  );
}

/// The staff notifications API (`docs/staff/notifications.md`).
///
/// Every endpoint here is authenticated-only and scoped to the caller by the
/// server — no permission key is involved, so every teacher has an inbox. The
/// device-token calls are what connect this app to FCM push.
abstract class NotificationsRepository {
  Future<NotificationPage> getNotifications(
    String token, {
    int page,
    int limit,
    bool? isRead,
  });

  Future<int> getUnreadCount(String token);

  Future<void> markAsRead(String token, {required int id});

  Future<void> markAllAsRead(String token);

  /// Registers this device's FCM registration token against the session user.
  /// Re-registering the same token is an update server-side, so this is safe
  /// to call on every launch.
  Future<void> registerDeviceToken(
    String token, {
    required String deviceToken,
    required String platform,
  });

  Future<void> unregisterDeviceToken(
    String token, {
    required String deviceToken,
  });
}
