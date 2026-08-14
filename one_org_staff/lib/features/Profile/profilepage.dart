import 'package:flutter/material.dart';

import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/theme_controller.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

import 'package:one_org_staff/shared/editable_avatar.dart';
import 'package:one_org_staff/shared/underline_tabs.dart';

enum ProfileTab { profile, password, help, system }

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeController,
    required this.loadProfile,
    required this.updatePassword,
    required this.uploadProfilePicture,
    required this.removeProfilePicture,
    this.onLogout,
  });

  final ThemeController themeController;
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

  bool get _isDarkMode => widget.themeController.isDark;

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
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
              // The same underlined bar the My Class student modal uses, so the
              // two tabbed sections read as one component.
              UnderlineTabs<ProfileTab>(
                items: const [
                  UnderlineTabItem(
                    value: ProfileTab.profile,
                    label: 'Profile',
                    icon: Icons.person_rounded,
                  ),
                  UnderlineTabItem(
                    value: ProfileTab.password,
                    label: 'Password',
                    icon: Icons.vpn_key_rounded,
                  ),
                  UnderlineTabItem(
                    value: ProfileTab.help,
                    label: 'Help',
                    icon: Icons.help_outline_rounded,
                  ),
                  UnderlineTabItem(
                    value: ProfileTab.system,
                    label: 'System',
                    icon: Icons.settings_rounded,
                  ),
                ],
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
        _SectionHeader(
          icon: Icons.vpn_key_rounded,
          title: 'Reset Password',
          color: Theme.of(context).colorScheme.primary,
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
              _isUpdatingPassword ? 'Updating password...' : 'Update password',
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
    final colors = appColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.settings_rounded,
          title: 'System',
          color: colors.accent.solid,
        ),
        const SizedBox(height: 6),
        Text(
          'Manage how the app looks. Changes apply across the whole app and '
          'are saved for next time.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.mutedText),
        ),
        const SizedBox(height: 22),

        _SettingsSection(
          title: 'APPEARANCE',
          description: 'Choose the system color used across the whole app.',
          mutedColor: colors.mutedText,
          child: _AccentPicker(
            selected: widget.themeController.accent,
            onSelected: widget.themeController.setAccent,
          ),
        ),
        const SizedBox(height: 24),

        _SettingsSection(
          title: 'DARK MODE',
          description:
              'Pick the dark flavor. The toggle below turns dark on and off; '
              'this sets which shade it uses.',
          mutedColor: colors.mutedText,
          child: _DarkVariantPicker(
            selected: widget.themeController.darkVariant,
            onSelected: widget.themeController.setDarkVariant,
          ),
        ),
        const SizedBox(height: 24),

        Container(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: colors.line),
          ),
          child: SwitchListTile(
            value: _isDarkMode,
            title: const Text('Dark mode'),
            subtitle: const Text('Switch between light and dark themes.'),
            secondary: Icon(
              _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
            ),
            onChanged: (value) {
              widget.themeController.setThemeMode(
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

/// A titled block within the System settings, matching the web's `Section`.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.description,
    required this.mutedColor,
    required this.child,
  });

  final String title;
  final String description;
  final Color mutedColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

/// The row of accent swatches. The selected one is ringed and ticked, and its
/// label is spelled out beside the row so the choice is readable, not just
/// colour-coded.
class _AccentPicker extends StatelessWidget {
  const _AccentPicker({required this.selected, required this.onSelected});

  final AppAccent selected;
  final ValueChanged<AppAccent> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final accent in kAccents)
              Semantics(
                label: accent.label,
                selected: accent.key == selected.key,
                button: true,
                child: GestureDetector(
                  onTap: () => onSelected(accent),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: accent.gradient,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: accent.key == selected.key
                            ? (Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black87)
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: accent.key == selected.key
                        ? const Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          selected.label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),

        // Live preview, so the effect of a pick is visible without leaving the
        // page — same idea as the web's swatch preview strip.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.line),
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: selected.gradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Primary button',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: colors.softBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Highlight',
                  style: TextStyle(
                    color: colors.softText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                'Accent text',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              CircleAvatar(
                radius: 16,
                backgroundColor: selected.solid,
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Dark-flavor picker. Each option is a miniature of the app in that shade —
/// three identical dark squares would tell the user nothing.
class _DarkVariantPicker extends StatelessWidget {
  const _DarkVariantPicker({required this.selected, required this.onSelected});

  final AppDarkVariant selected;
  final ValueChanged<AppDarkVariant> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final variant in kDarkVariants)
          Semantics(
            label: variant.label,
            selected: variant.key == selected.key,
            button: true,
            child: GestureDetector(
              onTap: () => onSelected(variant),
              child: Container(
                width: 118,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: variant.key == selected.key
                        ? Theme.of(context).colorScheme.primary
                        : colors.line,
                    width: variant.key == selected.key ? 2.5 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 62,
                      width: double.infinity,
                      color: variant.background,
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 14,
                            decoration: BoxDecoration(
                              color: variant.card,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 6,
                                  width: 46,
                                  decoration: BoxDecoration(
                                    color: variant.line,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Expanded(
                                  child: Container(
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: variant.card,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      color: colors.card,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      child: Text(
                        variant.label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    final mutedColor = appColorsOf(context).mutedText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: appColorsOf(context).line),
      ),
      child: Row(
        children: [
          EditableAvatar(
            fullName: profile.fullName,
            imageUrl: profile.profileImageUrl,
            ownerId: profile.id,
            isDarkMode: isDarkMode,
            uploadPicture:
                ({required ownerId, required bytes, required filename}) =>
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
                  style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
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

class _ProfileDetails extends StatelessWidget {
  const _ProfileDetails({required this.profile, required this.isDarkMode});

  final AppUserProfile profile;
  final bool isDarkMode;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.person_rounded,
          title: 'My Profile',
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        _InfoCard(
          title: 'Personal Information',
          icon: Icons.info_outline_rounded,
          headerColor: appColorsOf(context).ring,
          isDarkMode: isDarkMode,
          children: [
            _InfoRow(
              label: 'FULL NAME',
              value: profile.fullName,
              icon: Icons.person_outline_rounded,
              iconColor: Theme.of(context).colorScheme.primary,
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
        color: appColorsOf(context).card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: appColorsOf(context).line),
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
    final mutedColor = appColorsOf(context).mutedText;

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
    final mutedColor = appColorsOf(context).mutedText;

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
    final mutedColor = appColorsOf(context).mutedText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.help_outline_rounded,
          title: 'Help & Support',
          color: Theme.of(context).colorScheme.primary,
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
            color: appColorsOf(context).card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: appColorsOf(context).line),
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: appColorsOf(context).gradient,
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
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
