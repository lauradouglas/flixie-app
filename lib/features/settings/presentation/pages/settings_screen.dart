import '../widgets/appearance_setting.dart';
import 'package:flixie_app/features/settings/presentation/widgets/delete_account_button.dart';
import 'package:flixie_app/core/legal/terms_of_use_screen.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import 'package:flixie_app/features/library_import/data/library_import_controller.dart';
import 'package:flixie_app/features/library_import/presentation/library_import_screen.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/logout_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
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
import 'package:flixie_app/features/settings/presentation/widgets/favorite_genres_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_tile.dart';
import 'package:flixie_app/features/settings/presentation/widgets/watch_providers_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';

Future<void> showSettingsEditDetailsSheet(BuildContext context) async {
  final user = context.read<AuthProvider>().dbUser;
  if (user == null) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    clipBehavior: Clip.antiAlias,
    builder: (context) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
      child:
          SingleChildScrollView(child: _SettingsEditProfileSheet(user: user)),
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: FlixieTitleAppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _sectionLabel(context, 'Account'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.file_upload_outlined,
                label: 'Import ratings & watchlist',
                onTap: () async {
                  final auth = context.read<AuthProvider>();
                  final userId = auth.dbUser?.id;
                  if (userId == null) return;
                  final importController = LibraryImportController(
                      userId: userId,
                      isCurrentUser: () => auth.dbUser?.id == userId);
                  await Navigator.of(context, rootNavigator: true).push<void>(
                    MaterialPageRoute(
                        builder: (_) => LibraryImportScreen(
                              controller: importController,
                            )),
                  );
                  if (auth.dbUser?.id == userId) {
                    TabRefreshController.watchlist.value++;
                    TabRefreshController.requestHomeRefresh();
                    await auth.refreshUserData();
                  }
                },
              ),
              SettingsTile(
                icon: Icons.person_outline,
                label: 'Edit details',
                onTap: () => _showEditProfileSheet(context),
              ),
              SettingsTile(
                icon: Icons.face_outlined,
                label: 'Change Avatar',
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  useRootNavigator: true,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: context.colors.background,
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
          _sectionLabel(context, 'Social'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Invite a friend',
                onTap: () => context.push('/invite-friend?from=settings'),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Preferences'),
          _SettingsGroup(
            children: [
              const _EpisodeSpoilerSetting(),
              Consumer<AnalyticsController>(
                builder: (context, analytics, _) => SettingsTile(
                  icon: Icons.analytics_outlined,
                  label: 'Share usage analytics',
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
              const AppearanceSetting(),
              SettingsTile(
                icon: Icons.live_tv_outlined,
                label: 'Watch Providers',
                onTap: () => _showWatchProvidersSheet(context),
              ),
              SettingsTile(
                icon: Icons.tune_outlined,
                label: 'Content Preferences',
                onTap: () => _showFavoriteGenresSheet(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sectionLabel(context, 'Support'),
          _SettingsGroup(
            children: [
              SettingsTile(
                icon: Icons.explore_outlined,
                label: 'Flixie guide',
                onTap: () => context.push('/getting-started?from=settings'),
              ),
              SettingsTile(
                icon: Icons.help_outline,
                label: 'Help Center',
                onTap: () => context.push('/help-support'),
              ),
              SettingsTile(
                icon: Icons.feedback_outlined,
                label: 'Send Feedback',
                onTap: () => _sendFeedback(context),
              ),
              SettingsTile(
                icon: Icons.star_outline_rounded,
                label: 'Rate Flixie',
                onTap: () => _openStoreRating(context),
              ),
              SettingsTile(
                icon: Icons.info_outline,
                label: 'About & Credits',
                onTap: () => context.push('/about-credits'),
                isLast: true,
              ),
              SettingsTile(
                icon: Icons.description_outlined,
                label: 'Terms of Use',
                onTap: () => TermsOfUseScreen.open(context),
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
          const DeleteAccountButton(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        text,
        style: TextStyle(
          color: context.colors.medium,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showSettingsEditDetailsSheet(context);
  }

  Future<void> _openStoreRating(BuildContext context) async {
    final opened = await AppReviewService.openStoreListing();
    if (!context.mounted || opened) return;
    ScaffoldMessenger.of(context).showFlixieToast(
      FlixieToast(
        type: FlixieToastType.info,
        content: const Text(
            'Ratings will be available when Flixie is in the App Store.'),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ChangePasswordSheet(),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: context.colors.background,
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
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FavoriteGenresSheet(
          userId: dbUser.id, currentGenres: dbUser.favoriteGenres ?? []),
    );
  }

  Future<void> _openPrivacyPolicy(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse('https://www.flixie.co.uk/privacy'),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Could not open the privacy policy.'),
        ),
      );
    }
  }

  Future<void> _sendFeedback(BuildContext context) async {
    final uri =
        Uri.parse('mailto:flixieadmin@gmail.com?subject=Flixie%20Feedback');
    try {
      if (await launchUrl(uri)) return;
    } catch (_) {
      // A mail account or email application may not be configured.
    }
    if (!context.mounted) return;
    await showFlixiePromptSheet<void>(
      context: context,
      builder: (context) => FlixiePromptSheetContent(
        title: const Text('Contact Flixie'),
        content: const SelectableText(
          'Could not open an email app. You can copy this address and contact us from your preferred email service:\n\nflixieadmin@gmail.com',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'))
        ],
      ),
    );
  }

  void _showWatchProvidersSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
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
  final Set<String> _unblocking = {};
  String? _error;

  Future<void> _unblock(BlockedUser user) async {
    if (!_unblocking.add(user.id)) return;
    setState(() {
      _error = null;
    });
    try {
      await SafetyService.unblock(user.id);
      if (!mounted) return;
      final users = SafetyService.blockedUsers(refresh: true);
      setState(() {
        _users = users;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not unblock this user. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _unblocking.remove(user.id);
        });
      }
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
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Blocked users cannot contact or interact with you.',
            style: TextStyle(color: context.colors.medium),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BlockedUser>>(
            future: _users,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                  onPressed: () {
                    setState(() {
                      _users = SafetyService.blockedUsers(refresh: true);
                    });
                  },
                  child: const Text('Could not load blocked users. Retry'),
                ));
              }
              final users = snapshot.data ?? const [];
              if (users.isEmpty) {
                return Center(
                  child: Text(
                    'You have not blocked anyone.',
                    style: TextStyle(color: context.colors.medium),
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
                      onPressed: _unblocking.contains(user.id)
                          ? null
                          : () => _unblock(user),
                      child: Text(_unblocking.contains(user.id)
                          ? 'Unblocking…'
                          : 'Unblock'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text(_error!, style: TextStyle(color: context.colors.danger)),
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
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        border: Border.all(
          color: context.colors.tabBarBorder,
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
    return Material(
      clipBehavior: Clip.antiAlias,
      color: context.colors.danger.withValues(alpha: 0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kSettingsCornerRadius),
        side: BorderSide(
          color: context.colors.danger.withValues(alpha: 0.3),
        ),
      ),
      child: ListTile(
        leading: Icon(Icons.logout_rounded, color: context.colors.danger),
        title: Text(
          'Log Out',
          style: TextStyle(
            color: context.colors.danger,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
        onTap: () async {
          final auth = context.read<AuthProvider>();
          await showFlixiePromptSheet<void>(
            context: context,
            isDismissible: false,
            builder: (_) => LogoutSheet(onSignOut: auth.signOut),
          );
        },
      ),
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
  bool _loadingCountries = true;
  bool _countryLoadFailed = false;
  bool _countryChanged = false;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _loadingCountries = true;
      _countryLoadFailed = false;
    });
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
        _loadingCountries = false;
        _countryLoadFailed = countries.isEmpty;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCountries = false;
          _countryLoadFailed = true;
        });
      }
    }
  }

  Future<void> _pickCountry() async {
    final country = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      clipBehavior: Clip.antiAlias,
      useRootNavigator: true,
      useSafeArea: true,
      builder: (context) => ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        child: SingleChildScrollView(
            child: _SettingsCountryPickerSheet(
          countries: _countries,
          selected: _selectedCountry,
        )),
      ),
    );
    if (!mounted || country == null) return;
    setState(() {
      _selectedCountry = country;
      _countryChanged = country.id != widget.user.countryId;
    });
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

      // Only send changed fields - API takes one field at a time
      if (username != widget.user.username) {
        updated = await _settingsController.updateUserField(
            userId, 'username', username);
      }
      if (bio != (widget.user.bio ?? '')) {
        updated = await _settingsController.updateUserField(userId, 'bio', bio);
      }
      if (_countryChanged && _selectedCountry != null) {
        updated = await _settingsController.updateUserField(
            userId, 'countryId', _selectedCountry!.id);
        updated = updated.copyWith(
            countryId: _selectedCountry!.id,
            country: _selectedCountry!.toJson());
      }

      if (!mounted) return;
      auth.updateCachedUser(updated);
      Navigator.pop(context);
      messenger.showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: const Text('Profile updated'),
        backgroundColor: context.colors.surfaceElevated,
      ));
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: Text(error.code == 'USERNAME_NOT_AVAILABLE'
            ? error.message
            : 'Failed to update profile. Please try again.'),
        backgroundColor: context.colors.danger,
      ));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Failed to update profile. Please try again.'),
          backgroundColor: context.colors.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final unchanged = _usernameCtrl.text.trim() == widget.user.username &&
        _bioCtrl.text.trim() == (widget.user.bio ?? '') &&
        !_countryChanged;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: context.colors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit details',
              style: TextStyle(
                  color: context.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Username
            TextField(
              controller: _usernameCtrl,
              style: TextStyle(color: context.colors.white),
              textInputAction: TextInputAction.next,
              autocorrect: false,
              onChanged: (v) {
                setState(() {});
                _onUsernameChanged(v);
              },
              decoration: InputDecoration(
                labelText: 'Username',
                labelStyle: TextStyle(color: context.colors.medium),
                filled: true,
                fillColor: context.colors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                errorText: _usernameError,
                suffixIcon: _checkingUsername
                    ? Padding(
                        padding: const EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: context.colors.medium),
                        ),
                      )
                    : (_usernameError == null &&
                            _usernameCtrl.text.trim() != widget.user.username &&
                            _usernameCtrl.text.trim().length >= 3)
                        ? Icon(Icons.check_circle_outline,
                            color: context.colors.success)
                        : null,
              ),
            ),
            const SizedBox(height: 14),
            // Bio
            TextField(
              controller: _bioCtrl,
              style: TextStyle(color: context.colors.white),
              maxLines: 3,
              maxLength: 200,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: 'Bio',
                labelStyle: TextStyle(color: context.colors.medium),
                filled: true,
                fillColor: context.colors.tabBarBackgroundFocused,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                counterStyle: TextStyle(color: context.colors.medium),
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                tileColor: context.colors.tabBarBackgroundFocused,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                leading: Icon(Icons.location_on_outlined,
                    color: context.colors.light),
                title: Text('Country',
                    style: TextStyle(color: context.colors.white)),
                subtitle: Text(
                  _loadingCountries
                      ? 'Loading countries…'
                      : _countryLoadFailed
                          ? 'Couldn’t load countries. Tap to retry.'
                          : _selectedCountry?.name ??
                              widget.user.country?['name']?.toString() ??
                              'Select your country',
                  style: TextStyle(color: context.colors.light),
                ),
                trailing: _loadingCountries
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(
                        _countryLoadFailed ? Icons.refresh : Icons.expand_more,
                        color: context.colors.light),
                onTap: _loadingCountries || _saving
                    ? null
                    : _countryLoadFailed
                        ? _loadCountries
                        : _pickCountry,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 12, right: 12),
              child: Text('Used to find where you can watch movies and shows.',
                  style: TextStyle(color: context.colors.light, fontSize: 12)),
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
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                  color: context.colors.medium,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Select Country',
              style: TextStyle(
                color: context.colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _searchController,
              onChanged: _onSearch,
              autofocus: true,
              style: TextStyle(color: context.colors.white),
              decoration: InputDecoration(
                hintText: 'Search countries...',
                hintStyle: TextStyle(color: context.colors.medium),
                prefixIcon: Icon(Icons.search, color: context.colors.medium),
                filled: true,
                fillColor: context.colors.tabBarBackgroundFocused,
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
                  return Material(
                    color: Colors.transparent,
                    child: ListTile(
                      title: Text(
                        country.name,
                        style: TextStyle(
                          color: isSelected
                              ? context.colors.primaryTint
                              : context.colors.textPrimary,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_rounded,
                              color: context.colors.primaryTint)
                          : null,
                      onTap: () => Navigator.of(context).pop(country),
                    ),
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

class _EpisodeSpoilerSetting extends StatefulWidget {
  const _EpisodeSpoilerSetting();

  @override
  State<_EpisodeSpoilerSetting> createState() => _EpisodeSpoilerSettingState();
}

class _EpisodeSpoilerSettingState extends State<_EpisodeSpoilerSetting> {
  final preference = EpisodeSpoilerPreference.instance;

  @override
  void initState() {
    super.initState();
    preference.load().catchError((Object _) {});
  }

  Future<void> _change(bool value) async {
    try {
      await preference.setHidden(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
                'Couldn’t save your spoiler preference. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: preference,
        builder: (context, _) => SettingsTile(
          icon: Icons.visibility_off_outlined,
          label: 'Hide episode spoilers',
          onTap: () {
            if (!preference.saving) _change(!preference.hide);
          },
          trailing: Switch.adaptive(
            value: preference.hide,
            onChanged: preference.saving ? null : _change,
          ),
        ),
      );
}
