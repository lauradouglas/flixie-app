import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_reaction_bubble.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/activity_filter_bar.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_activity_card.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';

class GroupActivityTab extends StatefulWidget {
  const GroupActivityTab({
    super.key,
    required this.group,
    required this.memberCount,
    required this.groupId,
    this.conversationId,
    required this.initialRequests,
    required this.initialActivity,
    required this.groupLists,
    required this.onRefresh,
  });

  final Group? group;
  final int memberCount;
  final String groupId;
  final String? conversationId;
  final List<GroupWatchRequest> initialRequests;
  final List<ActivityListItem> initialActivity;
  final List<MovieList> groupLists;
  final Future<void> Function() onRefresh;

  @override
  State<GroupActivityTab> createState() => GroupActivityTabState();
}

class GroupActivityTabState extends State<GroupActivityTab>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  bool _searchOpen = false, _loading = false, _creating = false;
  String? _reactionError;
  late List<ActivityListItem> _activity;
  Future<void>? _feedRequest;
  String? _feedGroupId;
  String _newListName = 'Our watchlist';
  int _feedGeneration = 0;
  ActivityFeedFilter _filter = ActivityFeedFilter.all;
  Map<String, ActivityReactionSummary> _reactions = {};
  final Set<String> _saving = {};
  String _key(ActivityListItem item) => '${item.type.value}:${item.id}';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SafetyService.changes.addListener(_onSafetyChanged);
    _activity = widget.initialActivity;
    _loadFeed();
  }

  void _onSafetyChanged() {
    if (!mounted) return;
    // Hide cached content immediately, even while a refresh is in flight.
    setState(() {});
    _loadFeed();
  }

  @override
  void didUpdateWidget(covariant GroupActivityTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      _reactions = {};
      _activity = widget.initialActivity;
      _saving.clear();
    }
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.initialActivity != widget.initialActivity) {
      _loadFeed();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadFeed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SafetyService.changes.removeListener(_onSafetyChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFeed() {
    if (_feedRequest != null && _feedGroupId == widget.groupId) {
      return _feedRequest!;
    }
    _feedGroupId = widget.groupId;
    final request = _fetchFeed();
    _feedRequest = request;
    return request.whenComplete(() {
      if (identical(_feedRequest, request)) _feedRequest = null;
    });
  }

  Future<void> _fetchFeed() async {
    final generation = ++_feedGeneration;
    try {
      final result = await GroupService.getGroupActivityFeed(widget.groupId);
      if (!mounted || generation != _feedGeneration) return;
      setState(() {
        _reactions = {
          ...result.reactions,
          for (final key in _saving)
            key: _reactions[key] ?? const ActivityReactionSummary()
        };
        _activity = result.items;
        _reactionError =
            result.reactionsUnavailable ? 'Couldn’t load reactions' : null;
      });
    } catch (error) {
      logger.w('[Group activity] Feed failed: $error');
      if (mounted && generation == _feedGeneration) {
        setState(() {
          if (error is ApiException &&
              (error.statusCode == 401 || error.statusCode == 403)) {
            _activity = [];
            _reactions = {};
          }
          _reactionError = 'Couldn’t refresh activity';
        });
      }
    }
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await Future.wait([widget.onRefresh(), _loadFeed()]);
    } catch (_) {
      if (mounted) _error('Couldn’t refresh activity', _refresh);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error(String text, VoidCallback retry) =>
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: Text(text),
          action: SnackBarAction(label: 'Retry', onPressed: retry)));

  void _reply(ActivityListItem item) {
    final payload = ActivityReplyPayload.fromActivity(item);
    context.push('/chat/${item.userId}',
        extra: payload.isUsable ? payload : null);
  }

  Future<void> _chooseReaction(
      ActivityListItem item, BuildContext anchor) async {
    final current = _reactions[_key(item)]?.mine;
    final selected = await showActivityReactionBubble(context, anchor,
        current: current,
        canReply: item.userId != context.read<AuthProvider>().dbUser?.id);
    if (!mounted) return;
    if (selected == 'reply') {
      _reply(item);
    } else if (selected is ActivityReaction) {
      await _saveReaction(
          item, selected.emoji == current ? null : selected.emoji);
    }
  }

  Future<void> _saveReaction(ActivityListItem item, String? emoji) async {
    final groupId = widget.groupId;
    final key = _key(item);
    if (_saving.contains(key)) return;
    final previous = _reactions[key] ?? const ActivityReactionSummary();
    ++_feedGeneration;
    setState(() {
      _saving.add(key);
      _reactions[key] = previous.selecting(emoji);
    });
    try {
      final result =
          await GroupService.setActivityReaction(groupId, item, emoji);
      if (mounted && widget.groupId == groupId) {
        setState(() => _reactions[key] = result);
      }
    } catch (_) {
      if (mounted && widget.groupId == groupId) {
        setState(() => _reactions[key] = previous);
        _error('Couldn’t save your reaction', () {
          if (mounted && widget.groupId == groupId) _saveReaction(item, emoji);
        });
      }
    } finally {
      if (mounted && widget.groupId == groupId) {
        setState(() => _saving.remove(key));
      }
    }
  }

  void _openList(MovieList list) => context.push(
      '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&isOwner=${list.isOwner}&canEdit=${list.canEdit}');
  Future<void> _createList() async {
    if (_creating) return;
    final controller = TextEditingController(text: _newListName);
    final name = await showModalBottomSheet<String>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * .85),
            child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 24, 20, 24 + MediaQuery.viewInsetsOf(context).bottom),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Create a shared list',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: controller,
                          maxLength: 100,
                          decoration:
                              const InputDecoration(labelText: 'List name'),
                          autofocus: true),
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                              onPressed: () {
                                if (controller.text.trim().isNotEmpty) {
                                  Navigator.pop(
                                      context, controller.text.trim());
                                }
                              },
                              child: const Text('Create list'))),
                    ]))));
    // The route may still be animating out; disposal occurs after the animation.
    Future<void>.delayed(const Duration(milliseconds: 400), controller.dispose);
    if (!mounted || name == null) return;
    _newListName = name;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    setState(() => _creating = true);
    try {
      final list = await UserService.createMovieList(
          userId,
          CreateMovieListRequest(
              name: name,
              scope: ListScope.group,
              groupId: widget.groupId,
              whoCanAddMovies: 'members'));
      if (!mounted) return;
      await widget.onRefresh();
      if (mounted) _openList(list);
    } catch (_) {
      if (mounted) _error('Couldn’t create your shared list', _createList);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _openMedia(ActivityListItem item) {
    if (item.movieId != null) {
      context.push('/movies/${item.movieId}');
    } else if (item.showId != null) {
      context.push('/shows/${item.showId}');
    } else if (item.personId != null) {
      context.push('/people/${item.personId}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final items = _activity
        .where((item) =>
            !SafetyService.isBlocked(item.userId) &&
            _filter.matches(item) &&
            (query.isEmpty ||
                (item.mediaTitle ?? '').toLowerCase().contains(query) ||
                item.username.toLowerCase().contains(query)))
        .toList();
    final userId = context.read<AuthProvider>().dbUser?.id;
    return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            WatchPlanSurface(
                child: Row(children: [
              const Icon(Icons.list_alt_rounded,
                  color: FlixieColors.primary, size: 32),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Your group’s shared list',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary)),
                    const SizedBox(height: 4),
                    Text('Save films to choose together',
                        style: TextStyle(color: context.colors.light)),
                  ])),
              const SizedBox(width: 10),
              FilledButton(
                  onPressed: _creating
                      ? null
                      : widget.groupLists.isEmpty
                          ? _createList
                          : () => _openList(widget.groupLists.first),
                  child: Text(widget.groupLists.isEmpty ? 'Create' : 'Open')),
            ])),
            if (widget.groupLists.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Wrap(spacing: 8, runSpacing: 6, children: [
                    for (final list in widget.groupLists)
                      FlixiePill.action(
                          label: Text(list.name),
                          onPressed: () => _openList(list)),
                    FlixiePill.action(
                        label: const Text('New list'),
                        avatar: const Icon(Icons.add, size: 18),
                        onPressed: _creating ? null : _createList),
                  ])),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(
                  child: Text('Latest activity',
                      style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.colors.textPrimary))),
              IconButton.outlined(
                  tooltip: 'Search activity',
                  onPressed: () => setState(() {
                        _searchOpen = !_searchOpen;
                        if (!_searchOpen) _searchController.clear();
                      }),
                  icon: const Icon(Icons.search)),
            ]),
            if (_searchOpen)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                          hintText: 'Search titles or people',
                          prefixIcon: Icon(Icons.search)))),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final filter in [
                ActivityFeedFilter.all,
                ActivityFeedFilter.watched,
                ActivityFeedFilter.rated,
                ActivityFeedFilter.reviews
              ])
                FlixiePill.choice(
                    label: Text(filter.label),
                    selected: filter == _filter,
                    showCheckmark: false,
                    onSelected: (_) => setState(() => _filter = filter)),
            ]),
            if (_reactionError != null)
              TextButton.icon(
                  onPressed: _loadFeed,
                  icon: const Icon(Icons.refresh),
                  label: Text('$_reactionError · Retry')),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  child: Text('No activity to show yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colors.light))),
            for (final item in items)
              Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: GroupActivityCard(
                    key: ValueKey(_key(item)),
                    item: item,
                    reactions: _reactions[_key(item)] ??
                        const ActivityReactionSummary(),
                    busy: _saving.contains(_key(item)),
                    onReact: item.userId == userId
                        ? null
                        : (anchor) => _chooseReaction(item, anchor),
                    onReactionSelected: item.userId == userId
                        ? null
                        : (emoji) => _saveReaction(item, emoji),
                    onOpen: item.movieId != null ||
                            item.showId != null ||
                            item.personId != null
                        ? () => _openMedia(item)
                        : null,
                    onProfile: () => context.push('/friends/${item.userId}'),
                    onReply: item.userId == userId ? null : () => _reply(item),
                  )),
          ],
        ));
  }
}
