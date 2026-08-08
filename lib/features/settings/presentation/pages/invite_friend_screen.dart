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
        'We can build joint watchlists, see what each other watched and unlock a Film Friend badge.';
    final box = context.findRenderObject() as RenderBox?;
    await Share.share(
      'I invited you to Flixie! $reason\n\n'
      'Join me here: ${summary.inviteUrl}\n'
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
                'Send a personal invite to unlock the best bits of Flixie '
                'together. When they join with your code, you’ll be connected '
                'automatically.',
                textAlign: TextAlign.center,
                style: TextStyle(color: FlixieColors.medium, height: 1.45),
              ),
              const SizedBox(height: 24),
              const _TogetherBenefits(),
              const SizedBox(height: 20),
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

class _TogetherBenefits extends StatelessWidget {
  const _TogetherBenefits();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WHAT YOU CAN DO TOGETHER',
          style: TextStyle(
            color: FlixieColors.medium,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 10),
        _BenefitCard(
          icon: Icons.playlist_add_check_circle_rounded,
          title: 'Build a joint list',
          description:
              'Create a shared watchlist where you can both add films and shows.',
          preview: _JointListPreview(),
        ),
        SizedBox(height: 12),
        _BenefitCard(
          icon: Icons.people_alt_rounded,
          title: 'Unlock your Film Friend badge',
          description:
              'Your profile earns this badge when a friend joins with your code and completes their taste profile.',
          preview: _ProfileBadgePreview(),
        ),
        SizedBox(height: 12),
        _BenefitCard(
          icon: Icons.local_movies_rounded,
          title: 'See what friends think',
          description:
              'Open any movie or show to see who watched, rated, saved or recommended it.',
          preview: _FriendsBadgePreview(),
        ),
      ],
    );
  }
}

class _ProfileBadgePreview extends StatelessWidget {
  const _ProfileBadgePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
        border:
            Border.all(color: FlixieColors.secondary.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: FlixieColors.secondary.withValues(alpha: .14),
              shape: BoxShape.circle,
              border: Border.all(color: FlixieColors.secondary),
            ),
            child: const Icon(
              Icons.people_alt_rounded,
              color: FlixieColors.secondary,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Film Friend',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Displayed proudly on your profile',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.lock_open_rounded,
              color: FlixieColors.secondary, size: 19),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.preview,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: FlixieColors.primary.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: FlixieColors.primary, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          preview,
        ],
      ),
    );
  }
}

class _JointListPreview extends StatelessWidget {
  const _JointListPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [FlixieColors.primary, FlixieColors.secondary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.movie_filter_rounded, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Friday night picks',
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '12 titles · Shared list',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 11),
                ),
              ],
            ),
          ),
          const _ExampleAvatar(label: 'Y', color: FlixieColors.primary),
          Transform.translate(
            offset: const Offset(-6, 0),
            child: const _ExampleAvatar(
              label: 'F',
              color: FlixieColors.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FriendsBadgePreview extends StatelessWidget {
  const _FriendsBadgePreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.surfaceElevated,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white.withValues(alpha: .07)),
      ),
      child: const Row(
        children: [
          _ExampleAvatar(label: 'L', color: FlixieColors.primary),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Laura watched this',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: FlixieColors.light,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Friends · Watched',
                  style: TextStyle(color: FlixieColors.medium, fontSize: 10.5),
                ),
              ],
            ),
          ),
          Icon(Icons.thumb_up_rounded, color: FlixieColors.success, size: 18),
          SizedBox(width: 10),
          Icon(Icons.star_rounded, color: FlixieColors.warning, size: 19),
          Text(
            ' 8/10',
            style: TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleAvatar extends StatelessWidget {
  const _ExampleAvatar({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: FlixieColors.surfaceElevated, width: 2),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
