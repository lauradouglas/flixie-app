import 'preview_popcorn_visuals.dart';
// Fictional local visual preview. No auth, network or production scores.
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/popcorn_catch/data/popcorn_service.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';
import 'package:flixie_app/features/popcorn_catch/models/popcorn_leaderboard.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/pages/popcorn_catch_screen.dart';

class PreviewPopcornService extends PopcornService {
  PreviewPopcornService({this.version = 2, int? initialBest})
      : best = initialBest;
  final int version;
  int? best;
  @override
  Future<PopcornRound> start() async =>
      PopcornRound('preview-round', 1, personalBest: best, version: version);
  @override
  Future<int> submit(PopcornRound round, List<int> targets) async {
    final e = PopcornEngine(round.seed, version: round.version);
    for (final target in targets) {
      if (e.version >= 3 && e.roundComplete && !e.runOver) e.nextRound();
      e.step(target);
    }
    if (best == null || e.score > best!) best = e.score;
    return e.score;
  }

  @override
  Future<int> verify(PopcornRound round, List<int> targets) async {
    final e = PopcornEngine(round.seed, version: round.version);
    for (final target in targets) {
      if (e.version >= 3 && e.roundComplete && !e.runOver) e.nextRound();
      e.step(target);
    }
    return e.score;
  }

  @override
  Future<void> removeScore() async {
    best = null;
  }

  @override
  Future<PopcornLeaderboard> leaderboard() async {
    final rows = [
      const PopcornEntry(
          rank: 1,
          score: 4280,
          roundReached: 9,
          userId: 'fictional-robin',
          username: 'Robin',
          profileBadges: ['EARLY_ADOPTER']),
      const PopcornEntry(
          rank: 2,
          score: 3610,
          roundReached: 8,
          userId: 'fictional-ellis',
          username: 'Ellis'),
      if (version >= 3) ...[
        const PopcornEntry(
            rank: 3,
            score: 2950,
            roundReached: 7,
            userId: 'fictional-blair',
            username: 'Blair'),
        const PopcornEntry(
            rank: 5,
            score: 1880,
            roundReached: 5,
            userId: 'fictional-jamie',
            username: 'Jamie'),
      ],
      if (best != null)
        PopcornEntry(
            rank: 3,
            score: best!,
            roundReached: 6,
            userId: 'fictional-casey',
            username: 'Casey',
            profileBadges: ['FOUNDER']),
    ]..sort((a, b) => b.score.compareTo(a.score));
    return PopcornLeaderboard(
        items: [
          for (var i = 0; i < rows.length; i++)
            PopcornEntry(
                rank: i + 1,
                score: rows[i].score,
                roundReached: rows[i].roundReached,
                userId: rows[i].userId,
                username: rows[i].username,
                profileBadges: rows[i].profileBadges)
        ],
        personalBest: best,
        personalRank: best == null
            ? null
            : rows.indexWhere((e) => e.userId == 'fictional-casey') + 1);
  }
}

void main() => runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: ThemeMode.system,
    routes: {'/pip-visuals': (_) => const PopcornVisualsPreview()},
    home: _PopcornPreviewHome()));

class _PopcornPreviewHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Pip · local preview')),
      body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        FilledButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                    builder: (_) => PopcornCatchScreen(
                        userId: 'fictional-casey',
                        service: PreviewPopcornService(
                            version: 3, initialBest: 2450)))),
            child: const Text('Play Popcorn Catch')),
        const SizedBox(height: 16),
        FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/pip-visuals'),
            child: const Text('Performance & chat cards')),
        const Text('Fictional scores. No real messages.')
      ])));
}
