import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import '../models/chat_share_media.dart';
import 'media_share_session.dart';
import 'widgets/friend_share_composer.dart';
import 'widgets/group_share_composer.dart';

export '../models/chat_share_media.dart' show ChatShareMedia;

/// Opens the destination chooser and its account-owned composer.
class MediaChatShare {
  MediaChatShare(this.context);
  final BuildContext context;

  Future<T?> _sheet<T>(WidgetBuilder builder) => showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
          child: SingleChildScrollView(child: builder(context))));

  Future<void> show(ChatShareMedia movie) async {
    final session = MediaShareSession(context.read<AuthProvider>());
    try {
      if (!session.isCurrent) return;
      final toGroup = await _sheet<bool>((ctx) => ListenableBuilder(
          listenable: session,
          builder: (ctx, _) => !session.isCurrent
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Account changed. Close this sheet to continue.'))
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(height: 8),
                  Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: ctx.colors.medium.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 8),
                  ListTile(
                      leading:
                          Icon(Icons.person_rounded, color: ctx.colors.light),
                      title: const Text('Share to friend'),
                      subtitle: const Text('Send directly to one friend'),
                      onTap: () => Navigator.pop(ctx, false)),
                  ListTile(
                      leading: const Icon(Icons.groups_2_outlined,
                          color: FlixieColors.primary),
                      title: const Text('Share to group chat'),
                      subtitle: const Text(
                          'Post in one of your groups with a message'),
                      onTap: () => Navigator.pop(ctx, true)),
                  const SizedBox(height: 8),
                ])));
      if (toGroup == null || !context.mounted || !session.isCurrent) return;
      if (toGroup) {
        final groups = await session.loadGroups();
        if (!context.mounted || !session.isCurrent) return;
        if (groups.isEmpty) {
          _notice('Join or create a group to share there.');
          return;
        }
        await _sheet<void>((_) =>
            GroupShareComposer(movie: movie, groups: groups, session: session));
      } else {
        final friends = await session.loadFriends();
        if (!context.mounted || !session.isCurrent) return;
        if (friends.isEmpty) {
          _notice('Add a friend to share there.');
          return;
        }
        await _sheet<void>((_) => FriendShareComposer(
            movie: movie, friends: friends, session: session));
      }
    } catch (_) {
      if (context.mounted && session.isCurrent) {
        _notice('Could not load sharing recipients', error: true);
      }
    } finally {
      session.dispose();
    }
  }

  void _notice(String text, {bool error = false}) =>
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: error ? FlixieToastType.error : FlixieToastType.info,
          content: Text(text)));
}
