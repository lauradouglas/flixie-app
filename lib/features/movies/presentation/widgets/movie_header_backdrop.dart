import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Decorative header artwork. Loading/error states leave the original surface visible.
class MovieHeaderBackdrop extends StatelessWidget {
  const MovieHeaderBackdrop({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) => IgnorePointer(
          child: ExcludeSemantics(
              child: CachedNetworkImage(
        imageUrl: path.startsWith('http')
            ? path
            : 'https://image.tmdb.org/t/p/w1280$path',
        fit: BoxFit.cover,
        placeholder: (_, __) => const SizedBox.shrink(),
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
        imageBuilder: (context, provider) =>
            Stack(fit: StackFit.expand, children: [
          Image(
              image: provider,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter),
          DecoratedBox(
              decoration: BoxDecoration(
                  gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.colors.background.withValues(alpha: .65),
              context.colors.background.withValues(alpha: .82),
              context.colors.background
            ],
            stops: const [0, .65, 1],
          ))),
        ]),
      )));
}
