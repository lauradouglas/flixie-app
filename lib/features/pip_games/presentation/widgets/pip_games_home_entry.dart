import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class PipGamesHomeEntry extends StatelessWidget {
  const PipGamesHomeEntry(
      {super.key, this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24)});
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Padding(
      padding: padding,
      child: Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/play'),
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Image.asset('assets/icon/pip_popcorn_catch.png',
                      width: 64, height: 88, excludeFromSemantics: true),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Play with Pip',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        const Text('Pick a game. Take a little break.'),
                      ])),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ]))),
      ));
}
