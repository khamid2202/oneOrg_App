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
}

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
  };

  /// Small Home tiles, in the order teachers reach for them.
  List<AppItem> get smallTiles => const [
    AppItem.behavior,
    AppItem.teachingTools,
    AppItem.myPlan,
    AppItem.myPoints,
    AppItem.myFundings,
    AppItem.exams,
    AppItem.timetable,
    AppItem.colleagues,
    AppItem.pointReport,
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
