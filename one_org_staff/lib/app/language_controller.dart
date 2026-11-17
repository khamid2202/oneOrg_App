import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's language: English, Uzbek or Russian, as on the web. Stored under
/// the web's `system_language` key and, like the theme, kept across sign-out.
class LanguageController extends ChangeNotifier {
  LanguageController({SharedPreferences? preferences})
    : _preferences = preferences;

  static const storageKey = 'system_language';
  static const options = {'en': 'English', 'uz': 'O‘zbekcha', 'ru': 'Русский'};

  SharedPreferences? _preferences;
  String _code = 'en';

  String get code => _code;
  Locale get locale => Locale(_code);

  Future<void> load() async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      final stored = prefs.getString(storageKey);
      if (options.containsKey(stored)) {
        _code = stored!;
        notifyListeners();
      }
    } catch (_) {
      // English is already set; a language is never worth failing start-up.
    }
  }

  Future<void> setLanguage(String code) async {
    if (code == _code || !options.containsKey(code)) return;
    _code = code;
    notifyListeners();
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      await prefs.setString(storageKey, code);
    } catch (_) {
      // Still applied for this run.
    }
  }
}
