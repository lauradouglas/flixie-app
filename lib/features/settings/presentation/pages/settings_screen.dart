import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/user.dart' as user_model;
import 'package:flixie_app/features/settings/presentation/controllers/settings_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/settings/data/reference_data_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/settings/presentation/widgets/change_password_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_constants.dart';
import 'package:flixie_app/features/settings/presentation/widgets/favorite_genres_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/icon_color_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_tile.dart';
import 'package:flixie_app/features/settings/presentation/widgets/watch_providers_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionLabel('Account'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.person_outline,
                label: 'Edit Profile',
                onTap: () => _showEditProfileSheet(context),
              ),
              SettingsTile(
                icon: Icons.face_outlined,
                label: 'Change Avatar',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: FlixieColors.background,
                  builder: (_) => const FractionallySizedBox(
                    heightFactor: .9,
                    child: ChangeAvatarSheet(),
                  ),
                ),
              ),
              SettingsTile(
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () => _showChangePasswordSheet(context),
              ),
              SettingsTile(
                icon: Icons.block_outlined,
                label: 'Blocked Users',
                onTap: () => _showBlockedUsers(context),
                isLast: true,
              ),
              // TODO: implement Privacy screen
              // SettingsTile(
              //   icon: Icons.privacy_tip_outlined,
              //   label: 'Privacy',
              //   onTap: () {},
              //   isLast: true,
              // ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Social'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invite a friend',
                onTap: () => context.push('/invite-friend'),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Preferences'),
          _SettingsGroup(
            children: [
              Consumer<AnalyticsController>(
                builder: (context, analytics, _) => SettingsTile(
                  icon: Icons.analytics_outlined,
                  label: 'Share anonymous analytics',
                  onTap: () => analytics.isEnabled
                      ? analytics.decline()
                      : analytics.allow(),
                  trailing: Switch.adaptive(
                    value: analytics.consent == AnalyticsConsent.accepted,
                    onChanged: (enabled) =>
                        enabled ? analytics.allow() : analytics.decline(),
                  ),
                ),
              ),
              // TODO: implement Notifications settings
              // SettingsTile(
              //   icon: Icons.notifications_outlined,
              //   label: 'Notifications',
              //   onTap: () {},
              // ),
              // TODO: implement Appearance settings
              // SettingsTile(
              //   icon: Icons.dark_mode_outlined,
              //   label: 'Appearance',
              //   onTap: () {},
              // ),
              SettingsTile(
                icon: Icons.live_tv_outlined,
                label: 'Watch Providers',
                onTap: () => _showWatchProvidersSheet(context),
              ),
              SettingsTile(
                icon: Icons.tune_outlined,
                label: 'Content Preferences',
                onTap: () => _showFavoriteGenresSheet(context),
              ),
              SettingsTile(
                icon: Icons.palette_outlined,
                label: 'Avatar Colour',
                onTap: () => _showIconColorSheet(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel('Support'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.help_outline,
                label: 'Help Center',
                onTap: () => context.push('/help-support'),
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                label: 'Send Feedback',
                onTap: () => _sendFeedback(),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                label: 'About & Credits',
                onTap: () => context.push('/about-credits'),
                isLast: true,
              ),
              SettingsTile(
                icon: Icons.privacy_tip_outlined,
                label: 'Privacy Policy',
                onTap: () => _openPrivacyPolicy(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _LogOutButton(),
          const SizedBox(height: 16),
          const _DeleteAccountButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: const TextStyle(
          color: FlixieColors.medium,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsEditProfileSheet(user: dbUser),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlixieColors.background,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .75,
        child: _BlockedUsersSheet(),
      ),
    );
  }

  void _showFavoriteGenresSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FavoriteGenresSheet(
          userId: dbUser.id, currentGenres: dbUser.favoriteGenres ?? []),
    );
  }

  void _showIconColorSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IconColorSheet(
        userId: dbUser.id,
        currentColorId: dbUser.iconColorId,
      ),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://www.flixie.co.uk/privacy'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open the privacy policy.'),
        ),
      );
    }
  }

  Future<void> _sendFeedback() async {
    final uri =
        Uri.parse('mailto:flixieadmin@gmail.com?subject=Flixie%20Feedback');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showWatchProvidersSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchProvidersSheet(userId: dbUser.id),
    );
  }
}

