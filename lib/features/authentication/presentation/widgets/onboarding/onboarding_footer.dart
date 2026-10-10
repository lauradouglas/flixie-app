import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../../data/setup_service.dart';
import '../../controllers/onboarding_controller.dart';

class OnboardingFooter extends StatelessWidget {
  const OnboardingFooter(
      {super.key,
      required this.controller,
      required this.onAdvance,
      required this.onSkip});
  final OnboardingController controller;
  final VoidCallback onAdvance, onSkip;

  @override
  Widget build(BuildContext context) => _setupActions(context);
  Widget _setupActions(BuildContext context) {
    final label = switch (controller.step) {
      0 => 'Continue',
      1 =>
        controller.country == null ? 'Choose country' : 'Show my first picks',
      2 => 'Continue to favourites',
      3 => 'Continue to sharing',
      4 => 'Find my kind of people',
      _ => controller.selectedCommunities.isEmpty
          ? 'Explore Flixie'
          : 'Join ${controller.selectedCommunities.length} & explore',
    };
    final secondary = switch (controller.step) {
      0 => 'Skip taste picks',
      1 => 'Skip services for now',
      2 => 'Skip picks',
      3 => 'Skip favourites',
      _ => 'I’ll explore on my own',
    };
    final VoidCallback? advance = controller.busy ||
            (controller.step == 1 && controller.loading) ||
            (controller.step == 5 &&
                controller.loadingCommunities &&
                controller.selectedCommunities.isNotEmpty)
        ? null
        : onAdvance;
    return ColoredBox(
        key: const ValueKey('setup-footer-surface'),
        color: controller.step <= 2
            ? context.colors.surface
            : context.colors.background,
        child: SafeArea(
          top: false,
          child: Align(
            heightFactor: 1,
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Container(
                decoration: controller.step <= 2
                    ? BoxDecoration(
                        color: context.colors.surface,
                        border: Border(
                            top:
                                BorderSide(color: context.colors.tabBarBorder)))
                    : null,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (controller.step == 1) ...[
                      _providerSummary(context),
                      const SizedBox(height: 10),
                    ],
                    if (controller.step == 0) ...[
                      _tasteSummary(context),
                      const SizedBox(height: 10),
                    ],
                    if (controller.step == 2) ...[
                      _savedPicksSummary(context),
                      const SizedBox(height: 10),
                    ],
                    FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff8050e8),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14))),
                      onPressed: advance,
                      child: controller.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(label),
                    ),
                    TextButton(
                      onPressed: controller.busy ? null : onSkip,
                      style: TextButton.styleFrom(
                          textStyle: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500),
                          minimumSize: const Size(44, 44)),
                      child: Text(secondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ));
  }

  Widget _savedPicksSummary(BuildContext context) => Semantics(
      liveRegion: true,
      child: Row(children: [
        if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
          for (final title in controller.picks
              .where((t) => controller.added.contains(t.key))
              .take(3))
            Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _tastePoster(title)),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              controller.added.isEmpty
                  ? 'Something catch your eye?'
                  : '${controller.added.length} saved for later',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontSize: 14, fontWeight: FontWeight.w700)),
          Text(
              controller.added.isEmpty
                  ? 'Save a pick, or keep exploring.'
                  : 'Waiting for you in Watchlist.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontSize: 12)),
        ])),
      ]));

  Widget _tastePoster(SetupTitle title) => ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
            width: 28,
            height: 42,
            child: title.poster?.isNotEmpty == true
                ? Image.network(
                    title.poster!.startsWith('http')
                        ? title.poster!
                        : 'https://image.tmdb.org/t/p/w92${title.poster}',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.movie_outlined))
                : const Icon(Icons.movie_outlined)),
      );

  Widget _tasteSummary(BuildContext context) =>
      Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          if (MediaQuery.textScalerOf(context).scale(1) < 1.5)
            for (final title in controller.taste.values)
              Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _tastePoster(title)),
          Expanded(
              child: Semantics(
                  liveRegion: true,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${controller.taste.length} of 3 selected',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                    fontSize: 14, fontWeight: FontWeight.w700)),
                        Text(
                            controller.taste.isEmpty
                                ? 'Start with something you love.'
                                : 'A few is enough.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(fontSize: 12)),
                      ]))),
          if (controller.taste.isNotEmpty)
            TextButton(
                onPressed:
                    controller.busy ? null : controller.toggleEditingTaste,
                style: TextButton.styleFrom(
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    minimumSize: const Size(48, 48)),
                child: Text(controller.editingTaste ? 'Done' : 'Edit')),
        ]),
        if (controller.editingTaste && controller.taste.isNotEmpty)
          SizedBox(
              height: MediaQuery.sizeOf(context).height * .18,
              child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                      children: controller.taste.values
                          .map((title) => Row(children: [
                                _tastePoster(title),
                                const SizedBox(width: 10),
                                Expanded(child: Text(title.name)),
                                TextButton(
                                    key: ValueKey('remove-taste-${title.key}'),
                                    onPressed: controller.busy
                                        ? null
                                        : () =>
                                            controller.removeTaste(title.key),
                                    child: Semantics(
                                        excludeSemantics: true,
                                        label:
                                            'Remove ${title.name} from picks',
                                        child: const Text('Remove'))),
                              ]))
                          .toList()))),
      ]);

  Widget _providerSummary(BuildContext context) {
    final chosen = controller.providers
        .where((p) => controller.selectedProviders.contains(p.id))
        .take(3)
        .toList();
    return Semantics(
        liveRegion: true,
        child: Row(children: [
          if (chosen.isEmpty) const Icon(Icons.tv_outlined, size: 28),
          for (final provider in chosen)
            Padding(
                padding: const EdgeInsets.only(right: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(7),
                  child: provider.logoPath.isEmpty
                      ? const Icon(Icons.tv_outlined, size: 28)
                      : Image.network(provider.logoUrl,
                          width: 28,
                          height: 28,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.tv_outlined, size: 28)),
                )),
          const SizedBox(width: 8),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(
                    controller.selectedProviders.isEmpty
                        ? 'No services selected'
                        : '${controller.selectedProviders.length} service${controller.selectedProviders.length == 1 ? '' : 's'} selected',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                    controller.selectedProviders.isEmpty
                        ? 'You can add these later'
                        : 'Your services · change them anytime',
                    style: Theme.of(context).textTheme.bodySmall),
              ])),
        ]));
  }
}
