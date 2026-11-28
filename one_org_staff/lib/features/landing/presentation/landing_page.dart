import 'dart:async';

import 'package:flutter/material.dart';

import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/app/tab_back.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/language_controller.dart';
import 'package:one_org_staff/app/theme_controller.dart';
import 'package:one_org_staff/features/MyClass/homeroom.dart';
import 'package:one_org_staff/features/MyClass/my_class.dart';
import 'package:one_org_staff/features/MyClass/student_info_view.dart';
import 'package:one_org_staff/features/MyClass/student_people_sync.dart';
import 'package:one_org_staff/features/Profile/profilepage.dart';
import 'package:one_org_staff/features/timetable/presentation/timetable_page.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/behavior/presentation/behavior_page.dart';
import 'package:one_org_staff/features/branches/application/branch_controller.dart';
import 'package:one_org_staff/features/branches/presentation/branch_switcher.dart';
import 'package:one_org_staff/features/colleagues/presentation/colleagues_page.dart';
import 'package:one_org_staff/features/landing/presentation/coming_soon.dart';
import 'package:one_org_staff/features/search/domain/app_search.dart';
import 'package:one_org_staff/features/search/presentation/search_page.dart';
import 'package:one_org_staff/features/exams/presentation/exams_page.dart';
import 'package:one_org_staff/features/grades/domain/gradebook.dart';
import 'package:one_org_staff/features/grades/presentation/gradebooks_page.dart';
import 'package:one_org_staff/features/landing/application/next_lesson_day.dart';
import 'package:one_org_staff/features/landing/domain/app_items.dart';
import 'package:one_org_staff/features/landing/presentation/teacher_home.dart';
import 'package:one_org_staff/features/landing/presentation/updates_card.dart';
import 'package:one_org_staff/features/MyClass/dombit_pdf.dart';
import 'package:one_org_staff/shared/api_client.dart';
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
import 'package:one_org_staff/features/lessons/presentation/grading_sheet_page.dart';
import 'package:one_org_staff/features/lessons/presentation/lessons_page.dart';
import 'package:one_org_staff/features/lessons/presentation/uploads_sheet.dart';
import 'package:one_org_staff/features/teaching_tools/presentation/teaching_tools_page.dart';
import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:one_org_staff/features/MyLessons/lesson_points_repository.dart';
import 'package:one_org_staff/features/me/presentation/my_fundings_page.dart';
import 'package:one_org_staff/features/me/presentation/my_plan_page.dart';
import 'package:one_org_staff/features/me/presentation/my_points_page.dart';
import 'package:one_org_staff/features/notifications/application/notifications_controller.dart';
import 'package:one_org_staff/features/notifications/application/push_service.dart';
import 'package:one_org_staff/features/notifications/presentation/notification_bell.dart';
import 'package:one_org_staff/features/notifications/presentation/notification_permission_sheet.dart';
import 'package:one_org_staff/features/notifications/presentation/notifications_page.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_page.dart';
import 'package:one_org_staff/features/reset_grades/reset_grades_page.dart';
import 'package:one_org_staff/features/rewards/presentation/rewards_page.dart';
import 'package:one_org_staff/features/attendance_check/attendance_check_page.dart';
import 'package:one_org_staff/features/calendar/calendar_page.dart';
import 'package:one_org_staff/features/cashier/cashier_page.dart';
import 'package:one_org_staff/features/departments/my_department_page.dart';
import 'package:one_org_staff/features/fundings/fundings_page.dart';
import 'package:one_org_staff/features/lesson_analysis/lesson_analysis.dart';
import 'package:one_org_staff/features/lesson_plans/annual_plans.dart';
import 'package:one_org_staff/features/staff_points/staff_points_page.dart';
import 'package:one_org_staff/features/substitutions/substitutions_page.dart';
import 'package:one_org_staff/shared/staff_context.dart';
import 'package:one_org_staff/shared/sub_page.dart';
import 'package:one_org_staff/features/tour/product_tour.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.controller,
    required this.themeController,
    this.languageController,
    this.notificationsController,
    this.pushService,
    this.branchController,
    this.tourStore,
  });

  final AuthController controller;
  final ThemeController themeController;
  final LanguageController? languageController;

  /// Both null in a test harness that injects its own [AuthController]; the
  /// header then renders without a bell and the inbox tab is unreachable.
  final NotificationsController? notificationsController;
  final PushService? pushService;
  final BranchController? branchController;

  /// Shows the product tour once per user. Null (tests) never starts it on
  /// its own; Profile can still start it.
  final ProductTourStore? tourStore;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

// Home Tab Content 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁
class _LandingPageState extends State<LandingPage> {
  static const _bottomMenuOverlaySpace = 112.0;

