import 'package:flixie_app/features/movies/presentation/widgets/show_detail_images.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/sharing/presentation/media_chat_share.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class ShowDetailHero extends StatefulWidget {
  const ShowDetailHero({super.key, required this.show});
  final TvShow show;
  @override
  State<ShowDetailHero> createState() => _ShowDetailHeroState();
}

class _ShowDetailHeroState extends State<ShowDetailHero> {
  @override
  Widget build(BuildContext context) {
    final show = widget.show;
    return SliverToBoxAdapter(
        child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _heroIconButton(
                          icon: flixieBackIcon(context,
                              backIcon: Icons.arrow_back_ios_new_rounded),
                          onTap: () => flixieBackOrHome(context)),
                      _heroIconButton(
                          icon: Icons.ios_share_rounded,
                          onTap: () => MediaChatShare(context).show(
                              ChatShareMedia(
                                  id: show.id,
                                  title: show.name,
                                  posterPath: show.posterPath,
                                  isShow: true))),
                    ]),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, constraints) {
                  final stacked = constraints.maxWidth < 300 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.5;
                  final poster = SizedBox(
                      width: 112,
                      height: 168,
                      child: InkWell(
                          onTap: () => _showPosterViewer(show),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: ShowPoster(path: show.posterPath))));
                  final info = _buildHeroInformation(show, compact: true);
                  return stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [poster, const SizedBox(height: 16), info])
                      : Row(children: [
                          poster,
                          const SizedBox(width: 20),
                          Expanded(child: info)
                        ]);
                }),
              ]),
            )));
  }

  Widget _buildHeroInformation(TvShow show, {required bool compact}) {
    final year = DateTime.tryParse(show.firstAirDate ?? '')?.year;
    final seasons = show.numberOfSeasons ?? show.seasons.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(show.name,
            style: TextStyle(
                color: context.colors.textPrimary,
                fontSize: compact ? 24 : 28,
                height: 1.02,
                fontWeight: FontWeight.w900)),
        const SizedBox(height: 9),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: _ShowScoreBadge(
            show: show,
            onTap: () => _showFlixScoreInfo(context),
          ),
        ),
        const SizedBox(height: 7),
        Text(
            [
              if (year != null) '$year',
              if (seasons > 0)
                '$seasons ${seasons == 1 ? 'season' : 'seasons'}',
            ].join('  ·  '),
            style: TextStyle(color: context.colors.light, fontSize: 14)),
        if ((show.status ?? '').isNotEmpty) ...[
          const SizedBox(height: 8),
          _StatusChip(label: show.status!),
        ],
      ],
    );
  }

  void _showPosterViewer(TvShow show) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenShowPoster(show: show),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: 46,
      height: 46,
      child: IconButton(
        onPressed: onTap,
        tooltip: icon == Icons.ios_share_rounded
            ? 'Share show'
            : icon == Icons.home_outlined
                ? 'Home'
                : 'Back',
        style: IconButton.styleFrom(
          backgroundColor: context.colors.surface,
          shape: const CircleBorder(),
        ),
        icon: Icon(icon, color: context.colors.light, size: 21),
      ),
    );
  }

  void _showFlixScoreInfo(BuildContext context) {
    showFlixiePromptSheet<void>(
      context: context,
      builder: (context) => FlixiePromptSheetContent(
        title: Text(
          'FLIXSCORE',
          style: TextStyle(
            color: context.colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Community ratings from Flixie. The score updates as viewers rate this show.',
          style: TextStyle(
            color: context.colors.light,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Got it',
              style: TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShowScoreBadge extends StatelessWidget {
  const _ShowScoreBadge({required this.show, required this.onTap});

  final TvShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final score = show.flixieScore ?? show.voteAverage;
    final voteCount = show.voteCount ?? 0;
    final hasScore = score != null && score > 0 && voteCount > 0;
    final color = !hasScore
        ? context.colors.medium
        : score >= 8
            ? context.colors.success
            : score >= 7
                ? context.colors.tertiary
                : score >= 6
                    ? context.colors.warning
                    : context.colors.danger;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: FlixiePill.label(
            compact: false,
            avatar: Icon(Icons.star_rounded, color: color),
            label: Text(hasScore
                ? '${score.toStringAsFixed(1)}/10  FlixScore'
                : 'No FlixScore yet')),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.label(label: Text(label));
  }
}
