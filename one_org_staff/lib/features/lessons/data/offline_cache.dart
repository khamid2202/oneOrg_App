import 'package:shared_preferences/shared_preferences.dart';

/// The last good answer of the teaching day's GET requests, kept on the phone
/// so a lesson still opens without a connection. Like the web's
/// `offlineCache.js`, it holds recent small answers only and is cleared on
/// sign-out. A failure here only means the page needs a connection.
class OfflineCache {
  OfflineCache({SharedPreferences? preferences}) : _preferences = preferences;

  static const prefix = 'offline:get:';
  static const _indexKey = 'offline:index';
  static const maxEntries = 60;

  SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ??= await SharedPreferences.getInstance();

  Future<void> remember(String key, String body) async {
    try {
      final prefs = await _prefs;
      final storageKey = '$prefix$key';
      await prefs.setString(storageKey, body);
      final index = [
        storageKey,
        ...(prefs.getStringList(_indexKey) ?? const <String>[]).where(
          (existing) => existing != storageKey,
        ),
      ];
      for (final stale in index.skip(maxEntries)) {
        await prefs.remove(stale);
      }
      await prefs.setStringList(_indexKey, index.take(maxEntries).toList());
    } catch (_) {}
  }

  Future<String?> recall(String key) async {
    try {
      return (await _prefs).getString('$prefix$key');
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await _prefs;
      for (final key in prefs.getStringList(_indexKey) ?? const <String>[]) {
        await prefs.remove(key);
      }
      await prefs.remove(_indexKey);
    } catch (_) {}
  }
}
