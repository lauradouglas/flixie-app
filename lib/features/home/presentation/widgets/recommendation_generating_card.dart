import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class RecommendationGeneratingCard extends StatefulWidget {
  const RecommendationGeneratingCard({super.key});

  @override
  State<RecommendationGeneratingCard> createState() =>
      _RecommendationGeneratingCardState();
}

class _RecommendationGeneratingCardState
    extends State<RecommendationGeneratingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller
        ..stop()
        ..value = 0.5;
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            FlixieColors.primary.withValues(alpha: 0.18),
            context.colors.surfaceElevated,
            context.colors.tertiary.withValues(alpha: 0.10),
          ],
        ),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.28)),
      ),
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final movement = Curves.easeInOut.transform(_controller.value);
            return Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                Positioned(
                  left: 34,
                  top: 68,
                  child: Transform.translate(
                    offset: Offset(0, -movement * 8),
                    child: Transform.rotate(
                      angle: -0.14 + (movement * 0.05),
                      child: _GeneratingPoster(
                        color: context.colors.tertiary,
                        icon: Icons.favorite_rounded,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 34,
                  top: 68,
                  child: Transform.translate(
                    offset: Offset(0, movement * 8),
                    child: Transform.rotate(
                      angle: 0.14 - (movement * 0.05),
                      child: _GeneratingPoster(
                        color: context.colors.success,
                        icon: Icons.thumb_up_alt_rounded,
                      ),
                    ),
                  ),
                ),
                Center(
                    child: Transform.translate(
                  offset: Offset(0, -10 + (movement * 5)),
                  child: Container(
                    width: 88,
                    height: 112,
                    decoration: BoxDecoration(
                      color: context.colors.tabBarBackgroundFocused,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: FlixieColors.primary.withValues(alpha: 0.7),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: FlixieColors.primary.withValues(
                            alpha: 0.18 + movement * 0.12,
                          ),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: FlixieColors.primary,
                      size: 38,
                    ),
                  ),
                )),
                Positioned(
                  top: 46,
                  left: 112,
                  child: Transform.translate(
                    offset: Offset(0, movement * 5),
                    child: Icon(
                      Icons.star_rounded,
                      color: context.colors.tertiary,
                      size: 18,
                    ),
                  ),
                ),
                Positioned(
                  top: 52,
                  right: 108,
                  child: Transform.translate(
                    offset: Offset(0, -movement * 5),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: FlixieColors.primary,
                      size: 16,
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 24,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Mixing your movie magic…',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    Text('Taste, favourites and a little sparkle',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GeneratingPoster extends StatelessWidget {
  const _GeneratingPoster({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 88,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Icon(icon, color: color, size: 25),
    );
  }
}
