import 'package:flutter/material.dart';

import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/theme_controller.dart';
import 'package:one_org_staff/features/MyClass/my_class.dart';
import 'package:one_org_staff/features/MyClass/student_info_view.dart';
import 'package:one_org_staff/features/MyClass/student_people_sync.dart';
import 'package:one_org_staff/features/MyLessons/my_lessons.dart';
import 'package:one_org_staff/features/Profile/profilepage.dart';
import 'package:one_org_staff/features/TimeTable/TimeTable.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/colleagues/presentation/colleagues_page.dart';
import 'package:one_org_staff/features/point_report/presentation/point_report_page.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.controller,
    required this.themeController,
  });

  final AuthController controller;
  final ThemeController themeController;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

// Home Tab Content 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁 🏁
class _LandingPageState extends State<LandingPage> {
  static const _bottomMenuOverlaySpace = 156.0;

  static const _items = [
    _LandingTabItem(
      label: 'Home',
      icon: Icons.home_rounded,
      title: 'Home',
      subtitle: 'Your personal staff dashboard.',
    ),
    _LandingTabItem(
      label: 'Lessons',
      icon: Icons.menu_book_rounded,
      title: 'Lessons',
      subtitle: 'Your lessons section will appear here.',
    ),
    _LandingTabItem(
      label: 'Colleagues',
      icon: Icons.groups_rounded,
      title: 'Colleagues',
      subtitle: 'The staff directory with phone numbers.',
    ),
    _LandingTabItem(
      label: 'Profile',
      icon: Icons.person_rounded,
      title: 'Profile',
      subtitle: 'Your staff profile and settings will appear here.',
    ),
  ];

  // Tab indices. The first [_items].length are the navbar buttons, in order;
  // the rest deliberately sit past the end — Timetable, My Class and the point
  // report have no navbar button and are opened from the dashboard, which is
  // also why the navbar highlights nothing while one of them is showing.
  static const _homeTab = 0;
  static const _lessonsTab = 1;
  static const _colleaguesTab = 2;
  static const _profileTab = 3;
  static const _timetableTab = 4;
  static const _myClassTab = 5;
  static const _pointReportTab = 6;

  int _selectedIndex = 0;
  bool _returningViaSwipe = false;
  Future<AppUserProfile>? _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.controller.loadCurrentUserProfile();
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Are you sure you want to sign out of the staff application?',
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

