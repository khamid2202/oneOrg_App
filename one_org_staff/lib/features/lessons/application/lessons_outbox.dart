import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/lessons_repository.dart';

enum OutboxStatus { pending, uploading, rejected }

/// One save kept on the phone: a single request waiting to reach the server.
class OutboxEntry {
  OutboxEntry({
    required this.id,
    required this.kind,
    required this.lessonId,
    required this.body,
    required this.label,
    required this.createdAt,
    this.status = OutboxStatus.pending,
    this.attempts = 0,
    this.nextAt,
    this.error,
  });

  final String id;
  final UploadKind kind;
  final int lessonId;
  Map<String, dynamic> body;
  String label;
  final DateTime createdAt;
  OutboxStatus status;
  int attempts;
  DateTime? nextAt;
  String? error;

  bool get isWaiting => status != OutboxStatus.rejected;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'lessonId': lessonId,
    'body': body,
    'label': label,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    'nextAt': nextAt?.toIso8601String(),
    'error': error,
  };

  factory OutboxEntry.fromJson(Map<String, dynamic> json) {
    final status = OutboxStatus.values.byName(json['status'] as String);
    return OutboxEntry(
      id: json['id'] as String,
      kind: UploadKind.values.byName(json['kind'] as String),
      lessonId: json['lessonId'] as int,
      body: Map<String, dynamic>.from(json['body'] as Map),
      label: json['label'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      // An upload cut off by closing the app is simply tried again.
      status: status == OutboxStatus.uploading ? OutboxStatus.pending : status,
      attempts: json['attempts'] as int? ?? 0,
      nextAt: DateTime.tryParse(json['nextAt'] as String? ?? ''),
      error: json['error'] as String?,
    );
  }
}

/// A random v4 UUID, which makes a repeated upload count once.
String newRequestId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Saves kept on the phone first and uploaded behind the scenes, the same as
/// the web's `shared/offline/outbox.js`, so a teacher can keep working on a
/// slow or missing connection.
///
/// Entries upload oldest first, so attendance goes before the scores that need
/// it. While an entry waits, a newer save of the same kind for the same lesson
/// merges into it. A refused entry is kept with the server's reason until the
/// teacher discards it; nothing is dropped silently.
class LessonsOutbox extends ChangeNotifier {
  LessonsOutbox({
    required Future<void> Function(
      UploadKind kind,
      int lessonId,
      Map<String, dynamic> body,
    )
    upload,
    SharedPreferences? preferences,
    DateTime Function()? clock,
  }) : _upload = upload,
       _preferences = preferences,
       _clock = clock ?? DateTime.now;

  static const storageKey = 'outbox:v1';

  /// The lesson id of a save that isn't tied to a lesson.
  static const noLesson = 0;
  static const retryDelays = [
    Duration(seconds: 3),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];
  static const _tick = Duration(seconds: 15);

  final Future<void> Function(UploadKind, int, Map<String, dynamic>) _upload;
  final DateTime Function() _clock;
  SharedPreferences? _preferences;

  List<OutboxEntry> _entries = [];
  bool _running = false;
  bool _disposed = false;
  Timer? _ticker;
  final _uploaded = StreamController<int>.broadcast();

  List<OutboxEntry> get entries => List.unmodifiable(_entries);

  /// The lesson id, each time one of its saves reaches the server.
  Stream<int> get uploaded => _uploaded.stream;

  int get waitingCount => _entries.where((e) => e.isWaiting).length;

  /// Entries of one lesson still on their way, oldest first.
  List<OutboxEntry> waitingFor(int lessonId) => _entries
      .where((e) => e.lessonId == lessonId && e.isWaiting)
      .toList(growable: false);

  int rejectedFor(int lessonId) =>
      _entries.where((e) => e.lessonId == lessonId && !e.isWaiting).length;

  Future<void> load() async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      final raw = prefs.getString(storageKey);
      if (raw == null) return;
      _entries = (jsonDecode(raw) as List)
          .map((row) => OutboxEntry.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (_) {
      // A damaged store must not stop the app from starting.
      return;
    }
    _changed();
    unawaited(flush());
  }

