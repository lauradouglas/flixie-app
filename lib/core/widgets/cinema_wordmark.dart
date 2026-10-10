import 'package:flutter/material.dart';
import 'flixie_wordmark.dart';

class CinemaWordmark extends StatelessWidget {
  const CinemaWordmark({super.key, required this.fontSize});
  final double fontSize;

  @override
  Widget build(BuildContext context) => HeroMode(
        enabled: !MediaQuery.disableAnimationsOf(context),
        child: Hero(
          tag: 'cinema-auth-wordmark',
          child: Material(
            color: Colors.transparent,
            child: FlixieWordmark(fontSize: fontSize),
          ),
        ),
      );
}
