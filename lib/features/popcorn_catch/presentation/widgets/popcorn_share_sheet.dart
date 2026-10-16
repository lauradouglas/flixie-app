import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/friendship.dart';
import '../../data/popcorn_service.dart';
import '../../models/popcorn_challenge.dart';
import 'popcorn_arena.dart';

Future<void> showPopcornShareSheet(BuildContext context,
        {required String roundId,
        required String userId,
        required PopcornService service,
        required bool Function() isCurrent,
        Future<List<FriendshipUser>> Function()? loadFriends}) =>
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (ctx) => SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .78,
            child: _Composer(
                roundId: roundId,
                userId: userId,
                service: service,
                isCurrent: isCurrent,
                loadFriends: loadFriends)));

class _Composer extends StatefulWidget {
  const _Composer(
      {required this.roundId,
      required this.userId,
      required this.service,
      required this.isCurrent,
      this.loadFriends});
  final String roundId, userId;
  final PopcornService service;
  final bool Function() isCurrent;
  final Future<List<FriendshipUser>> Function()? loadFriends;
  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  List<FriendshipUser>? friends;
  FriendshipUser? selected;
  String query = '';
  String? error;
  bool sending = false;
  String requestKey = popcornRequestKey();
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = widget.loadFriends != null
          ? await widget.loadFriends!()
          : (await FriendService.getFriends(widget.userId))
              .friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .toList();
      if (mounted && widget.isCurrent()) {
        setState(() => friends = loaded);
      }
    } catch (_) {
      if (mounted) setState(() => error = 'Friends couldn’t load. Try again.');
    }
  }

  Future<void> _send() async {
    if (selected == null || sending || !widget.isCurrent()) return;
    setState(() {
      sending = true;
      error = null;
    });
    try {
      await widget.service.share(widget.roundId, selected!.id, requestKey);
      if (!mounted || !widget.isCurrent()) return;
      final id = selected!.id;
      final router = GoRouter.of(context);
      Navigator.pop(context);
      router.push('/chat/$id');
    } catch (_) {
      if (mounted) {
        setState(() => error =
            'Challenge wasn’t sent. Try again; retries won’t duplicate it.');
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = friends
        ?.where((f) => f.username.toLowerCase().contains(query.toLowerCase()))
        .toList();
    return Padding(
        padding: EdgeInsets.fromLTRB(
            20, 8, 20, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Challenge a friend',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'Send your verified score in chat. Your friend gets one first attempt.'),
          const SizedBox(height: 16),
          TextField(
              enabled: !sending,
              onChanged: (v) => setState(() => query = v),
              decoration: const InputDecoration(
                  hintText: 'Search friends', prefixIcon: Icon(Icons.search))),
          const SizedBox(height: 12),
          Expanded(
              child: friends == null
                  ? Center(
                      child: error == null
                          ? const CircularProgressIndicator()
                          : TextButton(
                              onPressed: _load,
                              child: const Text('Retry loading friends')))
                  : visible!.isEmpty
                      ? const Center(
                          child: Text(
                              'No friends to show. Add friends in Social to challenge them.'))
                      : ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (ctx, i) {
                            final f = visible[i];
                            return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    vertical: 6, horizontal: 2),
                                leading: SizedBox(
                                    width: 52,
                                    height: 52,
                                    child: Center(
                                        child: ProfileAvatarView(
                                            avatar: f.avatar,
                                            profileBadges: f.profileBadges,
                                            fallbackText: f.username.isEmpty
                                                ? '?'
                                                : f.username[0].toUpperCase(),
                                            size: 36,
                                            fallbackColor:
                                                const Color(0xFF8244E9)))),
                                title: Text(f.username),
                                trailing: Icon(selected?.id == f.id
                                    ? Icons.check_circle
                                    : Icons.radio_button_unchecked),
                                onTap: sending
                                    ? null
                                    : () => setState(() {
                                          if (selected?.id != f.id) {
                                            requestKey = popcornRequestKey();
                                          }
                                          selected = f;
                                        }));
                          })),
          if (error != null)
            Text(error!, style: const TextStyle(color: Color(0xFFFFC7B7))),
          SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: selected == null || sending ? null : _send,
                  style: FilledButton.styleFrom(
                      backgroundColor: popcornGold,
                      foregroundColor: const Color(0xFF28143D),
                      minimumSize: const Size(0, 52)),
                  child: Text(sending
                      ? 'Sending…'
                      : selected == null
                          ? 'Choose a friend'
                          : 'Challenge ${selected!.username}'))),
        ]));
  }
}
