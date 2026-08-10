import 'package:flutter/material.dart';

import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
    required this.loadProfile,
    required this.updatePassword,
    this.onLogout,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  final Future<AppUserProfile> Function() loadProfile;
  final Future<String> Function({
    required String currentPassword,
    required String newPassword,
  }) updatePassword;
  final VoidCallback? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  late Future<AppUserProfile> _profileFuture;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final containerColor = _isDarkMode
        ? const Color(0xFF121A24).withValues(alpha: 0.94)
        : Colors.white.withValues(alpha: 0.9);
    final borderColor = _isDarkMode
        ? const Color(0xFF273445)
        : const Color(0xFFD7E1EE);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: FutureBuilder<AppUserProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 280,
              child: Center(
                child: CircularProgressIndicator(),
              ),
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
              Center(
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        CircleAvatar(
                          radius: 48,
                          backgroundColor: colorScheme.primaryContainer,
                          backgroundImage: profile.profileImageUrl != null
                              ? NetworkImage(profile.profileImageUrl!)
                              : null,
                          child: profile.profileImageUrl == null
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 52,
                                  color: colorScheme.primary,
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: containerColor,
                                width: 3,
                              ),
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Text(
                      profile.fullName,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile.subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: _mutedTextColor(context),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const _SectionTitle(
                title: 'User data',
                subtitle: 'Basic information shown in the staff profile.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 10,
                children: [
                  _ProfileInfoCard(label: 'Email', value: profile.email),
                  _ProfileInfoCard(label: 'Phone', value: profile.phone),
                  _ProfileInfoCard(
                    label: 'Department',
                    value: profile.department,
                  ),
                  _ProfileInfoCard(label: 'Joined', value: profile.joinedDate),
                ],
              ),
              const SizedBox(height: 18),
              _SectionTitle(
                title: 'Appearance',
                subtitle: _isDarkMode
                    ? 'Dark theme is active.'
                    : 'Light theme is active.',
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 32),
              const _SectionTitle(
                title: 'Update password',
                subtitle: 'Change the account password from the profile page.',
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
              const SizedBox(height: 18),
              if (widget.onLogout != null) ...[
                
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onLogout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Sign out'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Color _mutedTextColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB7C3D1)
        : const Color(0xFF5C738B);
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final mutedTextColor = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFB7C3D1)
        : const Color(0xFF5C738B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: mutedTextColor,
          ),
        ),
      ],
    );
  }
}

class _ProfileInfoCard extends StatelessWidget {
  const _ProfileInfoCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Container(
  width: double.infinity,
  padding: const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: isDarkMode
        ? const Color(0xFF1A2430)
        : const Color(0xFFF4F7FB),
    borderRadius: BorderRadius.circular(22),
    border: Border.all(
      color: isDarkMode
          ? const Color(0xFF273445)
          : const Color(0xFFD7E1EE),
    ),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: isDarkMode
              ? const Color(0xFF9DB0C1)
              : const Color(0xFF5C738B),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        value,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  ),
);
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({
    required this.message,
    required this.onRetry,
  });

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