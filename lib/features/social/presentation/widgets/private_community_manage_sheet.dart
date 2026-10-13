import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../data/private_community_service.dart';

Future<void> showPrivateCommunityManagement(
    BuildContext context, int id, String role,
    {PrivateCommunityService service = const PrivateCommunityService()}) async {
  await showFlixiePromptSheet<void>(
      context: context,
      builder: (ctx) =>
          PrivateCommunityManageSheet(id: id, role: role, service: service));
}

class PrivateCommunityManageSheet extends StatefulWidget {
  const PrivateCommunityManageSheet(
      {super.key,
      required this.id,
      required this.role,
      this.service = const PrivateCommunityService()});
  final int id;
  final String role;
  final PrivateCommunityService service;
  @override
  State<PrivateCommunityManageSheet> createState() =>
      _PrivateCommunityManageSheetState();
}

class _PrivateCommunityManageSheetState
    extends State<PrivateCommunityManageSheet> {
  final _username = TextEditingController();
  List<Map<String, dynamic>> _members = [], _invites = [];
  String? _after, _link, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _username.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() => _busy = true);
    try {
      final data = await widget.service.get('/private/${widget.id}/members',
          {if (more && _after != null) 'after': _after!});
      final invitations =
          await widget.service.get('/private/${widget.id}/invitations');
      if (!mounted) return;
      setState(() {
        final rows = (data['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _members = more ? [..._members, ...rows] : rows;
        _after = data['nextAfter'];
        _invites = (invitations['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Couldn’t load community management. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _invite(bool link) async {
    if (_busy) return;
    if (!link && _username.text.trim().isEmpty) {
      setState(() => _error = 'Enter their Flixie username.');
      return;
    }
    setState(() => _busy = true);
    try {
      final data = await widget.service.post(
          '/private/${widget.id}/invitations',
          link ? {'link': true} : {'username': _username.text.trim()});
      if (!mounted) return;
      if (link) {
        setState(() => _link = data['inviteLink']);
      } else {
        _username.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Invitation added to their private communities.')));
      }
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t create the invitation. Check the username or try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _revoke(String id) async {
    if (_busy) return;
    final yes = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (ctx) => FlixiePromptSheetContent(
                title: const Text('Revoke invitation?'),
                content: const Text(
                    'This invitation will stop working. Existing members stay in the community.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Revoke'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.revoke(widget.id, id);
      if (mounted) {
        setState(() => _link = null);
        await _load();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t revoke this invitation. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _change(Map<String, dynamic> member, String role) async {
    final user =
        FriendshipUser.fromJson(Map<String, dynamic>.from(member['user']));
    final yes = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (ctx) => FlixiePromptSheetContent(
                title: Text(role == 'REMOVE'
                    ? 'Remove ${user.username}?'
                    : role == 'ADMIN'
                        ? 'Make ${user.username} an admin?'
                        : 'Make ${user.username} a member?'),
                content: Text(role == 'REMOVE'
                    ? 'They lose access immediately and will need a new personal invitation to return.'
                    : role == 'MEMBER'
                        ? 'They will lose access to invitations, member management and poll creation. They can still vote and discuss as a member.'
                        : 'Community admins can invite people, remove members and create polls.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirm'))
                ]));
    if (yes != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.service.changeRole(widget.id, user.id, role);
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t change this membership. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Manage community',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            const Text('Invite people',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
                controller: _username,
                enabled: !_busy,
                decoration:
                    const InputDecoration(labelText: 'Flixie username')),
            Wrap(spacing: 12, runSpacing: 8, children: [
              FilledButton(
                  onPressed: _busy ? null : () => _invite(false),
                  child: const Text('Invite member')),
              OutlinedButton.icon(
                  onPressed: _busy ? null : () => _invite(true),
                  icon: const Icon(Icons.link),
                  label: const Text('Create invite link'))
            ]),
            const SizedBox(height: 12),
            const Text(
                'Invitations expire after 7 days. Anyone with a shared link can join until it expires or you revoke it.'),
            if (_link != null) ...[
              const SizedBox(height: 12),
              SelectableText(_link!),
              TextButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: _link!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite link copied.')));
                    }
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy invite link'))
            ],
            if (_error != null)
              TextButton(onPressed: _load, child: Text(_error!)),
            if (_busy) const LinearProgressIndicator(),
            if (_invites.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text('Active invitations',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              for (final invitation in _invites)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(invitation['link'] == true
                        ? 'Shared invite link'
                        : 'Invite for ${invitation['username'] ?? 'Unavailable user'}'),
                    subtitle: Text(
                        'Expires ${MaterialLocalizations.of(context).formatCompactDate(DateTime.parse(invitation['expiresAt']).toLocal())}'),
                    trailing: TextButton(
                        onPressed:
                            _busy ? null : () => _revoke(invitation['id']),
                        child: const Text('Revoke')))
            ],
            const SizedBox(height: 24),
            const Text('Members',
                style: TextStyle(fontWeight: FontWeight.w700)),
            for (final member in _members) _member(member),
            if (_after != null)
              TextButton(
                  onPressed: _busy ? null : () => _load(more: true),
                  child: const Text('Load more members')),
          ]);
  Widget _member(Map<String, dynamic> member) {
    final user =
        FriendshipUser.fromJson(Map<String, dynamic>.from(member['user']));
    return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
                width: 48,
                height: 48,
                child: Center(
                    child: ProfileAvatarView(
                        fallbackColor: Theme.of(context).colorScheme.primary,
                        avatar: user.avatar,
                        profileBadges: user.profileBadges,
                        size: 36,
                        fallbackText:
                            user.username.isEmpty ? '?' : user.username[0]))),
            const SizedBox(width: 12),
            Expanded(
                child: Text('${user.username} · ${member['role']}',
                    style: const TextStyle(fontWeight: FontWeight.w600)))
          ]),
          if (member['role'] != 'OWNER')
            Wrap(spacing: 8, children: [
              if (widget.role == 'OWNER')
                TextButton(
                    onPressed: _busy
                        ? null
                        : () => _change(member,
                            member['role'] == 'ADMIN' ? 'MEMBER' : 'ADMIN'),
                    child: Text(member['role'] == 'ADMIN'
                        ? 'Remove admin role'
                        : 'Make admin')),
              if (widget.role == 'OWNER' || member['role'] == 'MEMBER')
                TextButton(
                    onPressed: _busy ? null : () => _change(member, 'REMOVE'),
                    child: const Text('Remove member'))
            ]),
        ]));
  }
}
