import 'package:flixie_app/core/utils/genre_catalogue.dart';
import 'package:flixie_app/core/widgets/genre_icon.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

class FriendGenreTag extends StatelessWidget {
  const FriendGenreTag({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    if (!isVisibleGenre(name)) return const SizedBox.shrink();
    return FlixiePill.label(
        colorKey: name, avatar: GenreIcon(name), label: Text(name));
  }
}
