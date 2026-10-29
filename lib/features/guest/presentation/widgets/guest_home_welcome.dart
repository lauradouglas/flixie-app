import 'package:flutter/material.dart';

/// Discovery comes before the optional account invitation.
class GuestHomeWelcome extends StatelessWidget {
  const GuestHomeWelcome({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('What’s your next watch?',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                        height: 1.2,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text(
                    'Find films and shows. Save your next watch.\nNo account needed.'),
              ])),
          const SizedBox(width: 8),
          Image.asset('assets/icon/community_pips/pip-flixie-hoodie.png',
              width: 56,
              height: 72,
              fit: BoxFit.contain,
              excludeFromSemantics: true),
        ]),
      );
}
