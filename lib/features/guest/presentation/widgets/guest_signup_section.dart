import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/pip_startup_illustration.dart';

/// A browsing-friendly invitation for signed-out Home visitors.
class GuestSignupSection extends StatelessWidget {
  const GuestSignupSection(
      {super.key, required this.onSignup, required this.onSignin});
  final VoidCallback onSignup;
  final VoidCallback onSignin;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(builder: (context, box) {
        final compact = box.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(16) > 20;
        return Row(children: [
          Expanded(
              child: Text('Make it your movie life.',
                  style: TextStyle(
                      fontSize: 26,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: colors.white))),
          const SizedBox(width: 12),
          ExcludeSemantics(
              child: PipStartupIllustration(
                  asset: 'assets/splash/pip/glasses.png',
                  size: compact ? 72 : 108)),
        ]);
      }),
      const SizedBox(height: 12),
      for (final benefit in [
        (
          Icons.bookmark_border,
          'Keep your next watch close',
          'Save films and shows to your watchlist.'
        ),
        (
          Icons.star_border,
          'Track your movie and TV life',
          'Log films, rate favourites and track episodes, seasons and where you left off.'
        ),
        (
          Icons.people_outline,
          'Find your film people',
          'Share reviews, join communities and plan what to watch with friends.'
        ),
      ])
        Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(benefit.$1, size: 22, color: colors.primary),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(benefit.$2,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: colors.white)),
                    const SizedBox(height: 3),
                    Text(benefit.$3,
                        style: TextStyle(
                            fontSize: 13, height: 1.4, color: colors.medium)),
                  ])),
            ])),
      SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: onSignup,
              style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Create account',
                  style: TextStyle(fontWeight: FontWeight.w700)))),
      Center(
          child: TextButton(
              onPressed: onSignin,
              child: const Text('Already a member? Sign in'))),
    ]);
  }
}
