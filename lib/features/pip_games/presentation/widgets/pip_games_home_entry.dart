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
      child: LayoutBuilder(builder: (context, constraints) {
        final narrow = compact ||
            constraints.maxWidth < 310 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        return Semantics(
          button: true,
          child: Stack(children: [
            Positioned.fill(
                top: narrow ? 12 : 22,
                child: DecoratedBox(
                    decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(16)))),
            Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/play'),
                  child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          narrow ? 12 : 16, 0, narrow ? 12 : 16, 8),
                      child: Row(children: [
                        Image.asset('assets/icon/pip_popcorn_catch.png',
                            width: narrow ? 44 : 70,
                            height: narrow ? 66 : 98,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true),
                        SizedBox(width: narrow ? 10 : 14),
                        Expanded(
                            child: Padding(
                                padding: const EdgeInsets.only(top: 30),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Fancy a quick game?',
                                          style: TextStyle(
                                              color: context.colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              height: 1.3)),
                                      const SizedBox(height: 4),
                                      Text('Take a break with Pip.',
                                          style: TextStyle(
                                              color: context.colors.light,
                                              fontSize: 14,
                                              height: 1.5)),
                                    ]))),
                        const SizedBox(width: 10),
                        Padding(
                            padding: const EdgeInsets.only(top: 30),
                            child: Container(
                                width: narrow ? 32 : 40,
                                height: narrow ? 32 : 40,
                                decoration: BoxDecoration(
                                    color: FlixieColors.primary,
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.arrow_forward_rounded,
                                    color: Colors.white, size: 20))),
                      ])),
                )),
          ]),
        );
      }));
}
