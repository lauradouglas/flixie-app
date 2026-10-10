import 'media_backdrop_inset.dart';
import 'movie_header_backdrop.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'full_screen_movie_poster.dart';
import 'genre_chip.dart';
import 'movie_detail_hero_tokens.dart';

class MovieDetailHero extends StatefulWidget {
  const MovieDetailHero(
      {super.key,
      required this.movie,
      required this.onShowScoreInfo,
      this.animateBackdropInset = false});
  final bool animateBackdropInset;
  final Movie movie;
  final VoidCallback onShowScoreInfo;
  @override
  State<MovieDetailHero> createState() => _MovieDetailHeroState();
}

class _MovieDetailHeroState extends State<MovieDetailHero> {
  String? _heroControlPosterPath;
  Color _heroControlBackgroundColor = Colors.black
      .withValues(alpha: MovieDetailHeroTokens.navButtonDarkBgAlpha);
  Color _heroControlIconColor = FlixieColors.white;
  Color _heroControlBorderColor = Colors.white
      .withValues(alpha: MovieDetailHeroTokens.navButtonBorderAlpha);
  Color _heroControlShadowColor = Colors.black
      .withValues(alpha: MovieDetailHeroTokens.navButtonShadowAlpha);
  bool _heroControlMinimal = false;
  static const List<Color> _kGenreChipColors = [
    Color(0xFF9B6CFF),
    FlixieColors.secondary,
    FlixieColors.tertiary,
    FlixieColors.warning,
  ];
  @override
  void initState() {
    super.initState();
    _syncHeroControlContrast(widget.movie);
  }

