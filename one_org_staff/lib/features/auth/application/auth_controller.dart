import 'package:flutter/foundation.dart';

import 'package:one_org_staff/config/api_config.dart';
import '../../TimeTable/time_table_repository.dart';
import '../../MyLessons/lesson_points_repository.dart';
import '../data/token_storage.dart';
import '../domain/auth_repository.dart';

enum AuthStatus {
  checking,
  unauthenticated,
  authenticated,
}

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required TokenStorage tokenStorage,
    TimetableRepository? timetableRepository,
    LessonPointsRepository? pointsRepository,
  })  : _authRepository = authRepository,
        _tokenStorage = tokenStorage,
        _timetableRepository = timetableRepository,
        _pointsRepository = pointsRepository;

  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;
  final TimetableRepository? _timetableRepository;
  final LessonPointsRepository? _pointsRepository;

  AuthStatus _status = AuthStatus.checking;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthStatus get status => _status;

  bool get isSubmitting => _isSubmitting;

  String? get errorMessage => _errorMessage;

  Future<AppUserProfile> loadCurrentUserProfile() async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return _authRepository.getCurrentUser(token);
  }

  Future<void> restoreSession() async {
    _status = AuthStatus.checking;
    _errorMessage = null;
    notifyListeners();

    final storedToken = await _tokenStorage.readToken();
    if (storedToken == null || storedToken.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      await _authRepository.validate(storedToken);
      _status = AuthStatus.authenticated;
    } on AuthFailure {
      await _tokenStorage.clearToken();
      _status = AuthStatus.unauthenticated;
    } catch (_) {
      await _tokenStorage.clearToken();
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> signIn({
    required String username,
    required String password,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final token = await _authRepository.signIn(
        username: username,
        password: password,
      );
      await _tokenStorage.writeToken(token);
      _status = AuthStatus.authenticated;
      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;
      _status = AuthStatus.unauthenticated;
      return false;
    } catch (_) {
      _errorMessage = 'Unable to sign in right now.';
      _status = AuthStatus.unauthenticated;
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  Future<String> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return _authRepository.updatePassword(
      token,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<TimetableDaySchedule> loadMyLessonsForDate(DateTime date) async {
    final timetableRepository = _timetableRepository;
    if (timetableRepository == null) {
      throw const AuthFailure('Timetable is not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return timetableRepository.getMyLessons(token, date: date);
  }

  Future<TimetableDaySchedule> loadTimetableForDate(DateTime date) {
    return loadMyLessonsForDate(date);
  }

  Future<List<TimetableLesson>> loadFullTimetable() async {
    final timetableRepository = _timetableRepository;
    if (timetableRepository == null) {
      throw const AuthFailure('Timetable is not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return timetableRepository.getTimetable(token);
  }

  Future<List<StudentEntry>> loadStudentsForGroup(int groupId) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getStudentsForGroup(token, groupId: groupId);
  }

  Future<void> savePointsBulk(List<StudentPointDraft> points) async {
    if (points.isEmpty) {
      return;
    }

    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    await pointsRepository.createPointsBulk(token, points);
  }

  Future<Map<int, double>> loadPointsForGroupAndDate({
    required int groupId,
    required DateTime date,
    int? subjectId,
  }) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getPointsForGroupAndDate(
      token,
      groupId: groupId,
      date: date,
      subjectId: subjectId,
    );
  }

  Future<List<GroupEntry>> loadGroups() async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getGroups(
      token,
      academicYearId: ApiConfig.academicYearId,
    );
  }

  Future<List<ContactEntry>> loadContactsForStudent(int studentId) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Contacts are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getContactsForStudent(token, studentId: studentId);
  }

  Future<ContactEntry> createContact({
    required int studentId,
    required String fullName,
    required String relationship,
    required String phoneNumber,
  }) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Contacts are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.createContact(
      token,
      studentId: studentId,
      fullName: fullName,
      relationship: relationship,
      phoneNumber: phoneNumber,
    );
  }

  Future<ContactEntry> updateContact({
    required int contactId,
    String? fullName,
    String? relationship,
    String? phoneNumber,
  }) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Contacts are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.updateContact(
      token,
      contactId: contactId,
      fullName: fullName,
      relationship: relationship,
      phoneNumber: phoneNumber,
    );
  }

  Future<void> deleteContact(int contactId) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Contacts are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    await pointsRepository.deleteContact(token, contactId: contactId);
  }

  Future<void> signOut() async {
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        await _authRepository.revoke(token);
      } catch (_) {
        // We still want to log out locally even if revoke fails
      }
    }

    await _tokenStorage.clearToken();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}