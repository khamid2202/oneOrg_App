import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_items.dart';

/// Each user's own order of the small Home tiles, set by holding a tile and
/// dragging it (like the web's home). Kept on this phone per user id; there
/// is no backend preference store, so it doesn't follow them to another
/// device.
class HomeTileOrder {
  HomeTileOrder({SharedPreferences? prefs}) : _prefs = prefs;

  static const storageKey = 'home_tile_order';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _store async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<Map<String, dynamic>> _readAll() async {
    final raw = (await _store).getString(storageKey);
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// The saved order for [userId], or null when they never moved anything.
  Future<List<String>?> load(Object userId) async {
    final mine = (await _readAll())['$userId'];
    return mine is List ? mine.map((e) => '$e').toList() : null;
  }

  /// Saves [order] for [userId]; null goes back to the default order.
  Future<void> save(Object userId, List<AppItem>? order) async {
    final all = await _readAll();
    if (order == null) {
      all.remove('$userId');
    } else {
      all['$userId'] = [for (final item in order) item.name];
    }
    await (await _store).setString(storageKey, jsonEncode(all));
  }
}

/// [tiles] in the user's [saved] order. A tile missing from it (one added
/// since they arranged theirs) slots in right after its neighbour in the
/// default order, so it shows where it belongs rather than at the end.
List<AppItem> sortTiles(List<AppItem> tiles, List<String>? saved) {
  if (saved == null || saved.isEmpty) return tiles;
  double rank(AppItem item) {
    final mine = saved.indexOf(item.name);
    if (mine >= 0) return mine.toDouble();
    final base = tiles.indexOf(item);
    for (var i = base - 1; i >= 0; i--) {
      final at = saved.indexOf(tiles[i].name);
      if (at >= 0) return at + 0.5 + base / 1000;
    }
    return -1 + base / 1000;
  }

  return [...tiles]..sort((a, b) => rank(a).compareTo(rank(b)));
}
