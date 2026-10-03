import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import '../widgets/community_follow_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import '../../data/community_service.dart';
import '../controllers/community_connections_controller.dart';
import '../widgets/community_friend_button.dart';

class CommunityProfileScreen extends StatefulWidget {
  const CommunityProfileScreen(
      {super.key,
      required this.userId,
      this.service = const CommunityService()});
  final String userId;
  final CommunityService service;
  @override
  State<CommunityProfileScreen> createState() => _CommunityProfileScreenState();
}

class _CommunityProfileScreenState extends State<CommunityProfileScreen> {
  CommunityProfile? _profile;
  CommunityConnectionsController? _connections;
  final List<ActivityListItem> _posts = [];
  String? _cursor, _error;
  bool _loading = true, _more = false;
  @override
  void initState() {
    super.initState();
    _load();
    SafetyService.changes.addListener(_blocked);
    final auth = context.read<AuthProvider?>();
    final me = auth?.dbUser?.id;
    if (me != null) {
      _connections = CommunityConnectionsController(
          userId: me,
          onSnapshot: (data) {
            if (auth?.dbUser?.id == me) auth!.updateCachedFriends(data);
          });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _connections!.refresh();
      });
    }
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_blocked);
    _connections?.dispose();
    super.dispose();
  }

  void _blocked() {
    if (!mounted || !SafetyService.isBlocked(widget.userId)) return;
    setState(() {
      _profile = null;
      _posts.clear();
      _loading = false;
      _more = false;
      _error = 'This user is blocked.';
    });
  }

  Future<void> _load({bool more = false}) async {
    if (SafetyService.isBlocked(widget.userId)) {
      _blocked();
      return;
    }
    if (more && (_more || _cursor == null)) return;
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
      }
    });
    try {
      final profile = await widget.service.profile(widget.userId);
      final page = await widget.service
          .load(owner: widget.userId, cursor: more ? _cursor : null);
      if (mounted && !SafetyService.isBlocked(widget.userId)) {
        setState(() {
          _profile = profile;
          if (!more) _posts.clear();
          _posts.addAll(page.items);
          _cursor = page.nextCursor;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _profile = null;
          _posts.clear();
          _error = 'This community profile is unavailable or couldn’t load.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => FlixiePageScaffold(
      appBar:
          FlixieTitleAppBar(title: const Text('Community profile'), actions: [
        if (_profile != null &&
            widget.userId != context.read<AuthProvider?>()?.dbUser?.id)
          PopupMenuButton<String>(
            tooltip: 'User safety options',
            icon: const Icon(Icons.more_horiz),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report user')),
              PopupMenuItem(value: 'block', child: Text('Block user')),
            ],
            onSelected: (action) async {
              final profile = _profile;
              if (profile == null) return;
              if (action == 'report') {
                await SafetyActions.report(context,
                    targetType: 'USER',
                    targetId: widget.userId,
                    reportedUserId: widget.userId,
                    contentPreview: profile.bio);
              } else {
                await SafetyActions.block(context,
                    userId: widget.userId, username: profile.user.username);
              }
            },
          ),
      ]),
      body: RefreshIndicator(
          onRefresh: () => _load(),
          child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null) ...[
                  Text(_error!),
                  TextButton(
                      onPressed: () => _load(), child: const Text('Try again'))
                ] else if (_profile case final profile?) ...[
                  Row(children: [
                    ProfileAvatarView(
                        fallbackColor: Theme.of(context).colorScheme.primary,
                        avatar: profile.user.avatar,
                        profileBadges: profile.user.profileBadges,
                        size: 64,
                        fallbackText: profile.user.username.isEmpty
                            ? '?'
                            : profile.user.username[0]),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Text(profile.user.username,
                            style: Theme.of(context).textTheme.headlineSmall))
                  ]),
                  if (profile.user.id !=
                      context.read<AuthProvider?>()?.dbUser?.id)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: CommunityFollowButton(
                            path: 'profiles/${profile.user.id}',
                            service: widget.service)),
                  if (_connections != null)
                    Align(
                        alignment: Alignment.centerLeft,
                        child: CommunityFriendButton(
                            connections: _connections!, author: profile.user)),
                  if (profile.bio?.trim().isNotEmpty == true)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(profile.bio!)),
                  if (profile.genres.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final genre in profile.genres)
                        Chip(label: Text(genre))
                    ]),
                  ],
                  if (profile.favourites.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Text('Favourite films',
                        style: Theme.of(context).textTheme.titleLarge),
                    for (final movie in profile.favourites)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(movie['title'] as String),
                          leading: const Icon(Icons.movie_outlined),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(movieDetailPath(movie['id'],
                              source: DetailSource.communityActivity)))
                  ],
                  const SizedBox(height: 20),
                  Text('Reviews & public lists',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  if (_posts.isEmpty)
                    const Text('No public reviews or lists yet.'),
                  for (final item in _posts) ...[
                    ActivityTile(
                        item: item,
                        community: true,
                        feedStyle: true,
                        detailSource: DetailSource.communityActivity),
                    TextButton.icon(
                        onPressed: () =>
                            context.push(widget.service.postPath(item)),
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('View post')),
                    const SizedBox(height: 16)
                  ],
                  if (_cursor != null)
                    TextButton(
                        onPressed: _more ? null : () => _load(more: true),
                        child: LoadingActionLabel(
                            loading: _more, text: 'More posts')),
                ],
              ])));
}
