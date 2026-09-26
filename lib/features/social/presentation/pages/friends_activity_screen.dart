import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'friends_activity_feed.dart';
import 'package:flixie_app/features/social/data/community_service.dart';
import 'community_activity_feed.dart';

class FriendsActivityScreen extends StatefulWidget {
  const FriendsActivityScreen(
      {super.key,
      this.communityService = const CommunityService(),
      this.initialCommunity = false});
  final CommunityService communityService;
  final bool initialCommunity;
  @override
  State<FriendsActivityScreen> createState() => _FriendsActivityScreenState();
}

class _FriendsActivityScreenState extends State<FriendsActivityScreen> {
  bool _settingsPending = false;
  final _communityKey = GlobalKey<CommunityActivityFeedState>();
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      initialIndex: widget.initialCommunity ? 1 : 0,
      child: Builder(
          builder: (context) => FlixiePageScaffold(
                appBar: FlixieTitleAppBar(
                    title: const Text('Activity'),
                    actions: [
                      IconButton(
                          tooltip: 'Around Flixie sharing',
                          onPressed: () {
                            DefaultTabController.of(context).animateTo(1);
                            final feed = _communityKey.currentState;
                            if (feed != null) {
                              feed.showSettings();
                            } else {
                              _settingsPending = true;
                            }
                          },
                          icon: const Icon(Icons.tune))
                    ],
                    bottom: const TabBar(
                        dividerColor: Colors.transparent,
                        tabs: [Tab(text: 'Friends'), Tab(text: 'Around Flixie')])),
                body: TabBarView(children: [
                  const FriendsActivityFeed(),
                  CommunityActivityFeed(
                      key: _communityKey,
                      onReady: () {
                        if (_settingsPending && mounted) {
                          _settingsPending = false;
                          _communityKey.currentState?.showSettings();
                        }
                      },
                      service: widget.communityService,
                      showSettingsButton: false)
                ]),
              )));
}
