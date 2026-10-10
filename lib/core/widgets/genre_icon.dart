import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flixie_app/core/utils/genre_catalogue.dart';

/// Decorative genre mark, using the same artwork as Flixie communities.
class GenreIcon extends StatelessWidget {
  const GenreIcon(this.name, {super.key, this.size = 16});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final id = genreIconId(name);
    final color =
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.secondary;
    return ExcludeSemantics(
        child: id == null
            ? Icon(Icons.movie_outlined, size: size, color: color)
            : SvgPicture.asset('assets/icon/communities/$id.svg',
                width: size,
                height: size,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn)));
  }
}
