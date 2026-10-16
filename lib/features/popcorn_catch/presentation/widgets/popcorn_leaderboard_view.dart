import 'package:flutter/material.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../models/popcorn_leaderboard.dart';
import '../controllers/popcorn_controller.dart';
import 'popcorn_arena.dart';

class PopcornLeaderboardView extends StatelessWidget {
  const PopcornLeaderboardView(
      {super.key, required this.controller, required this.userId});
  final PopcornController controller;
  final String? userId;
  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        const Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: 'Popcorn ', style: TextStyle(color: popcornGold)),
                TextSpan(text: 'legends', style: TextStyle(color: Colors.white))
              ]),
              style: TextStyle(
                  fontSize: 36, height: 1.05, fontWeight: FontWeight.w900)),
          SizedBox(height: 12),
          Text('Big catches. Bigger bragging rights.',
              style: TextStyle(
                  color: Color(0xFFE2CFF4),
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ])),
        ExcludeSemantics(
            child: Image.asset('assets/icon/pip_popcorn_dance.png',
                width: 100, height: 130, fit: BoxFit.contain)),
      ]),
      const SizedBox(height: 24),
      Row(children: [
        const Expanded(
            child: Text('PLAYER',
                style: TextStyle(
                    color: Color(0xFFCDB3E8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800))),
        const Text('SCORE',
            style: TextStyle(
                color: Color(0xFFCDB3E8),
                fontSize: 12,
                fontWeight: FontWeight.w800)),
        IconButton(
            tooltip: 'Refresh leaderboard',
            onPressed: c.boardLoading ? null : c.loadBoard,
            icon: const Icon(Icons.refresh, size: 20)),
      ]),
      if (c.boardLoading) const LinearProgressIndicator(color: popcornGold),
      if (c.boardError != null) ...[
        Text(c.boardError!, style: const TextStyle(color: Colors.white)),
        TextButton(onPressed: c.loadBoard, child: const Text('Try again')),
      ] else if (c.board.items.isEmpty && !c.boardLoading)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text(
                'The stage is yours. Post a score to start the leaderboard.',
                textAlign: TextAlign.center)),
      for (final entry in c.board.items)
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _ScoreRow(entry: entry, own: entry.userId == userId)),
      if (c.board.personalBest != null &&
          !c.board.items.any((e) => e.userId == userId))
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
                'Your best: ${formatPopcornScore(c.board.personalBest!)} · #${c.board.personalRank}',
                style: const TextStyle(
                    color: popcornGold, fontWeight: FontWeight.w800))),
    ]);
  }
}

String formatPopcornScore(int score) =>
    '$score'.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.entry, required this.own});
  final PopcornEntry entry;
  final bool own;
  @override
  Widget build(BuildContext context) => Container(
        key: ValueKey('popcorn-rank-${entry.userId}'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        decoration: BoxDecoration(
            color: own ? const Color(0xFF3B194D) : const Color(0xFF2A123B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: own ? popcornGold : Colors.transparent, width: 2)),
        child: LayoutBuilder(builder: (context, box) {
          final stacked = box.maxWidth < 340 ||
              MediaQuery.textScalerOf(context).scale(16) > 22;
          final points = Column(
              crossAxisAlignment:
                  stacked ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatPopcornScore(entry.score),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900)),
                Text('Round ${entry.roundReached}',
                    style: const TextStyle(
                        color: Color(0xFFD8BEEA), fontSize: 14)),
              ]);
          return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            SizedBox(
                width: 38,
                height: 48,
                child: entry.rank <= 3
                    ? _RankMedal(rank: entry.rank)
                    : Center(
                        child: Text('${entry.rank}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900)))),
            const SizedBox(width: 6),
            SizedBox(
                width: 54,
                height: 54,
                child: Center(
                    child: ProfileAvatarView(
                        avatar: entry.avatar,
                        fallbackText: entry.username,
                        fallbackColor: FlixieColors.primary,
                        size: 46,
                        profileBadges: entry.profileBadges))),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text('${entry.username}${own ? ' (you)' : ''}',
                      style: TextStyle(
                          color: own ? popcornGold : Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800)),
                  if (stacked) points,
                ])),
            if (!stacked) ...[const SizedBox(width: 12), points],
          ]);
        }),
      );
}

class _RankMedal extends StatelessWidget {
  const _RankMedal({required this.rank});
  final int rank;
  @override
  Widget build(BuildContext context) {
    final color = [
      popcornGold,
      const Color(0xFFD4D6E3),
      const Color(0xFFDF9F6D)
    ][rank - 1];
    return Semantics(
        label: 'Rank $rank',
        child: ExcludeSemantics(
            child: Stack(alignment: Alignment.topCenter, children: [
          Positioned(
              bottom: 0,
              child: Icon(Icons.workspace_premium, color: color, size: 44)),
          Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF684020), width: 1)),
              child: Text('$rank',
                  style: const TextStyle(
                      color: Color(0xFF381C31),
                      fontSize: 20,
                      fontWeight: FontWeight.w900))),
        ])));
  }
}
