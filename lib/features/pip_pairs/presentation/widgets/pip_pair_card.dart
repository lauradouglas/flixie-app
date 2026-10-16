import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/pip_outfit.dart';

class PipPairCard extends StatelessWidget {
  const PipPairCard(
      {super.key,
      required this.outfit,
      required this.index,
      required this.visible,
      required this.matched,
      required this.onTap});
  final PipOutfit outfit;
  final int index;
  final bool visible;
  final bool matched;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        label:
            'Card ${index + 1}, ${visible ? outfit.name : 'face down'}${matched ? ', matched' : ''}',
        button: !matched,
        onTap: onTap,
        enabled: onTap != null,
        child: ExcludeSemantics(
            child: TweenAnimationBuilder<double>(
          tween: Tween(end: visible ? 0 : math.pi),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          builder: (context, angle, _) {
            final front = angle < math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateY(angle),
              child: Material(
                color: matched
                    ? const Color(0xFF302845)
                    : front
                        ? const Color(0xFFFFF2D5)
                        : const Color(0xFF352257),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: matched
                            ? const Color(0xFFF6CF70)
                            : front
                                ? const Color(0xFFE1B66D)
                                : const Color(0xFF8262B5),
                        width: 2)),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTap,
                  child: Stack(fit: StackFit.expand, children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: front
                          ? Image.asset(outfit.asset,
                              fit: BoxFit.contain, cacheWidth: 320)
                          : Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.rotationY(math.pi),
                              child: Center(
                                  child: Image.asset(
                                      'assets/icon/flixie_f_transparent.png',
                                      width: 32,
                                      height: 40,
                                      fit: BoxFit.contain))),
                    ),
                    if (matched)
                      const Positioned(
                          right: 4,
                          top: 4,
                          child: Icon(Icons.check_circle,
                              color: Color(0xFFF6CF70), size: 20)),
                  ]),
                ),
              ),
            );
          },
        )),
      );
}