  /// Opens the header avatar full size. With no photo set there is nothing to
  /// enlarge, so the tap does nothing rather than showing a blown-up initial.
  void _showAvatarPreview(String name, String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.all(24),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            // Tapping the photo closes it too — the whole surface is the
            // dismiss target, which is what people expect of a lightbox.
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.contain,
                    semanticLabel: '$name profile photo',
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) {
                        return child;
                      }
                      return const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                          height: 240,
                          child: Center(
                            child: Text(
                              'Could not load the photo',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              tooltip: 'Close',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDarkMode) {
    return FutureBuilder<AppUserProfile>(
      future: _profileFuture ??= widget.controller.loadCurrentUserProfile(),
      builder: (context, snapshot) {
        final colors = appColorsOf(context);
        final profile = snapshot.data;
        final String name = profile?.fullName ?? 'Staff Member';
        final String? avatarUrl = profile?.profileImageUrl;

        return Row(
          children: [
            GestureDetector(
              onTap: () => _showAvatarPreview(name, avatarUrl),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: colors.ring.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colors.ring.withValues(alpha: 0.15),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.softBg,
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: colors.softText,
                          ),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color: colors.softBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colors.line, width: 1),
              ),
              child: IconButton(
                onPressed: widget.themeController.toggleThemeMode,
                icon: Icon(
                  isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: isDarkMode ? const Color(0xFFFFD043) : colors.softText,
                  size: 22,
                ),
                tooltip: isDarkMode
                    ? 'Switch to Light Mode'
                    : 'Switch to Dark Mode',
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeDashboard(BuildContext context, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isDarkMode),
          const SizedBox(height: 32),
          Text(
            'Quick Access',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: appColorsOf(context).mutedText,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),

          // One full-width row per destination. Profile and Sign Out are not
          // here: the avatar in the header opens the profile, and signing out
          // lives on the profile page behind its confirmation dialog.
          _DashboardListTile(
            title: 'My Class',
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF4ADE80),
            iconBgColor: isDarkMode
                ? const Color(0xFF1B3D2B)
                : const Color(0xFFE6FDF0),
            isDarkMode: isDarkMode,
            onTap: () {
              setState(() {
                _selectedIndex = _myClassTab;
              });
            },
          ),
          const SizedBox(height: 12),
          _DashboardListTile(
            title: 'Lessons',
            icon: Icons.menu_book_rounded,
            iconColor: const Color(0xFF64AFFF),
            iconBgColor: isDarkMode
                ? const Color(0xFF1E2D3D)
                : const Color(0xFFE6F0FA),
            isDarkMode: isDarkMode,
            onTap: () {
              setState(() {
                _selectedIndex = _lessonsTab;
              });
            },
          ),
          const SizedBox(height: 12),
          _DashboardListTile(
            title: 'Point report',
            icon: Icons.emoji_events_rounded,
            iconColor: const Color(0xFF38BDF8),
            iconBgColor: isDarkMode
                ? const Color(0xFF12303F)
                : const Color(0xFFE0F2FE),
            isDarkMode: isDarkMode,
            onTap: () {
              setState(() {
                _selectedIndex = _pointReportTab;
              });
            },
          ),
          const SizedBox(height: 12),
          _DashboardListTile(
            title: 'Colleagues',
            icon: Icons.groups_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBgColor: isDarkMode
                ? const Color(0xFF3D2F14)
                : const Color(0xFFFEF3C7),
            isDarkMode: isDarkMode,
            onTap: () {
              setState(() {
                _selectedIndex = _colleaguesTab;
              });
            },
          ),
          const SizedBox(height: 12),
          _DashboardListTile(
            title: 'Timetable',
            icon: Icons.calendar_month_rounded,
            iconColor: const Color(0xFFC084FC),
            iconBgColor: isDarkMode
                ? const Color(0xFF2C1E3D)
                : const Color(0xFFF3E8FF),
            isDarkMode: isDarkMode,
            onTap: () {
              setState(() {
                _selectedIndex = _timetableTab;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final accentColors = appColorsOf(context);
    final selectedItemLabel =
        _selectedIndex >= 0 && _selectedIndex < _items.length
        ? _items[_selectedIndex].label
        : 'My Class';

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
                        switchInCurve: Curves.easeOut,
                        switchOutCurve: Curves.easeIn,
                        child: SwipeBackDetector(
                          key: ValueKey(selectedItemLabel),
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
                                        child: _buildHomeDashboard(
                                          context,
                                          isDarkMode,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                          child: SizedBox(
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
                                  child: _selectedIndex == _homeTab
                                      ? _buildHomeDashboard(context, isDarkMode)
                                      : _selectedIndex == _lessonsTab
                                      ? MyLessonsPage(
                                          loadLessons: widget
                                              .controller
                                              .loadMyLessonsForDate,
                                          loadStudentsForGroup: widget
                                              .controller
                                              .loadStudentsForGroup,
                                          savePointsBulk:
                                              widget.controller.savePointsBulk,
                                          loadPointsForGroupAndDate: widget
                                              .controller
                                              .loadPointsForGroupAndDate,
                                        )
                                      : _selectedIndex == _timetableTab
                                      ? TimeTablePage(
                                          loadTimetable: widget
                                              .controller
                                              .loadFullTimetable,
                                        )
                                      : _selectedIndex == _colleaguesTab
                                      ? ColleaguesPage(
                                          loadColleagues:
                                              widget.controller.loadColleagues,
                                        )
                                      : _selectedIndex == _profileTab
                                      ? ProfilePage(
                                          themeController:
                                              widget.themeController,
                                          loadProfile: widget
                                              .controller
                                              .loadCurrentUserProfile,
                                          updatePassword:
                                              widget.controller.updatePassword,
                                          uploadProfilePicture: widget
                                              .controller
                                              .uploadProfilePicture,
                                          removeProfilePicture: widget
                                              .controller
                                              .removeProfilePicture,
                                          // Never sign out
                                          // straight from the tap
                                          // — confirm first.
                                          onLogout: _showSignOutDialog,
                                        )
                                      : _selectedIndex == _myClassTab
                                      ? MyClassPage(
                                          loadProfile: widget
                                              .controller
                                              .loadCurrentUserProfile,
                                          loadGroups:
                                              widget.controller.loadGroups,
                                          loadAcademicYears: widget
                                              .controller
                                              .loadAcademicYears,
                                          loadStudentsForGroup: widget
                                              .controller
                                              .loadStudentsForGroup,
                                          updatePersonDetails: widget
                                              .controller
                                              .updatePersonDetails,
                                          uploadPersonPicture: widget
                                              .controller
                                              .uploadPersonPicture,
                                          removePersonPicture: widget
                                              .controller
                                              .removePersonPicture,
                                          guardians: StudentGuardiansApi(
                                            load:
                                                widget.controller.loadGuardians,
                                            create: widget
                                                .controller
                                                .createGuardian,
                                            update: widget
                                                .controller
                                                .updateGuardian,
                                            delete: widget
                                                .controller
                                                .deleteGuardian,
                                          ),
                                          peopleSync: StudentPeopleSync(
                                            loadContacts: widget
                                                .controller
                                                .loadContactsForStudent,
                                            createContact:
                                                widget.controller.createContact,
                                            updateContact:
                                                widget.controller.updateContact,
                                            loadGuardians:
                                                widget.controller.loadGuardians,
                                            createGuardian: widget
                                                .controller
                                                .createGuardian,
                                            updateGuardian: widget
                                                .controller
                                                .updateGuardian,
                                          ),
                                          documents: StudentDocumentsApi(
                                            load:
                                                widget.controller.loadDocuments,
                                            create: widget
                                                .controller
                                                .createDocument,
                                            delete: widget
                                                .controller
                                                .deleteDocument,
                                          ),
                                        )
                                      : PointReportPage(
                                          loadAcademicYears: widget
                                              .controller
                                              .loadAcademicYears,
                                          loadGroups:
                                              widget.controller.loadGroups,
                                          loadStudentsForGroup: widget
                                              .controller
                                              .loadStudentsForGroup,
                                          loadPoints: widget
                                              .controller
                                              .loadPointsForReport,
                                          loadTimetable: widget
                                              .controller
                                              .loadFullTimetable,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomMenu(
                items: [
                  for (final item in _items)
                    BottomMenuItem(label: item.label, icon: item.icon),
                ],
                selectedIndex: _selectedIndex,
                onSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingTabItem {
  const _LandingTabItem({
    required this.label,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final String title;
  final String subtitle;
}

class _DashboardListTile extends StatefulWidget {
  const _DashboardListTile({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.isDarkMode,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  State<_DashboardListTile> createState() => _DashboardListTileState();
}

class _DashboardListTileState extends State<_DashboardListTile> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final colors = appColorsOf(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isPressed = true),
      onExit: (_) => setState(() => _isPressed = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          transform: Matrix4.diagonal3Values(
            _isPressed ? 0.99 : 1.0,
            _isPressed ? 0.99 : 1.0,
            1.0,
          ),
          transformAlignment: Alignment.center,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.card.withValues(alpha: isDark ? 0.92 : 0.9),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _isPressed
                        ? colors.ring.withValues(alpha: 0.55)
                        : colors.line,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? const Color(0x33000000)
                          : const Color(0x14000000),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: widget.iconBgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 24,
                      color: colors.mutedText,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
