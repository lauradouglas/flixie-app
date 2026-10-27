import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class PipGamesHomeEntry extends StatelessWidget {
  const PipGamesHomeEntry(
      {super.key,
      this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 24),
      this.compact = false});
  final EdgeInsetsGeometry padding;
  final bool compact;
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
                padding: EdgeInsets.all(compact ? 12 : 16),
                child: Row(children: [
                  Image.asset('assets/icon/pip_popcorn_catch.png',
                      width: compact ? 40 : 64,
                      height: compact ? 54 : 88,
                      excludeFromSemantics: true),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Play with Pip',
                            style: compact
                                ? const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w800)
                                : Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text('Pick a game. Take a little break.',
                            style:
                                compact ? const TextStyle(fontSize: 12) : null),
                      ])),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded),
                ]))),
      ));
}
