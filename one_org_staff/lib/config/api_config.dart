import 'package:flutter/foundation.dart';

class ApiConfig {
  const ApiConfig._();

  static const productionUrl = 'https://api.oneorg.uz';
  static const developmentUrl = 'https://dev-api.oneorg.uz';

  /// `--dart-define=API_BASE_URL=…` wins over both defaults.
  static const _override = String.fromEnvironment('API_BASE_URL');

  static const _academicYearIdValue = int.fromEnvironment(
    'ACADEMIC_YEAR_ID',
    defaultValue: 1,
  );

  /// Store builds (`flutter build appbundle/ipa`) talk to production;
  /// `flutter run` and tests stay on the dev server.
  static String get baseUrl => resolveBaseUrl(_override, release: kReleaseMode);

  @visibleForTesting
  static String resolveBaseUrl(String override, {required bool release}) {
    final chosen = override.trim().isNotEmpty
        ? override.trim()
        : release
        ? productionUrl
        : developmentUrl;
    return chosen.endsWith('/')
        ? chosen.substring(0, chosen.length - 1)
        : chosen;
  }

  static int get academicYearId => _academicYearIdValue;
}
