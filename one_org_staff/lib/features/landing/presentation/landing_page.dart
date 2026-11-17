import 'dart:async';

import 'package:flutter/material.dart';

import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/app/swipe_back_detector.dart';
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
import 'package:one_org_staff/features/lessons/domain/lessons_repository.dart';
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
import 'package:one_org_staff/features/rewards/presentation/rewards_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.controller,
    required this.themeController,
    this.languageController,
    this.notificationsController,
    this.pushService,
    this.branchController,
  });

  final AuthController controller;
  final ThemeController themeController;
  final LanguageController? languageController;

  /// Both null in a test harness that injects its own [AuthController]; the
  /// header then renders without a bell and the inbox tab is unreachable.
  final NotificationsController? notificationsController;
  final PushService? pushService;
  final BranchController? branchController;

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
  bool _returningViaSwipe = false;
  DateTime? _lessonsDate;
  RecentGrade? _gradebookRow;
  int? _branchId;
  NextLessonDayLoader? _today;
  String? _homeroom;
  List<RecentGrade>? _recentGrades;

  /// Null until `/users/me` answers, and if it can't.
  AppUserProfile? _profile;

  AppAccess get _access => AppAccess(_profile);

  @override
  void initState() {
    super.initState();
    final lessons = widget.controller.lessons;
    if (lessons != null) {
      _today = NextLessonDayLoader(getDay: lessons.getDay)..refreshIfStale();
    }
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
    setState(() {
      _selectedIndex = _notificationsTab;
    });
  }

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

  Future<void> _loadProfile() async {
    try {
      final profile = await widget.controller.loadCurrentUserProfile();
      if (!mounted) return;
      setState(() => _profile = profile);
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
      _homeroom = null;
      _recentGrades = null;
    });
    unawaited(_loadBranchData());
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
        if (notifications != null && widget.pushService != null)
          NotificationBell(
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
            onMark: _access.allows(AppItem.behavior)
                ? () => _openTab(_tabOf(AppItem.behavior))
                : null,
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
          onOpenItem: (item) => _openTab(_tabOf(item)),
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
  };

  void _openTab(int tab) => setState(() {
    _lessonsDate = null;
    _gradebookRow = null;
    _selectedIndex = tab;
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
    );
  }

  Widget _buildTools() {
    final lessons = widget.controller.lessons;
    if (lessons == null) return const SizedBox.shrink();
    return TeachingToolsPage(
      key: ValueKey('tools-$_branchId'),
      repository: lessons,
      bottomInset: _bottomMenuOverlaySpace,
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
    return _selectedIndex == _planTab
        ? MyPlanPage(
            key: ValueKey(key),
            repository: me,
            userId: userId,
            loadYear: _activeYear,
            bottomInset: _bottomMenuOverlaySpace,
          )
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
      onOpen: (item) => _openTab(_tabOf(item)),
      onOpenGradebook: (row) => setState(() {
        _gradebookRow = row;
        _selectedIndex = _gradesTab;
      }),
      onOpenDay: (day) => setState(() {
        _lessonsDate = day;
        _selectedIndex = _lessonsTab;
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
            label: appLabel(l, item, short: true),
            icon: appIcon(item),
            color: appHue(context, item).strong,
          ),
        BottomMenuItem(label: l.profile, icon: Icons.person_rounded),
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

    return Scaffold(
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
                              _selectedIndex = _homeTab;
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
                          child: _buildTabViewport(constraints),
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
              child: notifications == null
                  ? _buildBottomMenu(context)
                  : ListenableBuilder(
                      listenable: notifications,
                      builder: (context, _) => _buildBottomMenu(context),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
