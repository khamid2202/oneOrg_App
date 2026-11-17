import 'package:flutter/material.dart';

import 'package:one_org_staff/app/language_controller.dart';
import 'package:one_org_staff/app/theme.dart';
import 'package:one_org_staff/app/theme_controller.dart';

import 'package:one_org_staff/features/auth/domain/auth_repository.dart';
import 'package:one_org_staff/features/branches/application/branch_controller.dart';
import 'package:one_org_staff/features/branches/presentation/branch_switcher.dart';

import 'package:one_org_staff/l10n/generated/app_localizations.dart';
import 'package:one_org_staff/shared/editable_avatar.dart';

/// What Profile shows: the list itself, or one of the screens it opens.
enum ProfileView { list, password, system, suggestions }

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
final _phonePattern = RegExp(r'^\+?[\d\s()-]{7,20}$');

/// Profile, laid out like the web's phone Settings (`MobileView.jsx`): a
/// profile card, then grouped rows. Password, System and Suggestions open as
/// their own screen with a back arrow.
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.themeController,
    this.languageController,
    required this.loadProfile,
    required this.updatePassword,
    required this.uploadProfilePicture,
    required this.removeProfilePicture,
    this.loadContact,
    this.saveContact,
    this.sendSuggestion,
    this.branchController,
    this.onLogout,
  });

  final ThemeController themeController;
  final LanguageController? languageController;
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

  /// `/settings/profile`. Without it the rows show what `/users/me` sent and
  /// can't be edited.
  final Future<ProfileContact> Function()? loadContact;
  final Future<ProfileContact> Function({
    required String email,
    required String phone,
  })?
  saveContact;
  final Future<void> Function({
    required String message,
    required bool anonymous,
  })?
  sendSuggestion;

  /// Shown on the card when the person works at more than one branch.
  final BranchController? branchController;
  final VoidCallback? onLogout;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late Future<AppUserProfile> _profileFuture;
  ProfileView _view = ProfileView.list;
  bool _isUpdatingPassword = false;

  ProfileContact? _contact;
  bool _resolvingContact = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = widget.loadProfile();
    _resolveContact();
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

  Future<void> _resolveContact() async {
    final load = widget.loadContact;
    if (load == null) return;
    setState(() => _resolvingContact = true);
    try {
      final contact = await load();
      if (mounted) setState(() => _contact = contact);
    } catch (_) {
      // Fall back to what /users/me sent.
    } finally {
      if (mounted) setState(() => _resolvingContact = false);
    }
  }

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

  void _open(ProfileView view) => setState(() => _view = view);

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

  Future<void> _editContact({
    required String email,
    required String phone,
    required bool focusPhone,
  }) async {
    final save = widget.saveContact;
    if (save == null) return;
    final saved = await showModalBottomSheet<ProfileContact>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditContactSheet(
        email: email,
        phone: phone,
        focusPhone: focusPhone,
        save: save,
      ),
    );
    if (saved != null && mounted) {
      setState(() => _contact = saved);
      _showSnackBar(AppLocalizations.of(context).profileContactSaved);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The system back gesture leaves a sub-screen before it leaves Profile.
      canPop: _view == ProfileView.list,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _open(ProfileView.list);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
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
            final l = AppLocalizations.of(context);
            return switch (_view) {
              ProfileView.list => _buildList(profile),
              ProfileView.password => _SubScreen(
                title: l.profilePassword,
                onBack: () => _open(ProfileView.list),
                child: _buildPasswordSection(),
              ),
              ProfileView.system => _SubScreen(
                title: l.profileSystem,
                onBack: () => _open(ProfileView.list),
                child: _buildSystemSection(),
              ),
              ProfileView.suggestions => _SubScreen(
                title: l.profileSuggestions,
                onBack: () => _open(ProfileView.list),
                child: _SuggestionsForm(send: widget.sendSuggestion),
              ),
            };
          },
        ),
      ),
    );
  }

  Widget _buildList(AppUserProfile profile) {
    final l = AppLocalizations.of(context);
    final muted = appColorsOf(context).mutedText;

    String fromProfile(String value) =>
        value == 'Not specified' ? '' : value.trim();
    final email = _contact?.email ?? fromProfile(profile.email);
    final phone = _contact?.phone ?? fromProfile(profile.phone);
    String shown(String value) =>
        _resolvingContact ? '…' : (value.isEmpty ? l.profileNotSet : value);

    final canEdit = widget.saveContact != null;
    final pencil = Icon(Icons.edit_outlined, size: 18, color: muted);
    final chevron = Icon(Icons.chevron_right_rounded, size: 22, color: muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProfileCard(
          profile: profile,
          isDarkMode: _isDarkMode,
          branchController: widget.branchController,
          uploadProfilePicture: widget.uploadProfilePicture,
          removeProfilePicture: widget.removeProfilePicture,
          onAvatarChanged: (url) => _applyAvatar(profile, url),
          onError: _showSnackBar,
        ),
        _Group(
          label: l.profileAccount,
          children: [
            _Item(
              icon: Icons.mail_outline_rounded,
              title: l.profileEmail,
              subtitle: shown(email),
              trailing: canEdit ? pencil : null,
              onTap: canEdit
                  ? () => _editContact(
                      email: email,
                      phone: phone,
                      focusPhone: false,
                    )
                  : null,
            ),
            _Item(
              icon: Icons.phone_outlined,
              title: l.profilePhone,
              subtitle: shown(phone),
              trailing: canEdit ? pencil : null,
              onTap: canEdit
                  ? () => _editContact(
                      email: email,
                      phone: phone,
                      focusPhone: true,
                    )
                  : null,
            ),
            _Item(
              icon: Icons.key_outlined,
              title: l.profilePassword,
              trailing: chevron,
              onTap: () => _open(ProfileView.password),
            ),
          ],
        ),
        _Group(
          label: l.profileApp,
          children: [
            _Item(
              icon: Icons.palette_outlined,
              title: l.profileSystem,
              subtitle: l.profileSystemHint,
              trailing: chevron,
              onTap: () => _open(ProfileView.system),
            ),
            if (widget.sendSuggestion != null)
              _Item(
                icon: Icons.lightbulb_outline_rounded,
                title: l.profileSuggestions,
                trailing: chevron,
                onTap: () => _open(ProfileView.suggestions),
              ),
          ],
        ),
        if (widget.onLogout != null) ...[
          const SizedBox(height: 12),
          _Group(
            children: [
              _Item(
                icon: Icons.logout_rounded,
                title: l.profileLogOut,
                danger: true,
                onTap: widget.onLogout,
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        if (widget.languageController != null) ...[
          _SettingsSection(
            title: AppLocalizations.of(context).language.toUpperCase(),
            mutedColor: colors.mutedText,
            child: _LanguagePicker(controller: widget.languageController!),
          ),
          const SizedBox(height: 24),
        ],

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
      ],
    );
  }
}

/// A sub-screen: a back arrow and title, then its body.
class _SubScreen extends StatelessWidget {
  const _SubScreen({
    required this.title,
    required this.onBack,
    required this.child,
  });

  final String title;
  final VoidCallback onBack;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: onBack,
              tooltip: MaterialLocalizations.of(context).backButtonTooltip,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: child,
        ),
      ],
    );
  }
}