class _BlockedUsersSheet extends StatefulWidget {
  const _BlockedUsersSheet();

  @override
  State<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends State<_BlockedUsersSheet> {
  late Future<List<BlockedUser>> _users = SafetyService.blockedUsers();

  Future<void> _unblock(BlockedUser user) async {
    await SafetyService.unblock(user.id);
    if (mounted) {
      setState(() => _users = SafetyService.blockedUsers(refresh: true));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Blocked Users',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Blocked users cannot contact or interact with you.',
            style: TextStyle(color: FlixieColors.medium),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BlockedUser>>(
            future: _users,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final users = snapshot.data ?? const [];
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    'You have not blocked anyone.',
                    style: TextStyle(color: FlixieColors.medium),
                  ),
                );
              }
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user.username[0].toUpperCase()),
                    ),
                    title: Text('@${user.username}'),
                    subtitle: user.firstName?.isNotEmpty == true
                        ? Text(user.firstName!)
                        : null,
                    trailing: TextButton(
                      onPressed: () => _unblock(user),
                      child: const Text('Unblock'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Groups settings tiles into a rounded card container.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        border: Border.all(
          color: FlixieColors.tabBarBorder,
        ),
      ),
      child: Column(children: children),
    );
  }
}

/// Log out button shown at the bottom of Settings.
class _LogOutButton extends StatelessWidget {
  const _LogOutButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        border: Border.all(
          color: FlixieColors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: FlixieColors.danger),
        title: const Text(
          'Log Out',
          style: TextStyle(
            color: FlixieColors.danger,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: () async {
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text(
                'Log Out',
                style: TextStyle(color: Colors.white),
              ),
              content: const Text(
                'Are you sure you want to log out?',
                style: TextStyle(color: FlixieColors.light),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: FlixieColors.medium),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Log Out',
                    style: TextStyle(color: FlixieColors.danger),
                  ),
                ),
              ],
            ),
          );
          if (confirmed == true && context.mounted) {
            await context.read<AuthProvider>().signOut();
          }
        },
      ),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        border: Border.all(color: FlixieColors.danger.withValues(alpha: 0.2)),
      ),
      child: ListTile(
        leading: const Icon(
          Icons.delete_forever_outlined,
          color: FlixieColors.danger,
        ),
        title: const Text(
          'Delete account',
          style: TextStyle(
            color: FlixieColors.danger,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        subtitle: const Text(
          'Permanently deletes your account and Flixie data.',
          style: TextStyle(color: FlixieColors.medium, fontSize: 12),
        ),
        onTap: () async {
          final password = await showDialog<String>(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _DeleteAccountDialog(),
          );
          if (password == null || !context.mounted) return;

          final messenger = ScaffoldMessenger.of(context);
          final authProvider = context.read<AuthProvider>();
          final rootNavigator = Navigator.of(context, rootNavigator: true);

          showGeneralDialog<void>(
            context: context,
            barrierDismissible: false,
            barrierColor: FlixieColors.background,
            transitionDuration: const Duration(milliseconds: 220),
            pageBuilder: (_, __, ___) => const _AccountDeletionProgressScreen(),
            transitionBuilder: (_, animation, __, child) => FadeTransition(
              opacity: animation,
              child: child,
            ),
          );

          final error = await authProvider.deleteAccount(password);

          if (rootNavigator.mounted && rootNavigator.canPop()) {
            rootNavigator.pop();
          }
          if (error != null && messenger.mounted) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(error),
                backgroundColor: FlixieColors.danger,
              ),
            );
          }
        },
      ),
    );
  }
}

