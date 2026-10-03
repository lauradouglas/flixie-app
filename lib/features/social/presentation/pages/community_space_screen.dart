import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import '../../data/community_space_service.dart';
import '../../data/genre_community_service.dart';
import '../../data/community_service.dart';
import '../widgets/community_follow_button.dart';
import '../widgets/community_identity.dart';
import '../widgets/community_watchlist_button.dart';
import 'genre_community_feed_screen.dart';
import 'community_discussion_screen.dart';

class CommunitySpaceScreen extends StatefulWidget {
  const CommunitySpaceScreen(
      {super.key,
      required this.communityId,
      this.service = const CommunitySpaceService(),
      this.membership = const GenreCommunityService()});
  final int communityId;
  final CommunitySpaceService service;
  final GenreCommunityService membership;
  @override
  State<CommunitySpaceScreen> createState() => _CommunitySpaceScreenState();
}

class _CommunitySpaceScreenState extends State<CommunitySpaceScreen> {
  Map<String, dynamic>? _community;
  String? _error;
  bool _busy = false;
  int _revision = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await widget.service.get(widget.communityId, '');
      if (mounted) {
        setState(() {
          _community = value;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t load this community. Try again.');
      }
    }
  }

  Future<void> _join() async {
    if (_busy || _community == null) return;
    final joined = _community!['joined'] == true;
    final confirmed = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (context) => FlixiePromptSheetContent(
                title: Text(joined
                    ? 'Leave ${_community!['name']}?'
                    : 'Join ${_community!['name']}?'),
                content: Text(joined
                    ? 'Your contributions disappear from this community. Original reviews stay intact.'
                    : 'Your existing and future public reviews can appear here. Private reviews stay private. Discussions you publish are visible to people browsing the community.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(joined ? 'Leave' : 'Join'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.membership.setJoined(widget.communityId, !joined);
      if (mounted) {
        setState(() {
          _community!['joined'] = !joined;
          _revision++;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t change membership. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 4,
      child: Scaffold(
          appBar: AppBar(
            title: const Text('Communities'),
            actions: [
              if (_community != null)
                (_community!['joined'] == true
                    ? IconButton(
                        tooltip: 'Joined · Leave community',
                        onPressed: _busy ? null : _join,
                        icon: const Icon(Icons.how_to_reg_outlined))
                    : TextButton(
                        onPressed: _busy ? null : _join,
                        child: const Text('Join')))
            ],
          ),
          backgroundColor: context.colors.background,
          body: SafeArea(
              top: false,
              child: _community == null
                  ? (_error != null
                      ? CommunityRetry(message: _error!, onRetry: _load)
                      : const Center(child: CircularProgressIndicator()))
                  : NestedScrollView(
                      headerSliverBuilder: (context, innerBoxIsScrolled) => [
                            SliverToBoxAdapter(
                                child: CommunityIdentityHeader(
                                    id: widget.communityId,
                                    name: _community!['name'])),
                          ],
                      body: Column(children: [
                        TabBar(
                            dividerColor:
                                context.colors.medium.withValues(alpha: 0.3),
                            dividerHeight: 0.5,
                            isScrollable: true,
                            tabAlignment: TabAlignment.start,
                            tabs: const [
                              Tab(text: 'Discuss'),
                              Tab(text: 'Discover'),
                              Tab(text: 'Reviews'),
                              Tab(text: 'People')
                            ]),
                        Expanded(
                            child: TabBarView(children: [
                          SpaceCollection(
                              key: ValueKey('discuss:$_revision'),
                              communityId: widget.communityId,
                              service: widget.service,
                              section: 'discussions',
                              joined: _community!['joined'] == true),
                          SpaceCollection(
                              key: ValueKey('discover:$_revision'),
                              communityId: widget.communityId,
                              service: widget.service,
                              section: 'discover',
                              joined: _community!['joined'] == true),
                          GenreCommunityFeedScreen(
                              key: ValueKey('reviews:$_revision'),
                              genreId: widget.communityId,
                              embedded: true),
                          SpaceCollection(
                              key: ValueKey('people:$_revision'),
                              communityId: widget.communityId,
                              service: widget.service,
                              section: 'people',
                              joined: _community!['joined'] == true),
                        ])),
                      ])))));
}

class CommunityRetry extends StatelessWidget {
  const CommunityRetry(
      {super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(message, textAlign: TextAlign.center),
            TextButton(onPressed: onRetry, child: const Text('Try again'))
          ])));
}

class SpaceCollection extends StatefulWidget {
  const SpaceCollection(
      {super.key,
      required this.communityId,
      required this.service,
      required this.section,
      required this.joined});
  final int communityId;
  final CommunitySpaceService service;
  final String section;
  final bool joined;
  @override
  State<SpaceCollection> createState() => _SpaceCollectionState();
}

class _SpaceCollectionState extends State<SpaceCollection> {
  final List<Map<String, dynamic>> _items = [];
  bool _loading = true, _more = false, _failedMore = false;
  String? _error;
  dynamic _next;
  int _generation = 0;
  String get _nextField => widget.section == 'discover'
      ? 'nextOffset'
      : widget.section == 'people'
          ? 'nextAfter'
          : 'nextCursor';
  String get _queryField => widget.section == 'discover'
      ? 'offset'
      : widget.section == 'people'
          ? 'after'
          : 'cursor';
  @override
  void initState() {
    super.initState();
    SafetyService.changes.addListener(_safetyChanged);
    _load();
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_safetyChanged);
    super.dispose();
  }

  void _safetyChanged() {
    setState(() => _items.clear());
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_more || _loading || _next == null)) return;
    final revision = more ? _generation : ++_generation;
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _more = false;
      }
    });
    try {
      final page = await widget.service.get(widget.communityId,
          '/${widget.section}', {if (more) _queryField: _next.toString()});
      if (!mounted || revision != _generation) return;
      setState(() {
        if (!more) _items.clear();
        final keys = _items.map((e) => '${e['kind']}:${e['id']}').toSet();
        _items.addAll((page['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => keys.add('${e['kind']}:${e['id']}')));
        _next = page[_nextField];
      });
    } catch (_) {
      if (mounted && revision == _generation) {
        setState(() {
          _failedMore = more;
          _error = 'Couldn’t load ${widget.section}. Try again.';
        });
      }
    } finally {
      if (mounted && revision == _generation) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  Future<void> _compose() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => CommunityDiscussionComposer(
            communityId: widget.communityId, service: widget.service)));
    if (created == true && mounted) _load();
  }

  Future<void> _open(Map<String, dynamic> row) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CommunityDiscussionScreen(
            communityId: widget.communityId,
            discussionId: row['id'],
            service: widget.service,
            joined: widget.joined)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
      onRefresh: () => _load(),
      child: ListView(
          padding: const EdgeInsets.all(20),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
                switch (widget.section) {
                  'discussions' => widget.communityId == -1
                      ? 'Talk anime together'
                      : 'Talk films together',
                  'discover' => 'Find your next favourite',
                  _ => 'Find a voice you trust'
                },
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
                switch (widget.section) {
                  'discussions' =>
                    'Ask for a recommendation or talk through a title. Respect the spoiler boundary.',
                  'discover' =>
                    'Ratings from joined members’ public reviews. One latest score per person, with the sample size shown.',
                  _ =>
                    'Read their reviews before deciding to follow. Joining never follows anyone for you.'
                },
                style: TextStyle(color: context.colors.medium)),
            if (widget.section == 'discussions') ...[
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: widget.joined ? _compose : null,
                  child: Text(
                      widget.joined
                          ? 'Start a discussion'
                          : 'Join to start or reply',
                      textAlign: TextAlign.center)),
            ],
            const SizedBox(height: 24),
            if (_loading && _items.isEmpty)
              const Center(child: CircularProgressIndicator()),
            if (!_loading && _items.isEmpty && _error == null)
              Text(switch (widget.section) {
                'discussions' =>
                  'No discussions yet. Start with a question for the community.',
                'discover' =>
                  'No public member ratings yet. Titles appear here as members review them.',
                _ => 'No public members to show yet.'
              }),
            if (widget.section == 'discover') _discoveryGrid(),
            if (widget.section != 'discover')
              for (final row in _items) ...[
                if (widget.section == 'discussions')
                  _thread(row)
                else if (widget.section == 'discover')
                  _discovery(row)
                else
                  _person(row),
                const SizedBox(height: 20)
              ],
            if (_error != null)
              CommunityRetry(
                  message: _error!, onRetry: () => _load(more: _failedMore)),
            if (_next != null && _error == null)
              TextButton(
                  onPressed: _more ? null : () => _load(more: true),
                  child: LoadingActionLabel(loading: _more, text: 'Load more')),
          ]));
  Widget _thread(Map<String, dynamic> row) {
    final user =
        FriendshipUser.fromJson(Map<String, dynamic>.from(row['user']));
    final title = row['movie'] ?? row['show'];
    final poster = title?['posterPath'] as String?;
    final created = DateTime.tryParse(row['createdAt']?.toString() ?? '');
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(
          '${title?['title'] ?? 'Recommendations'} · ${discussionBoundary(row)}',
          style: TextStyle(
              color: row['spoiler'] == 'none'
                  ? context.colors.secondary
                  : context.colors.warning,
              fontSize: 12,
              height: 1.5)),
      const SizedBox(height: 8),
      TextButton(
          onPressed: () => _open(row),
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(48, 48),
              foregroundColor: context.colors.white),
          child: Text(row['title'],
              style: TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  fontWeight: FontWeight.w800,
                  color: context.colors.white))),
      if (row['body'] != null) ...[
        const SizedBox(height: 10),
        Text(row['body'],
            style: TextStyle(
                fontSize: 15, height: 1.6, color: context.colors.light)),
      ],
    ]);
    final replies = TextButton(
      onPressed: () => _open(row),
      style: TextButton.styleFrom(
          foregroundColor: context.colors.primaryText,
          padding: const EdgeInsets.symmetric(horizontal: 8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('${row['replyCount'] ?? 0} replies',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
        const SizedBox(width: 8),
        const Icon(Icons.chat_bubble_outline, size: 19),
      ]),
    );
    final author = CommunityAuthor(
        user: user,
        compact: true,
        timestamp: created == null ? null : communityRelativeTime(created));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, constraints) {
        // Give enlarged text the full line rather than squeezing it beside artwork.
        if (title == null ||
            MediaQuery.textScalerOf(context).scale(15) > 22 ||
            constraints.maxWidth < 300) {
          return content;
        }
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ExcludeSemantics(
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 58,
                    height: 87,
                    child: poster == null || poster.isEmpty
                        ? ColoredBox(
                            color: context.colors.surface,
                            child: const Icon(Icons.movie_outlined))
                        : CachedNetworkImage(
                            imageUrl: poster.startsWith('http')
                                ? poster
                                : 'https://image.tmdb.org/t/p/w185$poster',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                const Icon(Icons.movie_outlined)),
                  ))),
          const SizedBox(width: 13),
          Expanded(child: content),
        ]);
      }),
      const SizedBox(height: 20),
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(13) > 19) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                author,
                Align(alignment: Alignment.centerRight, child: replies)
              ]);
        }
        return Row(children: [
          Expanded(child: author),
          const SizedBox(width: 8),
          replies
        ]);
      }),
      const SizedBox(height: 20),
      Divider(
          height: 1,
          thickness: 0.5,
          color: context.colors.medium.withValues(alpha: 0.4)),
      const SizedBox(height: 4),
    ]);
  }

  Widget _discoveryGrid() => LayoutBuilder(builder: (context, constraints) {
        final enlarged = MediaQuery.textScalerOf(context).scale(16) > 24;
        final columns = enlarged
            ? (constraints.maxWidth / 280).floor().clamp(1, 3)
            : constraints.maxWidth < 600
                ? 2
                : (constraints.maxWidth / 200).floor().clamp(2, 4);
        return Column(children: [
          for (var start = 0; start < _items.length; start += columns)
            Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var column = 0; column < columns; column++) ...[
                        if (column > 0) const SizedBox(width: 14),
                        Expanded(
                            child: start + column < _items.length
                                ? _discovery(_items[start + column])
                                : const SizedBox.shrink()),
                      ],
                    ])),
        ]);
      });

  Widget _discovery(Map<String, dynamic> row) {
    final show = row['kind'] == 'show', id = row['id'] as int;
    final hidden = hideMovieRatings(context, id, isShow: show);
    final item = ActivityListItem(
        id: 'discover:${row['kind']}:$id',
        userId: '',
        username: '',
        firstName: '',
        lastName: '',
        removed: false,
        createdAt: '',
        updatedAt: '',
        type: show ? ActivityListType.showReview : ActivityListType.movieReview,
        movieId: show ? null : id,
        showId: show ? id : null,
        mediaTitle: row['title'],
        mediaPosterPath: row['posterPath']);
    return Column(
        key: ValueKey('discovery-card:${row['kind']}:$id'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Open ${row['title']}',
            button: true,
            child: InkWell(
                onTap: () => context.push('/${show ? 'shows' : 'movies'}/$id'),
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: row['posterPath'] == null
                            ? ColoredBox(
                                color: context.colors.surface,
                                child: const Icon(Icons.movie_outlined))
                            : CachedNetworkImage(
                                imageUrl: row['posterPath']
                                        .toString()
                                        .startsWith('http')
                                    ? row['posterPath']
                                    : 'https://image.tmdb.org/t/p/w342${row['posterPath']}',
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.movie_outlined))))),
          ),
          const SizedBox(height: 12),
          TextButton(
              onPressed: () =>
                  context.push('/${show ? 'shows' : 'movies'}/$id'),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  foregroundColor: context.colors.white),
              child: Text(row['title'],
                  style: const TextStyle(
                      fontSize: 17, height: 1.4, fontWeight: FontWeight.w800))),
          if (show) ...[
            Text('Series', style: TextStyle(color: context.colors.light)),
            const SizedBox(height: 6)
          ],
          Text(
              hidden
                  ? 'Rate first to reveal community scores'
                  : '${(row['average'] as num).toStringAsFixed(1)}/10',
              style: TextStyle(
                  color: context.colors.light,
                  fontSize: hidden ? 14 : 16,
                  height: 1.5,
                  fontWeight: hidden ? FontWeight.w400 : FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
              '${row['count']} ${widget.communityId == -1 ? 'Anime members' : 'members'}',
              style: TextStyle(
                  color: context.colors.light, fontSize: 12, height: 1.5)),
          const SizedBox(height: 4),
          CommunityWatchlistButton(key: ValueKey(item.id), item: item),
        ]);
  }

  Widget _person(Map<String, dynamic> row) {
    final user = FriendshipUser.fromJson(row);
    final me = context.read<AuthProvider>().dbUser?.id;
    final profile = InkWell(
      onTap: () => context.push('/community/profiles/${user.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(children: [
            Padding(
                padding: const EdgeInsets.all(4),
                child: ProfileAvatarView(
                    avatar: user.avatar,
                    profileBadges: user.profileBadges,
                    size: 38,
                    fallbackText:
                        user.username.isEmpty ? '?' : user.username[0],
                    fallbackColor: context.colors.primary)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      user.firstName?.trim().isNotEmpty == true
                          ? user.firstName!
                          : user.username,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('View profile & reviews',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: context.colors.light)),
                ])),
          ])),
    );
    final follow = CommunityFollowButton(
        key: ValueKey('follow:${user.id}'),
        outlined: true,
        path: 'profiles/${user.id}',
        service: const CommunityService());
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(15) > 22) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                profile,
                if (me != user.id)
                  Align(alignment: Alignment.centerRight, child: follow),
              ]);
        }
        return Row(children: [
          Expanded(child: profile),
          if (me != user.id) ...[const SizedBox(width: 12), follow]
        ]);
      }),
      const SizedBox(height: 14),
      Divider(
          height: 1,
          thickness: 0.5,
          color: context.colors.medium.withValues(alpha: 0.4)),
    ]);
  }
}

