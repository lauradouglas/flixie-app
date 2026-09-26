import 'package:flutter/material.dart';
import '../pages/community_activity_feed.dart';
import '../pages/friends_activity_feed.dart';

/// Mount scopes on first visit and retain their state and scroll position.
class SocialActivityView extends StatefulWidget {
  const SocialActivityView({super.key, this.feeds});
  final List<Widget>? feeds;
  @override
  State<SocialActivityView> createState() => _SocialActivityViewState();
}

class _SocialActivityViewState extends State<SocialActivityView> {
  int _selected = 0;
  final _visited = <int>{0};
  @override
  Widget build(BuildContext context) {
    final feeds = widget.feeds ??
        const [
          CommunityActivityFeed(
              initialFollowing: true, showAudienceSelector: false),
          FriendsActivityFeed(),
          CommunityActivityFeed(showAudienceSelector: false),
        ];
    return Column(children: [
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(spacing: 8, children: [
              for (final (index, label)
                  in ['Following', 'Friends', 'Around Flixie'].indexed)
                ChoiceChip(
                    label: Text(label),
                    selected: _selected == index,
                    onSelected: (_) => setState(() {
                          _selected = index;
                          _visited.add(index);
                        })),
            ]),
          )),
      Expanded(
          child: IndexedStack(index: _selected, children: [
        for (var i = 0; i < feeds.length; i++)
          _visited.contains(i)
              ? KeyedSubtree(
                  key: ValueKey('activity-scope-$i'), child: feeds[i])
              : const SizedBox.shrink(),
      ])),
    ]);
  }
}
