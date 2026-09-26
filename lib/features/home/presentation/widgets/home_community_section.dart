import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_bookmark_button.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'section_header.dart';

class HomeCommunitySection extends StatefulWidget {
  const HomeCommunitySection(
      {super.key,
      required this.userId,
      this.service = const CommunityService()});
  final String userId;
  final CommunityService service;
  @override
  State<HomeCommunitySection> createState() => HomeCommunitySectionState();
}

class HomeCommunitySectionState extends State<HomeCommunitySection> {
  List<ActivityListItem> _items = [];
  bool _loading = true, _failed = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    SafetyService.changes.addListener(_safetyChanged);
    refresh();
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_safetyChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HomeCommunitySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _items = [];
      refresh();
    }
  }

  void _safetyChanged() {
    setState(() =>
        _items.removeWhere((item) => SafetyService.isBlocked(item.userId)));
  }

  Future<void> refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _items = [];
    });
    try {
      final page = await widget.service.load();
      if (mounted && generation == _generation) {
        setState(() => _items = page.items
            .where((item) => !SafetyService.isBlocked(item.userId))
            .take(3)
            .toList());
      }
    } catch (_) {
      if (mounted && generation == _generation) setState(() => _failed = true);
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String route) async {
    await context.push(route);
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        HomeSectionHeader(
            title: 'Around Flixie',
            onSeeAll: () => _open('/friends-activity?tab=community')),
        Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (_loading)
                const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: LinearProgressIndicator())
              else if (_failed) ...[
                const Text('Couldn’t load Around Flixie.'),
                TextButton(onPressed: refresh, child: const Text('Try again'))
              ] else if (_items.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                    'No public posts yet. Discover reviews and lists shared around Flixie.'),
                TextButton(
                    onPressed: () => _open('/friends-activity?tab=community'),
                    child: const Text('Explore Around Flixie'))
              ] else
                for (final item in _items)
                  ActivityTile(
                      key: ValueKey(
                          'home-community:${item.type.value}:${item.id}'),
                      item: item,
                      community: true,
                      feedStyle: true,
                      openPostOnContent: true,
                      detailSource: DetailSource.communityActivity,
                      onCommunityProfile: () =>
                          _open('/community/profiles/${item.userId}'),
                      onDiscussion: () => _open(widget.service.postPath(item)),
                      saveAction: CommunityBookmarkButton(
                          item: item, service: widget.service, iconOnly: true),
                      onOptions: item.userId == widget.userId
                          ? null
                          : () => SafetyActions.contentMenu(context,
                              targetType:
                                  item.type == ActivityListType.movieReview
                                      ? 'MOVIE_REVIEW'
                                      : item.type == ActivityListType.showReview
                                          ? 'SHOW_REVIEW'
                                          : 'MOVIE_LIST',
                              targetId: item.id,
                              reportedUserId: item.userId,
                              username: item.username,
                              contentPreview: item.reviewData?.body ??
                                  item.listName ??
                                  '')),
            ])),
      ]);
}
