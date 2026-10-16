import 'dart:math';
import 'package:flutter/material.dart';
import 'flixie_wordmark.dart';
import 'pip_griddy.dart';

class PipStartupBrand extends StatelessWidget {
  const PipStartupBrand({super.key});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final size = min(
            165.0, min(box.maxWidth, MediaQuery.sizeOf(context).height * .225));
        return Column(mainAxisSize: MainAxisSize.min, children: [
          PipGriddy(size: size),
          const SizedBox(height: 12),
          const FlixieWordmark(fontSize: 36),
        ]);
      });
}
