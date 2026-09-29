import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class FindTonightsFilmSection extends StatelessWidget {
  const FindTonightsFilmSection({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('Find tonight’s film',
                  style: TextStyle(
                      color: context.colors.light,
                      fontSize: 20,
                      fontWeight: FontWeight.w800)),
            ),
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
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 16, fontWeight: FontWeight.w800),
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
