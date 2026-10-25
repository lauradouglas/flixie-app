import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The same optional tour entry on Welcome, guest Home and guest You.
class WhyFlixieButton extends StatelessWidget {
  const WhyFlixieButton({super.key});

  static const label = 'See what makes Flixie different';

  @override
  Widget build(BuildContext context) => OutlinedButton(
        onPressed: () => context.push('/why-flixie'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label, textAlign: TextAlign.center)),
          SizedBox(width: 10),
          Icon(Icons.arrow_forward_rounded, size: 18),
        ]),
      );
}