  void _changed() {
    if (_disposed) return;
    unawaited(_persist(jsonEncode(_entries.map((e) => e.toJson()).toList())));
    final waiting = _entries.any((e) => e.isWaiting);
    if (!waiting) {
      _ticker?.cancel();
      _ticker = null;
    } else {
      _ticker ??= Timer.periodic(_tick, (_) => flush());
    }
    notifyListeners();
  }

  Future<void> _persist(String encoded) async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      await prefs.setString(storageKey, encoded);
    } catch (_) {
      // The entries still live in memory for this run.
    }
  }

  /// Newer values for the same students replace older ones.
  static Map<String, dynamic> _merge(
    UploadKind kind,
    Map<String, dynamic> older,
    Map<String, dynamic> newer,
  ) {
    final field = kind == UploadKind.attendance ? 'marks' : 'grades';
    final byStudent = <dynamic, Map<String, dynamic>>{
      for (final row in older[field] as List)
        (row as Map)['student_id']: Map<String, dynamic>.from(row),
    };
    for (final row in newer[field] as List) {
      final next = Map<String, dynamic>.from(row as Map);
      final id = next['student_id'];
      // Attendance marks replace each other; score rows merge by field.
      byStudent[id] = kind == UploadKind.grades && byStudent.containsKey(id)
          ? {...byStudent[id]!, ...next}
          : next;
    }
    return {...older, ...newer, field: byStudent.values.toList()};
  }

  /// Keeps a save on the phone and starts uploading it.
  void enqueue({
    required UploadKind kind,
    required int lessonId,
    required Map<String, dynamic> body,
    required String label,
  }) {
    final mergeable = kind == UploadKind.behavior
        ? null
        : _entries
              .where(
                (e) =>
                    e.kind == kind &&
                    e.lessonId == lessonId &&
                    e.status == OutboxStatus.pending,
              )
              .firstOrNull;
    if (mergeable != null) {
      mergeable
        ..body = _merge(kind, mergeable.body, body)
        ..label = label
        ..attempts = 0
        ..nextAt = null;
    } else {
      _entries = [
        ..._entries,
        OutboxEntry(
          id: newRequestId(),
          kind: kind,
          lessonId: lessonId,
          body: body,
          label: label,
          createdAt: _clock(),
        ),
      ];
    }
    _changed();
    unawaited(flush());
  }

  /// Uploads waiting entries, stopping at the first one that can't go yet.
  Future<void> flush() async {
    if (_running || _disposed) return;
    _running = true;
    try {
      while (!_disposed) {
        final next = _entries
            .where((e) => e.status == OutboxStatus.pending)
            .firstOrNull;
        final due = next?.nextAt;
        if (next == null || (due != null && due.isAfter(_clock()))) break;

        next.status = OutboxStatus.uploading;
        _changed();
        try {
          await _upload(next.kind, next.lessonId, next.body);
          _entries = _entries.where((e) => e.id != next.id).toList();
          _changed();
          if (!_disposed) _uploaded.add(next.lessonId);
        } on UploadRefused catch (refused) {
          next
            ..status = OutboxStatus.rejected
            ..error = refused.message;
          _changed();
        } catch (error) {
          final delay = retryDelays[min(next.attempts, retryDelays.length - 1)];
          next
            ..status = OutboxStatus.pending
            ..attempts = next.attempts + 1
            ..nextAt = _clock().add(delay)
            ..error = error is UploadRetryLater ? error.message : '$error';
          _changed();
          break; // The rest would fail the same way; try again later.
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Clears every wait and tries now: the app came back, or the teacher asked.
  void retryAll() {
    for (final entry in _entries) {
      if (entry.status == OutboxStatus.pending) entry.nextAt = null;
    }
    if (_entries.isNotEmpty) _changed();
    unawaited(flush());
  }

  void discard(String id) {
    _entries = _entries.where((e) => e.id != id).toList();
    _changed();
  }

  /// Sign-out: these saves belong to the account that made them.
  void clear() {
    _entries = [];
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _uploaded.close();
    super.dispose();
  }
}
