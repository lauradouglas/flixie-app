import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../controllers/onboarding_controller.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';

class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame(
      {super.key,
      required this.controller,
      required this.scroll,
      required this.footer,
      required this.child,
      required this.entryActions,
      required this.onBack});
  final OnboardingController controller;
  final ScrollController scroll;
  final Widget footer, child;
  final List<Widget> entryActions;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    const titles = [
      'What stays with you?',
      'Make it an easy yes.',
      'Your picks.',
      'Your favourites.',
      'Sharing & spoilers.',
      'Good films start conversations.'
    ];
    const subtitles = [
      'Pick up to three films or shows you love. We’ll start there.',
      'Choose where you watch. We’ll put available picks first.',
      'A few places to start. Save what catches your eye.',
      'Bring the films you love onto your profile. This is optional.',
      'Choose what you share and what you see. You can change these in Settings.',
      'Browse a conversation before deciding to join. This part is optional.'
    ];
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Scaffold(
        backgroundColor: context.colors.background,
        bottomNavigationBar: footer,
        body: SafeArea(
            child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: SingleChildScrollView(
                      controller: scroll,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(children: [
                            if (controller.step > 0)
                              IconButton(
                                  tooltip: 'Back',
                                  onPressed:
                                      controller.busy ? null : () => onBack(),
                                  icon: const Icon(Icons.arrow_back)),
                            const Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: FlixieWordmark()),
                              ),
                            ),
                            Text('${controller.step + 1} of 6',
                                style: Theme.of(context).textTheme.bodySmall),
                          ]),
                          const SizedBox(height: 12),
                          TweenAnimationBuilder<double>(
                            tween: Tween(
                                begin: 0.5, end: (controller.step + 1) / 6),
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 280),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Row(
                              children: List.generate(
                                  6,
                                  (index) => Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(
                                              right: index == 5 ? 0 : 5),
                                          child: LinearProgressIndicator(
                                            key: ValueKey(
                                                'setup-progress-$index'),
                                            minHeight: 3,
                                            borderRadius:
                                                BorderRadius.circular(3),
                                            value: (value * 6 - index)
                                                .clamp(0.0, 1.0),
                                          ),
                                        ),
                                      )),
                            ),
                          ),
                          ...entryActions,
                          const SizedBox(height: 20),
                          AnimatedSwitcher(
                            duration: reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            layoutBuilder: (currentChild, previousChildren) =>
                                Stack(
                              alignment: Alignment.topLeft,
                              children: [
                                ...previousChildren,
                                if (currentChild != null) currentChild,
                              ],
                            ),
                            child: Column(
                              key: ValueKey('setup-heading-$controller.step'),
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(titles[controller.step],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w800)),
                                const SizedBox(height: 8),
                                Text(subtitles[controller.step]),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (controller.error != null) ...[
                            Text(controller.error!,
                                style: TextStyle(color: context.colors.danger)),
                            const SizedBox(height: 12)
                          ],
                          child,
                        ],
                      )),
                ))));
  }
}
