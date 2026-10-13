import 'dart:math';
import 'package:flutter/material.dart';
import 'flixie_wordmark.dart';
import 'pip_startup_illustration.dart';

/// Choose once for this process, so startup never changes character mid-load.
class PipStartupArtwork {
  static const assets = [
    'assets/splash/pip/popcorn.png',
    'assets/splash/pip/glasses.png',
    'assets/splash/pip/drink.png',
    'assets/splash/pip/ticket.png',
  ];
  static final String launchAsset = assets[Random().nextInt(assets.length)];
}

class PipStartupBrand extends StatelessWidget {
  const PipStartupBrand({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = min(
            220.0, min(box.maxWidth, MediaQuery.sizeOf(context).height * .30));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PipStartupIllustration(
              asset: PipStartupArtwork.launchAsset, size: size),
          const SizedBox(height: 12),
          const FlixieWordmark(fontSize: 36),
        ]);
      });
}
