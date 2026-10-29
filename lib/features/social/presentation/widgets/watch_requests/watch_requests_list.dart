import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_section_builder.dart';

import '../../controllers/watch_requests_controller.dart';
import '../../widgets/watch_requests/watch_request_controls.dart';

class WatchRequestsList extends StatelessWidget {
  const WatchRequestsList(
      {super.key,
      required this.controller,
      required this.isFocused,
      required this.searchController,
      required this.buildCard});
  final WatchRequestsController controller;
  final bool isFocused;
  final TextEditingController searchController;
  final Widget Function(WatchRequest, bool, String) buildCard;
  @override
  Widget build(BuildContext context) {
    if (controller.loading) return const WatchRequestsSkeleton();
    if (controller.error != null || controller.filtered.isEmpty) {
      return FlixieRefresh(
          onRefresh: controller.load,
          child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                    hasScrollBody: false,
                    child: controller.error != null
                        ? _buildError(context)
                        : _buildEmpty(context))
              ]));
    }
    final myUserId = controller.viewer ?? '';
    final filtered = controller.filtered;
    if (isFocused ||
        controller.filter != WatchPlanFilter.active ||
        searchController.text.trim().isNotEmpty) {
      return FlixieRefresh(
        onRefresh: controller.load,
        color: FlixieColors.primary,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
              isFocused ? 0 : 16, isFocused ? 0 : 16, isFocused ? 0 : 16, 24),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, index) =>
              buildCard(filtered[index], isFocused, myUserId),
        ),
      );
    }

    final sections = WatchPlanSectionBuilder.friendSections(
      controller.filtered,
      myUserId,
    );

    Widget section(String title, String subtitle, List<WatchRequest> items) =>
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          WatchRequestSectionHeader(
              title: title, subtitle: subtitle, count: items.length),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: buildCard(item, false, myUserId)),
          const SizedBox(height: 20),
        ]);
    if (MediaQuery.sizeOf(context).width >= 700 &&
        MediaQuery.textScalerOf(context).scale(1) <= 1.4) {
      final main = <Widget>[
        if (sections.upcoming.isNotEmpty)
          section('Upcoming', 'Your agreed watch plans', sections.upcoming),
        if (sections.planning.isNotEmpty)
          section('Planning', 'Invites waiting or being arranged',
              sections.planning),
      ];
      final actions = <Widget>[
        if (sections.needsReply.isNotEmpty)
          section('Needs your response', 'Watch plans with an action for you',
              sections.needsReply),
        if (sections.readyToWrapUp.isNotEmpty)
          section('Ready to wrap up', 'The planned time has passed',
              sections.readyToWrapUp),
      ];
      return FlixieRefresh(
          onRefresh: controller.load,
          color: FlixieColors.primary,
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 700 ||
                      main.isEmpty ||
                      actions.isEmpty) {
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...actions, ...main]);
                  }
                  return Row(
                      key: const ValueKey('tablet-watch-plan-columns'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 3,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: main)),
                        const SizedBox(width: 28),
                        Expanded(
                            flex: 2,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: actions)),
                      ]);
                }),
              ]));
    }

    final children = <Widget>[];
    void addSection(String title, String subtitle, List<WatchRequest> items) {
      if (items.isEmpty) return;
      if (children.isNotEmpty) children.add(const SizedBox(height: 22));
      children.add(WatchRequestSectionHeader(
        title: title,
        subtitle: subtitle,
        count: items.length,
      ));
      children.add(const SizedBox(height: 10));
      for (var i = 0; i < items.length; i++) {
        if (i > 0) children.add(const SizedBox(height: 10));
        children.add(buildCard(items[i], false, myUserId));
      }
    }

    addSection(
      'Needs your response',
      'Watch plans with an action for you',
      sections.needsReply,
    );
    addSection('Upcoming', 'Your agreed watch plans', sections.upcoming);
    addSection(
      'Planning',
      'Invites waiting or being arranged',
      sections.planning,
    );
    addSection('Ready to wrap up', 'The planned time has passed',
        sections.readyToWrapUp);

    return FlixieRefresh(
      onRefresh: controller.load,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: children,
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: 64, color: context.colors.medium),
          const SizedBox(height: 16),
          Text(
            searchController.text.isNotEmpty ||
                    controller.filter != WatchPlanFilter.active
                ? 'No Watch Plans match'
                : 'No Watch Plans yet',
            style: TextStyle(color: context.colors.medium, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: context.colors.danger, size: 48),
          const SizedBox(height: 16),
          Text(controller.error!,
              style: TextStyle(color: context.colors.light)),
          const SizedBox(height: 16),
          ElevatedButton(
              onPressed: controller.load, child: const Text('Retry')),
        ],
      ),
    );
  }
}
