import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import '../controllers/popcorn_controller.dart';
import '../widgets/popcorn_action_button.dart';
import '../widgets/popcorn_leaderboard_view.dart';

class PopcornLeaderboardScreen extends StatelessWidget {
  const PopcornLeaderboardScreen(
      {super.key,
      required this.controller,
      required this.userId,
      required this.onRemove,
      required this.onPlay,
      required this.playLabel});
  final PopcornController controller;
  final String? userId;
  final VoidCallback onRemove, onPlay;
  final String playLabel;
  @override
  Widget build(BuildContext context) => Theme(
      data: AppTheme.darkTheme,
      child: Scaffold(
        backgroundColor: const Color(0xFF190B28),
        body: Stack(children: [
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 240,
              child: ExcludeSemantics(
                  child: Stack(fit: StackFit.expand, children: [
                Image.asset('assets/icon/popcorn_cinema_stage.png',
                    fit: BoxFit.cover, alignment: Alignment.topCenter),
                const DecoratedBox(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x00190B28), Color(0xFF190B28)]))),
              ]))),
          SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: ListenableBuilder(
                          listenable: controller,
                          builder: (context, _) =>
                              LayoutBuilder(builder: (context, box) {
                                final footer = Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        24, 12, 24, 16),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          PopcornActionButton(
                                              label: playLabel,
                                              onPressed: controller.posting
                                                  ? null
                                                  : onPlay),
                                          if (controller.board.personalBest !=
                                              null)
                                            TextButton(
                                                onPressed: controller.posting
                                                    ? null
                                                    : onRemove,
                                                style: TextButton.styleFrom(
                                                    foregroundColor:
                                                        Colors.white,
                                                    minimumSize:
                                                        const Size.fromHeight(
                                                            48)),
                                                child: const Text(
                                                    'Remove my score')),
                                          const SizedBox(height: 8),
                                          const Text(
                                              'Only scores players choose to post appear here.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Color(0xFFD8BEEA),
                                                  fontSize: 12)),
                                        ]));
                                final content = Column(children: [
                                  Row(children: [
                                    IconButton(
                                        tooltip: 'Close sheet',
                                        onPressed: () => Navigator.pop(context),
                                        icon: const Icon(Icons.chevron_left,
                                            color: Colors.white, size: 32)),
                                    const Expanded(
                                        child: Center(
                                            child:
                                                FlixieWordmark(fontSize: 30))),
                                    const SizedBox(width: 48)
                                  ]),
                                  Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          24, 12, 24, 0),
                                      child: PopcornLeaderboardView(
                                          controller: controller,
                                          userId: userId)),
                                ]);
                                // Keep actions visible on normal phones; reflow into the same scroll
                                // surface in landscape or with large text instead of clipping the list.
                                if (box.maxHeight < 550 ||
                                    MediaQuery.textScalerOf(context).scale(16) >
                                        22) {
                                  return SingleChildScrollView(
                                      child:
                                          Column(children: [content, footer]));
                                }
                                return Column(children: [
                                  Expanded(
                                      child: SingleChildScrollView(
                                          child: content)),
                                  ColoredBox(
                                      color: const Color(0xFF190B28),
                                      child: footer)
                                ]);
                              }))))),
        ]),
      ));
}
