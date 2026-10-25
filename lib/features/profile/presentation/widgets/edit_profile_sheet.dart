import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_editor_sheet.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';

class EditProfileSheet extends StatefulWidget {
  const EditProfileSheet(
      {super.key, required this.currentUsername, required this.currentBio});
  final String currentUsername;
  final String? currentBio;
  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  late final _usernameController =
      TextEditingController(text: widget.currentUsername)
        ..addListener(_changed);
  late final _bioController =
      TextEditingController(text: widget.currentBio ?? '')
        ..addListener(_changed);
  late final _auth = context.read<AuthProvider>();
  late final _viewer = _auth.dbUser?.id;
  late String _savedUsername = widget.currentUsername,
      _savedBio = widget.currentBio ?? '';
  bool _saving = false;
  String? _error, _usernameError;
  bool get _active => mounted && _auth.dbUser?.id == _viewer && _viewer != null;
  bool get _dirty =>
      _usernameController.text.trim() != _savedUsername ||
      _bioController.text.trim() != _savedBio;
  @override
  void initState() {
    super.initState();
    _viewer;
  }

  void _changed() {
    if (mounted) {
      setState(() {
        _usernameError = null;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_active) {
      setState(
          () => _error = 'Your account changed. Close and reopen this editor.');
      return;
    }
    final username = _usernameController.text.trim(),
        bio = _bioController.text.trim();
    if (username.isEmpty ||
        (username != _savedUsername && username.length < 3)) {
      setState(() => _usernameError = 'Use at least 3 characters.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
      _usernameError = null;
    });
    try {
      if (username != _savedUsername) {
        final result =
            await UserService.updateUserField(_viewer!, 'username', username);
        if (!mounted || !_active) return;
        _savedUsername = result.username.isEmpty ? username : result.username;
        _auth.updateDbUser(_auth.dbUser!.copyWith(username: _savedUsername));
      }
      if (bio != _savedBio) {
        await UserService.updateUserField(_viewer!, 'bio', bio);
        if (!mounted || !_active) return;
        _savedBio = bio;
        _auth.updateDbUser(_auth.dbUser!.copyWith(bio: bio));
      }
      if (mounted && _active) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is ApiException && error.code == 'USERNAME_NOT_AVAILABLE') {
            _usernameError = error.message;
          } else {
            _error =
                'Couldn’t save all changes. Your edits are still here. Retry saves only the remaining changes.';
          }
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlixieEditorSheet(
      title: 'Edit profile',
      dirty: _dirty,
      busy: _saving,
      onSave: _save,
      error: _error,
      child: Column(children: [
        TextField(
            controller: _usernameController,
            decoration: InputDecoration(
                labelText: 'Username',
                errorText: _usernameError,
                prefixIcon: const Icon(Icons.alternate_email)),
            textInputAction: TextInputAction.next),
        const SizedBox(height: 16),
        TextField(
            controller: _bioController,
            decoration: const InputDecoration(labelText: 'Bio'),
            minLines: 3,
            maxLines: 6,
            maxLength: 500),
      ]));
}
