import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/show_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class CommunityWatchlistButton extends StatefulWidget {
  const CommunityWatchlistButton({super.key, required this.item});
  final ActivityListItem item;
  @override
  State<CommunityWatchlistButton> createState() =>
      CommunityWatchlistButtonState();
}

class CommunityWatchlistButtonState extends State<CommunityWatchlistButton> {
  bool _busy = false, _saved = false;
  Future<void> _save() async {
    final auth = context.read<AuthProvider>();
    final user = auth.dbUser;
    if (user == null || _busy) return;
    setState(() => _busy = true);
    try {
      if (widget.item.showId != null) {
        await ShowService.addToWatchlist(user.id, widget.item.showId!);
        if (auth.dbUser?.id != user.id) return;
        auth.updateUserList(showWatchlist: [
          {
            'userId': user.id,
            'showId': widget.item.showId,
            'removed': false,
            'show': {
              'id': widget.item.showId,
              'title': widget.item.mediaTitle,
              'posterPath': widget.item.mediaPosterPath
            }
          },
          ...?auth.dbUser?.showWatchlist
              ?.where((i) => i is! Map || i['showId'] != widget.item.showId)
        ]);
      } else {
        final entry =
            await UserService.addToWatchlist(user.id, widget.item.movieId!);
        if (auth.dbUser?.id != user.id) return;
        auth.updateUserList(movieWatchlist: [
          entry,
          ...?auth.dbUser?.movieWatchlist
              ?.where((i) => i.movieId != entry.movieId)
        ]);
      }
      if (mounted) setState(() => _saved = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t save to watchlist. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider?>()?.dbUser;
    final saved = _saved ||
        (widget.item.showId != null
            ? user?.showWatchlist?.any((i) =>
                    i is Map &&
                    i['showId'] == widget.item.showId &&
                    i['removed'] != true) ==
                true
            : user?.movieWatchlist?.any((i) =>
                    i.movieId == widget.item.movieId && i.removed != true) ==
                true);
    return TextButton.icon(
        onPressed: _busy || saved ? null : _save,
        icon: Icon(saved ? Icons.bookmark_added : Icons.bookmark_add_outlined),
        label: Text(saved
            ? 'Saved to watchlist'
            : _busy
                ? 'Saving…'
                : 'Watchlist'));
  }
}