  // The pages this shell can show. Which ones get a button in the phone bar
  // is [AppAccess.phoneBar]'s call; the bar highlights nothing on the others.
  static const _homeTab = 0;
  static const _lessonsTab = 1;
  static const _colleaguesTab = 2;
  static const _profileTab = 3;
  static const _timetableTab = 4;
  static const _myClassTab = 5;
  static const _pointReportTab = 6;
  static const _examsTab = 7;
  static const _rewardsTab = 8;
  static const _notificationsTab = 9;
  static const _gradesTab = 10;
  static const _behaviorTab = 11;
  static const _toolsTab = 12;
  static const _planTab = 13;
  static const _pointsTab = 14;
  static const _fundingsTab = 15;

  int _selectedIndex = 0;

  /// Tabs opened before the current one, oldest first, so Android's back
  /// button walks back through them instead of closing the app.
  final List<int> _history = [];

  /// Pages inside the open tab that step back on their own first.
  final List<bool Function()> _backHandlers = [];
  bool _returningViaSwipe = false;
  DateTime? _lessonsDate;
  RecentGrade? _gradebookRow;
  int? _branchId;
  NextLessonDayLoader? _today;
  String? _homeroom;
  List<RecentGrade>? _recentGrades;

  /// Time left in the lesson that is on now, for the Schedule tab.
  String? _countdown;
  Timer? _countdownTimer;

  /// Null until `/users/me` answers, and if it can't.
  AppUserProfile? _profile;

  AppAccess get _access => AppAccess(_profile);

  /// A new key per branch, so a branch switch reloads the Updates stack.
  GlobalKey _updatesKey = GlobalKey();

  // What the product tour points at.
  final _tourSchedule = GlobalKey();
  final _tourTiles = GlobalKey();
  final _tourBell = GlobalKey();
  final _tourNav = GlobalKey();
  final _tourProfile = GlobalKey();
  bool _touring = false;

