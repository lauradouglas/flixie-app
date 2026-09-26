import '../widgets/community_replies.dart';
import '../widgets/community_follow_button.dart';
import '../widgets/community_list_editors.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/models/friendship.dart';
import '../controllers/community_connections_controller.dart';
import '../widgets/community_friend_button.dart';
import '../widgets/community_watchlist_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import '../../data/community_service.dart';
import '../widgets/community_bookmark_button.dart';

class CommunityPostScreen extends StatefulWidget {
  const CommunityPostScreen(
      {super.key,
      required this.ownerId,
      required this.type,
      required this.postId,
      this.service = const CommunityService()});
  final String ownerId, type, postId;
  final CommunityService service;
  @override
  State<CommunityPostScreen> createState() => _CommunityPostScreenState();
}

class _CommunityPostScreenState extends State<CommunityPostScreen> {
  ActivityListItem? _post;
  CommunityConnectionsController? _connections;
  bool _loading = true;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    SafetyService.changes.addListener(_load);
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider?>();
    final id = auth?.dbUser?.id;
    if (_connections?.userId == id) return;
    _connections?.dispose();
    _connections = id == null
        ? null
        : CommunityConnectionsController(
            userId: id,
            onSnapshot: (data) {
              if (auth?.dbUser?.id == id) auth!.updateCachedFriends(data);
            });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connections?.refresh();
    });
  }

  @override
  void dispose() {
    _connections?.dispose();
    SafetyService.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _post = null;
    });
    try {
      final post =
          await widget.service.post(widget.ownerId, widget.type, widget.postId);
      if (mounted &&
          generation == _generation &&
          !SafetyService.isBlocked(post.userId)) {
        setState(() => _post = post);
      }
    } catch (_) {
      /* The unavailable state also covers removed sharing consent. */
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _options(ActivityListItem post) async {
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheet) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheet).height * .65),
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(post.mediaTitle ?? post.listName ?? 'Post options',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700)),
                      TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheet);
                            context.push('/community/profiles/${post.userId}');
                          },
                          icon: const Icon(Icons.person_outline),
                          label: const Text('View profile')),
                      if (post.type == ActivityListType.movieListAdded &&
                          post.userId ==
                              context.read<AuthProvider?>()?.dbUser?.id)
                        CommunityListEditors(
                            listId: post.listId ?? post.id,
                            userId: post.userId,
                            service: widget.service),
                      if (post.movieId != null || post.showId != null)
                        CommunityWatchlistButton(item: post),
                      if (post.userId !=
                          context.read<AuthProvider?>()?.dbUser?.id)
                        TextButton.icon(
                            onPressed: () {
                              Navigator.pop(sheet);
                              SafetyActions.contentMenu(context,
                                  targetType: post.type ==
                                          ActivityListType.movieReview
                                      ? 'MOVIE_REVIEW'
                                      : post.type == ActivityListType.showReview
                                          ? 'SHOW_REVIEW'
                                          : 'MOVIE_LIST',
                                  targetId: post.id,
                                  reportedUserId: post.userId,
                                  username: post.username,
                                  contentPreview: post.reviewData?.body ??
                                      post.listName ??
                                      '');
                            },
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Report or block')),
                    ]))));
  }

  @override
  Widget build(BuildContext context) => FlixiePageScaffold(
        appBar: const FlixieTitleAppBar(title: Text('Post'), centerTitle: true),
        body: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_post case final post?) ...[
                  ActivityTile(
                      item: post,
                      community: true,
                      postDetail: true,
                      saveAction: CommunityBookmarkButton(
                          item: post, service: widget.service, iconOnly: true),
                      headerAction: _connections == null
                          ? null
                          : CommunityFriendButton(
                              connections: _connections!,
                              compact: true,
                              author: FriendshipUser(
                                  id: post.userId,
                                  username: post.username,
                                  avatar: post.avatar,
                                  profileBadges: post.profileBadges)),
                      onOptions: () => _options(post),
                      onCommunityProfile: () =>
                          context.push('/community/profiles/${post.userId}')),
                  if (post.type == ActivityListType.movieListAdded)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: CommunityFollowButton(
                            path: 'lists/${post.listId ?? post.id}',
                            service: widget.service,
                            list: true)),
                  CommunityReplies(item: post, service: widget.service),
                ] else ...[
                  const Text(
                      'This post is unavailable or couldn’t load. It may no longer be public.'),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ]
              ],
            )),
      );
}
