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
      Set<int> excludeMovieIds = const {},
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
          if (excludeMovieIds.isNotEmpty)
            'excludeMovieIds': excludeMovieIds.toList(),
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
  final _scroll = ScrollController();
  final _search = TextEditingController();
  List<Friendship> _friends = [];
  List<Group> _groups = [];
  String? _friendId, _groupId, _error, _peopleError;
  String _company = 'solo';
  WatchlistMood _mood = WatchlistMood.any;
  int _step = 0, _minutes = 120, _selectedPick = 0;
  String _venue = 'streaming', _watching = 'together';
  bool _openToRent = false, _allowRewatches = false;
  bool _loadingPeople = false, _picking = false, _refining = false;
  final Set<String> _avoid = {};
  final Set<int> _shownIds = {};
  List<int> _genreIds = [];
  PickForUsResponse? _result;
  bool get _solo => _company == 'solo';
  bool get _validCompany =>
      _solo || (_company == 'friend' ? _friendId != null : _groupId != null);
  static const _genres = <String, List<int>>{
    'Any genre': [],
    'Rom com': [35, 10749],
    'Romance': [10749],
    'Crime': [80],
    'Sci-fi': [878],
    'Comedy': [35],
    'Drama': [18],
    'Adventure': [12],
    'Horror': [27],
  };
  String get _genreLabel => _genres.entries
      .firstWhere((e) => e.value.join(',') == _genreIds.join(','))
      .key;
  String get _companyLabel {
    if (_solo) return 'Just me';
    if (_company == 'friend') {
      for (final f in _friends) {
        if (f.friendUser?.id == _friendId) {
          return 'With ${f.friendUser!.displayName}';
        }
      }
      return 'Choose a friend';
    }
    for (final g in _groups) {
      if (g.id == _groupId) return g.name;
    }
    return 'Choose a group';
  }

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPeople() async {
    if (_loadingPeople) return;
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });
    // Social loading must never hold up a solo pick. Each list can recover independently.
    await Future.wait([
      () async {
        try {
          final friends = await _service.friends(widget.userId);
          if (mounted) setState(() => _friends = friends.friendships);
        } catch (_) {
          if (mounted) {
            setState(() => _peopleError =
                'Some viewers couldn’t load. Retry, or pick just for you.');
          }
        }
      }(),
      () async {
        try {
          final groups = await _service.groups(widget.userId);
          if (mounted) {
            setState(
                () => _groups = groups.where((g) => g.id != null).toList());
          }
        } catch (_) {
          if (mounted) {
            setState(() => _peopleError =
                'Some viewers couldn’t load. Retry, or pick just for you.');
          }
        }
      }(),
    ]);
    if (mounted) setState(() => _loadingPeople = false);
  }

  void _top() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _close() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _back() {
    if (_picking) {
      Navigator.of(context).pop();
      return;
    }
    if (_result != null) {
      setState(() {
        _result = null;
        _error = null;
        _step = 1;
      });
    } else if (_step > 0) {
      setState(() {
        _step = 0;
        _error = null;
      });
    } else {
      Navigator.of(context).pop();
    }
    _top();
  }

  Future<void> _pick({bool different = false}) async {
    if (_picking || !_validCompany) return;
    if (different && _shownIds.length >= 60) {
      setState(() => _error =
          'You’ve explored 60 films. Change your preferences to start a fresh search.');
      return;
    }
    setState(() {
      _picking = true;
      _error = null;
    });
    final excluded = different ? Set<int>.of(_shownIds) : <int>{};
    try {
      final response = await _service.pick(
        friendId: _company == 'friend' ? _friendId : null,
        groupId: _company == 'group' ? _groupId : null,
        maxMinutes: _minutes,
        mood: _mood.id,
        avoid: Set.of(_avoid),
        excludeMovieIds: excluded,
        genreIds: List.of(_genreIds),
        allowRewatches: _allowRewatches,
        venue: _venue,
        watching: _solo || _venue == 'cinema' ? 'together' : _watching,
        openToRent: _venue == 'streaming' &&
            (_solo || _watching == 'together') &&
            _openToRent,
      );
      if (!mounted) return;
      // Also filter locally while an older server rolls forward to the optional field.
      final fresh = response.choices
          .where((c) => !excluded.contains(c.movie.id))
          .take(3)
          .toList();
      setState(() {
        if (different && fresh.isEmpty) {
          _error =
              'No different films matched this time. Your previous picks are still here. Change your preferences to widen the search.';
        } else {
          if (!different) _shownIds.clear();
          _shownIds.addAll(fresh.map((c) => c.movie.id));
          _result = PickForUsResponse(fresh, response.message);
          _selectedPick = 0;
        }
      });
      _top();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is ApiException &&
                error.statusCode >= 400 &&
                error.statusCode < 500
            ? error.message
            : 'Couldn’t find your picks. Your choices are saved—please try again.');
      }
    } finally {
      if (mounted) setState(() => _picking = false);
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

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 12),
        child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
      );
  Widget _note(String text) =>
      Text(text, style: TextStyle(color: context.colors.medium, height: 1.5));
  Widget _pill(String label, bool selected, VoidCallback action) =>
      FlixiePill.choice(
        label: Text(label),
        selected: selected,
        onSelected: _picking ? null : (_) => setState(action),
      );
  Widget _primary(String label, VoidCallback? action, {bool busy = false}) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: action,
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
          child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              children: [
                if (busy)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                Text(label, textAlign: TextAlign.center),
              ]),
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _picking || (_step == 0 && _result == null),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
              leading: BackButton(onPressed: _back),
              title: Text(_solo ? 'Pick for me' : 'Pick for us'),
              actions: [
                IconButton(
                    tooltip: 'Close picker',
                    onPressed: _close,
                    icon: const Icon(Icons.close)),
              ]),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(children: [
              Expanded(
                  child: AbsorbPointer(
                      absorbing: _picking,
                      child: ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: [
                          if (_result == null) ...[
                            Text(
                                'Step ${_step + 1} of 2 · ${_step == 0 ? 'Your mood' : 'Your evening'}',
                                style: TextStyle(color: context.colors.medium)),
                            const SizedBox(height: 12),
                            if (_step == 0)
                              ..._moodStep()
                            else
                              ..._eveningStep(),
                          ] else
                            ..._results(),
                        ],
                      ))),
              _footer(),
            ]),
          ))),
        ),
      );

  List<Widget> _moodStep() => [
        Text('What would feel good tonight?',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        _note(
            'Choose the experience you want. We’ll use your taste to find the films.'),
        const SizedBox(height: 20),
        _pill('Keep my options open', _mood == WatchlistMood.any,
            () => _mood = WatchlistMood.any),
        const SizedBox(height: 12),
        for (final mood
            in WatchlistMood.values.where((m) => m != WatchlistMood.any))
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: _mood == mood
                    ? FlixieColors.primary.withValues(alpha: .15)
                    : context.colors.surface,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: _mood == mood
                            ? FlixieColors.primary
                            : Colors.transparent)),
                child: Semantics(
                    selected: _mood == mood,
                    button: true,
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      title: Text(mood.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(mood.description),
                      trailing: Icon(
                          _mood == mood
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: _mood == mood
                              ? context.colors.primaryText
                              : context.colors.medium),
                      onTap: () => setState(() => _mood = mood),
                    )),
              )),
      ];

  List<Widget> _eveningStep() => [
        Text('Make it your kind of evening.',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Align(
            alignment: Alignment.centerLeft,
            child: ActionChip(
                label: Text('${_mood.label} · Change'),
                onPressed: () {
                  setState(() => _step = 0);
                  _top();
                })),
        _heading('Who’s watching?'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final entry in {
            'solo': 'Just me',
            'friend': 'With a friend',
            'group': 'With a group'
          }.entries)
            _pill(entry.value, _company == entry.key, () {
              _company = entry.key;
              _search.clear();
            }),
        ]),
        if (!_solo) ..._people(),
        _heading('Where are you watching?'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _pill('Streaming', _venue == 'streaming', () => _venue = 'streaming'),
          _pill('Cinema', _venue == 'cinema', () => _venue = 'cinema'),
        ]),
        if (!_solo && _venue == 'streaming') ...[
          _heading('Together or separately?'),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill('Together', _watching == 'together',
                () => _watching = 'together'),
            _pill('Separately', _watching == 'separately',
                () => _watching = 'separately'),
          ]),
        ],
        const SizedBox(height: 16),
        _note(_venue == 'cinema'
            ? 'Current releases in your saved country. Check local showtimes before making plans.'
            : !_solo && _watching == 'separately'
                ? 'We’ll look for films on a service everyone has, in each viewer’s country.'
                : _solo
                    ? 'Using your saved streaming services and country.'
                    : 'One viewer’s saved streaming service is enough when you watch together.'),
        const SizedBox(height: 20),
        ExpansionTile(
          key: const PageStorageKey('pick-refinements'),
          initiallyExpanded: _refining,
          onExpansionChanged: (value) => _refining = value,
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          title: const Text('Refine your picks',
              style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(
              'Up to $_minutes min · $_genreLabel${_allowRewatches ? ' · Rewatches included' : ''}${_avoid.isNotEmpty ? ' · ${_avoid.length} content filters' : ''}'),
          children: [
            Align(
                alignment: Alignment.centerLeft,
                child: _heading('How much time do you have?')),
            Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final minutes in [90, 120, 150, 180, 240])
                    _pill('$minutes min', _minutes == minutes,
                        () => _minutes = minutes),
                ])),
            if (_venue == 'cinema')
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _note('Allow extra time for adverts and trailers.')),
            Align(
                alignment: Alignment.centerLeft,
                child: _heading('Genre · optional')),
            Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final genre in _genres.entries)
                    _pill(genre.key, _genreLabel == genre.key,
                        () => _genreIds = genre.value),
                ])),
            Align(
                alignment: Alignment.centerLeft,
                child: _heading('Anything to avoid?')),
            Align(
                alignment: Alignment.centerLeft,
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final concern in {
                    'horror': 'Horror',
                    'violence': 'Graphic violence',
                    'bleak': 'Bleak tone',
                    'heavy': 'Heavy themes'
                  }.entries)
                    _pill(concern.value, _avoid.contains(concern.key), () {
                      if (!_avoid.add(concern.key)) _avoid.remove(concern.key);
                    }),
                ])),
            const SizedBox(height: 8),
            _note(
                'Content filters exclude films when we don’t have enough information to check them.'),
            SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include rewatches'),
                subtitle: const Text(
                    'Films you’ve watched before can be suggested again.'),
                value: _allowRewatches,
                onChanged: (v) => setState(() => _allowRewatches = v)),
            if (_venue == 'streaming' && (_solo || _watching == 'together'))
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Open to renting'),
                  subtitle: const Text(
                      'Paid rentals are labelled. Off means subscription options only.'),
                  value: _openToRent,
                  onChanged: (v) => setState(() => _openToRent = v)),
          ],
        ),
      ];

  List<Widget> _people() {
    final query = _search.text.trim().toLowerCase();
    final friends = _friends
        .map((f) => f.friendUser)
        .whereType<FriendshipUser>()
        .where((f) => f.displayName.toLowerCase().contains(query))
        .toList();
    final groups =
        _groups.where((g) => g.name.toLowerCase().contains(query)).toList();
    return [
      const SizedBox(height: 12),
      if (_loadingPeople) const LinearProgressIndicator(),
      if (_peopleError != null) ...[
        _note(_peopleError!),
        TextButton(
            onPressed: _loadingPeople ? null : _loadPeople,
            child: const Text('Retry viewers')),
      ],
      TextField(
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
              labelText:
                  _company == 'friend' ? 'Find a friend' : 'Find a group',
              prefixIcon: const Icon(Icons.search))),
      const SizedBox(height: 8),
      if (!_loadingPeople &&
          (_company == 'friend' ? friends.isEmpty : groups.isEmpty))
        _note(query.isNotEmpty
            ? 'No matches. Try another name.'
            : _peopleError != null
                ? 'Your saved viewers will appear here when loading succeeds.'
                : _company == 'friend'
                    ? 'No friends yet. You can pick solo, or add friends in Social.'
                    : 'No groups yet. You can pick solo, or create a group in Social.'),
      ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .3),
          child: ListView(
            shrinkWrap: true,
            primary: false,
            children: _company == 'friend'
                ? [
                    for (final friend in friends)
                      Semantics(
                          selected: _friendId == friend.id,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            leading: ProfileAvatarView(
                                avatar: friend.avatar,
                                profileBadges: friend.profileBadges,
                                fallbackText:
                                    friend.initials ?? friend.displayName,
                                fallbackColor: FlixieColors.primary,
                                size: 40),
                            title: Text(friend.displayName),
                            trailing: Icon(_friendId == friend.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            onTap: () => setState(() {
                              _friendId = friend.id;
                              _groupId = null;
                            }),
                          )),
                  ]
                : [
                    for (final group in groups)
                      Semantics(
                          selected: _groupId == group.id,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.groups_outlined),
                            title: Text(group.name),
                            subtitle:
                                const Text('Accepted members · 2–12 viewers'),
                            trailing: Icon(_groupId == group.id
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off),
                            onTap: () => setState(() {
                              _groupId = group.id;
                              _friendId = null;
                            }),
                          )),
                  ],
          )),
    ];
  }

  List<Widget> _results() {
    final choices = _result!.choices;
    return [
      Semantics(
          header: true,
          child: Text(choices.isEmpty ? 'No films fit just yet.' : 'Your picks',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800))),
      const SizedBox(height: 10),
      _note(
          '${_mood.label} · $_companyLabel\n${_venue == 'cinema' ? 'Cinema' : 'Streaming'} · Up to $_minutes min${_genreIds.isNotEmpty ? ' · $_genreLabel' : ''}'),
      if (choices.isEmpty) ...[
        const SizedBox(height: 24),
        const Icon(Icons.movie_filter_outlined, size: 48),
        const SizedBox(height: 16),
        _note(
            'Try a little more time or a different mood. Your content and viewing preferences haven’t been relaxed.'),
      ],
      if (_result!.message?.isNotEmpty == true)
        Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _note(_result!.message!)),
      if (choices.isNotEmpty) ...[
        if (choices.length > 1) ...[
          const SizedBox(height: 20),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (var i = 0; i < choices.length; i++)
              _pill(i == 0 ? 'First pick' : 'Alternative $i',
                  _selectedPick == i, () => _selectedPick = i),
          ]),
        ],
        const SizedBox(height: 20),
        _choice(choices[_selectedPick]),
        Wrap(alignment: WrapAlignment.center, spacing: 12, children: [
          TextButton(
              onPressed: _picking ? null : () => _pick(different: true),
              child: Text(_picking
                  ? 'Finding different films…'
                  : 'Show different films')),
          TextButton(
              onPressed: _picking ? null : _back,
              child: const Text('Change preferences')),
        ]),
      ],
    ];
  }

  Widget _footer() {
    final hasResults = _result != null;
    return Container(
      decoration: BoxDecoration(
          color: context.colors.background,
          border: Border(top: BorderSide(color: context.colors.tabBarBorder))),
      child: SafeArea(
          top: false,
          child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .4),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (_error != null)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style:
                                    TextStyle(color: context.colors.danger)))),
                  if (_picking)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(
                                'Checking your taste, time and viewing options…',
                                textAlign: TextAlign.center,
                                style:
                                    TextStyle(color: context.colors.medium)))),
                  if (!hasResults && _step == 0)
                    _primary('Next · Your evening', () {
                      setState(() => _step = 1);
                      _top();
                    })
                  else if (!hasResults)
                    _primary(
                        _picking
                            ? 'Finding your picks…'
                            : _validCompany
                                ? (_solo ? 'Find my picks' : 'Find our picks')
                                : (_company == 'friend'
                                    ? 'Choose a friend to continue'
                                    : 'Choose a group to continue'),
                        _picking || !_validCompany ? null : () => _pick(),
                        busy: _picking)
                  else ...[
                    if (_result!.choices.isNotEmpty) ...[
                      _primary(
                          _solo ? 'View movie' : 'Make a Watch Plan',
                          _picking
                              ? null
                              : () {
                                  final pick = _result!.choices[_selectedPick];
                                  if (_solo) {
                                    context.push('/movies/${pick.movie.id}');
                                  } else {
                                    _plan(pick);
                                  }
                                }),
                    ] else ...[
                      _primary('Change preferences', _picking ? null : _back),
                      TextButton(
                          onPressed: _picking ? null : () => _pick(),
                          child: Text(_picking ? 'Checking…' : 'Try again')),
                    ],
                  ],
                ]),
              ))),
    );
  }

  Widget _choice(PickForUsResult pick) {
    final movie = pick.movie;
    final poster = movie.poster;
    final image = poster == null
        ? null
        : poster.startsWith('http')
            ? poster
            : 'https://image.tmdb.org/t/p/w342$poster';
    final artwork = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: image == null
            ? Container(
                width: 104,
                height: 156,
                color: context.colors.surface,
                child: const Icon(Icons.movie_outlined, size: 40))
            : CachedNetworkImage(
                imageUrl: image,
                width: 104,
                height: 156,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                    width: 104,
                    height: 156,
                    color: context.colors.surface,
                    child: const Icon(Icons.movie_outlined, size: 40))));
    final title =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(movie.name,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      _note('${pick.runtime} min'),
    ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 360 &&
                  MediaQuery.textScalerOf(context).scale(16) > 22
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [artwork, const SizedBox(height: 16), title])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  artwork,
                  const SizedBox(width: 20),
                  Expanded(child: title)
                ])),
      if (movie.overview?.isNotEmpty == true) ...[
        const SizedBox(height: 20),
        Text(movie.overview!, style: const TextStyle(height: 1.5))
      ],
      if (movie.recommendationReasons.isNotEmpty) ...[
        _heading('Why this fits'),
        for (final reason in movie.recommendationReasons)
          Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.check, size: 20, color: context.colors.secondary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(reason, style: const TextStyle(height: 1.5))),
              ])),
      ],
      const SizedBox(height: 16),
      if (!_solo)
        Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
                onPressed: () => context.push('/movies/${movie.id}'),
                child: const Text('View movie details'))),
    ]);
  }
}
