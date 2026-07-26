import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/referral_summary.dart';

class InviteFriendScreen extends StatefulWidget {
  const InviteFriendScreen({super.key});

  @override
  State<InviteFriendScreen> createState() => _InviteFriendScreenState();
}

class _InviteFriendScreenState extends State<InviteFriendScreen> {
  late Future<ReferralSummary> _summary;

  @override
  void initState() {
    super.initState();
    _summary = UserService.getMyReferral();
  }

  Future<void> _share(ReferralSummary summary) async {
    const reason =
        'Flixie helps us find films and shows and plan what to watch together.';
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'I invited you to Flixie! $reason\n\n'
      'Join the iOS beta: ${summary.inviteUrl}\n'
      'Your referral code: ${summary.code}',
      subject: 'Join me on Flixie',
      sharePositionOrigin:
          box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    );
    if (mounted) {
      await context.read<AnalyticsController>().referralInviteShared();
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('Invite a friend')),
      body: FutureBuilder<ReferralSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: FilledButton(
                onPressed: () => setState(
                  () => _summary = UserService.getMyReferral(),
                ),
                child: const Text('Try again'),
              ),
            );
          }
          final summary = snapshot.data!;
          final isAndroid = defaultTargetPlatform == TargetPlatform.android;
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Icon(
                Icons.people_alt_outlined,
                size: 58,
                color: FlixieColors.primary,
              ),
              const SizedBox(height: 18),
              Text(
                'Flixie is better with friends',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: FlixieColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Send a personal invite so you can share lists, compare '
                'favourites and plan what to watch together.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FlixieColors.medium, height: 1.45),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: FlixieColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                ),
                child: Column(
                  children: [
                    const Text(
                      'YOUR REFERRAL CODE',
                      style: TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.code,
                      style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _copyCode(summary.code),
                      icon: const Icon(Icons.copy_outlined),
                      label: const Text('Copy code'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (isAndroid)
                const Padding(
                  padding: EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Android is currently in closed testing. Your friend must '
                    'already be in the approved tester email group. The invite '
                    'link currently installs the iOS beta through TestFlight.',
                    style: TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              FilledButton.icon(
                onPressed: () => _share(summary),
                icon: const Icon(Icons.ios_share),
                label: const Text('Share invite'),
              ),
              const SizedBox(height: 22),
              Text(
                '${summary.referralCount} ${summary.referralCount == 1 ? 'friend has' : 'friends have'} joined with your code',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
