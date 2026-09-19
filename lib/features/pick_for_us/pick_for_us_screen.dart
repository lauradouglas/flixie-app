import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/features/watchlist/domain/tonight_filters.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/movie_short.dart';

class PickForUsResult {
  final MovieShort movie;
  final int runtime;
  const PickForUsResult(this.movie, this.runtime);
  factory PickForUsResult.fromJson(Map<String, dynamic> json) =>
      PickForUsResult(
          MovieShort.fromJson(json), (json['runtime'] as num).toInt());
}

class PickForUsResponse {
  final List<PickForUsResult> choices;
  final String? message;
  const PickForUsResponse(this.choices, this.message);
}

class PickForUsService {
  Future<FriendsData> friends(String id) => FriendService.getFriends(id);
  Future<List<Group>> groups(String id) => GroupService.getUserGroups(id);
  Future<PickForUsResponse> pick(
      {String? friendId,
      String? groupId,
      String request = '',
      bool allowRewatches = false,
      Set<String> avoid = const {},
      List<int> genreIds = const [],
      bool includePossible = true,
      bool includeUnknownContent = false,
      required int maxMinutes,
      required String mood,
      required String venue,
      required String watching,
      required bool openToRent}) async {
    final data = await ApiClient.post('/recommendations/pick-for-us',
        timeout: const Duration(seconds: 60),
        body: {
          if (friendId != null) 'friendId': friendId,
          if (groupId != null) 'groupId': groupId,
          'maxMinutes': maxMinutes,
          'mood': mood,
          'request': request,
          'allowRewatches': allowRewatches,
          'avoid': avoid.toList(),
          'genreIds': genreIds,
          'includePossible': includePossible,
          'includeUnknownContent': includeUnknownContent,
          'venue': venue,
          'watching': watching,
          'openToRent': openToRent,
        }) as Map<String, dynamic>;
    return PickForUsResponse(
        (data['choices'] as List)
            .map((e) => PickForUsResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        data['message'] as String?);
  }
}

class PickForUsScreen extends StatefulWidget {
  const PickForUsScreen({super.key, required this.userId, this.service});
  final String userId;
  final PickForUsService? service;
  @override
  State<PickForUsScreen> createState() => _PickForUsScreenState();
}

class _PickForUsScreenState extends State<PickForUsScreen> {
  late final PickForUsService _service = widget.service ?? PickForUsService();
  List<Friendship> _friends = [];
  List<Group> _groups = [];
  String? _friendId, _groupId, _error;
  int _minutes = 120;
  final String _mood = 'any';
  final Set<String> _avoid = {};
  List<int> _genreIds = [];
  String _venue = 'streaming';
  String _watching = 'together';
  bool _openToRent = false;
  bool _loading = true, _picking = false;
  PickForUsResponse? _result;
  bool _allowRewatches = false;
  bool get _solo => _friendId == null && _groupId == null;
  final _scroll = ScrollController();
  static final _moods = {
    for (final mood in WatchlistMood.values) mood.id: mood.label
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await Future.wait(
          [_service.friends(widget.userId), _service.groups(widget.userId)]);
      if (!mounted) return;
      setState(() {
        _friends = (data[0] as FriendsData).friendships;
        _groups = (data[1] as List<Group>).where((g) => g.id != null).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'We couldn’t load your friends and groups. Please try again.';
        });
      }
    }
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final result = await _service.pick(
          friendId: _friendId,
          groupId: _groupId,
          maxMinutes: _minutes,
          mood: _mood,
          avoid: _avoid,
          genreIds: _genreIds,
          allowRewatches: _allowRewatches,
          venue: _venue,
          watching: _solo || _venue == 'cinema' ? 'together' : _watching,
          openToRent: _venue == 'streaming' &&
              (_solo || _watching == 'together') &&
              _openToRent);
      if (!mounted) return;
      setState(() {
        _result = result;
        _picking = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _picking = false;
          _error = error is ApiException &&
                  error.statusCode >= 400 &&
                  error.statusCode < 500
              ? error.message
              : 'We couldn’t find your picks. Check your connection and try again.';
        });
      }
    }
  }

  Future<void> _plan(PickForUsResult pick) async {
    await showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: context.colors.surface,
        builder: (sheetContext) => SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * .9,
            child: MovieWatchRequestSheet(
                movieId: pick.movie.id,
                movieTitle: pick.movie.name,
                moviePoster: pick.movie.poster,
                requesterId: widget.userId,
                friends: _friends,
                initialCinema: _venue == 'cinema',
                initialFriendId: _friendId,
                initialGroupId: _groupId,
                initialGroupMode: _groupId != null,
                onSuccess: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Watch Plan created. Find it in your Watch Plans.')));
                  }
                },
                onError: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Couldn’t create your Watch Plan. Please try again.')));
                  }
                })));
  }

  Widget _chip(
          {required Widget label,
          required bool selected,
          required ValueChanged<bool>? onSelected,
          Widget? avatar}) =>
      FlixiePill.choice(
          label: label,
          selected: selected,
          onSelected: onSelected,
          avatar: avatar,
          showCheckmark: avatar == null);

  Widget _heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleLarge));

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
          title: Text(_solo ? 'Pick for me' : 'Pick for us',
              style: Theme.of(context).textTheme.titleLarge)),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          controller: _scroll,
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                          children: [
                              if (_result == null) ...[
                                Text('Less scrolling. More watching.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                Text(
                                    'Find up to three movies for your mood, based on your taste and audience favourites. Watch solo or bring your people.',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        height: 1.5)),
                                _heading('Who’s watching?'),
                                Text(
                                    'Go solo, choose a friend or include a whole group.',
                                    style:
                                        TextStyle(color: context.colors.light)),
                                const SizedBox(height: 8),
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Just me'),
                                  leading: const Icon(Icons.person_outline),
                                  selected: _solo,
                                  trailing: Icon(_solo
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off),
                                  onTap: _picking
                                      ? null
                                      : () => setState(() {
                                            _friendId = null;
                                            _groupId = null;
                                          }),
                                ),
                                ..._friends
                                    .where((f) => f.friendUser != null)
                                    .map((f) {
                                  final person = f.friendUser!;
                                  return ListTile(
                                      selected: _friendId == person.id,
                                      selectedColor: context.colors.primaryText,
                                      trailing: Icon(_friendId == person.id
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 4),
                                      title: Text(person.displayName),
                                      leading: Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: ProfileAvatarView(
                                              avatar: person.avatar,
                                              profileBadges:
                                                  person.profileBadges,
                                              fallbackText: person.initials ??
                                                  person.displayName,
                                              fallbackColor:
                                                  FlixieColors.primary,
                                              size: 40)),
                                      onTap: _picking
                                          ? null
                                          : () => setState(() {
                                                _friendId = person.id;
                                                _groupId = null;
                                              }));
                                }),
                                ..._groups.map((g) => ListTile(
                                    selected: _groupId == g.id,
                                    selectedColor: context.colors.primaryText,
                                    trailing: Icon(_groupId == g.id
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off),
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(g.name),
                                    subtitle: const Text(
                                        'All accepted members · 2–12 viewers'),
                                    leading: const Icon(Icons.groups_outlined),
                                    onTap: _picking
                                        ? null
                                        : () => setState(() {
                                              _groupId = g.id;
                                              _friendId = null;
                                            }))),
                                if (_friends.isEmpty &&
                                    _groups.isEmpty &&
                                    _error == null)
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 16),
                                      child: Text(
                                          'You can pick solo now. Add friends in Social whenever you want to pick together.')),
                                _heading('Where are you watching?'),
                                Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: ['streaming', 'cinema']
                                        .map((venue) => _chip(
                                              label: Text(venue == 'cinema'
                                                  ? 'Cinema'
                                                  : 'Streaming'),
                                              avatar: Icon(
                                                  venue == 'cinema'
                                                      ? Icons
                                                          .local_movies_outlined
                                                      : Icons.tv,
                                                  size: 18),
                                              selected: _venue == venue,
                                              onSelected: _picking
                                                  ? null
                                                  : (_) => setState(
                                                      () => _venue = venue),
                                            ))
                                        .toList()),
                                if (_venue == 'streaming') ...[
                                  if (!_solo) ...[
                                    _heading('Together or separately?'),
                                    Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: ['together', 'separately']
                                            .map((mode) => _chip(
                                                  label: Text(mode == 'together'
                                                      ? 'Together'
                                                      : 'Separately'),
                                                  selected: _watching == mode,
                                                  onSelected: _picking
                                                      ? null
                                                      : (_) => setState(() =>
                                                          _watching = mode),
                                                ))
                                            .toList()),
                                  ],
                                  if (_solo || _watching == 'together')
                                    SwitchListTile.adaptive(
                                        contentPadding: EdgeInsets.zero,
                                        title: const Text('Open to renting'),
                                        subtitle: const Text(
                                            'Include paid rentals when a subscription option isn’t available.'),
                                        value: _openToRent,
                                        onChanged: _picking
                                            ? null
                                            : (value) => setState(
                                                () => _openToRent = value)),
                                ],
                                _heading('How much time do you have?'),
                                Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [90, 120, 150, 180, 240]
                                        .map((m) => _chip(
                                            label: Text(m == 90
                                                ? '90 min'
                                                : m == 150
                                                    ? '2½ hours'
                                                    : '${m ~/ 60} hours'),
                                            selected: _minutes == m,
                                            onSelected: _picking
                                                ? null
                                                : (_) => setState(
                                                    () => _minutes = m)))
                                        .toList()),
                                _heading('Genre · optional'),
                                Wrap(spacing: 8, runSpacing: 8, children: [
                                  for (final entry in const <String, List<int>>{
                                    'Any genre': [],
                                    'Rom com': [35, 10749],
                                    'Romance': [10749],
                                    'Crime': [80],
                                    'Sci-fi': [878],
                                    'Comedy': [35],
                                    'Drama': [18],
                                    'Adventure': [12],
                                    'Horror': [27]
                                  }.entries)
                                    FlixiePill.choice(
                                        label: Text(entry.key),
                                        selected: _genreIds.join(',') ==
                                            entry.value.join(','),
                                        onSelected: _picking
                                            ? null
                                            : (_) => setState(
                                                () => _genreIds = entry.value)),
                                ]),
                                SwitchListTile.adaptive(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Include rewatches'),
                                  subtitle: const Text(
                                      'Include films you’ve watched before.'),
                                  value: _allowRewatches,
                                  onChanged: _picking
                                      ? null
                                      : (value) => setState(
                                          () => _allowRewatches = value),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                    _venue == 'cinema'
                                        ? 'Current cinema releases in your saved country. Your time limit covers the movie; allow extra time for adverts and trailers.'
                                        : _solo
                                            ? 'Picks use your saved streaming services and country, with rentals only if you opt in.'
                                            : _watching == 'separately'
                                                ? 'Every pick must be available on a streaming provider you all have, in each viewer’s country.'
                                                : _openToRent
                                                    ? 'One viewer’s subscription is enough. We’ll also include paid rentals, clearly labelled.'
                                                    : 'Picks must be available on at least one viewer’s saved services in their country. Rewatches follow your preference above.',
                                    style: TextStyle(
                                        color: context.colors.light,
                                        height: 1.5)),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                    onPressed: _picking ? null : _pick,
                                    icon: _picking
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2))
                                        : const Icon(
                                            Icons.auto_awesome_outlined),
                                    label: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 14),
                                        child: Text(_picking
                                            ? 'Finding your picks…'
                                            : _solo
                                                ? 'Find my picks'
                                                : 'Find our picks'))),
                              ] else ...[
                                Text(
                                    _result!.choices.isEmpty
                                        ? 'Let’s widen the search'
                                        : 'Your shortlist, sorted.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall),
                                const SizedBox(height: 8),
                                Text(
                                    '${_venue == 'cinema' ? 'Cinema' : _solo ? 'Streaming solo' : _watching == 'separately' ? 'Streaming separately' : 'Streaming together'} · Up to $_minutes minutes · ${_moods[_mood]}',
                                    style:
                                        TextStyle(color: context.colors.light)),
                                if (_result!.message != null)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 16),
                                      child: Text(_result!.message!,
                                          style: const TextStyle(height: 1.5))),
                                ..._result!.choices.map(_choice),
                                const SizedBox(height: 16),
                                OutlinedButton(
                                    onPressed: () => setState(() {
                                          _result = null;
                                          _error = null;
                                        }),
                                    child: const Text(
                                        'Change viewers, time or mood')),
                                if (_result!.choices.length < 3)
                                  TextButton(
                                      onPressed: _picking ? null : _pick,
                                      child: Text(_picking
                                          ? 'Checking…'
                                          : 'Check again')),
                              ],
                              if (_error != null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Column(children: [
                                      Text(_error!,
                                          style: TextStyle(
                                              color: context.colors.danger)),
                                      if (_friends.isEmpty && _groups.isEmpty)
                                        TextButton(
                                            onPressed: _load,
                                            child: const Text('Retry')),
                                    ])),
                            ])))));

  Widget _choice(PickForUsResult pick) {
    final movie = pick.movie;
    final poster = movie.poster;
    final image = poster == null
        ? null
        : poster.startsWith('http')
            ? poster
            : 'https://image.tmdb.org/t/p/w342$poster';
    return Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (image != null)
              Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                          imageUrl: image,
                          width: 80,
                          height: 120,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => const SizedBox(
                              width: 80,
                              height: 120,
                              child: Icon(Icons.movie_outlined))))),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(movie.name,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text('${pick.runtime} min',
                      style: TextStyle(color: context.colors.light)),
                  if (movie.overview?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Text(movie.overview!, style: const TextStyle(height: 1.5))
                  ],
                ])),
          ]),
          const SizedBox(height: 16),
          ...movie.recommendationReasons.map((reason) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check, size: 20, color: context.colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(reason, style: const TextStyle(height: 1.4)))
              ]))),
          FilledButton.icon(
              onPressed: () =>
                  _solo ? context.push('/movies/${movie.id}') : _plan(pick),
              icon: Icon(_solo ? Icons.movie_outlined : Icons.event_outlined),
              label: Text(_solo ? 'View movie' : 'Make a Watch Plan')),
          const SizedBox(height: 16),
          Divider(color: context.colors.tabBarBorder),
        ]));
  }
}
