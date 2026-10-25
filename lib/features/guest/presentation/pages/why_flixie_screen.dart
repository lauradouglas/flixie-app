import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/cinema_light_background.dart';
import '../why_flixie_story.dart';
import '../widgets/why_flixie_example.dart';

/// Optional guest introduction. Examples never save data or call an API.
class WhyFlixieScreen extends StatefulWidget {
  const WhyFlixieScreen({super.key});

  @override
  State<WhyFlixieScreen> createState() => _WhyFlixieScreenState();
}

class _WhyFlixieScreenState extends State<WhyFlixieScreen> {
  final _scroll = ScrollController();
  int _page = 0;
  static const _stories = WhyFlixieStory.values;
  bool get _finished => _page > _stories.length;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _move(int page) {
    setState(() => _page = page);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final story = _page > 0 && !_finished ? _stories[_page - 1] : null;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: Stack(children: [
        const Positioned.fill(child: CinemaLightBackground()),
        SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (story != null) ...[
                          Semantics(
                            label: 'Step $_page of ${_stories.length}',
                            child: ExcludeSemantics(
                              child: Row(children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: _page / _stories.length,
                                    minHeight: 3,
                                    color: context.colors.primaryText,
                                    backgroundColor:
                                        context.colors.surfaceElevated,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Text('$_page of ${_stories.length}',
                                    style: theme.textTheme.labelLarge),
                              ]),
                            ),
                          ),
                          const SizedBox(height: 28),
                        ],
                        Semantics(
                          header: true,
                          liveRegion: true,
                          child: Text(
                            story?.title ??
                                (_finished
                                    ? 'Find a film.\nBring your people.'
                                    : 'Films are better\nwith your people.'),
                            style: theme.textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.14,
                                letterSpacing: -.7),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          story?.description ??
                              (_finished
                                  ? 'Explore at your own pace. Create an account when you’re ready to connect with friends, join communities and make movie night happen.'
                                  : 'See what friends love, find where it’s streaming, and plan your next watch together.'),
                          style:
                              theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                        ),
                        const SizedBox(height: 28),
                        if (story != null)
                          WhyFlixieExample(story: story)
                        else if (_finished)
                          Image.asset('assets/icon/pip_emote_thumbs_up.png',
                              height: 156,
                              semanticLabel: 'Pip gives a thumbs up')
                        else
                          const _Overview(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_finished) ...[
                          FilledButton(
                              onPressed: () => context.go('/'),
                              child: const Text('Explore Flixie')),
                          const SizedBox(height: 8),
                          OutlinedButton(
                              onPressed: () => context.push('/auth/signup'),
                              child: const Text('Create account')),
                          TextButton(
                              onPressed: () => _move(0),
                              child: const Text('Take another look')),
                        ] else ...[
                          Row(children: [
                            if (_page > 0) ...[
                              TextButton(
                                  onPressed: () => _move(_page - 1),
                                  child: const Text('Back')),
                              const SizedBox(width: 12),
                            ],
                            Expanded(
                              child: FilledButton(
                                  onPressed: () => _move(_page + 1),
                                  child: Text(_page == 0
                                      ? 'Show me around'
                                      : _page == _stories.length
                                          ? 'Finish tour'
                                          : 'Next')),
                            ),
                          ]),
                          TextButton(
                              onPressed: () => context.go('/'),
                              child: Text(_page == 0
                                  ? 'Explore Flixie instead'
                                  : 'Skip tour & explore')),
                        ],
                      ]),
                ),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Overview extends StatelessWidget {
  const _Overview();

  @override
  Widget build(BuildContext context) => Column(children: [
        for (final benefit in const [
          (
            Icons.people_outline_rounded,
            'Better with friends',
            'Their watches, ratings and watchlists. Your next conversation.'
          ),
          (
            Icons.live_tv_rounded,
            'Your watchlist knows where to watch',
            'Providers beside your saved titles, subscription filters and optional availability alerts.'
          ),
          (
            Icons.forum_outlined,
            'Find your film people',
            'Genre discussions, member-rated discoveries and film & TV polls.'
          ),
          (
            Icons.history_rounded,
            'Every watch has its own story',
            'Dates, companions, your own rating — and a fresh entry when you rewatch.'
          ),
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(benefit.$1, color: context.colors.primaryText, size: 24),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(benefit.$2,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(benefit.$3,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ])),
            ]),
          ),
        Text(
            'Plus Pick for Us, TV progress, favourite rankings and a little friendly competition with Pip.',
            style: Theme.of(context).textTheme.bodyMedium),
      ]);
}
