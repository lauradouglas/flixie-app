import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/features/profile/presentation/pages/milestones_screen.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';

import '../controllers/friend_profile_controller.dart';
import '../friend_profile_action_flow.dart';
import '../widgets/friend_profile_header.dart';
import '../widgets/friend_profile_content.dart';

/// Shared other-user profile. The legacy class name does not imply friendship.
class FriendProfileScreen extends StatefulWidget {
  final String userId;
  final bool previewMode;
  final bool showCommunityFollow;

  const FriendProfileScreen({
    super.key,
    required this.userId,
    this.previewMode = false,
    this.showCommunityFollow = false,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  late FriendProfileController controller;
  late FriendProfileActionFlow flow;
  @override
  void initState() {
    super.initState();
    controller = FriendProfileController(
        auth: context.read<AuthProvider>(), subjectId: widget.userId);
    flow = FriendProfileActionFlow(context, controller);
    controller.addListener(_changed);
    controller.loadAll();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant FriendProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) controller.setSubject(widget.userId);
  }

  @override
  void dispose() {
    controller.removeListener(_changed);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = controller.user;
    if (controller.userLoading) {
      return Scaffold(
          appBar: AppBar(leading: const FlixieBackButton()),
          body: const Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return Scaffold(
        appBar: AppBar(leading: const FlixieBackButton()),
        body: const Center(child: Text('This profile is unavailable.')),
      );
    }

    final watched =
        (user.watchedMovies?.length ?? 0) + (user.watchedShows?.length ?? 0);
    final watchlist =
        (user.movieWatchlist?.length ?? 0) + (user.showWatchlist?.length ?? 0);
    final favourites =
        (user.favoriteMovies?.length ?? 0) + (user.favoriteShows?.length ?? 0);

    final coverUrl = user.creatorProfile?.coverUrl;
    final hasCover = coverUrl != null;
    final toolbar = AppBar(
      leading: const FlixieBackButton(),
      backgroundColor: hasCover ? Colors.transparent : null,
      foregroundColor: hasCover ? Colors.white : null,
      surfaceTintColor: hasCover ? Colors.transparent : null,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: hasCover && !controller.isSelf
          ? null
          : Text(controller.isSelf ? 'Public profile preview' : 'Profile'),
      centerTitle: true,
      actions: [
        if (!widget.previewMode && !controller.isSelf)
          PopupMenuButton<String>(
            tooltip: 'Profile actions',
            onSelected: (action) async {
              if (action == 'wrapped') {
                context.push('/wrapped/${controller.subjectId}');
              } else if (action == 'report') {
                await SafetyActions.report(
                  context,
                  targetType: 'USER',
                  targetId: controller.subjectId,
                  reportedUserId: controller.subjectId,
                );
              } else if (action == 'block') {
                final blocked = await SafetyActions.block(
                  context,
                  userId: controller.subjectId,
                  username: user.username,
                );
                if (blocked && context.mounted) context.pop();
              } else if (action == 'remove_friend') {
                await flow.removeFriend();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'wrapped',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.auto_awesome_outlined),
                  title: Text('View Wrapped'),
                ),
              ),
              const PopupMenuItem(
                value: 'report',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Report user'),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block, color: context.colors.danger),
                  title: Text('Block user',
                      style: TextStyle(color: context.colors.danger)),
                ),
              ),
              if (controller.friendshipStatus == FriendshipStatus.friends)
                PopupMenuItem(
                  value: 'remove_friend',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.person_remove_outlined,
                        color: context.colors.danger),
                    title: Text('Remove friend',
                        style: TextStyle(color: context.colors.danger)),
                  ),
                ),
            ],
          )
        else
          const SizedBox(width: 48),
      ],
    );
    return Scaffold(
      appBar: hasCover ? null : toolbar,
      body: RefreshIndicator(
        onRefresh: controller.loadAll,
        child: ListView(
          padding: EdgeInsets.only(top: hasCover ? 0 : 8, bottom: 32),
          children: [
            if (hasCover)
              LayoutBuilder(
                key: const ValueKey('profile-cover'),
                builder: (context, constraints) {
                  final top =
                      MediaQuery.paddingOf(context).top + kToolbarHeight;
                  final imageSpace =
                      (constraints.maxWidth * .36).clamp(100.0, 200.0);
                  return Stack(children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: top + imageSpace + 88,
                      child: Stack(fit: StackFit.expand, children: [
                        CachedNetworkImage(
                          imageUrl: coverUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        ),
                        DecoratedBox(
                            decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0, .4, 1],
                            colors: [
                              Colors.black.withValues(alpha: .45),
                              context.colors.background.withValues(alpha: .3),
                              context.colors.background
                            ],
                          ),
                        )),
                      ]),
                    ),
                    Column(children: [
                      SizedBox(height: top, child: toolbar),
                      SizedBox(height: imageSpace),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FriendProfileHeader(controller: controller),
                      ),
                    ]),
                  ]);
                },
              )
            else
              FriendProfileHeader(controller: controller),
            // Notification deep links use preview mode to suppress ordinary
            // profile actions. An incoming friend request is an exception:
            // its recipient still needs the Accept / Decline decision here.
            if (!controller.isSelf &&
                (!widget.previewMode ||
                    controller.friendshipStatus ==
                        FriendshipStatus.pending)) ...[
              const SizedBox(height: 18),
              FriendProfileActions(
                  controller: controller,
                  flow: flow,
                  showCommunityFollow: widget.showCommunityFollow),
            ],
            const SizedBox(height: 20),
            if (watched + watchlist + favourites > 0)
              FriendProfileTotals(
                  key: const ValueKey("profile-totals"), user: user),
            const SizedBox(height: 12),
            if (controller.activity.isNotEmpty ||
                controller.reviews.isNotEmpty ||
                controller.activityFailed ||
                controller.reviewsFailed ||
                controller.selectedTab != 0)
              FriendProfileTabs(controller: controller),
            const SizedBox(height: 18),
            ...buildFriendProfileContent(context,
                controller: controller, previewMode: widget.previewMode),
            if (controller.isSelf ||
                controller.friendshipStatus == FriendshipStatus.friends) ...[
              const SizedBox(height: 20),
              TextButton.icon(
                icon: const Icon(Icons.workspace_premium_outlined, size: 20),
                label: const Text('View earned milestones'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MilestonesScreen(
                          userId: controller.subjectId,
                          displayName: controller.user?.username,
                          earnedOnly: true,
                        ))),
              ),
            ],
          ]
              .map((child) => child.key == const ValueKey('profile-cover')
                  ? child
                  : Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal:
                              child.key == const ValueKey('profile-totals')
                                  ? 8
                                  : 20),
                      child: child))
              .toList(),
        ),
      ),
    );
  }
}
