import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/country.dart';
import 'package:flixie_app/models/user.dart' as user_model;
import '../controllers/settings_controller.dart';
import '../controllers/settings_username_check.dart';
import '../../data/reference_data_service.dart';
import 'settings_country_picker_sheet.dart';

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
      child: SingleChildScrollView(child: SettingsEditProfileSheet(user: user)),
    ),
  );
}

class SettingsEditProfileSheet extends StatefulWidget {
  const SettingsEditProfileSheet({super.key, required this.user});
  final user_model.User user;

  @override
  State<SettingsEditProfileSheet> createState() =>
      SettingsEditProfileSheetState();
}

class SettingsEditProfileSheetState extends State<SettingsEditProfileSheet> {
  final SettingsController _settingsController = SettingsController.instance;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;

  bool _saving = false;
  late final SettingsUsernameCheck _usernameCheck;
  bool get _checkingUsername => _usernameCheck.checking;
  String? get _usernameError => _usernameCheck.error;

  void _refreshUsername() {
    if (mounted) setState(() {});
  }

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
    _usernameCheck = SettingsUsernameCheck(
      original: widget.user.username,
      exists: _settingsController.usernameExists,
    )..addListener(_refreshUsername);
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
            child: SettingsCountryPickerSheet(
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
    _usernameCheck.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) => _usernameCheck.update(value);

  Future<void> _save() async {
    final username = _usernameCtrl.text.trim();
    final bio = _bioCtrl.text.trim();
    if (_saving || _usernameError != null || _checkingUsername) return;
    if (username.isEmpty) {
      _usernameCheck.update(username);
      return;
    }
    final auth = context.read<AuthProvider>();
    if (auth.dbUser?.id != widget.user.id) return;
    bool ownsAccount() => mounted && auth.dbUser?.id == widget.user.id;
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
      if (!ownsAccount()) return;
      if (bio != (widget.user.bio ?? '')) {
        updated = await _settingsController.updateUserField(userId, 'bio', bio);
      }
      if (!ownsAccount()) return;
      if (_countryChanged && _selectedCountry != null) {
        updated = await _settingsController.updateUserField(
            userId, 'countryId', _selectedCountry!.id);
        updated = updated.copyWith(
            countryId: _selectedCountry!.id,
            country: _selectedCountry!.toJson());
      }

      if (!mounted || !ownsAccount()) return;
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
                      ? (_selectedCountry?.name ??
                          widget.user.country?['name']?.toString() ??
                          'Select your country')
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
