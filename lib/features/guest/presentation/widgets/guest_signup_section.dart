import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// A browsing-friendly invitation for signed-out Home visitors.
class GuestSignupSection extends StatelessWidget {
  const GuestSignupSection(
      {super.key, required this.onSignup, required this.onSignin});
  final VoidCallback onSignup;
  final VoidCallback onSignin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.primary.withValues(alpha: .22)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Make it yours.',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(
                    'Keep your next watch close. Remember what you’ve seen. Share it with your people.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.35, color: colors.light)),
              ])),
          const SizedBox(width: 8),
          Image.asset('assets/icon/community_pips/pip-flixie-hoodie.png',
              width: 64,
              height: 80,
              fit: BoxFit.contain,
              excludeFromSemantics: true),
        ]),
        const SizedBox(height: 12),
        for (final benefit in [
          (Icons.bookmark_border, 'Save your watchlist'),
          (Icons.bar_chart_rounded, 'Log watches and rate favourites'),
          (Icons.people_outline, 'Find friends and plan a watch'),
        ])
          Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border:
                    Border.all(color: colors.primary.withValues(alpha: .16))),
            child: Row(children: [
              Icon(benefit.$1, size: 23, color: colors.primary),
              const SizedBox(width: 14),
              Expanded(
                  child: Text(benefit.$2,
                      style: TextStyle(fontSize: 14, color: colors.white))),
            ]),
          ),
        const SizedBox(height: 6),
        SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onSignup,
              style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  shape: const StadiumBorder(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                        child: Text('Create account',
                            style: TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ]),
            )),
        Center(
            child: TextButton(
                onPressed: onSignin,
                child: Text('Already a member? Sign in',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: colors.light)))),
      ]),
    );
  }
}
