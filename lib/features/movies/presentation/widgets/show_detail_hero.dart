import 'media_backdrop_inset.dart';
import 'show_status_badge.dart';
import 'movie_header_backdrop.dart';
import 'movie_detail_hero_tokens.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_images.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/show.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class ShowDetailHero extends StatefulWidget {
  const ShowDetailHero(
      {super.key, required this.show, this.animateBackdropInset = false});
  final bool animateBackdropInset;
  final TvShow show;
  @override
  State<ShowDetailHero> createState() => _ShowDetailHeroState();
}

class _ShowDetailHeroState extends State<ShowDetailHero> {
  @override
  Widget build(BuildContext context) {
    final show = widget.show;
    return SliverToBoxAdapter(
      child: LayoutBuilder(builder: (context, constraints) {
        final safeTop = MediaQuery.paddingOf(context).top;
        final hasBackdrop = show.backdropPath?.trim().isNotEmpty == true;
        final stacked = constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final posterWidth = (constraints.maxWidth *
                (constraints.maxWidth < 500
                    ? MovieDetailHeroTokens.posterCompactWidthFactor
                    : MovieDetailHeroTokens.posterRegularWidthFactor))
            .clamp(MovieDetailHeroTokens.posterMinWidth,
                MovieDetailHeroTokens.posterMaxWidth);
        final poster = SizedBox(
          width: posterWidth,
          child: AspectRatio(
            aspectRatio: 2 / 3,
            child: InkWell(
              onTap: () => _showPosterViewer(show),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(12)),
                child: ShowPoster(path: show.posterPath),
              ),
            ),
          ),
        );
        final info = Padding(
          padding: const EdgeInsets.only(right: 16, top: 4),
          child: _buildHeroInformation(show, compact: true),
        );
        return Stack(children: [
          if (hasBackdrop)
            Positioned.fill(
                child: MovieHeaderBackdrop(path: show.backdropPath!.trim())),
          MediaBackdropInset(
            animate: widget.animateBackdropInset,
            hasBackdrop: hasBackdrop,
            width: constraints.maxWidth,
            top: safeTop,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (stacked)
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        poster,
                        const SizedBox(height: 16),
                        Padding(
                            padding: const EdgeInsets.only(left: 16),
                            child: info)
                      ])
                else
                  Row(
                      crossAxisAlignment: hasBackdrop
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        poster,
                        const SizedBox(width: 12),
                        Expanded(child: info)
                      ]),
              ],
            ),
          ),
          Positioned(
            top: safeTop + MovieDetailHeroTokens.heroControlsTopInset,
            left: MovieDetailHeroTokens.pageHorizontalPadding,
            child: _heroIconButton(
              icon: flixieBackIcon(context,
                  backIcon: Icons.arrow_back_ios_new_rounded),
              onTap: () => flixieBackOrHome(context),
            ),
          ),
        ]);
      }),
    );
  }

  Widget _buildHeroInformation(TvShow show, {required bool compact}) {
    final years = showYearRange(show);
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
              if (years != null) years,
              if (seasons > 0)
                '$seasons ${seasons == 1 ? 'season' : 'seasons'}',
            ].join('  ·  '),
            style: TextStyle(color: context.colors.light, fontSize: 14)),
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
