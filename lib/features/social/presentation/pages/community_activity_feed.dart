import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import '../../data/starred_people.dart';
import 'dart:async';
import '../widgets/community_watchlist_button.dart';
import 'package:go_router/go_router.dart';
import '../widgets/community_preferences.dart';
import '../widgets/community_bookmark_button.dart';
import 'package:flixie_app/models/friendship.dart';
import '../controllers/community_connections_controller.dart';
import '../controllers/friend_actions_controller.dart';
import '../widgets/community_friend_button.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class CommunityActivityFeed extends StatefulWidget {
  const CommunityActivityFeed(
      {super.key,
      this.service = const CommunityService(),
      this.showSettingsButton = true,
      this.initialFollowing = false,
      this.showAudienceSelector = true,
      this.onReady,
      this.friendActions = const FriendActionsController()});
  final CommunityService service;
  final bool showSettingsButton;
  final bool initialFollowing;
  final bool showAudienceSelector;
  final VoidCallback? onReady;
  final FriendActionsController friendActions;
  @override
  State<CommunityActivityFeed> createState() => CommunityActivityFeedState();
}

class CommunityActivityFeedState extends State<CommunityActivityFeed>
    with AutomaticKeepAliveClientMixin {
  final List<ActivityListItem> _items = [];
  CommunityConnectionsController? _connections;
  bool _loading = true, _loadingMore = false, _savingSetting = false;
  bool? _sharing;
  String _filter = 'all', _sort = 'for-you';
  bool _savedOnly = false,
      _following = false,
      _newPosts = false,
      _checking = false;
  Timer? _newPostsTimer;
  String? _cursor, _error, _settingsError;
  int _generation = 0, _settingsGeneration = 0;
  @override
  bool get wantKeepAlive => true;
  @override
  void initState() {
    super.initState();
    StarredPeople.instance.addListener(_starsChanged);
    _following = widget.initialFollowing;
    _refresh();
    _newPostsTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkNewPosts());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady?.call();
    });
    SafetyService.changes.addListener(_blockedChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider?>();
    final userId = auth?.dbUser?.id;
    if (_connections?.userId == userId) return;
    _connections?.dispose();
    _connections = userId == null
        ? null
        : CommunityConnectionsController(
            userId: userId,
            actions: widget.friendActions,
            onSnapshot: (data) {
              if (auth?.dbUser?.id == userId) auth!.updateCachedFriends(data);
            },
          );
    // Loading and cache updates run after this build, outside provider notification.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _connections?.refresh();
    });
  }

  void _starsChanged() {
    if (mounted && _sort == 'for-you' && !_savedOnly) _refresh();
  }

  void _blockedChanged() {
    if (mounted) {
      setState(() =>
          _items.removeWhere((item) => SafetyService.isBlocked(item.userId)));
    }
  }

  @override
  void dispose() {
    StarredPeople.instance.removeListener(_starsChanged);
    _newPostsTimer?.cancel();
    _connections?.dispose();
    SafetyService.changes.removeListener(_blockedChanged);
    super.dispose();
  }

  Future<void> _settings() async {
    if (_savingSetting) return;
    final generation = ++_settingsGeneration;
    try {
      final value = await widget.service.sharing();
      if (mounted && generation == _settingsGeneration) {
        setState(() {
          _sharing = value;
          _settingsError = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _settingsGeneration) {
        setState(() => _settingsError = 'Couldn’t load sharing settings.');
      }
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _load(),
      _settings(),
      if (_connections != null) _connections!.refresh()
    ]);
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loadingMore || _loading || _cursor == null)) return;
    final generation = more ? _generation : ++_generation;
    setState(() {
      _error = null;
      if (more) {
        _loadingMore = true;
      } else {
        _loading = true;
        _loadingMore = false;
      }
    });
    try {
      final page = _following && !_savedOnly
          ? await widget.service.following(
              cursor: more ? _cursor : null, filter: _filter, sort: _sort)
          : await widget.service.load(
              cursor: more ? _cursor : null,
              filter: _filter,
              sort: _sort,
              saved: _savedOnly);
      if (!mounted || generation != _generation) return;
      setState(() {
        if (!more) {
          _items.clear();
          _newPosts = false;
        }
        final keys = _items.map((i) => '${i.type.value}:${i.id}').toSet();
        _items.addAll(page.items.where((i) =>
            !SafetyService.isBlocked(i.userId) &&
            keys.add('${i.type.value}:${i.id}')));
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Couldn’t load Around Flixie.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _checkNewPosts() async {
    if (_checking ||
        _loading ||
        _savedOnly ||
        (_sort != 'latest' && _sort != 'for-you') ||
        _items.isEmpty ||
        !(ModalRoute.of(context)?.isCurrent ?? true)) {
      return;
    }
    _checking = true;
    final generation = _generation;
    try {
      final page = _following
          ? await widget.service.following(filter: _filter, sort: _sort)
          : await widget.service.load(filter: _filter, sort: _sort);
      if (mounted &&
          generation == _generation &&
          page.items.isNotEmpty &&
          '${page.items.first.type.value}:${page.items.first.id}' !=
              '${_items.first.type.value}:${_items.first.id}') {
        setState(() => _newPosts = true);
      }
    } catch (_) {/* Keep the current feed readable when offline. */} finally {
      _checking = false;
    }
  }

  Future<void> _hide(ActivityListItem item, String action) async {
    try {
      await widget.service.feedPreference(item, action);
      if (mounted) {
        setState(() => _items.removeWhere((p) => action == 'mute'
            ? p.userId == item.userId
            : p.id == item.id && p.type == item.type));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t update your feed. Try again.')));
      }
    }
  }

  Future<void> _setSharing(bool value) async {
    ++_settingsGeneration;
    setState(() {
      _savingSetting = true;
      _settingsError = null;
    });
    try {
      await widget.service.setSharing(value);
      if (!mounted) return;
      setState(() => _sharing = value);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _settingsError = 'Sharing wasn’t changed. Try again.');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t update sharing. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _savingSetting = false);
    }
  }

  void _query({String? filter, String? sort, bool? saved}) {
    setState(() {
      _filter = filter ?? _filter;
      _sort = sort ?? _sort;
      _savedOnly = saved ?? _savedOnly;
      _cursor = null;
    });
    _load();
  }

  Future<void> showSettings() async {
    if (_sharing == null) await _settings();
    if (!mounted) return;
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
            builder: (sheetContext, update) => SizedBox(
                height: MediaQuery.sizeOf(sheetContext).height * .8,
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Expanded(
                                child: Text('Around Flixie sharing',
                                    style: TextStyle(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800))),
                            IconButton(
                                tooltip: 'Close settings',
                                onPressed: () => Navigator.pop(sheetContext),
                                icon: const Icon(Icons.close))
                          ]),
                          const Text(
                              'Share your existing and future film and show reviews, including ratings, and public personal lists with everyone on Flixie. Watch history, watchlists and watch plans stay out of Around Flixie. Turning this off stops sharing reviews and lists through Around Flixie and community review feeds; Friends is unchanged. Discussions and public replies you publish are separate and remain until you delete them.'),
                          if (_settingsError != null)
                            TextButton(
                                onPressed: () async {
                                  await _settings();
                                  if (sheetContext.mounted) update(() {});
                                },
                                child: Text('$_settingsError Retry')),
                          SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Share on Around Flixie'),
                              value: _sharing ?? false,
                              onChanged: _sharing == null || _savingSetting
                                  ? null
                                  : (value) async {
                                      final pending = _setSharing(value);
                                      update(() {});
                                      await pending;
                                      if (sheetContext.mounted) update(() {});
                                    }),
                          CommunityPreferences(service: widget.service),
                        ])))));
  }

  Future<void> _postOptions(ActivityListItem item) async {
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (sheet) => ConstrainedBox(
            constraints:
                BoxConstraints(maxHeight: MediaQuery.sizeOf(sheet).height * .7),
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.mediaTitle ?? item.listName ?? 'Post options',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700)),
                      TextButton.icon(
                          onPressed: () {
                            Navigator.pop(sheet);
                            context.push(widget.service.postPath(item));
                          },
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('View post')),
                      TextButton.icon(
                          icon: const Icon(Icons.visibility_off_outlined),
                          label: const Text('Hide this post'),
                          onPressed: () {
                            Navigator.pop(sheet);
                            _hide(item, 'hide');
                          }),
                      TextButton.icon(
                          icon: const Icon(Icons.person_off_outlined),
                          label: const Text('Show less from this person'),
                          onPressed: () {
                            Navigator.pop(sheet);
                            _hide(item, 'mute');
                          }),
                      if (item.movieId != null || item.showId != null)
                        CommunityWatchlistButton(item: item),
                      if (item.userId !=
                          context.read<AuthProvider?>()?.dbUser?.id)
                        TextButton.icon(
                            icon: const Icon(Icons.flag_outlined),
                            label: const Text('Report or block'),
                            onPressed: () {
                              Navigator.pop(sheet);
                              SafetyActions.contentMenu(context,
                                  targetType: item.type ==
                                          ActivityListType.movieReview
                                      ? 'MOVIE_REVIEW'
                                      : item.type == ActivityListType.showReview
                                          ? 'SHOW_REVIEW'
                                          : 'MOVIE_LIST',
                                  targetId: item.id,
                                  reportedUserId: item.userId,
                                  username: item.username,
                                  contentPreview: item.reviewData?.body ??
                                      item.listName ??
                                      '');
                            }),
                    ]))));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FlixieRefresh(
        onRefresh: _refresh,
        child: ListView(
          key: PageStorageKey('community-feed-${widget.initialFollowing}'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            if (widget.showAudienceSelector)
              Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FlixiePill.choice(
                        label: const Text('Discover'),
                        selected: !_following,
                        onSelected: (_) {
                          setState(() => _following = false);
                          _query(saved: false);
                        }),
                    FlixiePill.choice(
                        label: const Text('Following'),
                        selected: _following,
                        onSelected: (_) {
                          setState(() => _following = true);
                          _query(saved: false);
                        }),
                    TextButton.icon(
                        onPressed: () => context.push('/community/people'),
                        icon: const Icon(Icons.people_outline),
                        label: const Text('Find people')),
                  ]),
            if (_newPosts)
              Align(
                  alignment: Alignment.center,
                  child: TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.arrow_upward),
                      label: const Text('New posts available'))),
            Row(children: [
              Expanded(
                  child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        for (final entry in const {
                          'all': 'All',
                          'films': 'Films',
                          'shows': 'Shows',
                          'lists': 'Lists'
                        }.entries)
                          Semantics(
                              selected: !_savedOnly && _filter == entry.key,
                              child: TextButton(
                                  onPressed: () =>
                                      _query(filter: entry.key, saved: false),
                                  style: TextButton.styleFrom(
                                      foregroundColor: !_savedOnly && _filter == entry.key
                                          ? context.colors.textPrimary
                                          : context.colors.light,
                                      shape: const RoundedRectangleBorder()),
                                  child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 10),
                                      decoration: BoxDecoration(
                                          border: Border(
                                              bottom: BorderSide(
                                                  width: 2,
                                                  color: !_savedOnly && _filter == entry.key ? context.colors.primaryText : Colors.transparent))),
                                      child: Text(entry.value)))),
                      ]))),
              if (widget.showSettingsButton)
                IconButton(
                    tooltip: 'Around Flixie sharing',
                    onPressed: showSettings,
                    icon: const Icon(Icons.tune)),
            ]),
            OverflowBar(
                alignment: MainAxisAlignment.spaceBetween,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  if (!_savedOnly)
                    DropdownButton<String>(
                        value: _sort,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(
                              value: 'for-you', child: Text('For you')),
                          DropdownMenuItem(
                              value: 'latest', child: Text('Latest')),
                          DropdownMenuItem(
                              value: 'popular', child: Text('Popular'))
                        ],
                        onChanged: (value) {
                          if (value != null) _query(sort: value);
                        })
                  else
                    const Text('Saved posts',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  TextButton.icon(
                      onPressed: () => _query(saved: !_savedOnly),
                      icon: Icon(
                          _savedOnly ? Icons.bookmark : Icons.bookmark_border),
                      label: const Text('Saved')),
                ]),
            Divider(
                height: 1, color: context.colors.medium.withValues(alpha: .35)),
            if (_loading && _items.isEmpty)
              const ActivityRowsSkeleton()
            else ...[
              if (_items.isEmpty && _error == null)
                Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Column(children: [
                      const Icon(Icons.public_outlined, size: 44),
                      const SizedBox(height: 16),
                      Text(
                          _savedOnly
                              ? 'Your saved posts live here'
                              : 'No posts here yet',
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text(
                          _savedOnly
                              ? 'Save reviews and public lists to find them again. Only posts that are still public can appear here.'
                              : _following
                                  ? 'Your friends appear here automatically when they share publicly. You can also follow other people from their profiles.'
                                  : 'Try another filter, or check back when people share more reviews and public lists.',
                          textAlign: TextAlign.center)
                    ])),
              for (final item in _items)
                ActivityTile(
                    key: ValueKey('community:${item.type.value}:${item.id}'),
                    item: item,
                    community: true,
                    feedStyle: true,
                    onCommunityProfile: () =>
                        context.push('/community/profiles/${item.userId}'),
                    onDiscussion: () =>
                        context.push(widget.service.postPath(item)),
                    onOptions: () => _postOptions(item),
                    headerAction: _connections == null
                        ? null
                        : CommunityFriendButton(
                            connections: _connections!,
                            author: FriendshipUser(
                                id: item.userId,
                                username: item.username,
                                firstName: item.firstName,
                                lastName: item.lastName,
                                avatar: item.avatar,
                                profileBadges: item.profileBadges)),
                    saveAction: CommunityBookmarkButton(
                        key: ValueKey(
                            'bookmark:${item.type.value}:${item.id}:$_savedOnly'),
                        item: item,
                        service: widget.service,
                        initiallySaved: _savedOnly,
                        iconOnly: true,
                        onChanged: (saved) {
                          if (!saved && _savedOnly) {
                            setState(() => _items.removeWhere(
                                (p) => p.id == item.id && p.type == item.type));
                          }
                        }),
                    detailSource: DetailSource.communityActivity),
              if (_error != null)
                Column(children: [
                  Text(_error!),
                  TextButton(
                      onPressed: () =>
                          _load(more: _items.isNotEmpty && _cursor != null),
                      child: const Text('Try again'))
                ]),
              if (_cursor != null && _error == null)
                TextButton(
                    onPressed: _loadingMore ? null : () => _load(more: true),
                    child: LoadingActionLabel(
                        loading: _loadingMore, text: 'Show more')),
            ],
          ],
        ));
  }
}
