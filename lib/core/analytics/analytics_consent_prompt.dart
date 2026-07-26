import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

import 'analytics_consent.dart';
import 'flixie_analytics.dart';

class AnalyticsConsentPrompt extends StatefulWidget {
  const AnalyticsConsentPrompt({required this.child, super.key});

  final Widget child;

  @override
  State<AnalyticsConsentPrompt> createState() => _AnalyticsConsentPromptState();
}

class _AnalyticsConsentPromptState extends State<AnalyticsConsentPrompt> {
  bool _promptScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final consent = context.watch<AnalyticsController>().consent;
    if (consent != AnalyticsConsent.unknown || _promptScheduled) return;
    _promptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _showPrompt());
  }

  Future<void> _showPrompt() async {
    if (!mounted) return;
    final analytics = context.read<AnalyticsController>();
    if (analytics.consent != AnalyticsConsent.unknown) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Share anonymous analytics?'),
        content: const SingleChildScrollView(
          child: Text(
            'If you choose to allow analytics, Flixie uses Google Analytics '
            'for Firebase to understand how the app is used and improve its '
            'features and reliability. This may collect app interactions, '
            'session information, device and operating-system information, an '
            'anonymous app-instance identifier, and approximate location '
            'derived from a masked IP address.\n\n'
            'Flixie does not send Firebase Analytics your name, email address, '
            'username, reviews, messages, watch history, or the titles of '
            'movies and television programmes you interact with. We do not '
            'use Firebase Analytics for advertising or cross-app tracking, '
            'and we do not link analytics data to your Flixie account.\n\n'
            'Analytics is disabled unless you choose to allow it. You can '
            'change your choice at any time under Settings → Share anonymous '
            'analytics. Data already processed may remain in aggregated '
            'reports in accordance with Google’s retention and deletion '
            'practices.',
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          SizedBox(
            width: 142,
            child: OutlinedButton(
              onPressed: () async {
                await analytics.decline();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Decline'),
            ),
          ),
          SizedBox(
            width: 142,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: FlixieColors.primary,
              ),
              onPressed: () async {
                await analytics.allow();
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('Allow analytics'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
