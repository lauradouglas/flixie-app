import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../../data/setup_service.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingCommunitiesStep extends StatelessWidget {
  const OnboardingCommunitiesStep(
      {super.key, required this.controller, required this.onFinish});
  final OnboardingController controller;
  final ValueChanged<String> onFinish;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _communities(context));
  Widget _communityRow(
      BuildContext context, SetupCommunitySuggestion suggestion) {
    final community = suggestion.community;
    final thread = controller.conversations[community.id];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        value: community.joined ||
            controller.selectedCommunities.contains(community.id),
        onChanged: community.joined || controller.busy
            ? null
            : (value) =>
                controller.selectCommunity(community.id, value == true),
        title: Text(community.name,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(community.joined
            ? 'Already joined'
            : suggestion.reason ??
                'Reviews and ratings from community members'),
      ),
      if (thread != null) ...[
        Text('Spoiler-free conversation',
            style: TextStyle(color: context.colors.secondary, fontSize: 12)),
        Text(thread['title'] as String,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        TextButton(
          onPressed: controller.busy
              ? null
              : () => onFinish(
                  '/genre-communities/${community.id}/discussions/${Uri.encodeComponent(thread['id'].toString())}'),
          child: const Text('Read the conversation'),
        ),
      ],
      TextButton(
        onPressed: controller.busy
            ? null
            : () => onFinish('/genre-communities/${community.id}'),
        child: Text('Browse ${community.name} before joining'),
      ),
      const Divider(),
    ]);
  }

  List<Widget> _communities(BuildContext context) => [
        if (controller.loadingCommunities) const LinearProgressIndicator(),
        if (controller.communityError != null) ...[
          Semantics(
              liveRegion: true,
              child: Text(controller.communityError!,
                  style: TextStyle(color: context.colors.danger))),
          if (controller.selectedCommunities.isEmpty)
            TextButton(
                onPressed: controller.loadingCommunities || controller.busy
                    ? null
                    : controller.loadCommunities,
                child: const Text('Retry communities')),
        ],
        if (!controller.loadingCommunities &&
            controller.communityChoices.isEmpty &&
            controller.communityError == null)
          const Text('You can discover and join communities later in Social.'),
        if (controller.communityChoices
            .any((controller) => controller.suggested)) ...[
          const SizedBox(height: 12),
          const Text('Suggested for you',
              style: TextStyle(fontWeight: FontWeight.w700)),
          ...controller.communityChoices
              .where((controller) => controller.suggested)
              .map((s) => _communityRow(context, s)),
        ],
        if (controller.communityChoices
            .any((controller) => !controller.suggested))
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Browse communities'),
            children: controller.communityChoices
                .where((controller) => !controller.suggested)
                .map((s) => _communityRow(context, s))
                .toList(),
          ),
        const SizedBox(height: 16),
        const Text(
            'Joining adds communities to Social. It doesn’t turn on public sharing. Any reviews you already share publicly can appear in communities you join.'),
      ];
}
