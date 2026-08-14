import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Holds the user's appearance preferences and persists them.
///
/// The storage keys match the web app's localStorage keys (`system_accent`,
/// `system_theme_mode`, `system_dark_variant`) so the two apps describe the
/// same settings the same way.
///
/// Preferences deliberately survive sign-out: they are a device preference, not
/// account data, and snapping back to purple-on-light at the login screen after
/// someone has chosen True Black reads as a bug.
class ThemeController extends ChangeNotifier {
  ThemeController({SharedPreferences? preferences})
    : _preferences = preferences;

  static const accentKeyPref = 'system_accent';
  static const themeModePref = 'system_theme_mode';
  static const darkVariantPref = 'system_dark_variant';

  SharedPreferences? _preferences;

  AppAccent _accent = kDefaultAccent;
  ThemeMode _themeMode = ThemeMode.light;
  AppDarkVariant _darkVariant = kDefaultDarkVariant;

  AppAccent get accent => _accent;
  ThemeMode get themeMode => _themeMode;
  AppDarkVariant get darkVariant => _darkVariant;

  bool get isDark => _themeMode == ThemeMode.dark;

  /// Reads the stored preferences. Safe to call before [runApp] finishes — a
  /// failure here just leaves the defaults in place rather than blocking start.
  Future<void> load() async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();

      _accent = accentForKey(prefs.getString(accentKeyPref));
      _darkVariant = darkVariantForKey(prefs.getString(darkVariantPref));
      _themeMode = prefs.getString(themeModePref) == 'dark'
          ? ThemeMode.dark
          : ThemeMode.light;

      notifyListeners();
    } catch (_) {
      // Defaults are already set; appearance is never worth failing start-up.
    }
  }

  Future<void> setAccent(AppAccent accent) async {
    if (_accent.key == accent.key) {
      return;
    }
    _accent = accent;
    notifyListeners();
    await _write(accentKeyPref, accent.key);
  }

  /// Records which shade of dark to use. Like the web, this does **not** turn
  /// dark mode on — [setThemeMode] is the only thing that does.
  Future<void> setDarkVariant(AppDarkVariant variant) async {
    if (_darkVariant.key == variant.key) {
      return;
    }
    _darkVariant = variant;
    notifyListeners();
    await _write(darkVariantPref, variant.key);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _write(themeModePref, mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> toggleThemeMode() {
    return setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> _write(String key, String value) async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } catch (_) {
      // The in-memory choice already applied; losing the write only means it
      // won't survive a restart.
    }
  }
}
