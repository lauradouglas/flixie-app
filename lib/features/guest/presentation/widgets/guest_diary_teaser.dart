import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_calendar_sheet.dart';

/// A labelled example, never presented as the visitor's actual watch history.
class GuestDiaryTeaser extends StatelessWidget {
  const GuestDiaryTeaser({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: diaryPaper, borderRadius: BorderRadius.circular(14)),
        child: DefaultTextStyle(
            style: const TextStyle(
                color: diaryInk,
                fontSize: 16,
                fontFamily: 'Manrope',
                height: 1.4),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Dear film diary,',
                  style:
                      FlixieTypography.sectionTitle.copyWith(color: diaryInk)),
              const SizedBox(height: 4),
              const Text('A little home for what you’ve watched.'),
              const SizedBox(height: 12),
              const Text('Example diary',
                  style: TextStyle(color: diaryMuted, fontSize: 13)),
              const SizedBox(height: 8),
              const Text('19–25 October · example week',
                  style: TextStyle(color: diaryMuted, fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < 7; i++)
                  Container(
                      width: 32,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                          color: i == 6
                              ? diaryInk
                              : diaryMuted.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(16)),
                      child: Column(children: [
                        Text(const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i],
                            style: TextStyle(
                                color: i == 6 ? diaryPaper : diaryMuted,
                                fontSize: 12)),
                        Text('${19 + i}',
                            style: TextStyle(
                                color: i == 6 ? diaryPaper : diaryInk,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ])),
              ]),
              const Divider(color: diaryMuted),
              const Text('Alien',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const Wrap(spacing: 12, runSpacing: 8, children: [
                Text('9/10'),
                Text('Cinema'),
                Text('A lovely movie night.')
              ]),
              const SizedBox(height: 12),
              const Text(
                  'Keep your scores, watch dates and the little memories.'),
              TextButton(
                  onPressed: () => context.go('/search?focus=1'),
                  style: TextButton.styleFrom(foregroundColor: diaryInk),
                  child: const Text('Find a film to rate')),
              TextButton(
                  onPressed: () => context.push('/guest-diary'),
                  style: TextButton.styleFrom(foregroundColor: diaryInk),
                  child: const Text('View my diary drafts')),
              TextButton(
                  onPressed: () => context.push('/why-flixie'),
                  style: TextButton.styleFrom(foregroundColor: diaryInk),
                  child: const Text('See what makes Flixie different')),
            ])),
      );
}
