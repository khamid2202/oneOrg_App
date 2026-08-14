class ApiConfig {
  const ApiConfig._();

  static const _baseUrlValue = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://dev-api.oneorg.uz',
  );

  static const _academicYearIdValue = int.fromEnvironment(
    'ACADEMIC_YEAR_ID',
    defaultValue: 1,
  );

  static String get baseUrl {
    final trimmed = _baseUrlValue.trim();
    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed;
  }

  static int get academicYearId => _academicYearIdValue;
}
