import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import '../why_flixie_story.dart';

/// Fictional, entirely local demonstrations. No profile or library is mutated.
class WhyFlixieExample extends StatefulWidget {
  const WhyFlixieExample({super.key, required this.story});
  final WhyFlixieStory story;

  @override
  State<WhyFlixieExample> createState() => _WhyFlixieExampleState();
}

class _WhyFlixieExampleState extends State<WhyFlixieExample> {
  bool _saved = false,
      _planned = false,
      _rewatch = false,
      _episodeWatched = false;
  int? _firstRating, _rewatchRating;
  String? _provider;
  String _community = 'Discuss';

  Widget _title(String text) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleLarge
          ?.copyWith(fontWeight: FontWeight.w700));

  Widget _copy(String text) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(text,
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)));

  Widget _feedback(String text) => Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
          liveRegion: true,
          child: Text(text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.colors.primaryText, height: 1.5))));

  Widget _choices(List<String> options, String? selected,
          ValueChanged<String> onSelected) =>
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final option in options)
            FlixiePill.choice(
                label: Text(option),
                selected: selected == option,
                onSelected: (_) => onSelected(option)),
        ]),
      );

  Widget _friend(String name,
          {required String status,
          required IconData icon,
          bool rating = false}) =>
      Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ProfileAvatarView(
              avatar: null,
              imageProvider: AssetImage(name == 'Casey'
                  ? 'assets/icon/community_pips/pip-space-adventure.png'
                  : 'assets/icon/community_pips/pip-cosy-movie-night.png'),
              fallbackText: name.characters.first,
              fallbackColor: context.colors.primary,
              profileBadges: name == 'Casey'
                  ? const ['EARLY_ADOPTER']
                  : const ['FOUNDING_FILM_FRIEND'],
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(icon,
                        size: 18,
                        color: rating
                            ? context.colors.warning
                            : context.colors.primaryText),
                    const SizedBox(width: 5),
                    Expanded(
                        child: Text(status,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: rating
                                        ? context.colors.warning
                                        : context.colors.light))),
                  ]),
                ])),
          ]));

  Widget _alien({String subtitle = '1979 · Science fiction / Horror'}) =>
      Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset('assets/images/why-flixie-alien.jpg',
                  width: 52,
                  height: 78,
                  fit: BoxFit.cover,
                  semanticLabel: 'Alien poster')),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Alien', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ])),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final content = _content();
    return DecoratedBox(
        decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            content.first,
            const SizedBox(height: 8),
            Text('Example preview · fictional activity',
                style: Theme.of(context).textTheme.bodySmall),
            ...content.skip(1),
          ]),
        ));
  }

  List<Widget> _content() => switch (widget.story) {
        WhyFlixieStory.friends => [
            _title('Alien keeps coming up.'),
            _alien(),
            _friend('Casey',
                status: '9/10 · Watched',
                icon: Icons.star_rounded,
                rating: true),
            _friend('Robin',
                status: 'On watchlist', icon: Icons.bookmark_outline_rounded),
            const SizedBox(height: 18),
            OutlinedButton.icon(
                onPressed: () => setState(() => _saved = !_saved),
                icon: Icon(_saved
                    ? Icons.bookmark_added_outlined
                    : Icons.bookmark_add_outlined),
                label: Text(_saved
                    ? 'On your watchlist too'
                    : 'Add Alien to your watchlist')),
            if (_saved)
              _feedback('Saved in this preview. Now, where can you watch it?'),
          ],
        WhyFlixieStory.providers => [
            _title('An example watchlist'),
            if (_provider != 'Netflix') ...[
              _alien(),
              _friend('Robin',
                  status: 'Wants to watch',
                  icon: Icons.bookmark_outline_rounded),
            ],
            _choices(['Disney+', 'Netflix'], _provider,
                (value) => setState(() => _provider = value)),
            _feedback(switch (_provider) {
              'Disney+' => 'Alien\nDisney+ · Included with subscription',
              'Netflix' => 'No saved films match this service in this example.',
              _ => 'Choose a service to see a matching saved film.',
            }),
            _copy(
                'You can also opt into watchlist availability alerts for your country and selected subscriptions.'),
            _copy(
                'Illustrative provider matches. Real availability varies by country and date.'),
          ],
        WhyFlixieStory.plans => [
            _title('You + Robin · Friday night'),
            _alien(subtitle: 'Friday, 16 October · Film night'),
            _friend('Robin',
                status: 'Watching with you',
                icon: Icons.people_outline_rounded),
            const SizedBox(height: 18),
            OutlinedButton(
                onPressed: () => setState(() => _planned = !_planned),
                child: Text(
                    _planned ? 'Hide example plan' : 'Preview the watch plan')),
            if (_planned)
              _feedback(
                  'Alien · Friday, 16 October\nYou + Robin · Film night planned.\nAfterwards, log the viewing and add your own ratings.'),
          ],
        WhyFlixieStory.watches => _watchEntry(),
        WhyFlixieStory.communities => [
            _title('Inside the Horror community'),
            _choices(['Discuss', 'Poll', 'Discover'], _community,
                (value) => setState(() => _community = value)),
            _friend('Casey',
                status: _community == 'Poll'
                    ? 'Started a poll'
                    : 'In the Horror community',
                icon: Icons.forum_outlined),
            _feedback(switch (_community) {
              'Poll' =>
                'Which film should Horror fans watch next?\nAlien · The Thing · The Descent',
              'Discover' =>
                'Your next Horror watch\nExplore films rated by community members, then save your next watch.',
              _ =>
                'Alien: what makes the tension work?\nA spoiler-marked discussion, ready when you are.',
            }),
            if (_community == 'Poll')
              _copy(
                  'Members can vote and nominate a film or show from the catalogue.'),
          ],
        WhyFlixieStory.television => [
            _title('Continue Severance'),
            _feedback(
                'Season 1 · Episode ${_episodeWatched ? 5 : 4} is up next'),
            _copy('${_episodeWatched ? 4 : 3} episodes watched'),
            const SizedBox(height: 14),
            LinearProgressIndicator(
                value: (_episodeWatched ? 4 : 3) / 9,
                color: context.colors.primaryText,
                backgroundColor: context.colors.surfaceElevated),
            const SizedBox(height: 18),
            OutlinedButton.icon(
                onPressed: () =>
                    setState(() => _episodeWatched = !_episodeWatched),
                icon: Icon(
                    _episodeWatched ? Icons.undo_rounded : Icons.check_rounded),
                label: Text(_episodeWatched
                    ? 'Undo example watch'
                    : 'Mark episode 4 watched')),
            _copy(_episodeWatched
                ? 'Progress updated in this preview. Episode 5 is ready for next time.'
                : 'Pick up your story without losing your place.'),
          ],
        WhyFlixieStory.extras => [
            Image.asset('assets/icon/pip_emote_thumbs_up.png',
                height: 110, semanticLabel: 'Pip gives a thumbs up'),
            const SizedBox(height: 20),
            _title('See you on the leaderboard?'),
            _copy(
                'Popcorn Catch · Pip’s Pairs\nGames, leaderboards and profile badges.'),
            _copy('Come for the films. Find plenty to stay for.'),
          ],
      };

  List<Widget> _watchEntry() {
    final rating = _rewatch ? _rewatchRating : _firstRating;
    return [
      _title('Alien · ${_rewatch ? 'The rewatch' : 'Friday film night'}'),
      _alien(
          subtitle: _rewatch
              ? '17 October 2026 · Rewatch'
              : '16 October 2026 · Shared watch'),
      _copy(_rewatch
          ? '17 October 2026 · Watched solo'
          : '16 October 2026 · Watched with Robin'),
      if (!_rewatch)
        _friend('Robin',
            status: 'Robin’s rating: 7/10',
            icon: Icons.star_rounded,
            rating: true),
      _copy(_rewatch
          ? '“Noticed so much more the second time.”'
          : '“The best kind of tense. Robin hid behind a cushion.”'),
      const SizedBox(height: 16),
      Text('Your rating', style: Theme.of(context).textTheme.titleSmall),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (var number = 1; number <= 10; number++)
          Semantics(
            label: 'Rate this watch $number out of 10',
            child: FlixiePill.choice(
              label: Text('$number'),
              selected: rating == number,
              onSelected: (_) => setState(() {
                if (_rewatch) {
                  _rewatchRating = number;
                } else {
                  _firstRating = number;
                }
              }),
            ),
          ),
      ]),
      _feedback(rating == null
          ? 'Try your own rating.'
          : 'Your ${_rewatch ? 'rewatch' : 'film-night'} rating: $rating/10'),
      const SizedBox(height: 16),
      OutlinedButton(
          onPressed: () => setState(() => _rewatch = !_rewatch),
          child: Text(_rewatch
              ? 'Back to the first watch'
              : 'See a separate rewatch entry')),
      _copy(_rewatch
          ? 'First-watch rating: ${_firstRating == null ? 'not added' : '$_firstRating/10'}. This entry has its own date, comment and rating.'
          : 'Your rating belongs to you. Robin’s stays Robin’s.'),
    ];
  }
}
