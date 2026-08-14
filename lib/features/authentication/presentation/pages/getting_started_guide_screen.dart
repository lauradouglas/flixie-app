import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';

class GettingStartedGuideScreen extends StatefulWidget {
  const GettingStartedGuideScreen({
    super.key,
    this.openedFromSettings = false,
  });

  final bool openedFromSettings;

  @override
  State<GettingStartedGuideScreen> createState() =>
      _GettingStartedGuideScreenState();
}

class _GettingStartedGuideScreenState extends State<GettingStartedGuideScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _GuidePageData(
      eyebrow: 'DISCOVER',
      title: 'Find your next favourite',
      description:
          'Flixie learns from your taste and brings recommendations, trending picks and search together.',
      heroIcon: Icons.auto_awesome_rounded,
      accent: FlixieColors.primary,
      actions: [
        _GuideAction(Icons.refresh_rounded,
            'Refresh Just for you whenever you want fresh picks'),
        _GuideAction(Icons.favorite_outline_rounded,
            'Tap Favourite on a movie or show to shape your taste'),
        _GuideAction(Icons.visibility_off_outlined,
            'Use Not interested to improve future recommendations'),
      ],
    ),
    _GuidePageData(
      eyebrow: 'KEEP TRACK',
      title: 'Build your film life',
      description:
          'Save what is next, log what you watched and leave ratings or reviews you can revisit later.',
      heroIcon: Icons.bookmark_added_rounded,
      accent: FlixieColors.tertiary,
      actions: [
        _GuideAction(Icons.bookmark_outline_rounded,
            'Tap Watchlist on any movie or show to save it for later'),
        _GuideAction(Icons.check_circle_outline_rounded,
            'Tap Watched to create a movie log with its date and notes'),
        _GuideAction(Icons.star_outline_rounded,
            'Add a rating or review to each individual watch'),
      ],
    ),
    _GuidePageData(
      eyebrow: 'WHERE TO WATCH',
      title: 'See what is on your services',
      description:
          'Choose your streaming services once and Flixie will highlight where your saved movies are available.',
      heroIcon: Icons.live_tv_rounded,
      accent: FlixieColors.warning,
      actions: [
        _GuideAction(Icons.settings_outlined,
            'Open Settings → Watch Providers and select your services'),
        _GuideAction(Icons.play_circle_outline_rounded,
            'Check Where to watch on every movie and show page'),
        _GuideAction(Icons.bookmarks_outlined,
            'Your Watchlist can show which saved titles are available'),
      ],
    ),
    _GuidePageData(
      eyebrow: 'WATCH TOGETHER',
      title: 'Plan it with friends',
      description:
          'Turn “we should watch that” into an actual plan, then keep everyone together in Flixie.',
      heroIcon: Icons.people_alt_rounded,
      accent: FlixieColors.secondary,
      actions: [
        _GuideAction(Icons.event_available_outlined,
            'Tap Invite on a movie to send a friend a watch request'),
        _GuideAction(Icons.groups_rounded,
            'Open Social to create a group for your film crew'),
        _GuideAction(Icons.forum_outlined,
            'Chat directly with friends or inside a group'),
      ],
    ),
    _GuidePageData(
      eyebrow: 'BETTER TOGETHER',
      title: 'Flixie is better with friends',
      description:
          'Build joint lists, plan movie nights and see what your people are loving. Invite your first film friend to get started.',
      heroIcon: Icons.playlist_add_check_circle_rounded,
      accent: FlixieColors.success,
      actions: [
        _GuideAction(Icons.add_rounded,
            'Create lists from your profile or any movie page'),
        _GuideAction(Icons.group_add_outlined,
            'Choose selected friends who can add to a joint list'),
        _GuideAction(Icons.person_add_alt_1_rounded,
            'Invite a film friend and unlock your profile badge'),
      ],
      actionLabel: 'Invite a film friend',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() {
    if (widget.openedFromSettings && context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _next() {
    if (_page == _pages.length - 1) {
      _finish();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    return Scaffold(
      backgroundColor: FlixieColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 4),
              child: Row(
                children: [
                  const FlixieWordmark(),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: Text(widget.openedFromSettings ? 'Close' : 'Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _GuidePage(
                  data: _pages[index],
                  onAction: _pages[index].actionLabel == null
                      ? null
                      : () => context.push(
                            '/invite-friend?from=getting_started',
                          ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: index == _page ? 24 : 7,
                        height: 7,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: index == _page
                              ? page.accent
                              : FlixieColors.medium.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.primary,
                        foregroundColor: FlixieColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _next,
                      child: Text(
                        _page == _pages.length - 1
                            ? widget.openedFromSettings
                                ? 'Done'
                                : 'Start exploring'
                            : 'Next',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  const _GuidePage({required this.data, this.onAction});

  final _GuidePageData data;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Column(
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  data.accent.withValues(alpha: .34),
                  data.accent.withValues(alpha: .06),
                ],
              ),
              border: Border.all(color: data.accent.withValues(alpha: .45)),
            ),
            child: Icon(data.heroIcon, color: data.accent, size: 66),
          ),
          const SizedBox(height: 24),
          Text(
            data.eyebrow,
            style: TextStyle(
              color: data.accent,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.2,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 28,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: FlixieColors.surfaceElevated,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: data.accent.withValues(alpha: .24)),
            ),
            child: Column(
              children: data.actions
                  .map((action) => _GuideActionRow(
                        action: action,
                        accent: data.accent,
                        isLast: action == data.actions.last,
                      ))
                  .toList(),
            ),
          ),
          if (data.actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(data.actionLabel!),
                style: OutlinedButton.styleFrom(
                  foregroundColor: data.accent,
                  side: BorderSide(color: data.accent.withValues(alpha: .7)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GuideActionRow extends StatelessWidget {
  const _GuideActionRow({
    required this.action,
    required this.accent,
    required this.isLast,
  });

  final _GuideAction action;
  final Color accent;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(action.icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  action.label,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(color: FlixieColors.primary.withValues(alpha: .12)),
      ],
    );
  }
}

class _GuidePageData {
  const _GuidePageData({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.heroIcon,
    required this.accent,
    required this.actions,
    this.actionLabel,
  });

  final String eyebrow;
  final String title;
  final String description;
  final IconData heroIcon;
  final Color accent;
  final List<_GuideAction> actions;
  final String? actionLabel;
}

class _GuideAction {
  const _GuideAction(this.icon, this.label);

  final IconData icon;
  final String label;
}
