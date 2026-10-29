import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

/// Fictional educational plan; never a live invitation or the viewer's activity.
class GuestWatchTogetherTeaser extends StatelessWidget {
  const GuestWatchTogetherTeaser({super.key});

  void _explain(BuildContext context) => showFlixiePromptSheet<void>(
      context: context,
      maxHeightFraction: .85,
      builder: (context) => FlixiePromptSheetContent(
              title: const Text('Watch plans, together'),
              content: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pick a film',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                        'Choose something you want to watch with a friend or group.'),
                    SizedBox(height: 16),
                    Text('Make a plan',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Invite your people and agree when to watch.'),
                    SizedBox(height: 16),
                    Text('Keep your own memories',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text(
                        'After watching, each person can log the film and add their own rating.'),
                    SizedBox(height: 16),
                    Text(
                        'The plan shown here is an example. You’ll need an account to make plans with other people.'),
                  ]),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.primary,
                        foregroundColor: Colors.white),
                    child: const Text('Got it'))
              ]));

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Better together, whenever you’re ready.',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text('Pick a film. Make a plan. Watch together.',
            style: TextStyle(fontSize: 14, height: 1.5)),
        const SizedBox(height: 16),
        Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.colors.tabBarBorder)),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text('Friday film night',
                        style: TextStyle(
                            color: context.colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800))),
                const SizedBox(width: 12),
                Text('Example',
                    style:
                        TextStyle(fontSize: 12, color: context.colors.light)),
              ]),
              const SizedBox(height: 4),
              Text('Fri 30 Oct · 7:30 pm',
                  style: TextStyle(fontSize: 12, color: context.colors.light)),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, box) {
                final compact = box.maxWidth < 280 ||
                    MediaQuery.textScalerOf(context).scale(1) > 1.4;
                return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.asset(
                              'assets/images/guest-watch-plan-jurassic-park.jpg',
                              width: compact ? 64 : 100,
                              height: compact ? 96 : 150,
                              fit: BoxFit.contain,
                              semanticLabel: 'Jurassic Park poster')),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Jurassic Park',
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 3),
                            Text('1993',
                                style: TextStyle(
                                    fontSize: 12, color: context.colors.light)),
                            const SizedBox(height: 8),
                            Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.people,
                                      size: 16,
                                      color: context.colors.primaryText),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text('Watching together',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: context.colors.light))),
                                ]),
                            const SizedBox(height: 12),
                            const Wrap(spacing: 12, runSpacing: 12, children: [
                              _ExampleParticipant(
                                  name: 'Maya',
                                  badges: ['EARLY_ADOPTER'],
                                  pip: true),
                              _ExampleParticipant(
                                  name: 'Jamie', badges: ['FOUNDER']),
                            ]),
                          ])),
                    ]);
              }),
              const SizedBox(height: 16),
              Divider(height: 1, color: context.colors.tabBarBorder),
              TextButton(
                  onPressed: () => _explain(context),
                  style: TextButton.styleFrom(
                      foregroundColor: context.colors.primaryText,
                      minimumSize: const Size(0, 44),
                      padding: const EdgeInsets.only(top: 10),
                      textStyle: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  child: const Row(children: [
                    Expanded(child: Text('See how watch plans work')),
                    SizedBox(width: 10),
                    Icon(Icons.arrow_forward, size: 20)
                  ])),
            ])),
      ]);
}

class _ExampleParticipant extends StatelessWidget {
  const _ExampleParticipant(
      {required this.name, required this.badges, this.pip = false});
  final String name;
  final List<String> badges;
  final bool pip;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: 64,
      child: Column(children: [
        Padding(
            padding: const EdgeInsets.all(5),
            child: ProfileAvatarView(
                avatar: null,
                fallbackText: name[0],
                fallbackColor: const Color(0xFF008B80),
                size: 40,
                profileBadges: badges,
                imageProvider: pip
                    ? const AssetImage('assets/icon/pip_emote_thumbs_up.png')
                    : null)),
        const SizedBox(height: 4),
        Text(name,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: context.colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
      ]));
}
