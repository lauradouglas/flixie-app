import 'package:provider/provider.dart';
import 'package:flixie_app/features/pip/models/pip_collection.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'home_tablet_layout.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class FindTonightsFilmSection extends StatelessWidget {
  const FindTonightsFilmSection({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (HomeTabletLayout.active(context)) {
      final pip = context.watch<PipCollectionController?>();
      return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome,
                      color: context.colors.primaryText, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Find tonight’s film',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800))),
                ]),
                const SizedBox(height: 20),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Not sure what to watch?',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(
                            'Get a personalised recommendation based on your mood and favourite genres.',
                            style: TextStyle(
                                color: context.colors.light,
                                fontSize: 14,
                                height: 1.5)),
                      ])),
                  if (pip != null && pip.userId != null) ...[
                    const SizedBox(width: 8),
                    Image.asset(PipCollection.asset(pip.collection.activePip),
                        key: const ValueKey('portrait-picker-selected-pip'),
                        width: 72,
                        height: 88,
                        fit: BoxFit.contain,
                        excludeFromSemantics: true),
                  ],
                ]),
                const SizedBox(height: 20),
                FilledButton.icon(
                    onPressed: onPick,
                    style:
                        FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('Pick for me')),
              ]));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What are you in the mood for?',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text('Find tonight’s film, solo or with friends.',
              style: TextStyle(
                  color: context.colors.light, fontSize: 14, height: 1.5)),
          const SizedBox(height: 16),
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onPick,
              borderRadius: BorderRadius.circular(14),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 72),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: context.colors.primaryText
                                  .withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(Icons.shuffle,
                              color: context.colors.primaryText, size: 24)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Pick for me',
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Start with your mood',
                                style: TextStyle(
                                    color: context.colors.light,
                                    fontSize: 12,
                                    height: 1.5)),
                          ])),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_forward_rounded,
                          color: context.colors.primaryText, size: 22),
                    ])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