  @override
  void didUpdateWidget(covariant MovieDetailHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movie.posterPath != widget.movie.posterPath) {
      _syncHeroControlContrast(widget.movie);
    }
  }

  /// Formats the hero release date as year-only, or full date when released this year.
  String _formatHeroReleaseDate(String? iso) {
    final dt = DateTime.tryParse(iso ?? '');
    if (dt == null) return '';

    if (dt.year == DateTime.now().year) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }

    return '${dt.year}';
  }

  /// Formats runtime in minutes to "Xh Ym".
  String _formatRuntime(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  void _setHeroControlScheme({
    required bool darkPoster,
  }) {
    if (darkPoster) {
      _heroControlMinimal = true;
      _heroControlBackgroundColor = Colors.black
          .withValues(alpha: MovieDetailHeroTokens.navButtonDarkMinimalBgAlpha);
      _heroControlIconColor = Colors.white;
      _heroControlBorderColor = Colors.white
          .withValues(alpha: MovieDetailHeroTokens.navButtonMinimalBorderAlpha);
      _heroControlShadowColor = Colors.black
          .withValues(alpha: MovieDetailHeroTokens.navButtonMinimalShadowAlpha);
      return;
    }

    _heroControlMinimal = false;
    _heroControlBackgroundColor = Colors.white
        .withValues(alpha: MovieDetailHeroTokens.navButtonLightBgAlpha);
    _heroControlIconColor = Colors.black.withValues(alpha: 0.88);
    _heroControlBorderColor = Colors.black.withValues(alpha: 0.18);
    _heroControlShadowColor = Colors.black.withValues(alpha: 0.18);
  }

  Future<void> _syncHeroControlContrast(Movie movie) async {
    final posterPath = movie.posterPath;
    if (_heroControlPosterPath == posterPath) return;
    _heroControlPosterPath = posterPath;

    if (posterPath == null || posterPath.isEmpty) {
      if (mounted) {
        setState(() => _setHeroControlScheme(darkPoster: false));
      }
      return;
    }

    final posterUrl = 'https://image.tmdb.org/t/p/w342$posterPath';
    try {
      final palette = await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(posterUrl),
        size: const Size(120, 180),
        maximumColorCount: 12,
      );

      if (!mounted || _heroControlPosterPath != posterPath) return;

      final swatch = palette.dominantColor?.color ??
          palette.vibrantColor?.color ??
          palette.darkVibrantColor?.color ??
          palette.mutedColor?.color;

      if (swatch == null) {
        setState(() => _setHeroControlScheme(darkPoster: false));
        return;
      }

      final isLightPoster =
          ThemeData.estimateBrightnessForColor(swatch) == Brightness.light;
      setState(() => _setHeroControlScheme(darkPoster: !isLightPoster));
    } catch (_) {
      if (!mounted || _heroControlPosterPath != posterPath) return;
      setState(() => _setHeroControlScheme(darkPoster: false));
    }
  }

  Widget _heroIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Semantics(
        button: true,
        label: icon == Icons.home_outlined ? 'Home' : 'Back',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: MovieDetailHeroTokens.navButtonSize,
              height: MovieDetailHeroTokens.navButtonSize,
              child: _heroControlChrome(
                child: Icon(
                  icon,
                  color: _heroControlIconColor,
                  size: _heroControlMinimal
                      ? MovieDetailHeroTokens.navIconSizeMinimal
                      : MovieDetailHeroTokens.navIconSize,
                ),
              ),
            ),
          ),
        ));
  }

  Widget _heroControlChrome({required Widget child}) {
    final blurSigma = _heroControlMinimal
        ? MovieDetailHeroTokens.navButtonMinimalBlurSigma
        : MovieDetailHeroTokens.navButtonBlurSigma;
    final borderWidth = _heroControlMinimal
        ? MovieDetailHeroTokens.navButtonMinimalBorderWidth
        : MovieDetailHeroTokens.navButtonBorderWidth;

    return ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _heroControlMinimal
                    ? _heroControlBackgroundColor
                    : _heroControlBackgroundColor.withValues(alpha: 0.78),
                _heroControlBackgroundColor,
              ],
            ),
            border: Border.all(
              color: _heroControlBorderColor,
              width: borderWidth,
            ),
            boxShadow: [
              BoxShadow(
                color: _heroControlShadowColor,
                blurRadius: _heroControlMinimal ? 4 : 10,
                offset: Offset(0, _heroControlMinimal ? 2 : 4),
              ),
            ],
          ),
          child: Center(child: child),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final movie = widget.movie;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 500;
        final safeTop = MediaQuery.paddingOf(context).top;
        final hasBackdrop = movie.backdropPath?.trim().isNotEmpty == true;
        final heroScrimHeight =
            safeTop + MovieDetailHeroTokens.heroTopScrimHeight;
        final posterWidth = (constraints.maxWidth *
                (compact
                    ? MovieDetailHeroTokens.posterCompactWidthFactor
                    : MovieDetailHeroTokens.posterRegularWidthFactor))
            .clamp(MovieDetailHeroTokens.posterMinWidth,
                MovieDetailHeroTokens.posterMaxWidth);

        final stacked = constraints.maxWidth < 330 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        return Stack(
          children: [
            if (hasBackdrop)
              Positioned.fill(
                  child: MovieHeaderBackdrop(path: movie.backdropPath!.trim())),
            MediaBackdropInset(
              animate: widget.animateBackdropInset,
              hasBackdrop: hasBackdrop,
              width: constraints.maxWidth,
              top: safeTop + MovieDetailHeroTokens.heroSurfaceTopPadding,
              bottom: MovieDetailHeroTokens.heroSurfaceBottomPadding,
              child: Flex(
                direction: stacked ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: posterWidth.toDouble(),
                    child: AspectRatio(
                      aspectRatio: MovieDetailHeroTokens.posterAspectRatio,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(
                              MovieDetailHeroTokens.posterCornerRadius),
                          topRight: Radius.circular(
                              MovieDetailHeroTokens.posterRightRadius),
                          bottomLeft: Radius.circular(
                              MovieDetailHeroTokens.posterCornerRadius),
                          bottomRight: Radius.circular(
                              MovieDetailHeroTokens.posterRightRadius),
                        ),
                        child: Hero(
                          tag: 'movie-poster-${movie.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: movie.posterPath == null
                                  ? null
                                  : () => _showPosterViewer(movie),
                              child: movie.posterPath == null
                                  ? Container(
                                      color: context
                                          .colors.tabBarBackgroundFocused,
                                      child: Icon(Icons.movie_outlined,
                                          color: context.colors.medium,
                                          size: 42),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w780${movie.posterPath}',
                                      fit: BoxFit.cover,
                                      alignment: Alignment.center,
                                      errorWidget: (_, __, ___) => Center(
                                        child: Icon(Icons.movie_outlined,
                                            color: context.colors.medium,
                                            size: 42),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: MovieDetailHeroTokens.heroColumnGap),
                  Expanded(
                    flex: stacked ? 0 : 1,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        right: MovieDetailHeroTokens.heroContentRightInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(
                              top: compact ? 4 : 6,
                            ),
                            child: _buildTitleBlock(context, movie,
                                compact: compact),
                          ),
                          SizedBox(
                            height: compact
                                ? MovieDetailHeroTokens.textBlockGapCompact
                                : MovieDetailHeroTokens.textBlockGapRegular,
                          ),
                          _buildHeroFlixScoreBadge(context, movie),
                          SizedBox(
                            height: compact
                                ? MovieDetailHeroTokens.textBlockGapCompact
                                : MovieDetailHeroTokens.textBlockGapRegular,
                          ),
                          _buildHeroMetadataRow(movie, compact: compact),
                          if ((movie.tagline ?? '').isNotEmpty) ...[
                            SizedBox(
                              height: compact
                                  ? MovieDetailHeroTokens.textBlockGapCompact
                                  : MovieDetailHeroTokens.textBlockGapRegular,
                            ),
                            Text(
                              movie.tagline!,
                              style: TextStyle(
                                color: context.colors.light,
                                fontSize: compact
                                    ? MovieDetailHeroTokens.taglineCompact
                                    : MovieDetailHeroTokens.taglineRegular,
                                fontWeight: FontWeight.w700,
                                height: MovieDetailHeroTokens.taglineLineHeight,
                              ),
                            ),
                          ],
                          SizedBox(
                            height: compact
                                ? MovieDetailHeroTokens.genreTopGapCompact
                                : MovieDetailHeroTokens.genreTopGapRegular,
                          ),
                          _buildGenrePills(
                            movie,
                            compact: compact,
                            maxItems: compact ? 2 : 3,
                          ),
                          SizedBox(
                            height: compact
                                ? MovieDetailHeroTokens.textBlockGapCompact
                                : MovieDetailHeroTokens.textBlockGapRegular,
                          ),
                          _buildHeroLinks(movie, compact: true),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: heroScrimHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
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
          ],
        );
      },
    );
  }

  void _showPosterViewer(Movie movie) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 260),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) =>
            FullScreenMoviePoster(movie: movie),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  // ---- Title + meta --------------------------------------------------------

  Widget _buildTitleBlock(BuildContext context, Movie movie,
      {bool compact = false}) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = compact
        ? MovieDetailHeroTokens.titleCompact
        : (width < 700
            ? MovieDetailHeroTokens.titleRegular
            : MovieDetailHeroTokens.titleWide);

    return Text(
      movie.title,
      style: TextStyle(
        color: context.colors.white,
        fontSize: titleSize,
        fontWeight: FontWeight.w900,
        height: MovieDetailHeroTokens.titleLineHeight,
        letterSpacing: MovieDetailHeroTokens.titleLetterSpacing,
      ),
    );
  }

  Widget _buildHeroMetadataRow(Movie movie, {required bool compact}) {
    final year = _formatHeroReleaseDate(movie.releaseDate);
    final runtime = _formatRuntime(movie.runtime);
    final metadata = [year, runtime].where((item) => item.isNotEmpty).toList();

    if (metadata.isEmpty) {
      return const SizedBox.shrink();
    }

    final style = TextStyle(
      color: context.colors.light
          .withValues(alpha: MovieDetailHeroTokens.metadataAlpha),
      fontSize: compact
          ? MovieDetailHeroTokens.metadataCompact
          : MovieDetailHeroTokens.metadataRegular,
      fontWeight: FontWeight.w700,
      height: MovieDetailHeroTokens.metadataLineHeight,
    );
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var index = 0; index < metadata.length; index++) ...[
          if (index > 0) Text('•', style: style),
          Text(metadata[index], style: style),
        ],
      ],
    );
  }

  Widget _buildHeroFlixScoreBadge(BuildContext context, Movie movie) {
    final scoresHidden = hideMovieRatings(context, movie.id);
    final score = scoresHidden ? null : movie.voteAverage;
    final voteCount = movie.voteCount ?? 0;
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

    if (!hasScore) {
      return TextButton(
          onPressed: widget.onShowScoreInfo,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: Text(scoresHidden ? 'Rate to see scores' : 'No ratings yet'));
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: widget.onShowScoreInfo,
        child: FlixiePill.label(
            compact: false,
            avatar: Icon(Icons.star_rounded, color: color),
            label: Text(hasScore
                ? '${score.toStringAsFixed(1)}  FlixScore'
                : 'No FlixScore yet')),
      ),
    );
  }

  Widget _buildHeroLinks(Movie movie, {required bool compact}) {
    final videos = movie.videos ?? const [];
    final trailer = videos
        .where((video) =>
            video.videoTypeName.trim().toLowerCase() == 'trailer' &&
            video.key.trim().isNotEmpty)
        .firstOrNull;

    if (trailer == null) return const SizedBox.shrink();

    return _heroTextAction(
      icon: Icons.play_circle_outline_rounded,
      label: 'Watch trailer',
      iconColor: context.colors.danger,
      compact: compact,
      onTap: () => _openTrailer(trailer.youtubeUrl),
    );
  }

  Widget _heroTextAction({
    required IconData icon,
    required String label,
    Color iconColor = FlixieColors.light,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(MovieDetailHeroTokens.textActionRadius),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: MovieDetailHeroTokens.textActionVerticalPadding),
        child: SizedBox(
          height: compact
              ? MovieDetailHeroTokens.textActionIconCompact
              : MovieDetailHeroTokens.textActionIconRegular,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: iconColor,
                size: compact
                    ? MovieDetailHeroTokens.textActionIconCompact
                    : MovieDetailHeroTokens.textActionIconRegular,
              ),
              const SizedBox(width: 6),
              Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: context.colors.light,
                    fontSize: compact
                        ? MovieDetailHeroTokens.textActionLabelCompact
                        : MovieDetailHeroTokens.textActionLabelRegular,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openTrailer(String trailerUrl) async {
    final uri = Uri.tryParse(trailerUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not open this trailer')),
        );
      }
    }
  }

  // ---- Genre pills ---------------------------------------------------------

  Widget _buildGenrePills(Movie movie, {bool compact = false, int? maxItems}) {
    final genres = movie.genres;
    if (genres == null || genres.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleCount = maxItems ?? (compact ? 2 : genres.length);

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: genres.take(visibleCount).toList().asMap().entries.map((entry) {
        return GenreChip(
          label: entry.value.name.toUpperCase(),
          color: _kGenreChipColors[entry.key % _kGenreChipColors.length],
          compact: true,
        );
      }).toList(),
    );
  }
}