class CommunityAuthor extends StatelessWidget {
  const CommunityAuthor(
      {super.key, required this.user, this.compact = false, this.timestamp});
  final FriendshipUser user;
  final bool compact;
  final String? timestamp;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Padding(
            padding: const EdgeInsets.all(4),
            child: ProfileAvatarView(
                avatar: user.avatar,
                profileBadges: user.profileBadges,
                size: 32,
                fallbackColor: context.colors.primary,
                fallbackText: user.username.isEmpty ? '?' : user.username[0])),
        const SizedBox(width: 8),
        Flexible(
            child: Text(
                '${compact && user.firstName?.trim().isNotEmpty == true ? user.firstName!.trim() : user.username}${timestamp == null ? '' : ' · $timestamp'}',
                style: TextStyle(
                    fontSize: compact ? 12 : null,
                    height: 1.5,
                    color: compact ? context.colors.light : null,
                    fontWeight: compact ? FontWeight.w400 : FontWeight.w700)))
      ]);
}

String discussionBoundary(Map<String, dynamic> row) => switch (row['spoiler']) {
      'episode' => 'Spoilers through S${row['season']} E${row['episode']}',
      'full' => 'Full-title spoilers',
      _ => 'Spoiler-free'
    };

String communityRelativeTime(DateTime created, {DateTime? now}) {
  final age = (now ?? DateTime.now()).difference(created);
  if (age.inMinutes < 1) return 'Just now';
  if (age.inHours < 1) return '${age.inMinutes}m ago';
  if (age.inDays < 1) return '${age.inHours}h ago';
  if (age.inDays == 1) return 'Yesterday';
  return '${age.inDays}d ago';
}
