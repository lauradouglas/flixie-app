import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import '../../data/people_cache.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/starred_people.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../data/community_service.dart';

/// Private account-synced stars; no public friendship ranking.
class PeopleDirectory extends StatefulWidget {
  const PeopleDirectory(
      {super.key,
      required this.userId,
      required this.friends,
      this.service = const CommunityService()});
  final String userId;
  final List<FriendshipUser> friends;
  final CommunityService service;
  @override
  State<PeopleDirectory> createState() => _PeopleDirectoryState();
}

class _PeopleDirectoryState extends State<PeopleDirectory>
    with WidgetsBindingObserver {
  Set<String> get _stars => StarredPeople.instance.ids;
  List<FriendshipUser> _following = [];
  String _query = '';
  bool _showFollowing = false,
      _loading = false,
      _failed = false,
      _saving = false;
  bool _starsFailed = false;
  final Set<String> _busy = {};
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PeopleCache.instance.selectAccount(widget.userId);
    StarredPeople.instance.addListener(_starsChanged);
    _readStars();
    _following = List.of(PeopleCache.instance.following ?? []);
    PeopleCache.instance.addListener(_cacheChanged);
    _loadFollowing();
  }

  @override
  void didUpdateWidget(covariant PeopleDirectory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.friends, widget.friends)) _readStars();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _readStars();
  }

  void _starsChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _readStars() async {
    final userId = widget.userId;
    try {
      await StarredPeople.instance.refresh();
      if (mounted && widget.userId == userId) {
        setState(() => _starsFailed = false);
      }
    } catch (error) {
      // Social can stay mounted behind Home. Keep background failures in the
      // directory instead of posting a snackbar over an unrelated screen.
      apiLogger.w(
          'Starred people sync failed (${error is ApiException ? error.statusCode : error.runtimeType})');
      if (mounted && widget.userId == userId) {
        setState(() => _starsFailed = true);
      }
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  Future<void> _star(String id) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await StarredPeople.instance.setStar(id, !_stars.contains(id));
    } catch (_) {
      if (mounted) _message('Couldn’t save starred friends. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _cacheChanged() {
    if (!mounted) return;
    setState(() {
      _following = List.of(PeopleCache.instance.following ?? []);
      _loading = false;
      _failed = PeopleCache.instance.failed;
    });
  }

  @override
  void dispose() {
    PeopleCache.instance.removeListener(_cacheChanged);
    StarredPeople.instance.removeListener(_starsChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadFollowing({bool refresh = false}) async {
    if (PeopleCache.instance.following == null) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    await PeopleCache.instance
        .load(widget.service.followedPeople, refresh: refresh);
    _cacheChanged();
  }

  Future<void> _unfollow(FriendshipUser person) async {
    if (_busy.contains(person.id)) return;
    setState(() => _busy.add(person.id));
    try {
      await widget.service.follow('profiles/${person.id}', false);
      if (mounted) {
        setState(() => _following.removeWhere((u) => u.id == person.id));
      }
    } catch (_) {
      if (mounted) _message('Couldn’t unfollow. Try again.');
    } finally {
      if (mounted) setState(() => _busy.remove(person.id));
    }
  }

  String _name(FriendshipUser u) => [u.firstName, u.lastName]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .join(' ')
          .trim()
          .isEmpty
      ? u.username
      : [u.firstName, u.lastName].whereType<String>().join(' ').trim();
  Widget _row(FriendshipUser u) {
    final isFriend = widget.friends.any((f) => f.id == u.id);
    return Row(children: [
      Expanded(
          child: InkWell(
        onTap: () async {
          await context.push('/community/profiles/${u.id}');
          if (mounted && _showFollowing) _loadFollowing(refresh: true);
        },
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              ProfileAvatarView(
                  avatar: u.avatar,
                  fallbackColor: Theme.of(context).colorScheme.primary,
                  fallbackText: u.username.isEmpty ? '?' : u.username[0],
                  size: 44,
                  profileBadges: u.profileBadges),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(_name(u),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                        '@${u.username}${_showFollowing && isFriend ? ' · Friends' : ''}',
                        style: Theme.of(context).textTheme.bodySmall),
                  ])),
            ])),
      )),
      if (_showFollowing)
        _busy.contains(u.id)
            ? const SizedBox(
                width: 44,
                height: 44,
                child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2)))
            : PopupMenuButton<String>(
                tooltip: 'Following ${u.username}',
                onSelected: (_) => _unfollow(u),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'unfollow', child: Text('Unfollow'))
                ],
                child: MediaQuery.sizeOf(context).width < 400 ||
                        MediaQuery.textScalerOf(context).scale(14) > 18
                    ? const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(Icons.person_outline))
                    : const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('Following'),
                          Icon(Icons.expand_more, size: 18)
                        ])),
              ),
      IconButton(
          tooltip: _stars.contains(u.id)
              ? 'Unstar ${u.username}'
              : 'Star ${u.username}',
          onPressed: _saving ? null : () => _star(u.id),
          icon: Icon(
              _stars.contains(u.id)
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: _stars.contains(u.id) ? Colors.amber : null)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final people = (_showFollowing ? _following : widget.friends)
        .where(
            (u) => '${_name(u)} ${u.username}'.toLowerCase().contains(_query))
        .toList()
      ..sort((a, b) {
        final priority =
            (_stars.contains(b.id) ? 1 : 0) - (_stars.contains(a.id) ? 1 : 0);
        return _showFollowing && priority != 0
            ? priority
            : _name(a).toLowerCase().compareTo(_name(b).toLowerCase());
      });
    final starred = people.where((u) => _stars.contains(u.id)).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
          decoration: const InputDecoration(
              hintText: 'Search people', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _query = v.trim().toLowerCase())),
      const SizedBox(height: 12),
      Wrap(spacing: 8, children: [
        ChoiceChip(
            label: Text('Friends ${widget.friends.length}'),
            selected: !_showFollowing,
            onSelected: (_) => setState(() => _showFollowing = false)),
        ChoiceChip(
            label: const Text('Following'),
            selected: _showFollowing,
            onSelected: (_) {
              setState(() => _showFollowing = true);
              _loadFollowing();
            }),
      ]),
      const SizedBox(height: 16),
      if (_starsFailed)
        Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              const Text('Couldn’t sync starred people.'),
              TextButton(onPressed: _readStars, child: const Text('Retry')),
            ]),
      if (_showFollowing) ...[
        const Text('People whose posts appear in your Following feed'),
        if (_loading && _following.isEmpty)
          const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()))
        else if (_failed && PeopleCache.instance.following == null)
          TextButton(
              onPressed: _loadFollowing,
              child: const Text('Couldn’t load following. Retry'))
        else
          ...people.map(_row),
        if (!_loading && !_failed && people.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('No people found.')),
        const SizedBox(height: 12),
        const Text('Unfollowing a friend keeps your friendship.'),
      ] else ...[
        if (starred.isNotEmpty) ...[
          const Text('Starred', style: TextStyle(fontWeight: FontWeight.w700)),
          ...starred.map(_row),
          const Divider()
        ],
        const Text('All friends · A–Z',
            style: TextStyle(fontWeight: FontWeight.w700)),
        ...people.where((u) => !_stars.contains(u.id)).map(_row),
        if (people.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                  'No friends found. Find friends using the button above.')),
      ],
    ]);
  }
}
