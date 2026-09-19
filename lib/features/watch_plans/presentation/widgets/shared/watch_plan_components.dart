import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// The same poster and surface treatment for group and direct Watch Plans.
class WatchPlanPoster extends StatelessWidget {
  const WatchPlanPoster({super.key, this.path, this.title, this.width = 80});
  final String? path;
  final String? title;
  final double width;
  @override
  Widget build(BuildContext context) {
    final url = path == null || path!.isEmpty
        ? null
        : path!.startsWith('http')
            ? path
            : 'https://image.tmdb.org/t/p/w342$path';
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: width * 1.5,
        child: url == null
            ? ColoredBox(
                color: context.colors.surfaceElevated,
                child: Center(
                  child: Text(
                    title?.isNotEmpty == true ? title![0] : '?',
                    style: TextStyle(
                        color: context.colors.primaryText,
                        fontSize: 24,
                        fontWeight: FontWeight.w900),
                  ),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => ColoredBox(
                  color: context.colors.surfaceElevated,
                  child:
                      Icon(Icons.movie_outlined, color: context.colors.medium),
                ),
              ),
      ),
    );
  }
}

class WatchPlanSurface extends StatelessWidget {
  const WatchPlanSurface(
      {super.key,
      required this.child,
      this.border,
      this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final Color? border;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border ?? context.colors.tabBarBorder),
        ),
        child: child,
      );
}

/// Overlapping artwork for a plan whose movie is still being chosen.
class WatchPlanPosterStack extends StatelessWidget {
  const WatchPlanPosterStack({super.key, required this.posters});
  final List<WatchPlanPoster> posters;
  @override
  Widget build(BuildContext context) {
    final visible = posters.take(3).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    if (visible.length == 1) return visible.first;
    final width = visible.first.width;
    return SizedBox(
      width: width + 9 * (visible.length - 1),
      height: width * 1.5 + 9 * (visible.length - 1),
      child: Stack(children: [
        for (var i = visible.length - 1; i >= 0; i--)
          Positioned(left: i * 9.0, top: i * 9.0, child: visible[i]),
      ]),
    );
  }
}
