import '../features/auth/domain/auth_repository.dart';
import '../features/MyLessons/lesson_points_repository.dart';
import 'api_client.dart';

/// What the pages ported from the web need: the API, who is signed in and
/// the school year they work in.
class StaffContext {
  StaffContext({
    required this.api,
    required this.profile,
    required Future<List<AcademicYearEntry>> Function() loadAcademicYears,
  }) : _loadAcademicYears = loadAcademicYears;

  final ApiClient api;
  final AppUserProfile? profile;
  final Future<List<AcademicYearEntry>> Function() _loadAcademicYears;

  int? get userId => profile?.id;

  bool can(String key) => profile?.hasAnyPermission([key]) ?? false;
  bool canAny(Iterable<String> keys) =>
      profile?.hasAnyPermission(keys) ?? false;

  Future<List<Map<String, dynamic>>>? _staff;

  /// The staff roster from `GET /users`, asked once. Never throws.
  Future<List<Map<String, dynamic>>> staff() => _staff ??= () async {
    try {
      final body = await api.get('/users', {'limit': 1000});
      final list = body is Map && body['users'] is List
          ? body['users']
          : (body is Map ? body['result'] : null);
      return list is List
          ? list.whereType<Map>().map(Map<String, dynamic>.from).toList()
          : <Map<String, dynamic>>[];
    } catch (_) {
      _staff = null;
      return <Map<String, dynamic>>[];
    }
  }();

  /// Active staff holding the `teacher` role, by name.
  Future<List<Map<String, dynamic>>> teachers() async {
    final all = await staff();
    return all
        .where(
          (u) =>
              (u['status'] == null || u['status'] == 'active') &&
              userRoles(u).contains('teacher'),
        )
        .toList()
      ..sort((a, b) => personName(a).compareTo(personName(b)));
  }

  Future<AcademicYearEntry?>? _year;

  /// The active academic year, asked once.
  Future<AcademicYearEntry?> academicYear() => _year ??= () async {
    try {
      final years = await _loadAcademicYears();
      return years.where((y) => y.isActive).firstOrNull ?? years.firstOrNull;
    } catch (_) {
      _year = null;
      return null;
    }
  }();

  /// The active academic year's id.
  Future<int?> academicYearId() async => (await academicYear())?.id;
}
