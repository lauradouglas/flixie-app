import 'package:flixie_app/features/pip/presentation/widgets/my_pip_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
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
  late Future<ReferralSummary> _summary = UserService.getMyReferral();
  bool _sharing = false;
  String? _shareError;
  Future<void> _share(ReferralSummary summary) async {
    if (_sharing) return;
    setState(() {
      _sharing = true;
      _shareError = null;
    });
    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await Share.share(
          'Come join me on Flixie - we can save our next-watch ideas and compare what we thought of our movie nights.\n\n${summary.inviteUrl}\n\nJoin through my invite and we’ll be connected as friends.',
          subject: 'Your film person is on Flixie',
          sharePositionOrigin:
              box == null ? null : box.localToGlobal(Offset.zero) & box.size);
      if (mounted && result.status == ShareResultStatus.success) {
        unawaited(context
            .read<AnalyticsController>()
            .friendInviteSent(
                inviteMethod: 'referral_link',
                source: GoRouterState.of(context).uri.queryParameters['from'] ==
                        'settings'
                    ? 'settings'
                    : 'social')
            .catchError((Object _) {}));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _shareError =
            'Couldn’t open sharing. Try again, or copy your code.');
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _copy(String code) async {
    try {
      await Clipboard.setData(ClipboardData(text: code));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Referral code copied')));
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _shareError = 'Couldn’t copy your code. Please try again.');
      }
    }
  }

  Future<void> _sheet(String title, Widget content) =>
      showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          builder: (sheet) => SizedBox(
              height: MediaQuery.sizeOf(sheet).height * .8,
              child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(
                              child: Text(title,
                                  style:
                                      Theme.of(sheet).textTheme.headlineSmall)),
                          IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(sheet),
                              icon: const Icon(Icons.close))
                        ]),
                        const SizedBox(height: 16),
                        content,
                        TextButton(
                            onPressed: () => Navigator.pop(sheet),
                            child: const Text('Done'))
                      ]))));
  void _rules() => _sheet(
      'Your Film Friend badge',
      const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.people_alt_outlined),
            title: Text('A profile badge for both of you')),
        SizedBox(height: 16),
        Text(
            '1. Share your personal invite.\n\n2. Your friend creates a new account using your link or code.\n\n3. When they finish setting up, you both receive Film Friend.'),
        SizedBox(height: 20),
        Text(
            'Already on Flixie? You can still enjoy films together, but joining again doesn’t count as a new referral.')
      ]));
  void _progress(ReferralSummary summary) => _sheet(
      'Your film people',
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(
            '${summary.referralCount} joined · ${summary.qualifiedReferralCount} earned Film Friend'),
        const SizedBox(height: 16),
        if (summary.referrals.isEmpty)
          Text(summary.referralCount == 0
              ? 'No one has joined through your invite yet. Start with someone whose film opinions you want.'
              : 'Your totals are up to date. Individual invitation details aren’t available right now.'),
        for (final person in summary.referrals)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(person.displayName),
              subtitle: Text(person.qualified
                  ? 'Joined · Film Friend earned'
                  : 'Joined · reward not earned yet'),
              leading: Icon(person.qualified
                  ? Icons.verified_outlined
                  : Icons.person_outline)),
        if (summary.referralCount > summary.referrals.length &&
            summary.referrals.isNotEmpty)
          const Text('Showing your most recent invitations.'),
        const SizedBox(height: 20),
        const Text(
            'Sharing a link doesn’t mean someone has joined. Your friend earns Film Friend after finishing setup.')
      ]));
  @override
  Widget build(BuildContext context) => FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('Invite a friend')),
      body: FutureBuilder<ReferralSummary>(
          future: _summary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return Center(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('Couldn’t load your invitations.'),
                        FilledButton(
                            onPressed: () => setState(
                                () => _summary = UserService.getMyReferral()),
                            child: const Text('Try again'))
                      ])));
            }
            final summary = snapshot.data!;
            return Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text('Bring your film person.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineLarge)),
                            if (MediaQuery.textScalerOf(context).scale(1) <=
                                1.5)
                              Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Image.asset(
                                      'assets/icon/community_pips/pip-flixie-hoodie.png',
                                      width: 64,
                                      excludeFromSemantics: true))
                          ]),
                      const SizedBox(height: 16),
                      const Text(
                          'Swap opinions. Build a watchlist together. Make your next film night an easier choice.'),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                          onPressed: _sharing ? null : () => _share(summary),
                          icon: const Icon(Icons.ios_share),
                          label: Text(_sharing
                              ? 'Opening sharing…'
                              : 'Share your invite')),
                      const SizedBox(height: 12),
                      const Text(
                          'Your link connects your friend to you when they join.'),
                      const SizedBox(height: 16),
                      TextButton.icon(
                          onPressed: () => showMyPipSheet(context),
                          icon: Image.asset(
                              'assets/icon/pip_cosmetics/cinema_club.png',
                              width: 44,
                              height: 44,
                              fit: BoxFit.contain,
                              excludeFromSemantics: true),
                          label: const Text(
                              'Cinema Club Pip · rewards for your first shared film')),
                      if (_shareError != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(_shareError!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      const SizedBox(height: 24),
                      Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                              color: context.colors.surface,
                              borderRadius: BorderRadius.circular(14)),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(Icons.people_alt_outlined),
                                    title: Text('Film Friend'),
                                    subtitle: Text(
                                        'A profile badge for both of you.')),
                                const Text(
                                    'You both get the badge when your friend joins through your invite and finishes setting up.'),
                                TextButton(
                                    onPressed: _rules,
                                    child: const Text('How it works'))
                              ])),
                      const SizedBox(height: 24),
                      Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          children: [
                            Text('Your invitations',
                                style: Theme.of(context).textTheme.titleLarge),
                            TextButton(
                                onPressed: () => _progress(summary),
                                child: const Text('View progress'))
                          ]),
                      const SizedBox(height: 12),
                      Wrap(spacing: 28, runSpacing: 16, children: [
                        _count('${summary.referralCount}', 'friends joined'),
                        _count('${summary.qualifiedReferralCount}',
                            'friends earned Film Friend')
                      ]),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider()),
                      Text('Start with a film you shared',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 12),
                      const Text(
                          'Just watched something together? Log it and invite them to add their take.'),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: () => context.push('/search?focus=1'),
                          icon: const Icon(Icons.movie_outlined),
                          label: const Text('Find a film to log together')),
                      const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Divider()),
                      const Text('Prefer a code?'),
                      const SizedBox(height: 8),
                      Wrap(
                          spacing: 16,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SelectableText(summary.code,
                                style: Theme.of(context).textTheme.titleLarge),
                            TextButton.icon(
                                onPressed: () => _copy(summary.code),
                                icon: const Icon(Icons.copy),
                                label: const Text('Copy code'))
                          ])
                    ])));
          }));
  Widget _count(String number, String label) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(number, style: Theme.of(context).textTheme.headlineMedium),
        Text(label)
      ]);
}