class _AccountDeletionProgressScreen extends StatelessWidget {
  const _AccountDeletionProgressScreen();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: FlixieColors.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: FlixieColors.danger.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: FlixieColors.danger.withValues(alpha: 0.28),
                      ),
                    ),
                    child: const Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 82,
                          height: 82,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: FlixieColors.danger,
                            backgroundColor: FlixieColors.tabBarBorder,
                          ),
                        ),
                        Icon(
                          Icons.shield_outlined,
                          size: 38,
                          color: FlixieColors.dangerTint,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Deleting your account…',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'We’re securely deleting your Flixie data and login. '
                    'Please keep the app open.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: FlixieColors.light,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: FlixieColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: FlixieColors.tabBarBorder),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: FlixieColors.success,
                        ),
                        SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            'This may take a few moments',
                            style: TextStyle(
                              color: FlixieColors.medium,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog();

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _hidePassword = true;

  bool get _canDelete =>
      _passwordController.text.isNotEmpty &&
      _confirmationController.text.trim() == 'DELETE';

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Delete your account?',
        style: TextStyle(color: Colors.white),
      ),
      content: AutofillGroup(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This cannot be undone. Your profile, reviews, ratings, '
                'watch history, lists, friendships, messages and Firebase '
                'login will be permanently deleted.',
                style: TextStyle(color: FlixieColors.light, height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _passwordController,
                obscureText: _hidePassword,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Current password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                    onPressed: () =>
                        setState(() => _hidePassword = !_hidePassword),
                    icon: Icon(
                      _hidePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmationController,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _canDelete
              ? () => Navigator.pop(context, _passwordController.text)
              : null,
          style: FilledButton.styleFrom(
            backgroundColor: FlixieColors.danger,
            foregroundColor: Colors.white,
          ),
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile (username & bio) bottom sheet
// ---------------------------------------------------------------------------

class _SettingsEditProfileSheet extends StatefulWidget {
  const _SettingsEditProfileSheet({required this.user});
  final user_model.User user;

  @override
  State<_SettingsEditProfileSheet> createState() =>
      _SettingsEditProfileSheetState();
}

class _SettingsEditProfileSheetState extends State<_SettingsEditProfileSheet> {
  final SettingsController _settingsController = SettingsController.instance;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;

  bool _saving = false;
  bool _checkingUsername = false;
  String? _usernameError;
  DateTime? _lastCheck;

  List<Country> _countries = [];
  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await ReferenceDataService.getCountries();
      if (!mounted) return;
      Country? current;
      if (widget.user.countryId != null) {
        try {
          current = countries.firstWhere((c) => c.id == widget.user.countryId);
        } catch (_) {}
      }
      setState(() {
        _countries = countries;
        _selectedCountry = current;
      });
    } catch (_) {
      // Country list is optional; silently ignore load failures
    }
  }

  Future<void> _pickCountry() async {
    final country = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsCountryPickerSheet(
        countries: _countries,
        selected: _selectedCountry,
      ),
    );
    if (!mounted || country == null) return;
    setState(() => _selectedCountry = country);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _onUsernameChanged(String value) async {
    setState(() => _usernameError = null);
    final trimmed = value.trim();
    if (trimmed == widget.user.username) return;
    if (trimmed.length < 3) {
      setState(() => _usernameError = 'At least 3 characters required');
      return;
    }
    final stamp = DateTime.now();
    _lastCheck = stamp;
    setState(() => _checkingUsername = true);
    await Future.delayed(const Duration(milliseconds: 600));
    if (_lastCheck != stamp || !mounted) return;
    try {
      final exists = await _settingsController.usernameExists(trimmed);
      if (!mounted) return;
      setState(() {
        _checkingUsername = false;
        _usernameError = exists ? 'Username already taken' : null;
      });
    } catch (_) {
      if (mounted) setState(() => _checkingUsername = false);
    }
  }

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    if (_usernameError != null || _checkingUsername) return;
    if (username.isEmpty) {
      setState(() => _usernameError = 'Username cannot be empty');
      return;
    }
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);

    try {
      final userId = widget.user.id;
      user_model.User updated = widget.user;

      // Only send changed fields — API takes one field at a time
      if (username != widget.user.username) {
        updated = await _settingsController.updateUserField(
            userId, 'username', username);
      }
      if (bio != (widget.user.bio ?? '')) {
        updated = await _settingsController.updateUserField(userId, 'bio', bio);
      }
      if (_selectedCountry?.id != widget.user.countryId) {
        updated = await _settingsController.updateUserField(
            userId, 'countryId', _selectedCountry?.id);
      }

      if (!mounted) return;
      auth.updateCachedUser(updated);
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        content: Text('Profile updated'),
        backgroundColor: FlixieColors.success,
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(
        content: Text(error.code == 'USERNAME_NOT_AVAILABLE'
            ? error.message
            : 'Failed to update profile. Please try again.'),
        backgroundColor: FlixieColors.danger,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
          content: Text('Failed to update profile. Please try again.'),
          backgroundColor: FlixieColors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final unchanged = _usernameCtrl.text.trim() == widget.user.username &&
        _bioCtrl.text.trim() == (widget.user.bio ?? '') &&
        _selectedCountry?.id == widget.user.countryId;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Edit Profile',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Username
            TextField(
              controller: _usernameCtrl,
              style: const TextStyle(color: Colors.white),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (v) {
                setState(() {});
                _onUsernameChanged(v);
              },
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: const TextStyle(color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                errorText: _usernameError,
                suffixIcon: _checkingUsername
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: FlixieColors.medium),
                        ),
                      )
                    : (_usernameError == null &&
                            _usernameCtrl.text.trim() != widget.user.username &&
                            _usernameCtrl.text.trim().length >= 3)
                        ? const Icon(Icons.check_circle_outline,
                            color: FlixieColors.success)
                        : null,
              ),
            ),
            const SizedBox(height: 14),
            // Bio
            TextField(
              controller: _bioCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              maxLength: 200,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: const TextStyle(color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                counterStyle: const TextStyle(color: FlixieColors.medium),
              ),
            ),
            const SizedBox(height: 14),
            // Country
            if (_countries.isNotEmpty)
              GestureDetector(
                onTap: _pickCountry,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: FlixieColors.tabBarBackgroundFocused,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          color: FlixieColors.medium, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedCountry?.name ?? 'Country (optional)',
                          style: TextStyle(
                            color: _selectedCountry != null
                                ? Colors.white
                                : FlixieColors.medium,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Icon(Icons.expand_more_rounded,
                          color: FlixieColors.medium),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (unchanged ||
                        _saving ||
                        _checkingUsername ||
                        _usernameError != null)
                    ? null
                    : _save,
                style: FilledButton.styleFrom(
                    backgroundColor: FlixieColors.primary),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save Changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Country picker bottom sheet (used from Edit Profile in Settings)
// ---------------------------------------------------------------------------

class _SettingsCountryPickerSheet extends StatefulWidget {
  const _SettingsCountryPickerSheet({required this.countries, this.selected});

  final List<Country> countries;
  final Country? selected;

  @override
  State<_SettingsCountryPickerSheet> createState() =>
      _SettingsCountryPickerSheetState();
}

class _SettingsCountryPickerSheetState
    extends State<_SettingsCountryPickerSheet> {
  final _searchController = TextEditingController();
  late List<Country> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.countries;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.countries
          : widget.countries
              .where((c) => c.name.toLowerCase().contains(q))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Select Country',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                hintStyle: const TextStyle(color: FlixieColors.medium),
                prefixIcon:
                    const Icon(Icons.search, color: FlixieColors.medium),
                filled: true,
                fillColor: FlixieColors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ListView.builder(
                itemCount: _filtered.length,
                itemBuilder: (context, index) {
                  final country = _filtered[index];
                  final isSelected = country.id == widget.selected?.id;
                  return ListTile(
                    title: Text(
                      country.name,
                      style: TextStyle(
                        color: isSelected
                            ? FlixieColors.primaryTint
                            : FlixieColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: FlixieColors.primaryTint)
                        : null,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
