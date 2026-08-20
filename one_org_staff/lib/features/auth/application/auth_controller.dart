import 'package:flutter/foundation.dart';

import 'package:one_org_staff/config/api_config.dart';
import '../../timetable/time_table_repository.dart';
import '../../MyLessons/lesson_points_repository.dart';
import '../../colleagues/domain/colleagues_repository.dart';
import '../../exams/domain/exams_repository.dart';
import '../../notifications/domain/notifications_repository.dart';
import '../../point_report/domain/point_report_repository.dart';
import '../data/token_storage.dart';
import '../domain/auth_repository.dart';

enum AuthStatus { checking, unauthenticated, authenticated }

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required TokenStorage tokenStorage,
    TimetableRepository? timetableRepository,
    LessonPointsRepository? pointsRepository,
    ColleaguesRepository? colleaguesRepository,
    PointReportRepository? pointReportRepository,
    ExamsRepository? examsRepository,
    NotificationsRepository? notificationsRepository,
  }) : _authRepository = authRepository,
       _tokenStorage = tokenStorage,
       _timetableRepository = timetableRepository,
       _pointsRepository = pointsRepository,
       _colleaguesRepository = colleaguesRepository,
       _pointReportRepository = pointReportRepository,
       _examsRepository = examsRepository,
       _notificationsRepository = notificationsRepository;

  final AuthRepository _authRepository;
  final TokenStorage _tokenStorage;
  final TimetableRepository? _timetableRepository;
  final LessonPointsRepository? _pointsRepository;
  final ColleaguesRepository? _colleaguesRepository;
  final PointReportRepository? _pointReportRepository;
  final ExamsRepository? _examsRepository;
  final NotificationsRepository? _notificationsRepository;

  /// Runs just before the session token is discarded on sign-out, while an
  /// authenticated call is still possible. [PushService] hangs the
  /// device-token teardown off this — a token left registered would keep
  /// pushing this user's notifications to a phone they signed out of.
  /// Failures here never block the sign-out.
  Future<void> Function()? onBeforeSignOut;

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

  Future<String?> uploadProfilePicture({
    required int userId,
    required List<int> bytes,
    required String filename,
  }) async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return _authRepository.uploadProfilePicture(
      token,
      userId: userId,
      bytes: bytes,
      filename: filename,
    );
  }

  Future<String?> removeProfilePicture({required int userId}) async {
    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return _authRepository.removeProfilePicture(token, userId: userId);
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

  Future<List<TimetableLesson>> loadFullTimetable({int? academicYearId}) async {
    final timetableRepository = _timetableRepository;
    if (timetableRepository == null) {
      throw const AuthFailure('Timetable is not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return timetableRepository.getTimetable(
      token,
      academicYearId: academicYearId,
    );
  }

  Future<List<Colleague>> loadColleagues() async {
    final colleaguesRepository = _colleaguesRepository;
    if (colleaguesRepository == null) {
      throw const AuthFailure('Colleagues are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return colleaguesRepository.getColleagues(token);
  }

  Future<List<StudentPoint>> loadPointsForReport({
    required int groupId,
    required DateTime start,
    required DateTime end,
  }) async {
    final pointReportRepository = _pointReportRepository;
    if (pointReportRepository == null) {
      throw const AuthFailure('The point report is not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointReportRepository.getPoints(
      token,
      groupId: groupId,
      start: start,
      end: end,
    );
  }

  /// Shared guard for the exam calls: both a configured repository and a live
  /// session are required before any of them can run.
  Future<T> _withExams<T>(
    Future<T> Function(ExamsRepository repo, String token) action,
  ) async {
    final examsRepository = _examsRepository;
    if (examsRepository == null) {
      throw const AuthFailure('Exams are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return action(examsRepository, token);
  }

  Future<List<ExamPeriod>> loadExamPeriods({
    bool? isActive,
    int? academicYearId,
  }) {
    return _withExams(
      (repo, token) => repo.getExamPeriods(
        token,
        isActive: isActive,
        academicYearId: academicYearId,
      ),
    );
  }

  Future<List<Exam>> loadExams({int? examPeriodId}) => _withExams(
    (repo, token) => repo.getExams(token, examPeriodId: examPeriodId),
  );

  Future<Exam> createExam({
    required int examPeriodId,
    required int subjectId,
    required List<int> groupIds,
    required int maxScore,
  }) {
    return _withExams(
      (repo, token) => repo.createExam(
        token,
        examPeriodId: examPeriodId,
        subjectId: subjectId,
        groupIds: groupIds,
        maxScore: maxScore,
      ),
    );
  }

  Future<void> deleteExam(int examId) =>
      _withExams((repo, token) => repo.deleteExam(token, examId: examId));

  Future<List<SubjectEntry>> loadSubjects() =>
      _withExams((repo, token) => repo.getSubjects(token));

  Future<List<ExamResult>> loadExamResults(int examId) =>
      _withExams((repo, token) => repo.getExamResults(token, examId: examId));

  Future<void> createExamResultsBulk(List<ExamResultDraft> drafts) =>
      _withExams((repo, token) => repo.createExamResultsBulk(token, drafts));

  Future<void> updateExamResult({required int resultId, required double score}) {
    return _withExams(
      (repo, token) =>
          repo.updateExamResult(token, resultId: resultId, score: score),
    );
  }

  Future<void> deleteExamResult(int resultId) => _withExams(
    (repo, token) => repo.deleteExamResult(token, resultId: resultId),
  );

  Future<List<AcademicYearEntry>> loadAcademicYears() async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Academic years are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getAcademicYears(token);
  }

  Future<List<GuardianEntry>> loadGuardians(int personId) => _withPoints(
    (repo, token) => repo.getGuardians(token, personId: personId),
  );

  Future<GuardianEntry> createGuardian({
    required int personId,
    required String fullName,
    required String relation,
    required String phone,
    String? workAddress,
    String? position,
  }) {
    return _withPoints(
      (repo, token) => repo.createGuardian(
        token,
        personId: personId,
        fullName: fullName,
        relation: relation,
        phone: phone,
        workAddress: workAddress,
        position: position,
      ),
    );
  }

  Future<GuardianEntry> updateGuardian({
    required int guardianId,
    String? fullName,
    String? relation,
    String? phone,
    String? workAddress,
    String? position,
  }) {
    return _withPoints(
      (repo, token) => repo.updateGuardian(
        token,
        guardianId: guardianId,
        fullName: fullName,
        relation: relation,
        phone: phone,
        workAddress: workAddress,
        position: position,
      ),
    );
  }

  Future<void> deleteGuardian(int guardianId) => _withPoints(
    (repo, token) => repo.deleteGuardian(token, guardianId: guardianId),
  );

  Future<List<DocumentEntry>> loadDocuments(int personId) => _withPoints(
    (repo, token) => repo.getDocuments(token, personId: personId),
  );

  Future<DocumentEntry> createDocument({
    required int personId,
    required String documentName,
    required String documentType,
    required List<int> bytes,
    required String filename,
  }) {
    return _withPoints(
      (repo, token) => repo.createDocument(
        token,
        personId: personId,
        documentName: documentName,
        documentType: documentType,
        bytes: bytes,
        filename: filename,
      ),
    );
  }

  Future<void> deleteDocument(int documentId) => _withPoints(
    (repo, token) => repo.deleteDocument(token, documentId: documentId),
  );

  /// Shared guard for the person-scoped calls: both a configured repository and
  /// a live session are required before any of them can run.
  Future<T> _withPoints<T>(
    Future<T> Function(LessonPointsRepository repo, String token) action,
  ) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Student details are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return action(pointsRepository, token);
  }

  Future<String?> uploadPersonPicture({
    required int personId,
    required List<int> bytes,
    required String filename,
  }) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Student details are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.uploadPersonPicture(
      token,
      personId: personId,
      bytes: bytes,
      filename: filename,
    );
  }

  Future<String?> removePersonPicture({required int personId}) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Student details are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.removePersonPicture(token, personId: personId);
  }

  Future<PersonDetails> updatePersonDetails({
    required int personId,
    required Map<String, String> changes,
  }) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Student details are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.updatePersonDetails(
      token,
      personId: personId,
      changes: changes,
    );
  }

  Future<List<StudentEntry>> loadStudentsForGroup(
    int groupId, {
    bool includeContacts = false,
  }) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getStudentsForGroup(
      token,
      groupId: groupId,
      includeContacts: includeContacts,
    );
  }

  /// The rewards roster: one class, or every student when [groupId] is null.
  Future<List<StudentEntry>> loadAllStudents({int? groupId}) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getAllStudents(token, groupId: groupId);
  }

  /// Net point balances keyed by person id, for the same scope as
  /// [loadAllStudents].
  Future<Map<int, double>> loadPointTotalsByStudent({int? groupId}) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Points are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getPointTotalsByStudent(token, groupId: groupId);
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

  /// Defaults to the configured year; My Class passes the year the teacher
  /// picked so the roster follows the dropdown.
  Future<List<GroupEntry>> loadGroups({int? academicYearId}) async {
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
      academicYearId: academicYearId ?? ApiConfig.academicYearId,
    );
  }

  Future<List<ContactEntry>> loadContactsForStudent(int personId) async {
    final pointsRepository = _pointsRepository;
    if (pointsRepository == null) {
      throw const AuthFailure('Contacts are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return pointsRepository.getContactsForStudent(token, personId: personId);
  }

  Future<ContactEntry> createContact({
    required int personId,
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
      personId: personId,
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

  Future<NotificationPage> loadNotifications({
    int page = 1,
    int limit = 20,
    bool? isRead,
  }) async {
    final notificationsRepository = _notificationsRepository;
    if (notificationsRepository == null) {
      throw const AuthFailure('Notifications are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return notificationsRepository.getNotifications(
      token,
      page: page,
      limit: limit,
      isRead: isRead,
    );
  }

  Future<int> loadUnreadNotificationCount() async {
    final notificationsRepository = _notificationsRepository;
    if (notificationsRepository == null) {
      throw const AuthFailure('Notifications are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    return notificationsRepository.getUnreadCount(token);
  }

  Future<void> markNotificationRead(int id) async {
    final notificationsRepository = _notificationsRepository;
    if (notificationsRepository == null) {
      throw const AuthFailure('Notifications are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    await notificationsRepository.markAsRead(token, id: id);
  }

  Future<void> markAllNotificationsRead() async {
    final notificationsRepository = _notificationsRepository;
    if (notificationsRepository == null) {
      throw const AuthFailure('Notifications are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    await notificationsRepository.markAllAsRead(token);
  }

  Future<void> registerDeviceToken({
    required String deviceToken,
    required String platform,
  }) async {
    final notificationsRepository = _notificationsRepository;
    if (notificationsRepository == null) {
      throw const AuthFailure('Notifications are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    await notificationsRepository.registerDeviceToken(
      token,
      deviceToken: deviceToken,
      platform: platform,
    );
  }

  Future<void> unregisterDeviceToken(String deviceToken) async {
    final notificationsRepository = _notificationsRepository;
    if (notificationsRepository == null) {
      throw const AuthFailure('Notifications are not configured.');
    }

    final token = await _tokenStorage.readToken();
    if (token == null || token.isEmpty) {
      throw const AuthFailure('No active session found.');
    }

    await notificationsRepository.unregisterDeviceToken(
      token,
      deviceToken: deviceToken,
    );
  }

  Future<void> signOut() async {
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      try {
        await onBeforeSignOut?.call();
      } catch (_) {
        // Best effort — a device left registered is better than a user stuck
        // on a screen they asked to leave.
      }

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
