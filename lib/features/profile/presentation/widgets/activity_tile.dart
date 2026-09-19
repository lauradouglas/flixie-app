import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_reaction_bubble.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_feed_card.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';

/// The shared activity presentation used by Home, friends and profile feeds.
class ActivityTile extends StatefulWidget {
  const ActivityTile(
      {super.key,
      required this.item,
      this.compact = false,
      this.embedded = false,
      this.dismissSheetOnNavigate = false,
      this.showMoviePreview = true,
      this.detailSource = DetailSource.unknown});
  final ActivityListItem item;
  final bool compact, showMoviePreview;
  final bool embedded;
  final bool dismissSheetOnNavigate;
  final DetailSource detailSource;

  @override
  State<ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<ActivityTile>
    with WidgetsBindingObserver {
  ActivityListItem get item => widget.item;
  DetailSource get detailSource => widget.detailSource;
  ActivityReactionSummary _reactions = const ActivityReactionSummary();
  bool _saving = false;
  int _generation = 0;
  static final _loads = <String, ({DateTime time, Future<dynamic> future})>{};
  String get _key => '${item.type.value}:${item.id}';
  String get _path => '/friends/activity-reactions/${item.userId}';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  @override
  void didUpdateWidget(covariant ActivityTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item != item) {
      if (oldWidget.item.id != item.id ||
          oldWidget.item.type != item.type ||
          oldWidget.item.userId != item.userId) {
        ++_generation;
        _reactions = const ActivityReactionSummary();
        _saving = false;
      }
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final actor = context.read<AuthProvider?>()?.dbUser?.id;
    if (actor == null || item.userId.isEmpty || _saving) return;
    final generation = ++_generation;
    final cacheKey = '$actor:${item.userId}';
    final cached = _loads[cacheKey];
    final future = !force &&
            cached != null &&
            DateTime.now().difference(cached.time).inSeconds < 20
        ? cached.future
        : ApiClient.get(_path);
    if (_loads.length > 100) _loads.clear();
    _loads[cacheKey] = (time: DateTime.now(), future: future);
    try {
      final data = await future as Map;
      if (mounted && generation == _generation && !_saving) {
        setState(() => _reactions = data[_key] is Map
            ? ActivityReactionSummary.fromJson(
                Map<String, dynamic>.from(data[_key]))
            : const ActivityReactionSummary());
      }
    } catch (_) {
      _loads.remove(cacheKey);
    }
  }

  Future<void> _save(String? emoji) async {
    if (_saving) return;
    final previous = _reactions;
    final key = _key;
    ++_generation;
    setState(() {
      _saving = true;
      _reactions = previous.selecting(emoji);
    });
    try {
      final data = await ApiClient.put(_path, body: {
        'activityId': item.id,
        'activityType': item.type.value,
        'reaction': emoji
      });
      _loads.clear();
      if (mounted && _key == key) {
        setState(() => _reactions =
            ActivityReactionSummary.fromJson(Map<String, dynamic>.from(data)));
      }
    } catch (_) {
      if (mounted && _key == key) {
        setState(() => _reactions = previous);
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Couldn’t save your reaction'),
            action: SnackBarAction(
                label: 'Retry',
                onPressed: () {
                  if (mounted && _key == key) _save(emoji);
                })));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _react(BuildContext anchor) async {
    final chosen = await showActivityReactionBubble(context, anchor,
        current: _reactions.mine,
        canReply: item.userId != context.read<AuthProvider?>()?.dbUser?.id);
    if (!mounted) return;
    if (chosen == 'reply') {
      final payload = ActivityReplyPayload.fromActivity(item);
      context.push('/chat/${item.userId}',
          extra: payload.isUsable ? payload : null);
    }
    if (chosen is ActivityReaction) {
      await _save(chosen.emoji == _reactions.mine ? null : chosen.emoji);
    }
  }

  String? _mediaRoute() {
    final isPerson = item.type == ActivityListType.favoritePerson;
    if (isPerson && item.personId != null) {
      return personDetailPath(item.personId!, source: detailSource);
    }
    if (item.movieId != null) {
      return movieDetailPath(item.movieId!, source: detailSource);
    }
    if (item.showId != null) {
      return showDetailPath(item.showId!, source: detailSource);
    }
    return null;
  }

  void _openList(BuildContext context) {
    final listId = item.listId;
    final ownerId = item.listOwnerId;
    if (listId == null || ownerId == null) return;
    final name = Uri.encodeComponent(item.listName ?? 'List');
    context.push(
      '/movie-lists/$listId?name=$name&owner=$ownerId&isOwner=false&canEdit=false',
    );
  }

  void _navigate(String route, {Object? extra}) {
    final router = GoRouter.of(context);
    if (widget.dismissSheetOnNavigate) Navigator.of(context).pop();
    router.push(route, extra: extra);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider?>()?.dbUser?.id;
    final route = _mediaRoute();
    final payload = ActivityReplyPayload.fromActivity(item);
    if (widget.compact) {
      final label = switch (item.type) {
        ActivityListType.movieRating || ActivityListType.showRating => 'Rated',
        ActivityListType.movieReview ||
        ActivityListType.showReview =>
          'Wrote a review',
        ActivityListType.movieWatched ||
        ActivityListType.showWatched =>
          item.isRewatch ? 'Watched again' : 'Watched',
        ActivityListType.movieWatchlist ||
        ActivityListType.showWatchlist =>
          'Added to watchlist',
        ActivityListType.favoriteMovie ||
        ActivityListType.favoriteShow ||
        ActivityListType.favoritePerson =>
          'Added to favourites',
        _ => item.type.value.replaceAll('-', ' '),
      };
      return InkWell(
        onTap: () => showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            useSafeArea: true,
            isScrollControlled: true,
            builder: (context) => ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * .85),
                child: SafeArea(
                    top: false,
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(
                          height: 48,
                          child: Stack(children: [
                            Center(
                                child: Container(
                                    width: 36,
                                    height: 4,
                                    decoration: BoxDecoration(
                                        color: context.colors.medium,
                                        borderRadius:
                                            BorderRadius.circular(2)))),
                            Positioned(
                                right: 8,
                                top: 0,
                                child: IconButton(
                                    tooltip: 'Close activity',
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.close, size: 22))),
                          ])),
                      Flexible(
                          child: SingleChildScrollView(
                              child: ActivityTile(
                                  item: item,
                                  embedded: true,
                                  dismissSheetOnNavigate: true,
                                  detailSource: detailSource))),
                    ])))),
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                      width: 48,
                      height: 72,
                      child: item.mediaPosterPath == null
                          ? const Icon(Icons.movie_outlined)
                          : Image.network(
                              item.mediaPosterPath!.startsWith('http')
                                  ? item.mediaPosterPath!
                                  : 'https://image.tmdb.org/t/p/w185${item.mediaPosterPath}',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.movie_outlined)))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.mediaTitle ?? item.listName ?? 'Activity',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(label),
                    if (item.notes?.isNotEmpty == true &&
                        item.reviewData?.containsSpoilers != true)
                      Text(item.notes!,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    Wrap(spacing: 8, children: [
                      if (item.mediaRating != null)
                        Text(
                            '★ ${item.mediaRating!.toStringAsFixed(item.mediaRating! % 1 == 0 ? 0 : 1)}/10',
                            style: TextStyle(color: context.colors.warning)),
                      if (item.recommended == true)
                        Text('Recommends',
                            style: TextStyle(color: context.colors.success)),
                      for (final reaction in _reactions.counts.entries
                          .where((entry) => entry.value > 0))
                        Text('${reaction.key} ${reaction.value}'),
                    ]),
                  ])),
              const Icon(Icons.chevron_right, size: 20),
            ])),
      );
    }
    return ActivityFeedCard(
      item: item,
      embedded: widget.embedded,
      reactions: _reactions,
      busy: _saving,
      onReact: item.userId == currentUserId ? null : _react,
      onReactionSelected: item.userId == currentUserId ? null : _save,
      onOpen: route == null ? null : () => _navigate(route),
      onProfile: () => _navigate(item.userId == currentUserId
          ? '/profile'
          : '/friends/${item.userId}'),
      onReply: item.userId.isEmpty || item.userId == currentUserId
          ? null
          : () => _navigate('/chat/${item.userId}',
              extra: payload.isUsable ? payload : null),
      onOpenList: item.listId == null || item.listOwnerId == null
          ? null
          : () => _openList(context),
      onReview: item.reviewData == null
          ? null
          : () => showModalBottomSheet<void>(
                context: context,
                useRootNavigator: true,
                useSafeArea: true,
                isScrollControlled: true,
                builder: (context) => SizedBox(
                    height: MediaQuery.sizeOf(context).height * .8,
                    child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ReviewCard(
                            review: item.reviewData!,
                            currentUserId: currentUserId))),
              ),
    );
  }
}
