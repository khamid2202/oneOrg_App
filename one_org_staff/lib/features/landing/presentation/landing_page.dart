import 'package:flutter/material.dart';

import 'package:one_org_staff/features/BottomBar/bottom_menu.dart';
import 'package:one_org_staff/app/swipe_back_detector.dart';
import 'package:one_org_staff/features/MyClass/my_class.dart';
import 'package:one_org_staff/features/MyLessons/my_lessons.dart';
import 'package:one_org_staff/features/Profile/profilepage.dart';
import 'package:one_org_staff/features/TimeTable/TimeTable.dart';
import 'package:one_org_staff/features/auth/application/auth_controller.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({
    super.key,
    required this.controller,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AuthController controller;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
      label: 'Timetable',
      icon: Icons.calendar_month_rounded,
      title: 'Timetable',
      subtitle: 'Your class schedule and timing blocks will appear here.',
    ),
    _LandingTabItem(
      label: 'Profile',
      icon: Icons.person_rounded,
      title: 'Profile',
      subtitle: 'Your staff profile and settings will appear here.',
    ),
  ];

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
        content: const Text('Are you sure you want to sign out of the staff application?'),
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

  Widget _buildHeader(bool isDarkMode) {
    return FutureBuilder<AppUserProfile>(
      future: _profileFuture ??= widget.controller.loadCurrentUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final String name = profile?.fullName ?? 'Staff Member';
        final String? avatarUrl = profile?.profileImageUrl;

        return Row(
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF64AFFF).withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF64AFFF).withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: isDarkMode ? const Color(0xFF1F2E40) : const Color(0xFFE1EDFA),
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                    ? NetworkImage(avatarUrl)
                    : null,
                child: avatarUrl == null || avatarUrl.isEmpty
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'S',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? const Color(0xFF64AFFF) : const Color(0xFF1E5C99),
                        ),
                      )
                    : null,
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
                          color: isDarkMode
                              ? const Color(0xFFF5F7FB)
                              : const Color(0xFF16324A),
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
                color: isDarkMode
                    ? const Color(0xFF1E2D3D).withValues(alpha: 0.6)
                    : const Color(0xFFE6F0FA).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF273445)
                      : const Color(0xFFD7E1EE),
                  width: 1,
                ),
              ),
              child: IconButton(
                onPressed: () {
                  widget.onThemeModeChanged(
                    isDarkMode ? ThemeMode.light : ThemeMode.dark,
                  );
                },
                icon: Icon(
                  isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDarkMode ? const Color(0xFFFFD043) : const Color(0xFF1F5E89),
                  size: 22,
                ),
                tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
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
                  color: isDarkMode
                      ? const Color(0xFF8A9EB5)
                      : const Color(0xFF4A5F73),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
          ),
          const SizedBox(height: 16),
          _DashboardCard(
            title: 'My Class',
            subtitle: 'View homeroom roster & students',
            icon: Icons.school_rounded,
            iconColor: const Color(0xFF4ADE80),
            iconBgColor: isDarkMode
                ? const Color(0xFF1B3D2B)
                : const Color(0xFFE6FDF0),
            isDarkMode: isDarkMode,
            onTap: () {
              setState(() {
                _selectedIndex = 4;
              });
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Lessons',
                  subtitle: 'Grade & track',
                  icon: Icons.menu_book_rounded,
                  iconColor: const Color(0xFF64AFFF),
                  iconBgColor: isDarkMode
                      ? const Color(0xFF1E2D3D)
                      : const Color(0xFFE6F0FA),
                  isDarkMode: isDarkMode,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DashboardCard(
                  title: 'Timetable',
                  subtitle: 'View schedule',
                  icon: Icons.calendar_month_rounded,
                  iconColor: const Color(0xFFC084FC),
                  iconBgColor: isDarkMode
                      ? const Color(0xFF2C1E3D)
                      : const Color(0xFFF3E8FF),
                  isDarkMode: isDarkMode,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Profile',
                  subtitle: 'Manage account',
                  icon: Icons.person_rounded,
                  iconColor: const Color(0xFF2DD4BF),
                  iconBgColor: isDarkMode
                      ? const Color(0xFF183330)
                      : const Color(0xFFE6FBF7),
                  isDarkMode: isDarkMode,
                  onTap: () {
                    setState(() {
                      _selectedIndex = 3;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _DashboardCard(
                  title: 'Sign Out',
                  subtitle: 'Exit application',
                  icon: Icons.logout_rounded,
                  iconColor: const Color(0xFFFB7185),
                  iconBgColor: isDarkMode
                      ? const Color(0xFF3D1D24)
                      : const Color(0xFFFFEAEB),
                  isDarkMode: isDarkMode,
                  onTap: _showSignOutDialog,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final selectedItemLabel = _selectedIndex >= 0 && _selectedIndex < _items.length
        ? _items[_selectedIndex].label
        : 'My Class';

    return Scaffold(
      extendBody: true,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDarkMode
                ? const [Color(0xFF0D1218), Color(0xFF19232E)]
                : const [Color(0xFFF9FBFF), Color(0xFFE7EFF8)],
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
                          enabled: _selectedIndex != 0,
                          onSwipeBack: () {
                            setState(() {
                              _returningViaSwipe = true;
                              _selectedIndex = 0;
                            });
                            // Reset the flag after the frame so future
                            // tab switches animate normally.
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                _returningViaSwipe = false;
                              }
                            });
                          },
                          underneathChild: _selectedIndex == 0
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
                                          minHeight: (constraints.maxHeight -
                                                      _bottomMenuOverlaySpace) >
                                                  0
                                              ? constraints.maxHeight -
                                                  _bottomMenuOverlaySpace
                                              : 0,
                                        ),
                                        child: _buildHomeDashboard(context, isDarkMode),
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
                                    minHeight: (constraints.maxHeight -
                                                _bottomMenuOverlaySpace) >
                                            0
                                        ? constraints.maxHeight -
                                            _bottomMenuOverlaySpace
                                        : 0,
                                  ),
                                  child: _selectedIndex == 0
                                      ? _buildHomeDashboard(context, isDarkMode)
                                      : _selectedIndex == 1
                                          ? MyLessonsPage(
                                              loadLessons: widget
                                                  .controller
                                                  .loadMyLessonsForDate,
                                              loadStudentsForGroup: widget
                                                  .controller
                                                  .loadStudentsForGroup,
                                              savePointsBulk: widget
                                                  .controller
                                                  .savePointsBulk,
                                              loadPointsForGroupAndDate: widget
                                                  .controller
                                                  .loadPointsForGroupAndDate,
                                            )
                                          : _selectedIndex == 2
                                              ? TimeTablePage(
                                                  loadTimetable: widget
                                                      .controller
                                                      .loadFullTimetable,
                                                )
                                              : _selectedIndex == 3
                                                  ? ProfilePage(
                                                      themeMode: widget.themeMode,
                                                      onThemeModeChanged:
                                                          widget.onThemeModeChanged,
                                                      loadProfile: widget
                                                          .controller
                                                          .loadCurrentUserProfile,
                                                      updatePassword: widget
                                                          .controller
                                                          .updatePassword,
                                                      onLogout:
                                                          widget.controller.signOut,
                                                    )
                                                  : MyClassPage(
                                                      loadProfile: widget.controller.loadCurrentUserProfile,
                                                      loadGroups: widget.controller.loadGroups,
                                                      loadStudentsForGroup: widget.controller.loadStudentsForGroup,
                                                      loadContactsForStudent: widget.controller.loadContactsForStudent,
                                                      createContact: widget.controller.createContact,
                                                      updateContact: widget.controller.updateContact,
                                                      deleteContact: widget.controller.deleteContact,
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

class _DashboardCard extends StatefulWidget {
  const _DashboardCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.isDarkMode,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isHovered = true),
        onTapUp: (_) => setState(() => _isHovered = false),
        onTapCancel: () => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          transform: Matrix4.diagonal3Values(
            _isHovered ? 0.97 : 1.0,
            _isHovered ? 0.97 : 1.0,
            1.0,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(24),
              child: Ink(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: widget.isDarkMode
                      ? const Color(0xFF121A24).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.84),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _isHovered
                        ? widget.iconColor.withValues(alpha: 0.5)
                        : (widget.isDarkMode
                            ? const Color(0xFF273445)
                            : const Color(0xFFD7E1EE)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? widget.iconColor.withValues(alpha: 0.15)
                          : const Color(0x0A000000),
                      blurRadius: _isHovered ? 20 : 10,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: widget.iconBgColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: widget.isDarkMode
                                ? const Color(0xFFF5F7FB)
                                : const Color(0xFF16324A),
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: widget.isDarkMode
                                ? const Color(0xFF8A9EB5)
                                : const Color(0xFF59718A),
                            height: 1.3,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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