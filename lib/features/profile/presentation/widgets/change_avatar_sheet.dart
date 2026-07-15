import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
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
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedId = context.read<AuthProvider>().dbUser?.avatar?.id;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final avatars = await AvatarService.getAvatars();
      if (mounted) setState(() => _avatars = avatars);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load avatars.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_selectedId == null) return;
    setState(() => _saving = true);
    try {
      final avatar = await AvatarService.selectAvatar(_selectedId!);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      final user = auth.dbUser;
      if (user != null) auth.updateCachedUser(user.copyWith(avatar: avatar));
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile avatar updated'),
        backgroundColor: FlixieColors.success,
      ));
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to update avatar.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text('Change avatar',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: AvatarPicker(
                    avatars: _avatars,
                    selectedId: _selectedId,
                    loading: _loading,
                    error: _error,
                    onRetry: _load,
                    onSelected: (avatar) =>
                        setState(() => _selectedId = avatar.id),
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || _selectedId == null ? null : _save,
                  child: _saving
                      ? const CircularProgressIndicator()
                      : const Text('Save avatar'),
                ),
              ),
            ],
          ),
        ),
      );
}
