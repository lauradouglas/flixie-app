import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_challenge.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/popcorn_challenge_card.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/widgets/pip_performance.dart';
import 'package:flixie_app/features/popcorn_catch/data/popcorn_service.dart';

class PopcornVisualsPreview extends StatelessWidget {
  const PopcornVisualsPreview({super.key});
  @override
  Widget build(BuildContext context) => Theme(
      data: AppTheme.darkTheme,
      child: DefaultTabController(
          length: 2,
          child: Scaffold(
              appBar: AppBar(
                  title: const Text('Pip · fictional local preview'),
                  bottom: const TabBar(tabs: [
                    Tab(text: 'Performance'),
                    Tab(text: 'Chat cards')
                  ])),
              body: const TabBarView(children: [_Performances(), _Cards()]))));
}

class _Performances extends StatefulWidget {
  const _Performances();
  @override
  State<_Performances> createState() => _PerformancesState();
}

class _PerformancesState extends State<_Performances> {
  PipPerformanceMood mood = PipPerformanceMood.celebrate;
  int replay = 0;
  @override
  Widget build(BuildContext context) => Column(children: [
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          for (final m in PipPerformanceMood.values)
            ChoiceChip(
                label: Text(m.name),
                selected: mood == m,
                onSelected: (_) => setState(() {
                      mood = m;
                      replay++;
                    })),
          IconButton(
              tooltip: 'Replay performance',
              onPressed: () => setState(() => replay++),
              icon: const Icon(Icons.replay))
        ]),
        Expanded(
            child: Stack(fit: StackFit.expand, children: [
          Image.asset('assets/icon/popcorn_cinema_stage.png', fit: BoxFit.fill),
          Center(
              child: SizedBox(
                  width: 320,
                  height: 420,
                  child: PipPerformance(key: ValueKey(replay), mood: mood)))
        ]))
      ]);
}

class _Cards extends StatefulWidget {
  const _Cards();
  @override
  State<_Cards> createState() => _CardsState();
}

class _CardsState extends State<_Cards> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final score = <int?>[null, 560, 420, 480, 0][selected];
    return ListView(padding: const EdgeInsets.all(20), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < 5; i++)
          ChoiceChip(
              label: Text(['Challenge', 'Win', 'Loss', 'Tie', 'Rough'][i]),
              selected: selected == i,
              onSelected: (_) => setState(() => selected = i))
      ]),
      const SizedBox(height: 20),
      Center(
          child: PopcornChallengeCard(
              key: ValueKey(selected),
              currentUserId: 'fictional-robin',
              service: _PreviewCardService(),
              result: score != null,
              challenge: PopcornChallenge(
                  id: 'fictional-challenge',
                  score: 480,
                  senderId: 'fictional-casey',
                  recipientId: 'fictional-robin',
                  senderName: 'Casey',
                  recipientName: 'Robin',
                  sourceRoundId: 'fictional-round',
                  resultScore: score))),
    ]);
  }
}

class _PreviewCardService extends PopcornService {
  @override
  Future<PopcornChallenge> challenge(String id) async =>
      throw StateError('Visual preview only—no real friend messages are sent.');
}
