import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/genre.dart';
import '../models/icon_color.dart';
import '../models/user.dart' as user_model;
import '../providers/auth_provider.dart';
import '../services/reference_data_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        elevation: 0,
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('Account'),
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Edit Profile',
            onTap: () => _showEditProfileSheet(context),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.lock_outline,
            label: 'Change Password',
            onTap: () => _showChangePasswordSheet(context),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.movie_filter_outlined,
            label: 'Favourite Genres',
            onTap: () => _showFavoriteGenresSheet(context),
          ),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.palette_outlined,
            label: 'Avatar Colour',
            onTap: () => _showIconColorSheet(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: FlixieColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
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
      builder: (_) => _EditProfileSheet(user: dbUser),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePasswordSheet(),
    );
  }

  void _showFavoriteGenresSheet(BuildContext context) {
    final dbUser = context.read<AuthProvider>().dbUser;
    if (dbUser == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FavoriteGenresSheet(
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
      builder: (_) => _IconColorSheet(
        userId: dbUser.id,
        currentColorId: dbUser.iconColorId,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Settings list tile
// ---------------------------------------------------------------------------

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: FlixieColors.primary),
        title: Text(
          label,
          style: const TextStyle(color: FlixieColors.light, fontSize: 15),
        ),
        trailing: const Icon(Icons.chevron_right, color: FlixieColors.medium),
        onTap: onTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Change password bottom sheet
// ---------------------------------------------------------------------------

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _currentObscure = true;
  bool _newObscure = true;
  bool _confirmObscure = true;
  bool _saving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final error = await context
        .read<AuthProvider>()
        .updatePassword(_currentCtrl.text, _newCtrl.text);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Password updated successfully.'),
        backgroundColor: FlixieColors.success,
      ),
    );
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
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
                'Change Password',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              _PasswordField(
                controller: _currentCtrl,
                label: 'Current password',
                obscure: _currentObscure,
                onToggle: () =>
                    setState(() => _currentObscure = !_currentObscure),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _newCtrl,
                label: 'New password',
                obscure: _newObscure,
                onToggle: () => setState(() => _newObscure = !_newObscure),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Minimum 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              _PasswordField(
                controller: _confirmCtrl,
                label: 'Confirm new password',
                obscure: _confirmObscure,
                onToggle: () =>
                    setState(() => _confirmObscure = !_confirmObscure),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v != _newCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style:
                      const TextStyle(color: FlixieColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Update Password',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  final TextEditingController controller;
  final String label;
  final bool obscure;
  final VoidCallback onToggle;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: FlixieColors.medium),
        filled: true,
        fillColor: FlixieColors.tabBarBorder,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: FlixieColors.medium,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Favourite genres bottom sheet
// ---------------------------------------------------------------------------

class _FavoriteGenresSheet extends StatefulWidget {
  const _FavoriteGenresSheet({
    required this.userId,
    required this.currentGenres,
  });

  final String userId;
  final List<dynamic> currentGenres;

  @override
  State<_FavoriteGenresSheet> createState() => _FavoriteGenresSheetState();
}

class _FavoriteGenresSheetState extends State<_FavoriteGenresSheet> {
  List<Genre> _allGenres = [];
  late Set<int> _selectedIds;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Populate current selections from the user's existing favoriteGenres
    _selectedIds = widget.currentGenres.map<int>((item) {
      if (item is Map<String, dynamic>) {
        final nested = item['genre'];
        if (nested is Map<String, dynamic>) return nested['id'] as int;
        return (item['id'] ?? item['genreId']) as int;
      }
      return item as int;
    }).toSet();
    _loadGenres();
  }

  Future<void> _loadGenres() async {
    try {
      final genres = await ReferenceDataService.getGenres();
      if (mounted)
        setState(() {
          _allGenres = genres;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await UserService.addFavoriteGenres(widget.userId, _selectedIds.toList());
      if (!mounted) return;
      await context.read<AuthProvider>().refreshUserData();
      if (!mounted) return;
      // Capture messenger before pop — context is deactivated after pop()
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Favourite genres updated.'),
          backgroundColor: FlixieColors.success,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to save genres. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
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
            // Handle bar
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
              'Favourite Genres',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Select the genres you enjoy most.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: FlixieColors.primary))
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _allGenres.map((genre) {
                      final selected = _selectedIds.contains(genre.id);
                      return GestureDetector(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedIds.remove(genre.id);
                          } else {
                            _selectedIds.add(genre.id);
                          }
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? FlixieColors.primary.withValues(alpha: 0.2)
                                : FlixieColors.tabBarBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: selected
                                  ? FlixieColors.primary
                                  : FlixieColors.tabBarBorder,
                              width: selected ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (selected) ...[
                                const Icon(Icons.check_rounded,
                                    size: 14, color: FlixieColors.primary),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                genre.name,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selected
                                      ? FlixieColors.primary
                                      : FlixieColors.light,
                                  fontWeight: selected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Avatar colour bottom sheet
// ---------------------------------------------------------------------------

class _IconColorSheet extends StatefulWidget {
  const _IconColorSheet({
    required this.userId,
    required this.currentColorId,
  });

  final String userId;
  final int currentColorId;

  @override
  State<_IconColorSheet> createState() => _IconColorSheetState();
}

class _IconColorSheetState extends State<_IconColorSheet> {
  List<IconColor> _colors = [];
  late int _selectedId;
  bool _loading = true;
  int? _savingId; // id currently being saved, disables all others

  @override
  void initState() {
    super.initState();
    _selectedId = widget.currentColorId;
    _loadColors();
  }

  Future<void> _loadColors() async {
    try {
      final colors = await ReferenceDataService.getColors();
      if (mounted)
        setState(() {
          _colors = colors;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _select(IconColor color) async {
    if (_savingId != null || color.id == _selectedId) return;
    // Capture context-dependent objects before any await
    final auth = context.read<AuthProvider>();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _savingId = color.id);
    try {
      final updatedUser =
          await UserService.updateIconColor(widget.userId, color.id);
      if (!mounted) return;
      auth.updateCachedUser(updatedUser);
      setState(() {
        _selectedId = color.id;
        _savingId = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _savingId = null);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Failed to update colour. Please try again.'),
          backgroundColor: FlixieColors.danger,
        ),
      );
    }
  }

  Color _parseHex(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value =
        int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return Color(value ?? 0xFFFFFFFF);
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
            // Handle
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
              'Avatar Colour',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap a colour to apply it to your avatar.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 13),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                  child: CircularProgressIndicator(color: FlixieColors.primary))
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _colors.map((c) {
                  final isSelected = c.id == _selectedId;
                  final isSaving = _savingId == c.id;
                  final isDisabled = _savingId != null && !isSaving;
                  final circleColor = _parseHex(c.hexCode);

                  return GestureDetector(
                    onTap: isDisabled ? null : () => _select(c),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: isDisabled ? 0.35 : 1.0,
                      child: SizedBox(
                        width: 46,
                        height: 46,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Colour circle
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: circleColor,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(
                                        color: Colors.white, width: 2.5)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: circleColor.withValues(
                                              alpha: 0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                            // Spinner while saving this colour
                            if (isSaving)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            // Check mark when selected
                            else if (isSelected)
                              const Icon(Icons.check_rounded,
                                  size: 18, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Edit profile (username & bio) bottom sheet
// ---------------------------------------------------------------------------

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});
  final user_model.User user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _bioCtrl;

  bool _saving = false;
  bool _checkingUsername = false;
  String? _usernameError;
  DateTime? _lastCheck;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.user.username);
    _bioCtrl = TextEditingController(text: widget.user.bio ?? '');
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
      final exists = await UserService.usernameExists(trimmed);
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
        updated = await UserService.updateUserField(userId, 'username', username);
      }
      if (bio != (widget.user.bio ?? '')) {
        updated = await UserService.updateUserField(userId, 'bio', bio);
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
        _bioCtrl.text.trim() == (widget.user.bio ?? '');

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
                            _usernameCtrl.text.trim() !=
                                widget.user.username &&
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