  @override
  void initState() {
    super.initState();
    final lessons = widget.controller.lessons;
    if (lessons != null) {
      _today = NextLessonDayLoader(getDay: lessons.getDay)..refreshIfStale();
    }
    // Every second during a lesson the label moves; otherwise nothing changes.
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = lessonCountdown(_today?.result, DateTime.now());
      if (next != _countdown && mounted) setState(() => _countdown = next);
    });
    _branchId = widget.branchController?.activeBranchId;
    widget.branchController?.addListener(_branchChanged);
    unawaited(_loadProfile());

    final notifications = widget.notificationsController;
    final push = widget.pushService;
    if (notifications != null) {
      notifications.start();
    }
    if (push != null) {
      push.onNotificationOpened = _openNotificationsTab;
    }

    // Deferred a frame: the ask needs a mounted `Scaffold` for the snackbar it
    // may show, and a permission sheet racing the dashboard's first paint
    // reads as a pop-up out of nowhere.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (push != null && push.consumeOpenInboxRequest()) {
        // Cold-started by tapping a push — the inbox is what they asked for.
        _openNotificationsTab();
      }
      _askForNotificationPermission();
    });
  }

  @override
  void dispose() {
    widget.branchController?.removeListener(_branchChanged);
    _today?.dispose();
    _countdownTimer?.cancel();
    widget.pushService?.onNotificationOpened = null;
    widget.notificationsController?.stop();
    super.dispose();
  }

  void _openNotificationsTab() {
    widget.pushService?.consumeOpenInboxRequest();
    if (widget.notificationsController == null || widget.pushService == null) {
      return;
    }
    if (!mounted || _selectedIndex == _notificationsTab) return;
    setState(() => _select(_notificationsTab));
  }

  /// Switches to [tab], remembering where we came from. Going back to a tab
  /// already in the history drops what was opened after it, so back never
  /// loops.
  void _select(int tab) {
    if (tab == _selectedIndex) return;
    final seen = _history.indexOf(tab);
    if (seen >= 0) {
      _history.removeRange(seen, _history.length);
    } else {
      _history.add(_selectedIndex);
    }
    // Home is where back ends: nothing before it is worth returning to.
    if (tab == _homeTab) _history.clear();
    _selectedIndex = tab;
  }

  /// Android back: closes the tour, then steps back a tab, then Home.
  void _goBack() {
    if (_touring) {
      _endTour();
      return;
    }
    if (TabBackScope.dispatch(_backHandlers)) return;
    setState(() {
      _lessonsDate = null;
      _gradebookRow = null;
      _selectedIndex = _history.isNotEmpty ? _history.removeLast() : _homeTab;
      if (_selectedIndex == _homeTab) _history.clear();
    });
  }

  bool get _canLeave =>
      !_touring && _selectedIndex == _homeTab && _history.isEmpty;

  /// Asks once per install, and only after sign-in — a teacher who has just
  /// seen what the app is for has some basis for answering, which someone
  /// staring at a login screen does not.
  Future<void> _askForNotificationPermission() async {
    final push = widget.pushService;
    if (push == null) return;

    // [PushService.initialize] is fire-and-forget from the app shell, so the
    // real permission state is very likely still settling when this frame
    // lands. Asking before it does would read the placeholder `unavailable`
    // and burn the once-per-install prompt on it.
    await push.ready;
    if (!mounted) return;

    await maybeAskForNotificationPermission(context, push);
  }

  /// The first time someone signs in on this phone, once Home is settled and
  /// nothing (like the notifications prompt) is on top of it.
  Future<void> _maybeStartTour(int userId) async {
    final store = widget.tourStore;
    if (store == null || await store.hasSeen(userId)) return;
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted || _touring) return;
      final onTop = ModalRoute.of(context)?.isCurrent ?? true;
      if (onTop && _selectedIndex == _homeTab) {
        _startTour();
        return;
      }
    }
  }

  void _startTour() {
    setState(() {
      _select(_homeTab);
      _touring = true;
    });
  }

  void _endTour() {
    setState(() => _touring = false);
    final userId = _profile?.id;
    if (userId != null) unawaited(widget.tourStore?.markSeen(userId));
  }

  List<TourStep> _tourSteps(AppLocalizations l) {
    final name = _profile?.fullName.trim().split(' ').first ?? '';
    return [
      TourStep(
        id: 'welcome',
        title: l.tourWelcomeTitle(name),
        body: l.tourWelcomeBody,
      ),
      TourStep(
        id: 'schedule',
        title: l.tourScheduleTitle,
        body: l.tourScheduleBody,
        target: _tourSchedule,
      ),
      TourStep(
        id: 'updates',
        title: l.tourUpdatesTitle,
        body: l.tourUpdatesBody,
        target: _updatesKey,
      ),
      TourStep(
        id: 'apps',
        title: l.tourAppsTitle,
        body: l.tourAppsBody,
        target: _tourTiles,
      ),
      TourStep(
        id: 'notifications',
        title: l.tourNotificationsTitle,
        body: l.tourNotificationsBody,
        target: _tourBell,
      ),
      TourStep(
        id: 'nav',
        title: l.tourNavTitle,
        body: l.tourNavBody,
        target: _tourNav,
      ),
      TourStep(
        id: 'profile',
        title: l.tourProfileTitle,
        body: l.tourProfileBody,
        target: _tourProfile,
      ),
      TourStep(id: 'done', title: l.tourDoneTitle, body: l.tourDoneBody),
    ];
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.controller.loadCurrentUserProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
      unawaited(_maybeStartTour(profile.id));
      if (_access.allows(AppItem.lessons)) {
        unawaited(_prepareLessonsOffline());
      }
    } catch (_) {
      // Home falls back to what a regular teacher sees.
    }
    if (mounted) unawaited(_loadBranchData());
  }

  /// The homeroom and recent grades belong to the branch being viewed.
  void _branchChanged() {
    final id = widget.branchController?.activeBranchId;
    if (id == _branchId) return;
    _branchId = id;
    setState(() {
      _updatesKey = GlobalKey();
      _homeroom = null;
      _recentGrades = null;
    });
    unawaited(_loadBranchData());
    if (_access.allows(AppItem.lessons)) {
      unawaited(_prepareLessonsOffline());
    }
  }

  Future<void> _prepareLessonsOffline() async {
    final lessons = widget.controller.lessons;
    if (lessons is! OfflineLessonsPreparer) return;
    final preparer = lessons as OfflineLessonsPreparer;
    int? academicYearId;
    try {
      final years = await widget.controller.loadAcademicYears();
      academicYearId =
          (years.where((year) => year.isActive).firstOrNull ??
                  years.firstOrNull)
              ?.id;
    } catch (_) {}
    try {
      await preparer.prepareOffline(academicYearId: academicYearId);
    } catch (_) {}
  }

  Future<void> _loadBranchData() async {
    final branch = _branchId;
    await Future.wait([_loadHomeroom(branch), _loadRecentGrades(branch)]);
  }

  Future<void> _loadHomeroom(int? branch) async {
    if (!_access.allows(AppItem.myClass) || _profile == null) return;
    try {
      final years = await widget.controller.loadAcademicYears();
      final year =
          years.where((e) => e.isActive).firstOrNull ?? years.firstOrNull;
      final groups = await widget.controller.loadGroups(
        academicYearId: year?.id,
      );
      final group = homeroomOf(groups, _profile);
      if (!mounted || branch != _branchId) return;
      setState(() {
        _homeroom = group == null ? null : '${group.grade}${group.className}';
      });
    } catch (_) {
      // Without it Home just leaves the class card out.
    }
  }

  Future<void> _loadRecentGrades(int? branch) async {
    final lessons = widget.controller.lessons;
    if (lessons == null || !_access.allows(AppItem.grades)) return;
    List<RecentGrade> recent;
    try {
      recent = await lessons.getRecentGrades();
    } catch (_) {
      recent = const [];
    }
    if (!mounted || branch != _branchId) return;
    setState(() => _recentGrades = recent);
  }

  void _showSignOutDialog() {
    final unsent = widget.controller.outbox?.waitingCount ?? 0;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: Text(
          unsent > 0
              ? AppLocalizations.of(context).signOutUnsent(unsent)
              : 'Are you sure you want to sign out of the staff application?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
              widget.controller.signOut();
            },
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final name = _profile?.fullName.trim().split(RegExp(r'\s+')).first ?? '';
    final notifications = widget.notificationsController;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name.isEmpty ? ' ' : AppLocalizations.of(context).hiName(name),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.branchController != null)
                BranchSwitcher(controller: widget.branchController!),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('open-search'),
          onPressed: _openSearch,
          icon: const Icon(Icons.search_rounded),
          tooltip: AppLocalizations.of(context).search,
        ),
        // The web puts the dark/light switch next to the bell on phones.
        IconButton(
          key: const ValueKey('toggle-theme'),
          onPressed: widget.themeController.toggleThemeMode,
          icon: Icon(
            widget.themeController.isDark
                ? Icons.light_mode_rounded
                : Icons.dark_mode_rounded,
          ),
        ),
        if (notifications != null && widget.pushService != null)
          NotificationBell(
            key: _tourBell,
            controller: notifications,
            onTap: _openNotificationsTab,
          ),
      ],
    );
  }

  /// The page for the selected tab, without any scroll wrapper — see
  /// [_buildTabViewport], which decides whether the page scrolls itself.
  Widget _buildTabPage(BuildContext context) {
    // Hoisted so the notifications branch promotes them instead of asserting
    // non-null on a pair that a test harness legitimately leaves out.
    final notifications = widget.notificationsController;
    final push = widget.pushService;

    return _selectedIndex == _homeTab
        ? _buildHomeDashboard()
        : _selectedIndex == _gradesTab
        ? _buildGradebooks()
        : _selectedIndex == _behaviorTab
        ? _buildBehavior(context)
        : _selectedIndex == _toolsTab
        ? _buildTools()
        : _selectedIndex == _planTab ||
              _selectedIndex == _pointsTab ||
              _selectedIndex == _fundingsTab
        ? _buildMine()
        : _selectedIndex == _lessonsTab
        ? (widget.controller.lessons == null || widget.controller.outbox == null
              ? const SizedBox.shrink()
              : LessonsPage(
                  key: ValueKey('lessons-$_branchId'),
                  repository: widget.controller.lessons!,
                  outbox: widget.controller.outbox!,
                  loadAcademicYears: widget.controller.loadAcademicYears,
                  bottomInset: _bottomMenuOverlaySpace,
                  initialDate: _lessonsDate,
                ))
        : _selectedIndex == _timetableTab
        ? TimetablePage(
            loadTimetable: widget.controller.loadFullTimetable,
            loadProfile: widget.controller.loadCurrentUserProfile,
            loadAcademicYears: widget.controller.loadAcademicYears,
          )
        : _selectedIndex == _colleaguesTab
        ? ColleaguesPage(
            // Each branch has its own staff list.
            key: ValueKey('colleagues-$_branchId'),
            loadColleagues: widget.controller.loadColleagues,
            bottomInset: _bottomMenuOverlaySpace,
          )
        : _selectedIndex == _profileTab
        ? ProfilePage(
            themeController: widget.themeController,
            languageController: widget.languageController,
            loadProfile: widget.controller.loadCurrentUserProfile,
            updatePassword: widget.controller.updatePassword,
            uploadProfilePicture: widget.controller.uploadProfilePicture,
            removeProfilePicture: widget.controller.removeProfilePicture,
            loadContact: widget.controller.loadContact,
            saveContact: widget.controller.saveContact,
            sendSuggestion: widget.controller.sendSuggestion,
            onStartTour: _startTour,
            branchController: widget.branchController,
            // Never sign out straight from the tap — confirm first.
            onLogout: _showSignOutDialog,
          )
        : _selectedIndex == _examsTab
        ? ExamsPage(
            api: ExamsApi(
              loadProfile: widget.controller.loadCurrentUserProfile,
              loadAcademicYears: widget.controller.loadAcademicYears,
              loadExamPeriods: widget.controller.loadExamPeriods,
              loadExams: widget.controller.loadExams,
              createExam: widget.controller.createExam,
              deleteExam: widget.controller.deleteExam,
              loadSubjects: widget.controller.loadSubjects,
              loadGroups: widget.controller.loadGroups,
              loadColleagues: widget.controller.loadColleagues,
              loadTimetable: widget.controller.loadFullTimetable,
              loadStudentsForGroup: widget.controller.loadStudentsForGroup,
              loadExamResults: widget.controller.loadExamResults,
              createExamResultsBulk: widget.controller.createExamResultsBulk,
              updateExamResult: widget.controller.updateExamResult,
              deleteExamResult: widget.controller.deleteExamResult,
              loadDivision: widget.controller.api == null
                  ? null
                  : (id) async => ApiClient.one(
                      await widget.controller.api!.get('/group-divisions/$id'),
                    ),
            ),
          )
        : _selectedIndex == _rewardsTab
        ? RewardsPage(
            loadGroups: widget.controller.loadGroups,
            loadStudents: widget.controller.loadAllStudents,
            loadPointTotals: widget.controller.loadPointTotalsByStudent,
            savePoints: widget.controller.savePointsBulk,
          )
        : (_selectedIndex == _notificationsTab &&
              notifications != null &&
              push != null)
        ? NotificationsPage(
            controller: notifications,
            pushService: push,
            bottomInset: _bottomMenuOverlaySpace,
          )
        : _selectedIndex == _myClassTab
        ? MyClassPage(
            loadProfile: widget.controller.loadCurrentUserProfile,
            loadGroups: widget.controller.loadGroups,
            loadAcademicYears: widget.controller.loadAcademicYears,
            loadStudentsForGroup: widget.controller.loadStudentsForGroup,
            updatePersonDetails: widget.controller.updatePersonDetails,
            uploadPersonPicture: widget.controller.uploadPersonPicture,
            removePersonPicture: widget.controller.removePersonPicture,
            guardians: _guardiansApi,
            peopleSync: _peopleSync,
            documents: _documentsApi,
            insights: widget.controller.classInsights,
            shareDombit: widget.controller.api == null
                ? null
                : (groupId) => shareDombitPdf(widget.controller.api!, groupId),
          )
        : PointReportPage(
            loadAcademicYears: widget.controller.loadAcademicYears,
            loadGroups: widget.controller.loadGroups,
            loadStudentsForGroup: widget.controller.loadStudentsForGroup,
            loadPoints: widget.controller.loadPointsForReport,
            loadTimetable: widget.controller.loadFullTimetable,
          );
  }

  /// Wraps [_buildTabPage] for display.
  ///
  /// Most tabs are plain columns and get the shared scroll view. A list page
  /// owns its scrolling instead, so it can build rows lazily and control its
  /// own offset — nesting one inside this scroll view would give it unbounded
  /// height. It is handed the nav bar's overlay height to pad its own list.
  Widget _buildTabViewport(BoxConstraints constraints) {
    final page = _buildTabPage(context);
    final scrollsItself =
        _selectedIndex == _colleaguesTab ||
        _selectedIndex == _lessonsTab ||
        _selectedIndex == _gradesTab ||
        _selectedIndex == _behaviorTab ||
        _selectedIndex == _toolsTab ||
        _selectedIndex == _planTab ||
        _selectedIndex == _pointsTab ||
        _selectedIndex == _fundingsTab ||
        _selectedIndex == _rewardsTab ||
        _selectedIndex == _notificationsTab;

    return SizedBox(
      height: constraints.maxHeight,
      width: double.infinity,
      child: scrollsItself
          ? page
          : SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.only(bottom: _bottomMenuOverlaySpace),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        (constraints.maxHeight - _bottomMenuOverlaySpace) > 0
                        ? constraints.maxHeight - _bottomMenuOverlaySpace
                        : 0,
                  ),
                  child: page,
                ),
              ),
            ),
    );
  }

  StudentGuardiansApi get _guardiansApi => StudentGuardiansApi(
    load: widget.controller.loadGuardians,
    create: widget.controller.createGuardian,
    update: widget.controller.updateGuardian,
    delete: widget.controller.deleteGuardian,
  );

  StudentPeopleSync get _peopleSync => StudentPeopleSync(
    loadContacts: widget.controller.loadContactsForStudent,
    createContact: widget.controller.createContact,
    updateContact: widget.controller.updateContact,
    loadGuardians: widget.controller.loadGuardians,
    createGuardian: widget.controller.createGuardian,
    updateGuardian: widget.controller.updateGuardian,
  );

  StudentDocumentsApi get _documentsApi => StudentDocumentsApi(
    load: widget.controller.loadDocuments,
    create: widget.controller.createDocument,
    delete: widget.controller.deleteDocument,
  );

  /// The web's ⌘K search, as a full screen.
  void _openSearch() {
    final canSearchPeople =
        _profile?.hasAnyPermission(const [
          'persons.read',
          'persons.create',
          'persons.update',
          'persons.delete',
          'students.read',
          'students.create',
          'students.update',
          'students.delete',
        ]) ??
        false;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => SearchPage(
          access: _access,
          repository: widget.controller.search,
          canSearchPeople: canSearchPeople,
          hasNotifications:
              widget.notificationsController != null &&
              widget.pushService != null,
          onOpenItem: _openItem,
          onOpenPlace: (place) => switch (place) {
            SearchPlace.home => _openTab(_homeTab),
            SearchPlace.profile => _openTab(_profileTab),
            SearchPlace.notifications => _openNotificationsTab(),
          },
          profileBuilder: (context, student, classPair, onBack) =>
              StudentInfoView(
                key: ValueKey('search-${student.personId}'),
                student: student,
                classPair: classPair,
                isDarkMode: Theme.of(context).brightness == Brightness.dark,
                onBack: onBack,
                updatePersonDetails: widget.controller.updatePersonDetails,
                uploadPersonPicture:
                    ({required ownerId, required bytes, required filename}) =>
                        widget.controller.uploadPersonPicture(
                          personId: ownerId,
                          bytes: bytes,
                          filename: filename,
                        ),
                removePersonPicture: ({required ownerId}) =>
                    widget.controller.removePersonPicture(personId: ownerId),
                onSaved: (_, _) {},
                onPictureChanged: (_, _) {},
                guardians: _guardiansApi,
                documents: _documentsApi,
                peopleSync: _peopleSync,
              ),
        ),
      ),
    );
  }

  int _tabOf(AppItem item) => switch (item) {
    AppItem.lessons => _lessonsTab,
    AppItem.myClass => _myClassTab,
    AppItem.exams => _examsTab,
    AppItem.timetable => _timetableTab,
    AppItem.rewards => _rewardsTab,
    AppItem.colleagues => _colleaguesTab,
    AppItem.pointReport => _pointReportTab,
    AppItem.grades => _gradesTab,
    AppItem.behavior => _behaviorTab,
    AppItem.teachingTools => _toolsTab,
    AppItem.myPlan => _planTab,
    AppItem.myPoints => _pointsTab,
    AppItem.myFundings => _fundingsTab,
    // Pushed over the shell by [_openItem]; never a tab.
    AppItem.calendar ||
    AppItem.myLessonAnalysis ||
    AppItem.lessonAnalysis ||
    AppItem.myDepartment ||
    AppItem.substitutions ||
    AppItem.attendanceCheck ||
    AppItem.cashier ||
    AppItem.staffPoints ||
    AppItem.fundings ||
    AppItem.resetGrades => _homeTab,
  };

  /// Shared by the pages that came over from the web without a tab.
  Widget? _updatesCard() {
    final api = widget.controller.api;
    final userId = _profile?.id;
    if (api == null || userId == null) return null;
    // The tour points at it; a new key per branch reloads it.
    return KeyedSubtree(
      key: _updatesKey,
      child: UpdatesCard(
        key: ValueKey('updates-$userId'),
        api: api,
        userId: userId,
        onOpen: _openItem,
        canOpen: _access.allows,
      ),
    );
  }

  StaffContext? get _staffContext {
    final api = widget.controller.api;
    if (api == null) return null;
    return StaffContext(
      api: api,
      profile: _profile,
      loadAcademicYears: widget.controller.loadAcademicYears,
    );
  }

  /// Opens [item]: a tab of the shell, or a page with a back arrow.
  void _openItem(AppItem item) {
    if (!pushedItems.contains(item)) {
      _openTab(_tabOf(item));
      return;
    }
    final ctx = _staffContext;
    if (ctx == null) return;
    final me = widget.controller.me;
    final page = switch (item) {
      AppItem.calendar => CalendarPage(ctx: ctx),
      AppItem.myLessonAnalysis => MyLessonAnalysisPage(ctx: ctx),
      AppItem.lessonAnalysis => LessonAnalysisPage(ctx: ctx),
      AppItem.myDepartment => MyDepartmentPage(ctx: ctx),
      AppItem.substitutions => SubstitutionsPage(ctx: ctx),
      AppItem.attendanceCheck => AttendanceCheckPage(ctx: ctx),
      AppItem.cashier => CashierPage(ctx: ctx),
      AppItem.staffPoints => StaffPointsPage(ctx: ctx, me: me),
      AppItem.fundings => FundingsPage(ctx: ctx, me: me),
      AppItem.resetGrades => ResetGradesPage(ctx: ctx),
      _ => null,
    };
    if (page != null) SubPage.push(context, page);
  }

  void _openTab(int tab) => setState(() {
    _lessonsDate = null;
    _gradebookRow = null;
    _select(tab);
  });

  Future<List<GradebookPair>> _loadGradebookPairs() async {
    int? year;
    try {
      final years = await widget.controller.loadAcademicYears();
      year =
          (years.where((e) => e.isActive).firstOrNull ?? years.firstOrNull)?.id;
    } catch (_) {
      // The server falls back to the current year.
    }
    return widget.controller.lessons!.getMyGradebooks(academicYearId: year);
  }

  Widget _buildGradebooks() {
    final lessons = widget.controller.lessons;
    if (lessons == null) return const SizedBox.shrink();
    return GradebooksPage(
      key: ValueKey('gradebooks-$_branchId'),
      loadPairs: _loadGradebookPairs,
      loadGradebook: lessons.getGradebook,
      initialGroupId: _gradebookRow?.groupId,
      initialSubjectId: _gradebookRow?.subjectId,
      bottomInset: _bottomMenuOverlaySpace,
    );
  }

  Widget _buildBehavior(BuildContext context) {
    final lessons = widget.controller.lessons;
    final outbox = widget.controller.outbox;
    if (lessons == null || outbox == null) return const SizedBox.shrink();
    return BehaviorPage(
      key: ValueKey('behavior-$_branchId'),
      repository: lessons,
      outbox: outbox,
      // Keeps the action bar above the docked phone bar.
      bottomInset: 60 + MediaQuery.paddingOf(context).bottom,
      deleteMark: _staffContext?.can('behavior.delete') == true
          ? (id) async {
              final body = await widget.controller.api!.delete(
                '/behavior/marks/${Uri.encodeComponent(id)}',
              );
              return body is Map ? asInt(body['deletedPoints']) ?? 0 : 0;
            }
          : null,
    );
  }

  Widget _buildTools() {
    final lessons = widget.controller.lessons;
    if (lessons == null) return const SizedBox.shrink();
    final outbox = widget.controller.outbox;
    return TeachingToolsPage(
      key: ValueKey('tools-$_branchId'),
      repository: lessons,
      bottomInset: _bottomMenuOverlaySpace,
      gradeWithTeams: outbox == null
          ? null
          : (lesson, teams) => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GradingSheetPage(
                  repository: lessons,
                  outbox: outbox,
                  lessonId: lesson.instanceId!,
                  fallbackTitle: lesson.fullClassLabel ?? lesson.classLabel,
                  fallbackSubject: lesson.subject,
                  teams: teams,
                ),
              ),
            ),
    );
  }

  Future<AcademicYearEntry?> _activeYear() async {
    final years = await widget.controller.loadAcademicYears();
    return years.where((e) => e.isActive).firstOrNull ?? years.firstOrNull;
  }

  Future<Map<int, String>> _staffNames() async => {
    for (final person in await widget.controller.loadColleagues())
      person.id: person.displayName,
  };

  /// Each of these asks for the person's own id, so they wait for the profile.
  Widget _buildMine() {
    // My Plan is built but not wanted yet; MyPlanPage comes back here later.
    if (_selectedIndex == _planTab) {
      return ComingSoonPage(
        title: AppLocalizations.of(context).myPlan,
        icon: Icons.edit_note_rounded,
      );
    }
    final me = widget.controller.me;
    final userId = _profile?.id;
    if (me == null) return const SizedBox.shrink();
    if (userId == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final key = '$_selectedIndex-$_branchId';
    final api = widget.controller.api;
    return _selectedIndex == _planTab
        ? (api != null && _staffContext?.can('lesson_plans.read') == true
              ? MyPlansTabs(
                  key: ValueKey(key),
                  api: LessonPlansApi.http(
                    api,
                    () async => (await _activeYear())?.id,
                  ),
                  userId: userId,
                  bottomInset: _bottomMenuOverlaySpace,
                  goals: MyPlanPage(
                    repository: me,
                    userId: userId,
                    loadYear: _activeYear,
                    bottomInset: _bottomMenuOverlaySpace,
                  ),
                )
              : MyPlanPage(
                  key: ValueKey(key),
                  repository: me,
                  userId: userId,
                  loadYear: _activeYear,
                  bottomInset: _bottomMenuOverlaySpace,
                ))
        : _selectedIndex == _pointsTab
        ? MyPointsPage(
            key: ValueKey(key),
            repository: me,
            userId: userId,
            loadNames: _staffNames,
            bottomInset: _bottomMenuOverlaySpace,
          )
        : MyFundingsPage(
            key: ValueKey(key),
            repository: me,
            userId: userId,
            bottomInset: _bottomMenuOverlaySpace,
          );
  }

  Widget _buildHomeDashboard() {
    return TeacherHome(
      header: _buildHeader(),
      access: _access,
      today: _today,
      homeroom: _homeroom,
      recentGrades: _recentGrades,
      updates: _updatesCard(),
      onOpen: _openItem,
      userId: _profile?.id,
      scheduleKey: _tourSchedule,
      tilesKey: _tourTiles,
      onOpenGradebook: (row) => setState(() {
        _gradebookRow = row;
        _select(_gradesTab);
      }),
      onOpenDay: (day) => setState(() {
        _lessonsDate = day;
        _select(_lessonsTab);
      }),
    );
  }

  Widget _buildBottomMenu(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bar = _access.phoneBar;
    final tabs = [_homeTab, for (final item in bar) _tabOf(item), _profileTab];
    final unread = widget.notificationsController?.unreadCount ?? 0;
    return BottomMenu(
      items: [
        BottomMenuItem(
          label: l.home,
          icon: Icons.home_rounded,
          showDot: unread > 0 && _selectedIndex != _homeTab,
        ),
        for (final item in bar)
          BottomMenuItem(
            // While a lesson is on, the Schedule tab shows the time left.
            label: item == AppItem.lessons && _countdown != null
                ? _countdown!
                : appLabel(l, item, short: true),
            labelColor: item == AppItem.lessons && _countdown != null
                ? const Color(0xFFDC2626)
                : null,
            icon: appIcon(item),
            color: appHue(context, item).strong,
          ),
        BottomMenuItem(
          label: l.profile,
          icon: Icons.person_rounded,
          targetKey: _tourProfile,
        ),
      ],
      selectedIndex: tabs.indexOf(_selectedIndex),
      onSelected: (index) => _openTab(tabs[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColors = appColorsOf(context);
    final notifications = widget.notificationsController;

    return PopScope(
      canPop: _canLeave,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        extendBody: true,
        body: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            // A faint wash of the accent over the scaffold colour, so the chosen
            // colour reads on the page itself and not only on the controls.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Color.alphaBlend(
                  accentColors.accent.solid.withValues(
                    alpha: isDarkMode ? 0.10 : 0.07,
                  ),
                  Theme.of(context).scaffoldBackgroundColor,
                ),
              ],
            ),
          ),
          child: Stack(
            children: [
              SafeArea(
                bottom: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 820),
                        child: AnimatedSwitcher(
                          duration: _returningViaSwipe
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          // The page being left has to go at once, not fade.
                          // Tabs paint no background of their own — the gradient
                          // behind them belongs to the shell — so an outgoing
                          // page is *visible through* the incoming one for as
                          // long as it lingers, which read as the old page
                          // flashing back before the dashboard settled. It has to
                          // be a constant: `AnimatedSwitcher` hands each entry
                          // its durations when the entry is created and never
                          // revisits them, so the conditional `duration` above
                          // only ever shortens the fade *in* — the outgoing page
                          // still left on whatever duration was in force when it
                          // arrived.
                          reverseDuration: Duration.zero,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          child: SwipeBackDetector(
                            key: ValueKey(_selectedIndex),
                            enabled: _selectedIndex != _homeTab,
                            onSwipeBack: () {
                              setState(() {
                                _returningViaSwipe = true;
                                _select(_homeTab);
                              });
                              // Reset the flag after the frame so future
                              // tab switches animate normally.
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (mounted) {
                                  _returningViaSwipe = false;
                                }
                              });
                            },
                            underneathChild: _selectedIndex == _homeTab
                                ? null
                                : SizedBox(
                                    height: constraints.maxHeight,
                                    width: double.infinity,
                                    child: SingleChildScrollView(
                                      physics: const ClampingScrollPhysics(),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: _bottomMenuOverlaySpace,
                                        ),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minHeight:
                                                (constraints.maxHeight -
                                                        _bottomMenuOverlaySpace) >
                                                    0
                                                ? constraints.maxHeight -
                                                      _bottomMenuOverlaySpace
                                                : 0,
                                          ),
                                          child: _buildHomeDashboard(),
                                        ),
                                      ),
                                    ),
                                  ),
                            child: TabBackScope(
                              handlers: _backHandlers,
                              child: _buildTabViewport(constraints),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (widget.controller.outbox != null)
                Positioned(
                  right: 14,
                  bottom: 104,
                  child: UploadsPill(outbox: widget.controller.outbox!),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: KeyedSubtree(
                  key: _tourNav,
                  child: notifications == null
                      ? _buildBottomMenu(context)
                      : ListenableBuilder(
                          listenable: notifications,
                          builder: (context, _) => _buildBottomMenu(context),
                        ),
                ),
              ),
              if (_touring)
                Positioned.fill(
                  child: ProductTour(
                    steps: _tourSteps(AppLocalizations.of(context)),
                    onDone: _endTour,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
