import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../controllers/watch_composer_controller.dart';
import 'composer_components.dart';
import 'composer_provider_matches.dart';

class ComposerLocation extends StatelessWidget {
  const ComposerLocation({super.key, required this.controller});
  final WatchComposerController controller;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const PlanStepHeading(number: '3', title: 'Where?'),
        const SizedBox(height: 10),
        Row(children: [
          for (final contextOption in WatchContext.values)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: contextOption == WatchContext.undecided ? 0 : 8,
                ),
                child: ModeTab(
                  label: switch (contextOption) {
                    WatchContext.home => 'At home',
                    WatchContext.cinema => 'Cinema',
                    WatchContext.undecided => 'Decide later',
                  },
                  icon: switch (contextOption) {
                    WatchContext.home => Icons.home_outlined,
                    WatchContext.cinema => Icons.theaters_outlined,
                    WatchContext.undecided => Icons.more_horiz_rounded,
                  },
                  selected: controller.watchContext == contextOption,
                  onTap: () => controller.setWatchContext(contextOption),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 12),
        if (controller.watchContext == WatchContext.home)
          WatchRequestProviders(
            providers:
                controller.providers.forMovie(controller.selectedMovieId),
            movieTitle: controller.movieChoices
                .where((movie) => movie.id == controller.selectedMovieId)
                .map((movie) => movie.name)
                .firstOrNull,
            myProviderIds: controller.providers.myIds,
            friendProviderIds: controller.providers.friendIds,
            friendName: controller.selectedFriendName,
            loading: controller.providers.loadingSelf ||
                controller.providers.movieLoading(controller.selectedMovieId),
            loadingFriend: controller.providers.loadingFriend,
            showFriendMatch:
                !controller.isGroupMode && controller.selectedFriendId != null,
            groupMode: controller.isGroupMode,
            groupSelected: controller.selectedGroupId != null,
            groupProviderCounts: controller.providers.groupCounts,
            groupProviderNameCounts: controller.providers.groupNameCounts,
            groupMemberCount: controller.providers.groupMemberCount,
            loadingGroup: controller.providers.loadingGroup,
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: FlixieColors.primary.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(12)),
            child: Text(
              controller.watchContext == WatchContext.cinema
                  ? 'Cinema plan - streaming providers won’t be checked.'
                  : 'You can decide where to watch together later.',
              style: TextStyle(color: context.colors.secondary, fontSize: 13),
            ),
          ),
      ]);
}
