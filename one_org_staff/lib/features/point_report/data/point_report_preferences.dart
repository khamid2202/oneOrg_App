import 'package:shared_preferences/shared_preferences.dart';

import '../domain/point_report_repository.dart';

/// Remembers the report's filters between visits.
///
/// The web keeps the same choices in localStorage under
/// `POINT_REPORT_FILTERS_KEY`; a teacher who hid the name column and picked
/// their class should not have to redo it every time they leave the tab.
///
/// Only the choices are stored — never the report data itself, which must come
/// back from the API so a stale week is never shown as current.
class PointReportPreferences {
  PointReportPreferences({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _classKey = 'point_report_group_id';
  static const _dateModeKey = 'point_report_date_mode';
  static const _hiddenColumnsKey = 'point_report_hidden_columns';

  SharedPreferences? _preferences;

  Future<SharedPreferences?> get _prefs async {
    try {
      return _preferences ??= await SharedPreferences.getInstance();
    } catch (_) {
      // A preference store that won't open is not worth failing the page over.
      return null;
    }
  }

  Future<int?> loadGroupId() async => (await _prefs)?.getInt(_classKey);

  Future<void> saveGroupId(int? groupId) async {
    final prefs = await _prefs;
    if (prefs == null) return;
    if (groupId == null) {
      await prefs.remove(_classKey);
    } else {
      await prefs.setInt(_classKey, groupId);
    }
  }

  Future<PointReportDateMode> loadDateMode() async {
    final stored = (await _prefs)?.getString(_dateModeKey);
    for (final mode in PointReportDateMode.values) {
      if (mode.name == stored) {
        return mode;
      }
    }
    return PointReportDateMode.weekly;
  }

  Future<void> saveDateMode(PointReportDateMode mode) async {
    await (await _prefs)?.setString(_dateModeKey, mode.name);
  }

  /// Hidden columns are stored rather than shown ones, so a subject that did
  /// not exist when the choice was made appears by default instead of being
  /// silently missing.
  Future<Set<String>> loadHiddenColumns() async {
    final prefs = await _prefs;
    final stored = prefs?.getStringList(_hiddenColumnsKey);
    if (stored == null) {
      // First run: match the web's default of hiding the name column.
      return {...PointReportColumns.hiddenByDefault};
    }
    return stored.toSet();
  }

  Future<void> saveHiddenColumns(Set<String> hidden) async {
    await (await _prefs)?.setStringList(_hiddenColumnsKey, hidden.toList());
  }
}
