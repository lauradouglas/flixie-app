import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

class FriendGenreTag extends StatelessWidget {
  const FriendGenreTag({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.label(colorKey: name, label: Text(name));
  }
}
