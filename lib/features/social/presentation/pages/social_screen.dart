import '../widgets/social_tablet_companion.dart';
import 'genre_communities_screen.dart';
import '../widgets/social_activity_view.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/social/presentation/widgets/segmented_toggle.dart';

import '../widgets/social_people_view.dart';
import '../widgets/social_groups_view.dart';
import '../widgets/social_messages_button.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key, this.initialTab = 1});
  final int initialTab;

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  int _selectedTab =
      1; // Legacy IDs: People 0, Activity 1, Groups 3, Communities 4
  final _visited = <int>{};
  final _feedKey = GlobalKey();
  String? _viewer;
  int _refreshRevision = 0;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 2 ? 1 : widget.initialTab;
    _visited.add(_selectedTab);
    TabRefreshController.social.addListener(_onSocialTabRefresh);
  }

  @override
  void didUpdateWidget(covariant SocialScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      _selectedTab = widget.initialTab == 2 ? 1 : widget.initialTab;
      _visited.add(_selectedTab);
    }
  }

  @override
  void dispose() {
    TabRefreshController.social.removeListener(_onSocialTabRefresh);
    super.dispose();
  }

  void _onSocialTabRefresh() {
    if (mounted) setState(() => _refreshRevision++);
  }

  @override
  Widget build(BuildContext context) {
    final viewer =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    if (_viewer != viewer) {
      _viewer = viewer;
      _visited
        ..clear()
        ..add(_selectedTab);
    }
    return FlixiePageScaffold(
      adaptiveContent: true,
      appBar: FlixieTitleAppBar(
        title: Text(
          'Social',
          style: TextStyle(
            color: context.colors.light,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          SocialMessagesButton(),
        ],
      ),
      body: Column(
        children: [
          SocialSegmentedToggle(
            selectedIndex: const [1, 0, 3, 4].indexOf(_selectedTab),
            labels: const ['Activity', 'People', 'Groups', 'Communities'],
            onChanged: (i) => setState(() {
              _selectedTab = const [1, 0, 3, 4][i];
              _visited.add(_selectedTab);
            }),
          ),
          if (_selectedTab == 1 || _selectedTab == 0)
            Padding(
                padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                child: Row(children: [
                  Expanded(
                      child: Text(
                          _selectedTab == 0 ? 'Your people' : 'Activity feed',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: context.colors.white))),
                  TextButton.icon(
                      onPressed: () => context.push('/plans'),
                      icon: const Icon(Icons.event_outlined, size: 19),
                      label:
                          const Text('Plans', style: TextStyle(fontSize: 14))),
                ])),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              final feed = ClipRect(
                key: _feedKey,
                child: Material(
                  type: MaterialType.transparency,
                  child: IndexedStack(
                    key: ValueKey('social:$viewer'),
                    index: _selectedTab,
                    children: [
                      _visited.contains(0)
                          ? SocialPeopleView(
                              key: ValueKey('people:$_refreshRevision'),
                              active: _selectedTab == 0)
                          : const SizedBox.shrink(),
                      _visited.contains(1)
                          ? SocialActivityView(active: _selectedTab == 1)
                          : const SizedBox.shrink(),
                      const SizedBox.shrink(),
                      _visited.contains(3)
                          ? SocialGroupsView(
                              key: ValueKey('groups:$_refreshRevision'))
                          : const SizedBox.shrink(),
                      _visited.contains(4)
                          ? GenreCommunitiesView(
                              key: ValueKey(
                                  'communities:${context.watch<AuthProvider>().dbUser?.id}'))
                          : const SizedBox.shrink(),
                    ],
                  ),
                ),
              );
              if (constraints.maxWidth < 900 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.4 ||
                  _selectedTab != 1) {
                return feed;
              }
              return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 2, child: feed),
                    const SizedBox(width: 16),
                    Expanded(
                        child: SocialTabletCompanion(
                            key: ValueKey('social-plans:$viewer'))),
                  ]);
            }),
          ),
        ],
      ),
    );
  }
}
