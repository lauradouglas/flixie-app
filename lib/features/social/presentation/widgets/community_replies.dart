import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import '../../data/community_service.dart';
import '../../data/friend_activity_service.dart';

class CommunityReplies extends StatefulWidget {
  const CommunityReplies(
      {super.key, required this.item, required this.service, this.parent});
  final ActivityListItem item;
  final CommunityService service;
  final String? parent;
  @override
  State<CommunityReplies> createState() => _CommunityRepliesState();
}

class _CommunityRepliesState extends State<CommunityReplies>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  void _blocked() {
    if (mounted) {
      setState(() =>
          _items.removeWhere((r) => SafetyService.isBlocked(r.author.id)));
    }
  }

  final _draft = TextEditingController();
  final _items = <CommunityReply>[];
  final _revealed = <String>{}, _threads = <String>{};
  String? _cursor, _error;
  String _draftId = FriendActivityService.newCommentId();
  bool _loading = true, _sending = false, _spoilers = false, _enabled = true;
  @override
  void initState() {
    super.initState();
    _load();
    SafetyService.changes.addListener(_blocked);
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_blocked);
    _draft.dispose();
    super.dispose();
  }

  Future<void> _load({bool more = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.service.replies(widget.item,
          cursor: more ? _cursor : null, parent: widget.parent);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        final ids = _items.map((e) => e.id).toSet();
        _items.addAll((data['items'] as List)
            .map((e) => CommunityReply(Map<String, dynamic>.from(e)))
            .where(
                (e) => !SafetyService.isBlocked(e.author.id) && ids.add(e.id)));
        _cursor = data['nextCursor'] as String?;
        _enabled = data['repliesEnabled'] != false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load replies.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_sending || _draft.text.trim().isEmpty) return;
    setState(() => _sending = true);
    try {
      await widget.service.reply(widget.item,
          id: _draftId,
          body: _draft.text.trim(),
          spoilers: _spoilers,
          parent: widget.parent);
      if (!mounted) return;
      _draft.clear();
      _draftId = FriendActivityService.newCommentId();
      _spoilers = false;
      FocusScope.of(context).unfocus();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Couldn’t post. Your draft is still here. Replies may have been turned off.')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(CommunityReply reply) async {
    try {
      await widget.service.deleteReply(widget.item, reply.id);
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t delete this reply.')));
      }
    }
  }

  Future<void> _settings(bool value) async {
    try {
      await widget.service.setReplies(widget.item, value);
      if (mounted) setState(() => _enabled = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t change replies.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final me = context.read<AuthProvider?>()?.dbUser?.id;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.parent == null) ...[
        const SizedBox(height: 24),
        Text('Community replies',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Public replies. Mark spoilers before posting.'),
        if (me == widget.item.userId)
          SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow replies'),
              value: _enabled,
              onChanged: _settings),
      ],
      if (_loading) const LinearProgressIndicator(),
      if (_error != null)
        TextButton(onPressed: _load, child: Text('$_error Retry')),
      if (!_loading && _error == null && _items.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(widget.parent == null
                ? 'No replies yet. Start the conversation.'
                : 'No replies in this thread yet.')),
      for (final reply in _items)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                        child: ProfileAvatarView(
                            avatar: reply.author.avatar,
                            profileBadges: reply.author.profileBadges,
                            size: 32,
                            fallbackText: reply.author.username.isEmpty
                                ? '?'
                                : reply.author.username[0],
                            fallbackColor:
                                Theme.of(context).colorScheme.primary))),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(reply.author.username,
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                if (!reply.deleted)
                  IconButton(
                      tooltip: me == reply.author.id
                          ? 'Delete reply'
                          : 'Report or block reply',
                      icon: Icon(me == reply.author.id
                          ? Icons.delete_outline
                          : Icons.more_horiz),
                      onPressed: () => me == reply.author.id
                          ? _delete(reply)
                          : SafetyActions.contentMenu(context,
                              targetType: 'COMMUNITY_REPLY',
                              targetId: reply.id,
                              reportedUserId: reply.author.id,
                              username: reply.author.username,
                              contentPreview: reply.body)),
              ]),
              if (reply.spoilers && !_revealed.contains(reply.id))
                TextButton(
                    onPressed: () => setState(() => _revealed.add(reply.id)),
                    child: const Text('Show reply · contains spoilers'))
              else
                Text(reply.body, style: const TextStyle(height: 1.5)),
              if (widget.parent == null) ...[
                TextButton(
                    onPressed: () => setState(() => _threads.contains(reply.id)
                        ? _threads.remove(reply.id)
                        : _threads.add(reply.id)),
                    child: Text(_threads.contains(reply.id)
                        ? 'Hide thread'
                        : 'View thread / reply')),
                if (_threads.contains(reply.id))
                  Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: CommunityReplies(
                          item: widget.item,
                          service: widget.service,
                          parent: reply.id)),
              ]
            ])),
      if (_cursor != null)
        TextButton(
            onPressed: _loading ? null : () => _load(more: true),
            child: const Text('More replies')),
      if (!_loading && _error == null) ...[
        if (!_enabled)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('The author has turned off replies.'))
        else ...[
          FilterChip(
              label: const Text('Contains spoilers'),
              selected: _spoilers,
              onSelected: _sending
                  ? null
                  : (v) => setState(() {
                        _spoilers = v;
                        _draftId = FriendActivityService.newCommentId();
                      })),
          const SizedBox(height: 8),
          TextField(
              controller: _draft,
              enabled: !_sending,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => setState(() {
                    _draftId = FriendActivityService.newCommentId();
                  }),
              decoration: InputDecoration(
                  hintText: widget.parent == null
                      ? 'Write a public reply…'
                      : 'Reply to this thread…',
                  border: const OutlineInputBorder())),
          Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                  onPressed:
                      _sending || _draft.text.trim().isEmpty ? null : _send,
                  icon: const Icon(Icons.send_outlined),
                  label: Text(_sending ? 'Posting…' : 'Post reply')))
        ]
      ]
    ]);
  }
}
