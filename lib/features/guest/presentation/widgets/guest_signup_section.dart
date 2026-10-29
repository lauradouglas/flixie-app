import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Optional account value after guests have had a chance to browse and collect.
class GuestSignupSection extends StatelessWidget {
  const GuestSignupSection(
      {super.key, required this.onSignup, required this.onSignin});
  final VoidCallback onSignup;
  final VoidCallback onSignin;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ExcludeSemantics(
                child: SizedBox.square(
                    dimension: 34,
                    child: Stack(children: [
                      Icon(Icons.bookmark_outline_rounded,
                          size: 30, color: context.colors.primaryText),
                      Positioned(
                          right: 0,
                          bottom: 0,
                          child: ColoredBox(
                              color: context.colors.surface,
                              child: Icon(Icons.sync_rounded,
                                  size: 16,
                                  color: context.colors.primaryText))),
                    ]))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text('Make yourself at home.',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(
                      'Keep your watchlist across devices and start your film diary.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: context.colors.light, height: 1.5)),
                ])),
          ]),
          const SizedBox(height: 18),
          const Wrap(spacing: 24, runSpacing: 12, children: [
            _AccountBenefit(
                icon: Icons.bookmark_outline_rounded, label: 'Watchlist'),
            _AccountBenefit(
                icon: Icons.menu_book_outlined, label: 'Film diary'),
          ]),
          const SizedBox(height: 18),
          FilledButton(
              onPressed: onSignup,
              style: FilledButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              child: const Text('Create free account',
                  textAlign: TextAlign.center)),
          const SizedBox(height: 8),
          TextButton(
              onPressed: onSignin,
              style: TextButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  foregroundColor: context.colors.primaryText),
              child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'Already a member? ',
                        style: TextStyle(color: context.colors.light)),
                    TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                            color: context.colors.primaryText,
                            fontWeight: FontWeight.w600)),
                  ]),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, height: 1.5))),
        ]),
      );
}

class _AccountBenefit extends StatelessWidget {
  const _AccountBenefit({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 22, color: context.colors.primaryText),
        const SizedBox(width: 8),
        Flexible(
            child: Text(label,
                style: TextStyle(color: context.colors.light, fontSize: 14))),
      ]);
}
