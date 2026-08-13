import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

import 'package:one_org_staff/shared/editable_avatar.dart';

enum ProfileTab { profile, password, help, system }

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.loadProfile,
    required this.updatePassword,
    required this.uploadProfilePicture,
    required this.removeProfilePicture,
    this.onLogout,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<AppUserProfile> Function() loadProfile;
  final Future<String> Function({
    required String currentPassword,
    required String newPassword,
  })
  updatePassword;
  final Future<String?> Function({
    required int userId,
    required List<int> bytes,
    required String filename,
  })
  uploadProfilePicture;
  final Future<String?> Function({required int userId}) removeProfilePicture;
  final VoidCallback? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  static const _telegramLink = 'https://t.me/+PLLPyJI2F6JhYWQy';

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late Future<AppUserProfile> _profileFuture;
  ProfileTab _tab = ProfileTab.profile;
  bool _isUpdatingPassword = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.loadProfile();
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loadProfile != widget.loadProfile) {
      _profileFuture = widget.loadProfile();
    }
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _isDarkMode => widget.themeMode == ThemeMode.dark;

  void _reloadProfile() {
    setState(() {
      _profileFuture = widget.loadProfile();
    });
  }

  /// Swaps in the new avatar without a round trip, so the change is visible
  /// straight away.
  void _applyAvatar(AppUserProfile profile, String? url) {
    setState(() {
      _profileFuture = Future.value(profile.copyWithProfileImageUrl(url));
    });
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handlePasswordUpdate() async {
    if (_isUpdatingPassword) {
      return;
    }

    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (currentPassword.isEmpty ||
        newPassword.isEmpty ||
        confirmPassword.isEmpty) {
      _showSnackBar('Fill in all password fields before updating.');
      return;
    }

    if (newPassword.length < 6) {
      _showSnackBar('New password must be at least 6 characters long.');
      return;
    }

    if (newPassword == currentPassword) {
      _showSnackBar('New password must be different from current password.');
      return;
    }

    if (newPassword != confirmPassword) {
      _showSnackBar('New password and confirmation do not match.');
      return;
    }

    setState(() {
      _isUpdatingPassword = true;
    });

    try {
      final message = await widget.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );

      if (!mounted) {
        return;
      }

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      FocusScope.of(context).unfocus();
      _showSnackBar(message);
    } on AuthFailure catch (error) {
      if (!mounted) {
        return;
      }
      _showSnackBar(error.message);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Unable to update the password right now.');
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingPassword = false;
        });
      }
    }
  }

  Future<void> _openTelegram() async {
    final uri = Uri.parse(_telegramLink);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      _showSnackBar('Unable to open Telegram.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: FutureBuilder<AppUserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 280,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasError || !snapshot.hasData) {
            return _ProfileLoadError(
              message: snapshot.error is AuthFailure
                  ? (snapshot.error as AuthFailure).message
                  : 'Unable to load the profile right now.',
              onRetry: _reloadProfile,
            );
          }

          final profile = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ProfileHeaderCard(
                profile: profile,
                isDarkMode: _isDarkMode,
                uploadProfilePicture: widget.uploadProfilePicture,
                removeProfilePicture: widget.removeProfilePicture,
                onAvatarChanged: (url) => _applyAvatar(profile, url),
                onError: _showSnackBar,
              ),
              const SizedBox(height: 16),
              _TabSelector(
                selected: _tab,
                isDarkMode: _isDarkMode,
                onSelected: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 20),
              switch (_tab) {
                ProfileTab.profile => _ProfileDetails(
                  profile: profile,
                  isDarkMode: _isDarkMode,
                ),
                ProfileTab.password => _buildPasswordSection(),
                ProfileTab.help => _HelpSection(onOpenTelegram: _openTelegram),
                ProfileTab.system => _buildSystemSection(),
              },
            ],
          );
        },
      ),
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.vpn_key_rounded,
          title: 'Reset Password',
          color: Color(0xFF1F5E89),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _currentPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Current password',
            labelStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(Icons.lock_outline_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _newPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'New password',
            labelStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(Icons.key_rounded),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Confirm new password',
            labelStyle: TextStyle(color: Colors.grey),
            prefixIcon: Icon(Icons.verified_user_rounded),
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isUpdatingPassword ? null : _handlePasswordUpdate,
            icon: _isUpdatingPassword
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  )
                : const Icon(Icons.password_rounded),
            label: Text(
              _isUpdatingPassword
                  ? 'Updating password...'
                  : 'Update password',
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemSection() {
    final borderColor = _isDarkMode
        ? const Color(0xFF273445)
        : const Color(0xFFD7E1EE);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.settings_rounded,
          title: 'System',
          color: Color(0xFF7C6BC4),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: _isDarkMode
                ? const Color(0xFF1A2430)
                : const Color(0xFFF4F7FB),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: SwitchListTile(
            value: _isDarkMode,
            title: const Text('Dark mode'),
            subtitle: const Text('Switch between light and dark themes.'),
            secondary: Icon(
              _isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
            ),
            onChanged: (value) {
              widget.onThemeModeChanged(
                value ? ThemeMode.dark : ThemeMode.light,
              );
            },
          ),
        ),
        if (widget.onLogout != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Theme.of(context).colorScheme.error,
                side: BorderSide(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({
    required this.profile,
    required this.isDarkMode,
    required this.uploadProfilePicture,
    required this.removeProfilePicture,
    required this.onAvatarChanged,
    required this.onError,
  });

  final AppUserProfile profile;
  final bool isDarkMode;
  final Future<String?> Function({
    required int userId,
    required List<int> bytes,
    required String filename,
  })
  uploadProfilePicture;
  final Future<String?> Function({required int userId}) removeProfilePicture;
  final ValueChanged<String?> onAvatarChanged;
  final ValueChanged<String> onError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121A24) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF273445)
              : const Color(0xFFD7E1EE),
        ),
      ),
      child: Row(
        children: [
          EditableAvatar(
            fullName: profile.fullName,
            imageUrl: profile.profileImageUrl,
            ownerId: profile.id,
            isDarkMode: isDarkMode,
            uploadPicture: ({required ownerId, required bytes, required filename}) =>
                uploadProfilePicture(
                  userId: ownerId,
                  bytes: bytes,
                  filename: filename,
                ),
            removePicture: ({required ownerId}) =>
                removeProfilePicture(userId: ownerId),
            onChanged: onAvatarChanged,
            onError: onError,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.username != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${profile.username}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: mutedColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  profile.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSelector extends StatelessWidget {
  const _TabSelector({
    required this.selected,
    required this.isDarkMode,
    required this.onSelected,
  });

  final ProfileTab selected;
  final bool isDarkMode;
  final ValueChanged<ProfileTab> onSelected;

  static const _labels = {
    ProfileTab.profile: ('Profile', Icons.person_rounded),
    ProfileTab.password: ('Password', Icons.vpn_key_rounded),
    ProfileTab.help: ('Help', Icons.help_outline_rounded),
    ProfileTab.system: ('System', Icons.settings_rounded),
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in ProfileTab.values) ...[
            _TabChip(
              label: _labels[tab]!.$1,
              icon: _labels[tab]!.$2,
              isSelected: selected == tab,
              isDarkMode: isDarkMode,
              onTap: () => onSelected(tab),
            ),
            if (tab != ProfileTab.values.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final unselectedForeground = isDarkMode
        ? const Color(0xFFC6D3E1)
        : const Color(0xFF44566B);

    return Material(
      color: isSelected
          ? primary
          : (isDarkMode ? const Color(0xFF1A2430) : Colors.white),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? primary
                  : (isDarkMode
                        ? const Color(0xFF273445)
                        : const Color(0xFFD7E1EE)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : unselectedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : unselectedForeground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile, required this.isDarkMode});

  final AppUserProfile profile;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.person_rounded,
          title: 'My Profile',
          color: Color(0xFF1F5E89),
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Personal Information',
          icon: Icons.info_outline_rounded,
          headerColor: const Color(0xFF3E88C0),
          isDarkMode: isDarkMode,
          children: [
            _InfoRow(
              label: 'FULL NAME',
              value: profile.fullName,
              icon: Icons.person_outline_rounded,
              iconColor: const Color(0xFF1F5E89),
              isDarkMode: isDarkMode,
            ),
            _InfoRow(
              label: 'EMAIL ADDRESS',
              value: profile.email,
              icon: Icons.mail_outline_rounded,
              iconColor: const Color(0xFF2563EB),
              isDarkMode: isDarkMode,
            ),
            _InfoRow(
              label: 'PHONE NUMBER',
              value: profile.phone,
              icon: Icons.phone_outlined,
              iconColor: const Color(0xFF16A34A),
              isDarkMode: isDarkMode,
            ),
            _InfoRow(
              label: 'USERNAME',
              value: profile.username ?? 'Not set',
              icon: Icons.key_outlined,
              iconColor: const Color(0xFF7C6BC4),
              isDarkMode: isDarkMode,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Account Details',
          icon: Icons.verified_user_outlined,
          headerColor: const Color(0xFF2F9E77),
          isDarkMode: isDarkMode,
          children: [
            _InfoRow(
              label: 'STATUS',
              value: _capitalize(profile.status ?? 'Unknown'),
              valueColor: const Color(0xFF16A34A),
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF16A34A),
              isDarkMode: isDarkMode,
            ),
            if (profile.roles.isNotEmpty)
              _RolesRow(roles: profile.roles, isDarkMode: isDarkMode),
          ],
        ),
      ],
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) {
      return value;
    }
    return value[0].toUpperCase() + value.substring(1);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.icon,
    required this.headerColor,
    required this.isDarkMode,
    required this.children,
  });

  final String title;
  final IconData icon;
  final Color headerColor;
  final bool isDarkMode;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF121A24) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDarkMode
              ? const Color(0xFF273445)
              : const Color(0xFFD7E1EE),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: headerColor,
            child: Row(
              children: [
                Icon(icon, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.isDarkMode,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final bool isDarkMode;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: isDarkMode ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: valueColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RolesRow extends StatelessWidget {
  const _RolesRow({required this.roles, required this.isDarkMode});

  final List<String> roles;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDarkMode ? 0.2 : 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.sell_outlined, size: 18, color: primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ROLES',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final role in roles)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          role,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection extends StatelessWidget {
  const _HelpSection({required this.onOpenTelegram});

  final Future<void> Function() onOpenTelegram;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final mutedColor = isDarkMode
        ? const Color(0xFF9DB0C1)
        : const Color(0xFF5C738B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          color: Color(0xFF1F5E89),
        ),
        const SizedBox(height: 6),
        Text(
          'Get assistance and connect with our community.',
          style: theme.textTheme.bodyMedium?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode ? const Color(0xFF121A24) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDarkMode
                  ? const Color(0xFF273445)
                  : const Color(0xFFD7E1EE),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                  ),
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Need Help?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Join our Telegram community for support and updates.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenTelegram,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open Telegram'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final item in const [
          ('Instant Support', Icons.bolt_rounded),
          ('Community Help', Icons.groups_rounded),
          ('Latest Updates', Icons.campaign_rounded),
        ]) ...[
          Row(
            children: [
              Icon(item.$2, size: 18, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(
                item.$1,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 280,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
