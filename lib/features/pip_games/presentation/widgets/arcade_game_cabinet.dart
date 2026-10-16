import 'package:flutter/material.dart';

/// Native controls over a decorative scene; all game selection remains accessible.
class ArcadeGameCabinet extends StatelessWidget {
  const ArcadeGameCabinet(
      {super.key,
      required this.title,
      required this.description,
      required this.asset,
      required this.neon,
      required this.onPlay});
  final String title;
  final String description;
  final String asset;
  final Color neon;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: 'Play $title. $description',
        onTap: onPlay,
        child: ExcludeSemantics(
            child: DecoratedBox(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: neon.withValues(alpha: 0.24),
                    blurRadius: 16,
                    offset: const Offset(0, 4))
              ]),
          child: Material(
            color: const Color(0xFF24103E),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: neon, width: 3)),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
                onTap: onPlay,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _MarqueeLights(),
                        const SizedBox(height: 6),
                        ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: AspectRatio(
                                aspectRatio: 2.1,
                                child: Image.asset(asset,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    cacheWidth: 1280,
                                    excludeFromSemantics: true))),
                        Container(
                          decoration: BoxDecoration(
                              color: const Color(0xFF100C25),
                              border: Border(
                                  top: BorderSide(color: neon, width: 2)),
                              borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(12))),
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: LayoutBuilder(builder: (context, constraints) {
                            final stacked = constraints.maxWidth < 300 ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.3;
                            final name = Text(title.toUpperCase(),
                                style: const TextStyle(
                                    fontFamily: 'PressStart2P',
                                    fontSize: 18,
                                    height: 1.6,
                                    color: Color(0xFFFFF0C8)));
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (stacked) ...[
                                    name,
                                    const SizedBox(height: 10),
                                    const Align(
                                        alignment: Alignment.centerRight,
                                        child: _PlaySign()),
                                  ] else
                                    Row(children: [
                                      Expanded(child: name),
                                      const SizedBox(width: 8),
                                      const _PlaySign()
                                    ]),
                                  const SizedBox(height: 8),
                                  Text(description,
                                      style: const TextStyle(
                                          color: Color(0xFFFFF0C8),
                                          height: 1.35)),
                                ]);
                          }),
                        ),
                      ]),
                )),
          ),
        )),
      );
}

class _PlaySign extends StatelessWidget {
  const _PlaySign();
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minHeight: 48, minWidth: 100),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
            gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFFFE58A), Color(0xFFFFBE40)]),
            border: Border.all(color: const Color(0xFFFFF0B1), width: 2),
            borderRadius: BorderRadius.circular(14)),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.play_arrow_rounded, color: Color(0xFF35143C), size: 24),
          SizedBox(width: 4),
          Text('PLAY',
              style: TextStyle(
                  fontFamily: 'PressStart2P',
                  fontSize: 12,
                  color: Color(0xFF35143C))),
        ]),
      );
}

class _MarqueeLights extends StatelessWidget {
  const _MarqueeLights();
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 8,
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        for (var i = 0; i < 11; i++)
          Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFFEB99),
                  boxShadow: [
                    BoxShadow(color: Color(0xFFFFBC47), blurRadius: 6)
                  ])),
      ]));
}
