import 'package:flixie_app/core/widgets/flixie_editor_sheet.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
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
  if (!await GuestAccess.require(context,
      title: 'Remember your streaming preferences', intent: 'providers')) {
    return;
  }
  if (!context.mounted) return;
  final user = context.read<AuthProvider>().dbUser;
  if (user == null) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    backgroundColor: context.colors.surface,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    clipBehavior: Clip.antiAlias,
    builder: (context) => SettingsEditProfileSheet(user: user),
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
  String? _saveError, _serverUsernameError;
  late String _savedUsername = widget.user.username;
  late String _savedBio = widget.user.bio ?? '';
  late int? _savedCountry = widget.user.countryId;
  late final SettingsUsernameCheck _usernameCheck;
  bool get _checkingUsername => _usernameCheck.checking;
  String? get _usernameError => _serverUsernameError ?? _usernameCheck.error;

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
      _countryChanged = country.id != _savedCountry;
    });
  }

  @override
  void dispose() {
    _usernameCheck.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _serverUsernameError = null;
    _usernameCheck.update(value);
  }

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
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _saveError = null;
    });

    try {
      final userId = widget.user.id;
      if (username != _savedUsername) {
        await _settingsController.updateUserField(userId, 'username', username);
        if (!mounted || !ownsAccount()) return;
        _savedUsername = username;
        auth.updateCachedUser(auth.dbUser!.copyWith(username: username));
      }
      if (bio != _savedBio) {
        await _settingsController.updateUserField(userId, 'bio', bio);
        if (!mounted || !ownsAccount()) return;
        _savedBio = bio;
        auth.updateCachedUser(auth.dbUser!.copyWith(bio: bio));
      }
      if (_countryChanged && _selectedCountry != null) {
        await _settingsController.updateUserField(
            userId, 'countryId', _selectedCountry!.id);
        if (!mounted || !ownsAccount()) return;
        _savedCountry = _selectedCountry!.id;
        _countryChanged = false;
        auth.updateCachedUser(auth.dbUser!.copyWith(
            countryId: _savedCountry, country: _selectedCountry!.toJson()));
      }
      if (!mounted || !ownsAccount()) return;
      Navigator.pop(context);
      messenger.showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: const Text('Profile updated'),
        backgroundColor: context.colors.surfaceElevated,
      ));
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          if (error.code == 'USERNAME_NOT_AVAILABLE') {
            _serverUsernameError = error.message;
          } else {
            _saveError =
                'Couldn’t save all changes. Your edits are still here. Retry saves only the remaining changes.';
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError =
              'Couldn’t save all changes. Your edits are still here. Retry saves only the remaining changes.';
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unchanged = _usernameCtrl.text.trim() == _savedUsername &&
        _bioCtrl.text.trim() == _savedBio &&
        !_countryChanged;

    return FlixieEditorSheet(
        title: 'Edit details',
        dirty: !unchanged,
        busy: _saving,
        onSave: _checkingUsername || _usernameError != null ? null : _save,
        error: _saveError,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              leading:
                  Icon(Icons.location_on_outlined, color: context.colors.light),
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
                  : Icon(_countryLoadFailed ? Icons.refresh : Icons.expand_more,
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
        ]));
  }
}
