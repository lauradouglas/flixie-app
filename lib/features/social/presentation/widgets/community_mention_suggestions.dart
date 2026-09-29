import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/community_space_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/friendship.dart';

/// Suggestions are opt-in selections; plain @ text never invents recipients.
class CommunityMentionSuggestions extends StatefulWidget {
  const CommunityMentionSuggestions(
      {super.key,
      required this.controller,
      required this.communityId,
      required this.service,
      required this.selected,
      this.additionalController,
      this.discussionId});
  final TextEditingController controller;
  final int communityId;
  final String? discussionId;
  final CommunitySpaceService service;
  final Map<String, String> selected;
  final TextEditingController? additionalController;
  @override
  State<CommunityMentionSuggestions> createState() =>
      _CommunityMentionSuggestionsState();
}

class _CommunityMentionSuggestionsState
    extends State<CommunityMentionSuggestions> {
  Timer? _timer;
  int _revision = 0;
  List<Map<String, dynamic>> _items = [];
  String? _error;
  bool _loading = false;
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  RegExpMatch? _match() {
    final c = widget.controller;
    final end = c.selection.baseOffset;
    if (end < 0 || end > c.text.length) return null;
    return RegExp(r'(?:^|\s)@([A-Za-z0-9_.-]{1,50})$')
        .firstMatch(c.text.substring(0, end));
  }

  void _changed() {
    _timer?.cancel();
    final revision = ++_revision;
    final m = _match();
    setState(() {
      _items = [];
      _error = null;
      _loading = m != null;
    });
    if (m == null) return;
    _timer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final result = await widget.service
            .get(widget.communityId, '/mention-candidates', {
          'q': m.group(1)!,
          if (widget.discussionId != null) 'discussionId': widget.discussionId!
        });
        if (mounted && revision == _revision) {
          setState(() => _items = (result['items'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList());
        }
      } catch (_) {
        if (mounted && revision == _revision) {
          setState(() => _error = 'Couldn’t find people. Tap to retry.');
        }
      } finally {
        if (mounted && revision == _revision) setState(() => _loading = false);
      }
    });
  }

  void _select(Map<String, dynamic> row) {
    final active = activeCommunityMentions(widget.selected,
        '${widget.controller.text} ${widget.additionalController?.text ?? ''}');
    widget.selected.removeWhere((id, _) => !active.contains(id));
    if (widget.selected.length >= 5 &&
        !widget.selected.containsKey(row['id'])) {
      setState(() => _error = 'Mention up to five people per post.');
      return;
    }
    final m = _match();
    if (m == null) return;
    final c = widget.controller, end = c.selection.baseOffset;
    final start = end - m.group(1)!.length - 1;
    final text = '@${row['username']} ';
    widget.selected[row['id']] = row['username'];
    c.value = TextEditingValue(
        text: c.text.replaceRange(start, end, text),
        selection: TextSelection.collapsed(offset: start + text.length));
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_loading)
          const Padding(
              padding: EdgeInsets.all(8), child: Text('Finding people…')),
        if (_error != null)
          TextButton(onPressed: _changed, child: Text(_error!)),
        for (final row in _items)
          Builder(builder: (context) {
            final user = FriendshipUser.fromJson(row);
            return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Padding(
                    padding: const EdgeInsets.all(4),
                    child: ProfileAvatarView(
                        avatar: user.avatar,
                        fallbackColor: Theme.of(context).colorScheme.primary,
                        profileBadges: user.profileBadges,
                        size: 30,
                        fallbackText:
                            user.username.isEmpty ? '?' : user.username[0])),
                title: Text('@${user.username}'),
                onTap: () => _select(row));
          }),
        if (!_loading && _error == null && _match() != null && _items.isEmpty)
          const Text('No matching members or friends.'),
      ]);
}

List<String> activeCommunityMentions(
        Map<String, String> selected, String text) =>
    selected.entries
        .where((entry) => RegExp(
                '(^|\\s)@${RegExp.escape(entry.value)}(?=\$|[\\s.,!?;:])',
                caseSensitive: false)
            .hasMatch(text))
        .map((entry) => entry.key)
        .toList();
