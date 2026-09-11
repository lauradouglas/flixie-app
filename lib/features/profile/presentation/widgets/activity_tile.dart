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
      this.showMoviePreview = true,
      this.detailSource = DetailSource.unknown});
  final ActivityListItem item;
  final bool compact, showMoviePreview;
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
    if (state == AppLifecycleState.resumed) _load(force: true);
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

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.read<AuthProvider?>()?.dbUser?.id;
    final route = _mediaRoute();
    final payload = ActivityReplyPayload.fromActivity(item);
    return ActivityFeedCard(
      item: item,
      reactions: _reactions,
      busy: _saving,
      onReact: item.userId == currentUserId ? null : _react,
      onReactionSelected: item.userId == currentUserId ? null : _save,
      onOpen: route == null ? null : () => context.push(route),
      onProfile: () => context.push(item.userId == currentUserId
          ? '/profile'
          : '/friends/${item.userId}'),
      onReply: item.userId.isEmpty || item.userId == currentUserId
          ? null
          : () => context.push('/chat/${item.userId}',
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
