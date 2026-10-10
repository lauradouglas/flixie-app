import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import '../../data/starred_people.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class FriendsActivityFeed extends StatefulWidget {
  const FriendsActivityFeed({super.key});

  @override
  State<FriendsActivityFeed> createState() => _FriendsActivityFeedState();
}

class _FriendsActivityFeedState extends State<FriendsActivityFeed> {
  List<ActivityListItem> _items = const [];
  bool _loading = true;
  String? _error;
  int _generation = 0;
  String? _viewer;
  bool _viewerKnown = false;

  @override
  void initState() {
    super.initState();
    StarredPeople.instance.addListener(_starsChanged);
    final cached = context.read<AuthProvider>().cachedFriendsActivity;
    if (cached != null) {
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      _items = cached.where((item) {
        final timestamp = DateTime.tryParse(item.timestamp);
        return timestamp == null || timestamp.isAfter(cutoff);
      }).toList();
      _loading = false;
    }
    _load(showSpinner: cached == null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewer = context.watch<AuthProvider>().dbUser?.id;
    final changed = _viewerKnown && _viewer != viewer;
    _viewerKnown = true;
    _viewer = viewer;
    if (!changed) return;
    _generation++;
    _items = const [];
    _loading = viewer != null;
    _error = null;
    if (viewer != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load(showSpinner: true);
      });
    }
  }

  void _starsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    StarredPeople.instance.removeListener(_starsChanged);
    super.dispose();
  }

  Future<void> _load({bool showSpinner = false}) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    final generation = ++_generation;
    bool owns() =>
        mounted && generation == _generation && auth.dbUser?.id == userId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (showSpinner) setState(() => _loading = true);
    setState(() => _error = null);
    try {
      final items = await FriendService.getFriendsActivityLists(
        userId,
        days: 14,
        limit: 100,
        cachedFriends: auth.cachedFriends,
      );
      if (owns()) {
        setState(() => _items = items);
      }
    } catch (_) {
      if (owns() && _items.isEmpty) {
        setState(() => _error = 'Couldn\'t load friend activity.');
      }
    } finally {
      if (owns()) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ranked = StarredPeople.instance.rank(_items);
    return FlixieRefresh(
      onRefresh: () => _load(),
      child: _loading
          ? ListView(
              padding: const EdgeInsets.all(16),
              children: const [ActivityRowsSkeleton(), ActivityRowsSkeleton()])
          : _error != null
              ? ListView(
                  children: [
                    const SizedBox(height: 180),
                    Center(child: Text(_error!)),
                    TextButton(
                        onPressed: _load, child: const Text('Try again')),
                  ],
                )
              : _items.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 160),
                        Icon(Icons.people_outline_rounded,
                            size: 52, color: context.colors.medium),
                        const SizedBox(height: 12),
                        Text(
                          'No friend activity in the last two weeks.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: context.colors.medium),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                      itemCount: ranked.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, index) {
                        return ActivityTile(
                          feedStyle: true,
                          item: ranked[index],
                          detailSource: DetailSource.friendActivity,
                        );
                      },
                    ),
    );
  }
}
