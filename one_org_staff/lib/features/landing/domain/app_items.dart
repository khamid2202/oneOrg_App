import '../../auth/domain/auth_repository.dart';

/// The app's destinations, named after the web's navigation items.
enum AppItem {
  lessons,
  myClass,
  grades,
  behavior,
  teachingTools,
  myPlan,
  myPoints,
  myFundings,
  exams,
  timetable,
  rewards,
  colleagues,
  pointReport,
  calendar,
  myLessonAnalysis,
  lessonAnalysis,
  myDepartment,
  substitutions,
  attendanceCheck,
  cashier,
  staffPoints,
  fundings,
}

/// Pages opened over the shell (with a back arrow) instead of as a tab.
const pushedItems = {
  AppItem.calendar,
  AppItem.myLessonAnalysis,
  AppItem.lessonAnalysis,
  AppItem.myDepartment,
  AppItem.substitutions,
  AppItem.attendanceCheck,
  AppItem.cashier,
  AppItem.staffPoints,
  AppItem.fundings,
};

List<String> _keys(String resource) => [
  '$resource.read',
  '$resource.create',
  '$resource.update',
  '$resource.delete',
];

/// The rules of the web's `navigationConfig.jsx`, for the pages this app has.
/// Before the profile is known, the person is treated as a regular teacher.
class AppAccess {
  const AppAccess(this.profile);

  final AppUserProfile? profile;

  bool get _teacher => profile?.isTeacher ?? true;
  bool get _admin => profile?.isAdmin ?? false;

  bool _any(Iterable<String> keys) => profile?.hasAnyPermission(keys) ?? false;

  bool allows(AppItem item) => switch (item) {
    AppItem.lessons => _teacher || _any(const ['my_lessons.read']),
    AppItem.myClass => _teacher,
    // Whoever reads every grade has a school-wide report for that instead,
    // unless they also teach.
    AppItem.grades =>
      _any(const ['lesson_grades.read']) &&
          (_teacher || !_any(const ['lesson_grades.read_all'])),
    AppItem.behavior => _any(_keys('behavior')),
    // Uses the Report page's class lists, so it shares its permission.
    AppItem.teachingTools => _teacher || _any(_keys('behavior')),
    // The server scopes these to the signed-in person.
    AppItem.myPlan || AppItem.myPoints || AppItem.myFundings => true,
    AppItem.exams =>
      _teacher || _any([..._keys('exams'), ..._keys('exam_results')]),
    AppItem.timetable => _teacher || _any(_keys('timetable')),
    // Switched off for now: no tile, no search hit. The page is kept.
    AppItem.rewards => false,
    AppItem.colleagues => true,
    AppItem.pointReport => _teacher || _any(const ['lesson_grades.read']),
    // `GET /calendar` needs no permission.
    AppItem.calendar => true,
    // The API scopes the list to the teacher's own lessons.
    AppItem.myLessonAnalysis => _teacher,
    AppItem.lessonAnalysis => _any(_keys('lesson_observations')),
    AppItem.myDepartment => _any(const ['departments.read']),
    AppItem.substitutions => _any(const ['substitutions.create']),
    AppItem.attendanceCheck => _any(const ['attendance.update']),
    AppItem.cashier => _any(_keys('cashier')),
    AppItem.staffPoints => _any(_keys('user_points')),
    AppItem.fundings => _any(_keys('fundings')),
  };

  /// Small Home tiles, in the order teachers reach for them.
  List<AppItem> get smallTiles => const [
    AppItem.behavior,
    AppItem.teachingTools,
    AppItem.myPlan,
    AppItem.myPoints,
    AppItem.myFundings,
    AppItem.myLessonAnalysis,
    AppItem.exams,
    AppItem.timetable,
    AppItem.calendar,
    AppItem.colleagues,
    AppItem.pointReport,
    AppItem.myDepartment,
    AppItem.lessonAnalysis,
    AppItem.substitutions,
    AppItem.attendanceCheck,
    AppItem.cashier,
    AppItem.staffPoints,
    AppItem.fundings,
  ].where(allows).toList();

  bool get _regularTeacher => _teacher && !_admin;

  /// Phone bar items between Home and Profile. Regular teachers have Report in
  /// the middle; others get the full Timetable instead.
  List<AppItem> get phoneBar => [
    if (allows(AppItem.lessons)) AppItem.lessons,
    if (_regularTeacher && allows(AppItem.behavior)) AppItem.behavior,
    if (allows(AppItem.myClass)) AppItem.myClass,
    if (allows(AppItem.timetable) && !_regularTeacher) AppItem.timetable,
  ];
}
