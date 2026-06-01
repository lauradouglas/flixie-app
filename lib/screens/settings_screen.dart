import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/country.dart';
import '../models/user.dart' as user_model;
import '../presentation/shared/settings_controller.dart';
import '../providers/auth_provider.dart';
import '../services/reference_data_service.dart';
import '../theme/app_theme.dart';
import '../widgets/flixie_page.dart';
import 'settings/change_password_sheet.dart';
import 'settings/constants.dart';
import 'settings/favorite_genres_sheet.dart';
import 'settings/icon_color_sheet.dart';
import 'settings/settings_tile.dart';

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
                icon: Icons.lock_outline,
                label: 'Change Password',
                onTap: () => _showChangePasswordSheet(context),
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
          _sectionLabel('Preferences'),
          _SettingsGroup(
            children: [
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
                label: 'About Flixie',
                onTap: () => _showAboutDialog(context),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const _LogOutButton(),
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

  Future<void> _sendFeedback() async {
    final uri =
        Uri.parse('mailto:support@flixie.app?subject=Flixie%20Feedback');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Flixie',
      applicationVersion: '1.0.1',
      applicationLegalese: '© 2024 Flixie',
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
        updated =
            await _settingsController.updateUserField(userId, 'username', username);
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Failed to update profile. Please try again.'),
        backgroundColor: FlixieColors.danger,
      ));
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
        color: Color(0xFF1B3258),
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 16),
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
  const _SettingsCountryPickerSheet(
      {required this.countries, this.selected});

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
        color: Color(0xFF1B3258),
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
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.normal,
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
