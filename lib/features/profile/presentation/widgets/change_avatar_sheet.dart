import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/widgets/flixie_editor_sheet.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/data/avatar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:flixie_app/models/profile_avatar.dart';

class ChangeAvatarSheet extends StatefulWidget {
  const ChangeAvatarSheet({super.key});
  @override
  State<ChangeAvatarSheet> createState() => _ChangeAvatarSheetState();
}

class _ChangeAvatarSheetState extends State<ChangeAvatarSheet> {
  List<ProfileAvatar> _avatars = const [];
  int? _selectedId;
  bool _loading = true, _saving = false;
  String? _loadError, _saveError;
  late final AuthProvider _auth;
  late final String? _viewer;
  late final ProfileAvatar? _original;
  bool get _active => mounted && _auth.dbUser?.id == _viewer && _viewer != null;
  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _viewer = _auth.dbUser?.id;
    _original = _auth.dbUser?.avatar;
    _selectedId = _original?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final avatars = await AvatarService.getAvatars();
      if (_active) setState(() => _avatars = avatars);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Unable to load avatars.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving || _selectedId == null || !_active) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final auth = _auth, viewer = _viewer, original = _original;
    try {
      final avatar = await AvatarService.selectAvatar(_selectedId!);
      if (!mounted || !_active) return;
      auth.updateCachedUser(auth.dbUser!.copyWith(avatar: avatar));
      Navigator.pop(context);
      var undoing = false;
      Future<void> undo() async {
        if (undoing ||
            auth.dbUser?.id != viewer ||
            auth.dbUser?.avatar?.id != avatar.id) {
          return;
        }
        undoing = true;
        try {
          if (original == null) {
            await AvatarService.removeAvatar();
          } else {
            await AvatarService.selectAvatar(original.id);
          }
          if (auth.dbUser?.id != viewer ||
              auth.dbUser?.avatar?.id != avatar.id) {
            return;
          }
          auth.updateCachedUser(auth.dbUser!
              .copyWith(avatar: original, clearAvatar: original == null));
          if (messenger.mounted) {
            messenger.showSnackBar(
                const SnackBar(content: Text('Previous avatar restored')));
          }
        } catch (_) {
          if (messenger.mounted && auth.dbUser?.id == viewer) {
            messenger.showSnackBar(SnackBar(
                content: const Text('Couldn’t restore your avatar.'),
                action: SnackBarAction(label: 'Retry', onPressed: undo)));
          }
        } finally {
          undoing = false;
        }
      }

      messenger.showSnackBar(SnackBar(
          content: const Text('Profile avatar updated'),
          action: original?.id == avatar.id
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo)));
    } catch (_) {
      if (mounted) {
        setState(() => _saveError =
            'Couldn’t save your avatar. Your selection is still here.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => FlixieEditorSheet(
      title: 'Change avatar',
      dirty: _selectedId != _original?.id,
      busy: _saving,
      saveLabel: 'Save avatar',
      onSave:
          _loading || _selectedId == null || _loadError != null ? null : _save,
      error: _saveError,
      child: AvatarPicker(
          avatars: _avatars,
          profileBadges: _auth.dbUser?.profileBadges ?? const [],
          selectedId: _selectedId,
          loading: _loading,
          error: _loadError,
          onRetry: _load,
          onSelected: (avatar) => setState(() {
                _selectedId = avatar.id;
                _saveError = null;
              })));
}
