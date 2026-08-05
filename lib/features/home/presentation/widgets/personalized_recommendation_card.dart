import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_short.dart';

class PersonalizedRecommendationCard extends StatelessWidget {
  const PersonalizedRecommendationCard({
    super.key,
    required this.movie,
    required this.reasons,
    required this.isBookmarked,
    required this.isBookmarkUpdating,
    required this.isPreviouslyWatched,
    required this.onTap,
    required this.onBookmarkTap,
    required this.onMarkWatched,
    required this.onNotInterested,
  });

  final MovieShort movie;
  final List<String> reasons;
  final bool isBookmarked;
  final bool isBookmarkUpdating;
  final bool isPreviouslyWatched;
  final VoidCallback onTap;
  final VoidCallback onBookmarkTap;
  final VoidCallback onMarkWatched;
  final VoidCallback onNotInterested;

  // Accommodates the headline reason plus two supporting reasons at two lines.
  static const double height = 270;
  static const double posterWidth = height * 2 / 3;

  @override
  Widget build(BuildContext context) {
    final visibleReasons = reasons
        .where((reason) => reason.trim().isNotEmpty)
        .take(3)
        .toList(growable: false);
    final primaryReason = visibleReasons.isEmpty
        ? 'Picked for you based on your movie taste'
        : visibleReasons.first;
    final supportingReasons = visibleReasons.skip(1);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [FlixieColors.surfaceElevated, FlixieColors.surface],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.tabBarBorder),
            boxShadow: [
              BoxShadow(
                color: FlixieColors.primary.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
                child: SizedBox(
                  width: posterWidth,
                  height: height,
                  child: _poster(),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 13, 12, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        movie.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontSize: 18,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _metadata,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (movie.voteAverage != null &&
                          movie.voteAverage! > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: FlixieColors.warning, size: 18),
                            const SizedBox(width: 4),
                            Text(
                              movie.voteAverage!.toStringAsFixed(1),
                              style: const TextStyle(
                                color: FlixieColors.warning,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 9),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 1),
                            child: Icon(Icons.auto_awesome_rounded,
                                color: FlixieColors.warning, size: 13),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              primaryReason,
                              maxLines: 3,
                              overflow: TextOverflow.clip,
                              style: const TextStyle(
                                color: FlixieColors.warningTint,
                                fontSize: 11,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (final reason in supportingReasons) ...[
                        const SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                color: FlixieColors.primary,
                                size: 11,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                reason,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontSize: 9.5,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const Spacer(),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            _ActionButton(
                              tooltip: isPreviouslyWatched
                                  ? 'Log another watch'
                                  : 'Mark watched',
                              icon: isPreviouslyWatched
                                  ? Icons.replay_circle_filled_rounded
                                  : Icons.check_circle_outline_rounded,
                              color: FlixieColors.success,
                              borderColor:
                                  FlixieColors.success.withValues(alpha: 0.38),
                              backgroundColor:
                                  FlixieColors.success.withValues(alpha: 0.10),
                              onPressed: onMarkWatched,
                            ),
                            const SizedBox(width: 5),
                            _ActionButton(
                              tooltip: isBookmarked
                                  ? 'Remove from watchlist'
                                  : 'Add to watchlist',
                              icon: isBookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                              color: FlixieColors.warning,
                              borderColor:
                                  FlixieColors.warning.withValues(alpha: 0.38),
                              backgroundColor:
                                  FlixieColors.warning.withValues(alpha: 0.10),
                              isBusy: isBookmarkUpdating,
                              onPressed:
                                  isBookmarkUpdating ? null : onBookmarkTap,
                            ),
                            const SizedBox(width: 5),
                            _ActionButton(
                              tooltip: 'Not interested',
                              icon: Icons.visibility_off_outlined,
                              color: FlixieColors.danger,
                              borderColor:
                                  FlixieColors.danger.withValues(alpha: 0.72),
                              backgroundColor:
                                  FlixieColors.danger.withValues(alpha: 0.08),
                              animateBeforeAction: true,
                              onPressed: onNotInterested,
                            ),
                            const SizedBox(width: 5),
                            _ActionButton(
                              tooltip: 'Movie details',
                              icon: Icons.info_outline_rounded,
                              color: const Color(0xFF64B5F6),
                              borderColor: const Color(0xFF64B5F6)
                                  .withValues(alpha: 0.38),
                              backgroundColor: const Color(0xFF64B5F6)
                                  .withValues(alpha: 0.10),
                              onPressed: onTap,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _metadata {
    final year = DateTime.tryParse(movie.releaseDate ?? '')?.year;
    return [if (year != null) '$year', 'Movie'].join(' · ');
  }

  Widget _poster() {
    final path = movie.poster;
    if (path == null || path.isEmpty) return _fallbackPoster();
    final url =
        path.startsWith('http') ? path : 'https://image.tmdb.org/t/p/w500$path';
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, __, ___) => _fallbackPoster(),
    );
  }

  Widget _fallbackPoster() => Container(
        color: FlixieColors.tabBarBackgroundFocused,
        alignment: Alignment.center,
        child: const Icon(Icons.movie_outlined,
            color: FlixieColors.medium, size: 38),
      );
}

class _ActionButton extends StatefulWidget {
  const _ActionButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.borderColor,
    this.backgroundColor,
    this.animateBeforeAction = false,
    this.isBusy = false,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final Color? borderColor;
  final Color? backgroundColor;
  final bool animateBeforeAction;
  final bool isBusy;

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton>
    with TickerProviderStateMixin {
  late final AnimationController _tapController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  late final Animation<double> _tapScale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: 0.78).chain(
        CurveTween(curve: Curves.easeOutCubic),
      ),
      weight: 38,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 0.78, end: 1.12).chain(
        CurveTween(curve: Curves.easeOutBack),
      ),
      weight: 34,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.12, end: 1.0).chain(
        CurveTween(curve: Curves.easeInOut),
      ),
      weight: 28,
    ),
  ]).animate(_tapController);
  late final AnimationController _busyController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );

  @override
  void initState() {
    super.initState();
    if (widget.isBusy) _busyController.repeat();
  }

  @override
  void didUpdateWidget(covariant _ActionButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isBusy == oldWidget.isBusy) return;
    if (widget.isBusy && !MediaQuery.disableAnimationsOf(context)) {
      _busyController.repeat();
    } else {
      _busyController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _tapController.dispose();
    _busyController.dispose();
    super.dispose();
  }

  Future<void> _handlePressed() async {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (!reduceMotion) {
      final animation = _tapController.forward(from: 0);
      if (widget.animateBeforeAction) {
        await animation;
        if (!mounted) return;
      }
    }
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: ScaleTransition(
        scale: _tapScale,
        child: IconButton(
          onPressed: widget.onPressed == null ? null : _handlePressed,
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween<double>(begin: -0.08, end: 0).animate(animation),
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: RotationTransition(
              key: ValueKey(widget.icon),
              turns: widget.isBusy
                  ? _busyController
                  : const AlwaysStoppedAnimation<double>(0),
              child: Icon(
                widget.icon,
                size: 19,
              ),
            ),
          ),
          color: widget.color,
          // Keep the selected icon legible while its optimistic update is
          // being confirmed by the API.
          disabledColor: widget.color,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          style: IconButton.styleFrom(
            backgroundColor: widget.backgroundColor ??
                FlixieColors.navy.withValues(alpha: 0.56),
            side: BorderSide(
              color: widget.borderColor ?? Colors.white.withValues(alpha: 0.08),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
    );
  }
}