/// The card at the top: photo, name, @username and roles, then the branch.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.isDarkMode,
    required this.branchController,
    required this.uploadProfilePicture,
    required this.removeProfilePicture,
    required this.onAvatarChanged,
    required this.onError,
  });

  final AppUserProfile profile;
  final bool isDarkMode;
  final BranchController? branchController;
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
    final colors = appColorsOf(context);
    final branches = branchController;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              EditableAvatar(
                fullName: profile.fullName,
                imageUrl: profile.profileImageUrl,
                ownerId: profile.id,
                isDarkMode: isDarkMode,
                radius: 30,
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
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (profile.username != null)
                      Text(
                        '@${profile.username}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: colors.mutedText,
                        ),
                      ),
                    if (profile.roles.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          for (final role in profile.roles)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.softBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                role,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.softText,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (branches != null)
            ListenableBuilder(
              listenable: branches,
              builder: (context, _) {
                final branch = branches.activeBranch;
                if (!branches.canSwitch || branch == null) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Material(
                    color: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: colors.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => BranchSwitcher.pick(context, branches),
                      child: SizedBox(
                        height: 44,
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            Icon(
                              Icons.apartment_rounded,
                              size: 18,
                              color: colors.accent.solid,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                branch.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.expand_more_rounded,
                              size: 18,
                              color: colors.mutedText,
                            ),
                            const SizedBox(width: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// A labelled block of rows on one rounded surface, like the web's `Group`.
class _Group extends StatelessWidget {
  const _Group({this.label, required this.children});

  final String? label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = appColorsOf(context);
    final gap = Theme.of(context).scaffoldBackgroundColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              label!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: colors.softText,
              ),
            ),
          ),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) Divider(height: 2, thickness: 2, color: gap),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// One row: leading icon, title with optional subtitle, trailing icon.
class _Item extends StatelessWidget {
  const _Item({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    final error = theme.colorScheme.error;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: danger ? error : colors.mutedText),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontSize: 15,
                        color: danger ? error : null,
                        fontWeight: danger ? FontWeight.w600 : null,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          color: colors.mutedText,
                        ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Email and phone in one sheet, as the web's `EditContactModal`. Pops with
/// what the server saved.
class _EditContactSheet extends StatefulWidget {
  const _EditContactSheet({
    required this.email,
    required this.phone,
    required this.focusPhone,
    required this.save,
  });

  final String email;
  final String phone;
  final bool focusPhone;
  final Future<ProfileContact> Function({
    required String email,
    required String phone,
  })
  save;

  @override
  State<_EditContactSheet> createState() => _EditContactSheetState();
}

class _EditContactSheetState extends State<_EditContactSheet> {
  late final _email = TextEditingController(text: widget.email);
  late final _phone = TextEditingController(text: widget.phone);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final email = _email.text.trim();
    final phone = _phone.text.trim();
    if (email.isNotEmpty && !_emailPattern.hasMatch(email)) {
      setState(() => _error = l.profileInvalidEmail);
      return;
    }
    if (phone.isNotEmpty && !_phonePattern.hasMatch(phone)) {
      setState(() => _error = l.profileInvalidPhone);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await widget.save(email: email, phone: phone);
      if (mounted) Navigator.pop(context, saved);
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _error = failure.message);
    } catch (_) {
      if (mounted) setState(() => _error = l.profileContactFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.profileContactTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _email,
              autofocus: !widget.focusPhone,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: l.profileEmail,
                prefixIcon: const Icon(Icons.mail_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              autofocus: widget.focusPhone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.profilePhone,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l.save),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The web's Help page: a suggestion box that goes to the school's Telegram
/// group through the bot.
class _SuggestionsForm extends StatefulWidget {
  const _SuggestionsForm({required this.send});

  final Future<void> Function({
    required String message,
    required bool anonymous,
  })?
  send;

  @override
  State<_SuggestionsForm> createState() => _SuggestionsFormState();
}

class _SuggestionsFormState extends State<_SuggestionsForm> {
  final _message = TextEditingController();
  bool _anonymous = false;
  bool _sending = false;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _message.addListener(() {
      if (_sent) _sent = false;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  bool get _canSend =>
      widget.send != null && _message.text.trim().length >= 3 && !_sending;

  Future<void> _submit() async {
    if (!_canSend) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      await widget.send!(message: _message.text.trim(), anonymous: _anonymous);
      _message.clear();
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      setState(() => _sent = true);
      messenger
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(l.suggestionsSent)));
    } catch (error) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(
              error is AuthFailure ? error.message : l.suggestionsFailed,
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colors = appColorsOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.suggestionsLead,
          style: theme.textTheme.bodySmall?.copyWith(color: colors.mutedText),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: colors.softText,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l.suggestionsPrompt,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _message,
                minLines: 5,
                maxLines: 8,
                maxLength: 3000,
                decoration: InputDecoration(
                  hintText: l.suggestionsHint,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Checkbox(
                    value: _anonymous,
                    onChanged: (value) =>
                        setState(() => _anonymous = value ?? false),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _anonymous = !_anonymous),
                    child: Text(l.suggestionsAnonymous),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _canSend ? _submit : null,
                    icon: _sending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _sent ? Icons.check_rounded : Icons.send_rounded,
                            size: 18,
                          ),
                    label: Text(
                      _sent ? l.suggestionsSentButton : l.suggestionsSend,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A titled block within the System settings, matching the web's `Section`.
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    this.description,
    required this.mutedColor,
    required this.child,
  });

  final String title;
  final String? description;
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
        if (description != null)
          Text(
            description!,
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

class _LanguagePicker extends StatelessWidget {
  const _LanguagePicker({required this.controller});

  final LanguageController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          for (final option in LanguageController.options.entries)
            ButtonSegment(value: option.key, label: Text(option.value)),
        ],
        selected: {controller.code},
        onSelectionChanged: (picked) => controller.setLanguage(picked.first),
      ),
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
