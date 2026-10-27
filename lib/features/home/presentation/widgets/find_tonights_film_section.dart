import 'home_tablet_layout.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class FindTonightsFilmSection extends StatelessWidget {
  const FindTonightsFilmSection({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    if (HomeTabletLayout.active(context)) {
      return Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Find tonight’s film',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('Solo or with friends. Start with your mood.',
                style: TextStyle(
                    color: context.colors.light, fontSize: 12, height: 1.4)),
            const SizedBox(height: 12),
            FilledButton.icon(
                onPressed: onPick,
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('Pick for me')),
          ]));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FlixieSectionHeader(title: 'Find tonight’s film'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onPick,
              style: FilledButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              child: const Text('Pick for me', textAlign: TextAlign.center),
            ),
          ),
          const SizedBox(height: 10),
          Text('Solo or with friends. Start with your mood.',
              style: TextStyle(color: context.colors.medium, fontSize: 14)),
        ],
      ),
    );
  }
}
