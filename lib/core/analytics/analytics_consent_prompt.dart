import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/router/router.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedulePrompt());
  }

  void _schedulePrompt() {
    // The router replaces its initial splash route shortly after launch. Give
    // that transition time to complete so it cannot dismiss this dialog.
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _showPrompt();
    });
  }

  Future<void> _showPrompt() async {
    if (!mounted) return;
    final analytics = context.read<AnalyticsController>();
    if (analytics.consent != AnalyticsConsent.unknown) return;
    // This widget is installed by MaterialApp.router's builder, which is
    // above the Navigator. Use the router's context so the dialog has a
    // Navigator ancestor instead of trying to push from the builder context.
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      _promptScheduled = false;
      _schedulePrompt();
      return;
    }

    await showFlixiePromptSheet<void>(
      context: navigatorContext,
      isDismissible: false,
      builder: (dialogContext) => FlixiePromptSheetContent(
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
        actions: [
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await analytics.decline();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                onPressed: () async {
                  await analytics.allow();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                },
                child:
                    const Text('Allow analytics', maxLines: 1, softWrap: false),
              ),
            ],
          ),
        ],
      ),
    );
    // A route rebuild can still dismiss a dialog during an unusually slow
    // startup. Reopen it once the router is stable unless a choice was made.
    if (mounted && analytics.consent == AnalyticsConsent.unknown) {
      _promptScheduled = false;
      _schedulePrompt();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
