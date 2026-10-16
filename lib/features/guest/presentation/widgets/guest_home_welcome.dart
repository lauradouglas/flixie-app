import 'package:flutter/material.dart';

/// A brief introduction that leaves the catalogue as Home's main content.
class GuestHomeWelcome extends StatelessWidget {
  const GuestHomeWelcome({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 360 ||
            (box.maxWidth < 600 &&
                MediaQuery.textScalerOf(context).scale(1) > 1.4);
        final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('A great watch starts here.',
                  style: Theme.of(context)
                      .textTheme
                      .headlineLarge
                      ?.copyWith(fontWeight: FontWeight.w800, height: 1.12)),
              const SizedBox(height: 12),
              Text('Explore films and shows. Find something worth watching.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(height: 1.45)),
            ]);
        final pip = ExcludeSemantics(
            child: Image.asset(
                'assets/icon/community_pips/pip-flixie-hoodie.png',
                width: compact ? 80 : 112,
                height: compact ? 104 : 146,
                fit: BoxFit.contain));
        return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        pip,
                        const SizedBox(height: 12),
                        copy,
                      ])
                : Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                    Expanded(child: copy),
                    const SizedBox(width: 16),
                    pip,
                  ]));
      });
}
