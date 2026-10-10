import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import '../../models/chat_share_media.dart';
import '../media_share_session.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class FriendShareComposer extends StatefulWidget {
  const FriendShareComposer(
      {super.key,
      required this.movie,
      required this.friends,
      required this.session});
  final ChatShareMedia movie;
  final List<Friendship> friends;
  final MediaShareSession session;
  @override
  State<FriendShareComposer> createState() => _FriendShareComposerState();
}

class _FriendShareComposerState extends State<FriendShareComposer> {
  late String selectedFriendId = widget.friends.first.friendUser!.id;
  final messageController =
      TextEditingController(text: 'You should watch this.');
  bool sending = false;
  ChatShareMedia get movie => widget.movie;
  List<Friendship> get friends => widget.friends;
  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: widget.session,
      builder: (context, _) {
        if (!widget.session.isCurrent) {
          return const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Account changed. Close this sheet to continue.'));
        }
        final selectedFriend = friends.firstWhere(
          (friendship) => friendship.friendUser?.id == selectedFriendId,
          orElse: () => friends.first,
        );
        final friendUser = selectedFriend.friendUser;

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.medium.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Share to friend',
                style: TextStyle(
                  color: context.colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                movie.title,
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Choose a friend',
                style: TextStyle(
                  color: context.colors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 228),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, index) {
                    final friendship = friends[index];
                    final friend = friendship.friendUser;
                    if (friend == null) return const SizedBox.shrink();
                    final isSelected = friend.id == selectedFriendId;
                    final avatar = friend.avatar;
                    final initials = friend.initials ??
                        (friend.username.isNotEmpty
                            ? friend.username[0].toUpperCase()
                            : '?');

                    return InkWell(
                      onTap: sending
                          ? null
                          : () => setState(() => selectedFriendId = friend.id),
                      borderRadius: BorderRadius.circular(14),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? FlixieColors.primary.withValues(alpha: 0.14)
                              : context.colors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? FlixieColors.primary.withValues(alpha: 0.45)
                                : context.colors.tabBarBorder,
                          ),
                        ),
                        child: Row(
                          children: [
                            ProfileAvatarView(
                              avatar: avatar,
                              profileBadges: friend.profileBadges,
                              fallbackText: initials,
                              fallbackColor: FlixieColors.primary,
                              size: 34,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                friend.displayName,
                                style: TextStyle(
                                  color: context.colors.light,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: FlixieColors.primary,
                                size: 20,
                              )
                            else
                              Icon(
                                Icons.radio_button_unchecked_rounded,
                                color: context.colors.medium,
                                size: 20,
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                minLines: 2,
                maxLines: 3,
                enabled: !sending,
                style: TextStyle(color: context.colors.light),
                decoration: const InputDecoration(
                  labelText: 'Message',
                  hintText: 'You should watch this.',
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: sending
                      ? null
                      : () async {
                          if (!widget.session.isCurrent) return;
                          setState(() => sending = true);
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);
                          final customMessage = messageController.text.trim();

                          try {
                            await widget.session.shareDirect(
                              movie: movie,
                              friend: selectedFriend,
                              message: customMessage,
                            );
                            if (!mounted ||
                                !context.mounted ||
                                !widget.session.isCurrent ||
                                ModalRoute.of(context)?.isCurrent != true) {
                              return;
                            }
                            navigator.pop();
                            messenger.showFlixieToast(
                              FlixieToast(
                                type: FlixieToastType.success,
                                content: Text(
                                    'Shared to ${friendUser?.displayName ?? 'friend'}'),
                              ),
                            );
                          } catch (_) {
                            if (!mounted ||
                                !context.mounted ||
                                !widget.session.isCurrent ||
                                ModalRoute.of(context)?.isCurrent != true) {
                              return;
                            }
                            setState(() => sending = false);
                            messenger.showFlixieToast(
                              FlixieToast(
                                type: FlixieToastType.error,
                                content: const Text(
                                    'Could not share to that friend yet'),
                              ),
                            );
                          }
                        },
                  icon: sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(sending ? 'Sharing...' : 'Share in direct chat'),
                ),
              ),
            ],
          ),
        );
      });
}
