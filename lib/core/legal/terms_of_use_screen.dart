import 'package:flutter/material.dart';

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => const TermsOfUseScreen(),
      ),
    );
  }

  static const sections = <(String, String)>[
    (
      'Using Flixie',
      'These Terms of Use govern your use of Flixie. You must agree to them '
          'before creating an account or signing in. Use Flixie lawfully, '
          'respect other people and keep your account credentials secure.',
    ),
    (
      'Zero tolerance for objectionable content and abuse',
      'Flixie has zero tolerance for objectionable content or abusive users. '
          'Do not post, upload or share content that is hateful, discriminatory, '
          'sexually explicit, threatening, violent, illegal or otherwise abusive. '
          'Harassment, bullying, impersonation, spam and sharing another '
          'person’s private information without permission are prohibited. '
          'These rules apply to profiles, reviews, comments, messages and all '
          'other user-generated content.',
    ),
    (
      'Your content',
      'Only share content you have the right to share. You remain responsible '
          'for your content and give Flixie permission to store and display it '
          'as needed to operate the service. Do not infringe other people’s '
          'copyright, privacy or other rights.',
    ),
    (
      'Reporting and blocking',
      'Use Report in a user or content menu to flag objectionable content or '
          'behaviour for review. To block someone, open their profile menu and '
          'choose Block user. You can manage blocked users in Settings → '
          'Blocked Users. For further help, use Help Center or Send Feedback '
          'in Settings.',
    ),
    (
      'Moderation and enforcement',
      'Flixie may review reported content, remove objectionable content and '
          'suspend or terminate accounts that violate these terms. Abusive '
          'users may be removed from the service. Do not evade a block, '
          'suspension or other moderation action.',
    ),
    (
      'Privacy and your rights',
      'See the Privacy Policy in Settings for information about how Flixie '
          'handles personal data. Nothing in these terms limits rights you '
          'have under applicable consumer law.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Use')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Effective 16 September 2026',
                      style: textTheme.bodySmall),
                  for (final section in sections) ...[
                    const SizedBox(height: 24),
                    Text(section.$1, style: textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(section.$2, style: textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
