import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_typography.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_calendar_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

/// A labelled, fictional example, never the visitor's actual watch history.
class GuestDiaryTeaser extends StatelessWidget {
  const GuestDiaryTeaser({super.key});
  @override
  Widget build(BuildContext context) => Container(
      // The final 44px action contributes its own inset below the visible label.
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      decoration: BoxDecoration(
          color: diaryPaper, borderRadius: BorderRadius.circular(18)),
      child: DefaultTextStyle(
          style: FlixieTypography.body.copyWith(color: diaryInk),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Dear film diary,',
                style: FlixieTypography.sectionTitle.copyWith(color: diaryInk)),
            const SizedBox(height: 4),
            const Text('Your films. Your ratings. Your memories.'),
            const SizedBox(height: 10),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Expanded(child: Text('19–25 October')),
              const SizedBox(width: 12),
              Text('Example',
                  style: FlixieTypography.metadata.copyWith(color: diaryMuted)),
            ]),
            const SizedBox(height: 12),
            const _ExampleWeek(),
            const SizedBox(height: 10),
            Divider(height: 1, color: diaryMuted.withValues(alpha: .45)),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.asset('assets/images/why-flixie-alien.jpg',
                      width: 64,
                      height: 96,
                      fit: BoxFit.contain,
                      semanticLabel: 'Alien poster')),
              const SizedBox(width: 14),
              const Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('Alien',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    Text('1979',
                        style: TextStyle(color: diaryMuted, fontSize: 12)),
                    SizedBox(height: 6),
                    Wrap(spacing: 12, runSpacing: 6, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.star_rounded,
                            size: 17, color: Color(0xFFBA7900)),
                        SizedBox(width: 4),
                        Text('9/10',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ]),
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.confirmation_number_outlined,
                            size: 16, color: diaryMuted),
                        SizedBox(width: 5),
                        Flexible(
                            child: Text('Cinema',
                                style: TextStyle(
                                    color: diaryMuted, fontSize: 12))),
                      ]),
                    ]),
                    SizedBox(height: 7),
                    Text('Still thinking about that final scene.'),
                  ])),
            ]),
            const SizedBox(height: 12),
            const Text('Watched with',
                style: TextStyle(fontSize: 12, color: diaryMuted)),
            const SizedBox(height: 4),
            const Row(children: [
              Padding(
                  padding: EdgeInsets.all(4),
                  child: ProfileAvatarView(
                      avatar: null,
                      fallbackText: 'M',
                      fallbackColor: FlixieColors.primary,
                      profileBadges: ['EARLY_ADOPTER'],
                      size: 28,
                      imageProvider:
                          AssetImage('assets/icon/pip_emote_thumbs_up.png'))),
              SizedBox(width: 8),
              Expanded(
                  child: Text('Maya',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 14),
            const Text(
                'Save what you watched, when you watched it and what you thought.',
                style: TextStyle(color: diaryMuted)),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: () => context.go('/search?focus=1'),
                    style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    icon: const Icon(Icons.edit_note_rounded, size: 20),
                    label: const Text('Find a film to log',
                        textAlign: TextAlign.center))),
            const SizedBox(height: 6),
            TextButton(
                onPressed: () => context.push('/guest-diary'),
                style: TextButton.styleFrom(
                    foregroundColor: diaryInk,
                    minimumSize: const Size(0, 44),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                child: const Row(children: [
                  Expanded(child: Text('View my diary drafts')),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 20)
                ])),
          ])));
}

class _ExampleWeek extends StatelessWidget {
  const _ExampleWeek();
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
        final width = math.max(box.maxWidth, 7 * 32 * scale);
        return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
                width: width,
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                            child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: Semantics(
                                    label: '${const [
                                      'Monday',
                                      'Tuesday',
                                      'Wednesday',
                                      'Thursday',
                                      'Friday',
                                      'Saturday',
                                      'Sunday'
                                    ][i]} ${19 + i} October, example',
                                    selected: i == 6,
                                    child: ExcludeSemantics(
                                        child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 6),
                                            decoration: BoxDecoration(
                                                color: i == 6
                                                    ? diaryInk
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(14)),
                                            child: Column(children: [
                                              Text(
                                                  const [
                                                    'Mon',
                                                    'Tue',
                                                    'Wed',
                                                    'Thu',
                                                    'Fri',
                                                    'Sat',
                                                    'Sun'
                                                  ][i],
                                                  style: TextStyle(
                                                      color: i == 6
                                                          ? diaryPaper
                                                          : diaryMuted,
                                                      fontSize: 12,
                                                      height: 1.3)),
                                              const SizedBox(height: 3),
                                              Text('${19 + i}',
                                                  style: TextStyle(
                                                      color: i == 6
                                                          ? diaryPaper
                                                          : diaryInk,
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      height: 1.2)),
                                              const SizedBox(height: 4),
                                              SizedBox(
                                                  height: 4,
                                                  child: i == 6
                                                      ? const DecoratedBox(
                                                          decoration: BoxDecoration(
                                                              color: Color(
                                                                  0xFFB9A0FF),
                                                              shape: BoxShape
                                                                  .circle),
                                                          child:
                                                              SizedBox.square(
                                                                  dimension: 4))
                                                      : null),
                                            ]))))))
                    ])));
      });
}
