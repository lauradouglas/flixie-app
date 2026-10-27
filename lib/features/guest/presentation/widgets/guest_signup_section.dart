import 'package:flutter/material.dart';

/// Optional account value after guests have had a chance to browse and collect.
class GuestSignupSection extends StatelessWidget {
  const GuestSignupSection(
      {super.key, required this.onSignup, required this.onSignin});
  final VoidCallback onSignup;
  final VoidCallback onSignin;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Your picks, wherever you sign in.',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Your watchlist works here already. An account keeps it across devices and gives your ratings and diary a home.'),
        const SizedBox(height: 16),
        OutlinedButton(
            onPressed: onSignup,
            child: const Text('Keep my picks across devices')),
        TextButton(
            onPressed: onSignin,
            child: const Text('Already a member? Sign in')),
      ]);
}
