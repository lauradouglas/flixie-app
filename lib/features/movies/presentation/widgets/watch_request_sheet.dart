import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/movie_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_avatar.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/movies/utils/group_provider_match.dart';
import 'package:flixie_app/models/movie_short.dart';

enum _WatchContext { home, cinema, undecided }

enum _ScheduleMode { dateOnly, dateAndTime, suggestDates }

class MovieWatchRequestSheet extends StatefulWidget {
  const MovieWatchRequestSheet({
    super.key,
    required this.movieId,
    required this.movieTitle,
    this.moviePoster,
    required this.requesterId,
    required this.friends,
    required this.onSuccess,
    required this.onError,
    this.initialFriendId,
    this.initialGroupId,
    this.fromMovieMatch = false,
  });

  final int? movieId;
  final String? movieTitle;
  final String? moviePoster;
  final String requesterId;
  final List<Friendship> friends;
  final VoidCallback onSuccess;
  final VoidCallback onError;
  final String? initialFriendId;
  final String? initialGroupId;
  final bool fromMovieMatch;

  @override
  State<MovieWatchRequestSheet> createState() => _MovieWatchRequestSheetState();
}

class _MovieWatchRequestSheetState extends State<MovieWatchRequestSheet> {
  final _messageController = TextEditingController();
  final _recipientSearchController = TextEditingController();
  String _recipientSearch = '';
  bool _isGroupMode = false;
  String? _selectedFriendId;
  String? _selectedGroupId;
  bool _isSending = false;
  _WatchContext _watchContext = _WatchContext.home;
  _ScheduleMode _scheduleMode = _ScheduleMode.dateAndTime;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  late final List<MovieShort> _movieChoices;

  List<Group> _groups = [];
  bool _loadingGroups = false;
  bool _loadingProviders = true;
  bool _loadingFriendProviders = false;
  bool _providerLoadStarted = false;
  List<WatchProvider> _streamingProviders = [];
  final Map<int, List<WatchProvider>> _streamingProvidersByMovieId = {};
  final Set<int> _loadingProviderMovieIds = {};
  int? _selectedMovieId;
  Set<int> _myProviderIds = {};
  Set<int> _friendProviderIds = {};
  Map<int, int> _groupProviderCounts = {};
  Map<String, int> _groupProviderNameCounts = {};
  int _groupMemberCount = 0;
  bool _loadingGroupProviders = false;

  @override
  void initState() {
    super.initState();
    _movieChoices = widget.movieId == null
        ? []
        : [
            MovieShort(
              id: widget.movieId!,
              name: widget.movieTitle ?? 'Movie',
              poster: widget.moviePoster,
            ),
          ];
    _selectedMovieId = widget.movieId;
    _fetchGroups();
    if (widget.initialGroupId != null) {
      _isGroupMode = true;
      _selectedGroupId = widget.initialGroupId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _selectGroup(widget.initialGroupId!);
      });
    }
    if (widget.initialFriendId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final initialId = widget.initialFriendId!;
        if (widget.friends
            .any((friendship) => friendship.friendUser?.id == initialId)) {
          _selectFriend(initialId);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_providerLoadStarted) return;
    _providerLoadStarted = true;
    _loadProviders();
  }

  Future<void> _loadProviders() async {
    final movieId = widget.movieId;
    if (movieId == null) {
      if (mounted) setState(() => _loadingProviders = false);
      return;
    }
    final auth = context.read<AuthProvider>();
    final region = auth.dbUser?.watchProviderRegion ?? 'GB';
    try {
      final results = await Future.wait([
        MovieService().getMovieWatchProviders(movieId, region),
        UserService.getUserWatchProviders(widget.requesterId),
      ]);
      if (!mounted) return;
      final available =
          results[0].where((provider) => provider.isStreaming).toList()
            ..sort(
              (a, b) => a.displayPriority.compareTo(b.displayPriority),
            );
      setState(() {
        _streamingProviders = {
          for (final provider in available) provider.id: provider,
        }.values.toList();
        _streamingProvidersByMovieId[movieId] = _streamingProviders;
        _myProviderIds = results[1].map((provider) => provider.id).toSet();
        _loadingProviders = false;
      });
    } catch (error) {
      logger.w('Unable to load watch-request providers: $error');
      if (mounted) setState(() => _loadingProviders = false);
    }
  }

  Future<void> _selectFriend(String friendId) async {
    setState(() {
      _selectedFriendId = friendId;
      _friendProviderIds = {};
      _loadingFriendProviders = true;
    });
    try {
      final providers = await UserService.getUserWatchProviders(friendId);
      if (!mounted || _selectedFriendId != friendId) return;
      setState(() {
        _friendProviderIds = providers.map((provider) => provider.id).toSet();
        _loadingFriendProviders = false;
      });
    } catch (error) {
      logger.w('Unable to load friend watch providers: $error');
      if (mounted && _selectedFriendId == friendId) {
        setState(() => _loadingFriendProviders = false);
      }
    }
  }

  Future<void> _selectMovieChoice(MovieShort movie) async {
    setState(() => _selectedMovieId = movie.id);
    if (_streamingProvidersByMovieId.containsKey(movie.id) ||
        _loadingProviderMovieIds.contains(movie.id)) {
      return;
    }
    _loadingProviderMovieIds.add(movie.id);
    try {
      final region =
          context.read<AuthProvider>().dbUser?.watchProviderRegion ?? 'GB';
      final providers =
          await MovieService().getMovieWatchProviders(movie.id, region);
      if (!mounted) return;
      setState(() {
        _streamingProvidersByMovieId[movie.id] = {
          for (final provider
              in providers.where((provider) => provider.isStreaming))
            provider.id: provider,
        }.values.toList()
          ..sort((a, b) => a.displayPriority.compareTo(b.displayPriority));
      });
    } catch (error) {
      logger.w('Unable to load providers for ${movie.name}: $error');
    } finally {
      _loadingProviderMovieIds.remove(movie.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _selectGroup(String groupId) async {
    setState(() {
      _selectedGroupId = groupId;
      _groupProviderCounts = {};
      _groupProviderNameCounts = {};
      _groupMemberCount = 0;
      _loadingGroupProviders = true;
    });
    try {
      final members = (await GroupService.getGroupMembers(groupId))
          .where((member) => member.isAccepted)
          .toList();
      final providerLists = await Future.wait(members.map((member) async {
        try {
          return await UserService.getUserWatchProviders(member.memberId);
        } catch (error) {
          logger.w(
            'Unable to load watch providers for group member '
            '${member.memberId}: $error',
          );
          return <WatchProvider>[];
        }
      }));
      if (!mounted || _selectedGroupId != groupId) return;
      final counts = countGroupProviderMatches(
        providerLists
            .map((providers) => providers.map((provider) => provider.id)),
      );
      final nameCounts = countGroupProviderMatches(
        providerLists.map(
          (providers) => providers.map((provider) => provider.matchKey),
        ),
      );
      setState(() {
        _groupProviderCounts = counts;
        _groupProviderNameCounts = nameCounts;
        _groupMemberCount = members.length;
        _loadingGroupProviders = false;
      });
    } catch (error) {
      logger.w('Unable to compare group watch providers: $error');
      if (mounted && _selectedGroupId == groupId) {
        setState(() => _loadingGroupProviders = false);
      }
    }
  }

  Future<void> _fetchGroups() async {
    setState(() => _loadingGroups = true);
    try {
      final groups = await GroupService.getUserGroups(widget.requesterId);
      if (mounted) setState(() => _groups = groups);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingGroups = false);
    }
  }

  bool _isMovieAvailableToEveryone(MovieShort movie) {
    if (!_isGroupMode || _selectedGroupId == null || _groupMemberCount == 0) {
      return false;
    }
    return (_streamingProvidersByMovieId[movie.id] ?? const <WatchProvider>[])
        .any((provider) =>
            (_groupProviderCounts[provider.id] ??
                _groupProviderNameCounts[provider.matchKey] ??
                0) ==
            _groupMemberCount);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _recipientSearchController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final canSend =
        _isGroupMode ? _selectedGroupId != null : _selectedFriendId != null;
    if (!canSend || _isSending || _movieChoices.isEmpty || !_hasValidSchedule) {
      return;
    }
    final analytics = context.read<AnalyticsController>();
    setState(() => _isSending = true);
    try {
      String? watchPlanId;
      if (_isGroupMode) {
        // Legacy fallback: POST /groups/:groupId/send-request
        // The response may now include a conversationId from the updated backend.
        final result = await GroupService.sendWatchRequest(
          _selectedGroupId!,
          widget.requesterId,
          _messageController.text.trim(),
          'MOVIE',
          _movieChoices.first.id,
          candidateMovieIds: _movieChoices.map((movie) => movie.id).toList(),
          proposedDate: _proposedDate?.toIso8601String(),
          location: _locationLabel,
        );
        final conversationId = result?['conversationId'] as String?;
        final watchRequest = result?['watchRequest'] as Map<String, dynamic>?;
        watchPlanId = (watchRequest?['pgGroupRequestId'] ?? watchRequest?['id'])
            ?.toString();
        logger.d('[WatchRequest] group send result: $result, '
            'conversationId: $conversationId');
      } else {
        final result = await RequestService.sendRequest({
          'requesterId': widget.requesterId,
          'recipientId': _selectedFriendId,
          'movieId': widget.movieId,
          'candidateMovieIds': _movieChoices.map((movie) => movie.id).toList(),
          'message': _messageController.text.trim(),
          'type': 'MOVIE_WATCH_REQUEST',
          if (_proposedDate != null)
            'proposedDate': _proposedDate!.toIso8601String(),
          if (_locationLabel != null) 'location': _locationLabel,
        });
        final request = result?['request'] as Map<String, dynamic>?;
        watchPlanId = request?['id']?.toString();
        final notification = result?['notification'] as Map<String, dynamic>?;
        logger.d('[WatchRequest] notification created: $notification');
      }
      await analytics.watchPlanCreated(
        watchPlanId: watchPlanId,
        contentId: widget.movieId,
        contentType: 'movie',
        planType: _isGroupMode ? 'group' : 'friend',
        participantCount: _isGroupMode
            ? (_groupMemberCount > 0 ? _groupMemberCount : null)
            : 2,
        source: widget.fromMovieMatch ? 'recommendations' : 'movie_detail',
      );
      if (mounted) Navigator.pop(context);
      widget.onSuccess();
    } catch (e) {
      logger.e('Failed to send watch request: $e');
      if (mounted) setState(() => _isSending = false);
      widget.onError();
    }
  }

  Future<void> _addMovieChoice() async {
    if (_movieChoices.length >= 5) return;
    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.surface,
      builder: (_) => MovieSearchSheet(
        title: 'Add a movie option',
        searchMovies: (query) async {
          final result = await SearchService.search(query, type: 'movie');
          return result.results
              .where((item) => item.movie != null)
              .map((item) => item.movie!)
              .where((item) =>
                  !_movieChoices.any((choice) => choice.id == item.id))
              .toList();
        },
      ),
    );
    if (movie != null && mounted) {
      setState(() => _movieChoices.add(movie));
      _selectMovieChoice(movie);
    }
  }

  void _removeMovieChoice(MovieShort movie) {
    if (_movieChoices.length <= 1) return;
    setState(() {
      _movieChoices.remove(movie);
      if (_selectedMovieId == movie.id) {
        _selectedMovieId = _movieChoices.first.id;
      }
    });
  }

  bool get _hasValidSchedule {
    if (_selectedDate == null) return false;
    if (_scheduleMode == _ScheduleMode.dateAndTime && _selectedTime == null) {
      return false;
    }
    final proposed = _proposedDate;
    return proposed == null || !proposed.isBefore(DateTime.now());
  }

  DateTime? get _proposedDate {
    final date = _selectedDate;
    if (date == null) return null;
    if (_scheduleMode != _ScheduleMode.dateAndTime) return date;
    final time = _selectedTime;
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String? get _locationLabel => switch (_watchContext) {
        _WatchContext.home => 'At home',
        _WatchContext.cinema => 'Cinema',
        _WatchContext.undecided => null,
      };

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate == null || _selectedDate!.isBefore(today)
          ? today
          : _selectedDate!,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 3),
    );
    if (picked != null && mounted) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null && mounted) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final query = _recipientSearch.toLowerCase();
    final visibleFriends = widget.friends.where((item) {
      final friend = item.friendUser;
      if (friend == null) return false;
      return query.isEmpty || friend.displayName.toLowerCase().contains(query);
    }).toList();
    final visibleGroups = _groups
        .where((group) =>
            query.isEmpty ||
            group.name.toLowerCase().contains(query) ||
            (group.abbreviation?.toLowerCase().contains(query) ?? false))
        .toList();
    final hasFriends = widget.friends.isNotEmpty;
    final hasGroups = _groups.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            MediaQuery.of(context).padding.top + 16,
            24,
            MediaQuery.of(context).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: FlixieColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.movie_creation_outlined,
                        color: FlixieColors.primary, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Plan to watch',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Plan a watch together around this movie',
                          style: TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded,
                        color: FlixieColors.medium),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Friend / Group toggle
              Container(
                decoration: BoxDecoration(
                  color: FlixieColors.surfaceElevated,
                  border: Border.all(color: FlixieColors.tabBarBorder),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _ModeTab(
                      label: 'A Friend',
                      icon: Icons.person_outline_rounded,
                      selected: !_isGroupMode,
                      onTap: () => setState(() {
                        _isGroupMode = false;
                        _selectedGroupId = null;
                      }),
                    ),
                    _ModeTab(
                      label: 'A Group',
                      icon: Icons.groups_2_outlined,
                      selected: _isGroupMode,
                      onTap: () => setState(() {
                        _isGroupMode = true;
                        _selectedFriendId = null;
                      }),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if ((_isGroupMode ? hasGroups : hasFriends)) ...[
                TextField(
                  controller: _recipientSearchController,
                  onChanged: (value) =>
                      setState(() => _recipientSearch = value.trim()),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText:
                        _isGroupMode ? 'Search your groups' : 'Search friends',
                    suffixIcon: _recipientSearch.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _recipientSearchController.clear();
                              setState(() => _recipientSearch = '');
                            },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (!_isGroupMode) ...[
                const Text(
                  'SELECT A FRIEND',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                if (!hasFriends)
                  const Text(
                    'Add some friends to plan a watch together',
                    style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibleFriends.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final friend = visibleFriends[i].friendUser;
                        if (friend == null) return const SizedBox.shrink();
                        final isSelected = _selectedFriendId == friend.id;
                        return _RecipientOptionTile(
                          title: friend.displayName,
                          avatar: friend.avatar,
                          avatarColor:
                              avatarColorFromIconColor(friend.iconColor),
                          selected: isSelected,
                          onTap: () => _selectFriend(friend.id),
                        );
                      },
                    ),
                  ),
              ] else ...[
                const Text(
                  'SELECT A GROUP',
                  style: TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                if (_loadingGroups)
                  const SizedBox(
                    height: 44,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (!hasGroups)
                  const Text(
                    "You're not in any groups yet",
                    style: TextStyle(color: FlixieColors.medium, fontSize: 13),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: visibleGroups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final group = visibleGroups[i];
                        final isSelected = _selectedGroupId == group.id;
                        return _RecipientOptionTile(
                          title: group.name,
                          subtitle: group.abbreviation?.isNotEmpty == true
                              ? group.abbreviation
                              : null,
                          selected: isSelected,
                          group: true,
                          groupModel: group,
                          onTap: () => _selectGroup(group.id!),
                        );
                      },
                    ),
                  ),
              ],
              const SizedBox(height: 16),
              _WatchRequestProviders(
                providers: _streamingProvidersByMovieId[_selectedMovieId] ??
                    _streamingProviders,
                movieTitle: _movieChoices
                    .where((movie) => movie.id == _selectedMovieId)
                    .map((movie) => movie.name)
                    .firstOrNull,
                myProviderIds: _myProviderIds,
                friendProviderIds: _friendProviderIds,
                friendName: _selectedFriendName,
                loading: _loadingProviders,
                loadingFriend: _loadingFriendProviders,
                showFriendMatch: !_isGroupMode && _selectedFriendId != null,
                groupMode: _isGroupMode,
                groupSelected: _selectedGroupId != null,
                groupProviderCounts: _groupProviderCounts,
                groupProviderNameCounts: _groupProviderNameCounts,
                groupMemberCount: _groupMemberCount,
                loadingGroup: _loadingGroupProviders,
              ),
              const SizedBox(height: 14),
              Text(
                '${_movieChoices.length} of 5 movie options',
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _movieChoices
                    .map(
                      (movie) => SizedBox(
                        width: 76,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              onTap: () => _selectMovieChoice(movie),
                              borderRadius: BorderRadius.circular(9),
                              child: Stack(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(9),
                                      border: Border.all(
                                        color:
                                            _isMovieAvailableToEveryone(movie)
                                                ? FlixieColors.success
                                                : movie.id == _selectedMovieId
                                                    ? FlixieColors.primary
                                                    : Colors.transparent,
                                        width:
                                            _isMovieAvailableToEveryone(movie)
                                                ? 2
                                                : 1,
                                      ),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: SizedBox(
                                        width: 76,
                                        height: 114,
                                        child: movie.poster == null
                                            ? Container(
                                                color: FlixieColors
                                                    .surfaceElevated,
                                                child: const Icon(
                                                    Icons.movie_outlined,
                                                    color: FlixieColors.medium),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: movie.poster!
                                                        .startsWith('http')
                                                    ? movie.poster!
                                                    : 'https://image.tmdb.org/t/p/w185${movie.poster}',
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                  if (_movieChoices.length > 1)
                                    Positioned(
                                      top: 3,
                                      right: 3,
                                      child: InkWell(
                                        onTap: () => _removeMovieChoice(movie),
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.all(3),
                                          decoration: const BoxDecoration(
                                            color: Colors.black54,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close_rounded,
                                              size: 14, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              movie.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: FlixieColors.light,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
              TextButton.icon(
                onPressed: _movieChoices.length >= 5 ? null : _addMovieChoice,
                icon: const Icon(Icons.add_circle_outline_rounded),
                label: const Text('Add another movie'),
              ),
              const SizedBox(height: 20),
              const Text(
                'MESSAGE (OPTIONAL)',
                style: TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 2,
                style: const TextStyle(color: FlixieColors.light),
                decoration: InputDecoration(
                  hintText: 'e.g. Want to watch this together?',
                  hintStyle:
                      const TextStyle(color: FlixieColors.medium, fontSize: 13),
                  filled: true,
                  fillColor: FlixieColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: FlixieColors.tabBarBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        const BorderSide(color: FlixieColors.tabBarBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: FlixieColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSending ||
                          _movieChoices.isEmpty ||
                          (_isGroupMode
                              ? _selectedGroupId == null
                              : _selectedFriendId == null)
                      ? null
                      : _send,
                  child: _isSending
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : Text(_sendButtonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _sendButtonLabel {
    if (_isGroupMode ? _selectedGroupId != null : _selectedFriendId != null) {
      return 'Send watch plan';
    }
    return 'Choose who\'s watching';
  }

  String? get _selectedFriendName {
    for (final friendship in widget.friends) {
      final friend = friendship.friendUser;
      if (friend?.id == _selectedFriendId) return friend?.displayName;
    }
    return null;
  }
}

class _WatchRequestProviders extends StatelessWidget {
  const _WatchRequestProviders({
    required this.providers,
    this.movieTitle,
    required this.myProviderIds,
    required this.friendProviderIds,
    required this.friendName,
    required this.loading,
    required this.loadingFriend,
    required this.showFriendMatch,
    required this.groupMode,
    required this.groupSelected,
    required this.groupProviderCounts,
    required this.groupProviderNameCounts,
    required this.groupMemberCount,
    required this.loadingGroup,
  });

  final List<WatchProvider> providers;
  final String? movieTitle;
  final Set<int> myProviderIds;
  final Set<int> friendProviderIds;
  final String? friendName;
  final bool loading;
  final bool loadingFriend;
  final bool showFriendMatch;
  final bool groupMode;
  final bool groupSelected;
  final Map<int, int> groupProviderCounts;
  final Map<String, int> groupProviderNameCounts;
  final int groupMemberCount;
  final bool loadingGroup;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _ProviderPanel(
        child: Row(
          children: [
            SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 9),
            Text(
              'Checking streaming availability…',
              style: TextStyle(color: FlixieColors.medium, fontSize: 12),
            ),
          ],
        ),
      );
    }
    if (providers.isEmpty) {
      return const _ProviderPanel(
        child: Row(
          children: [
            Icon(Icons.tv_off_outlined, size: 17, color: FlixieColors.medium),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Not currently available on a streaming subscription.',
                style: TextStyle(color: FlixieColors.medium, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    final shared = providers
        .where((provider) =>
            myProviderIds.contains(provider.id) &&
            friendProviderIds.contains(provider.id))
        .toList();
    return _ProviderPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            movieTitle == null
                ? 'WHERE TO WATCH'
                : 'WHERE TO WATCH · $movieTitle',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final provider in providers.take(8))
                _ProviderMatchLogo(
                  provider: provider,
                  youHaveIt: myProviderIds.contains(provider.id),
                  friendHasIt: friendProviderIds.contains(provider.id),
                  compareFriend: showFriendMatch && !loadingFriend,
                  groupMatchCount: groupMode && groupSelected
                      ? _groupMatchCount(provider)
                      : 0,
                  groupMemberCount:
                      groupMode && groupSelected ? groupMemberCount : 0,
                ),
            ],
          ),
          const SizedBox(height: 9),
          if (groupMode && !groupSelected)
            const Text(
              'Select a group to compare everyone’s streaming services.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 12),
            )
          else if (groupMode && loadingGroup)
            const Text(
              'Checking group members’ services…',
              style: TextStyle(color: FlixieColors.medium, fontSize: 12),
            )
          else if (groupMode)
            Text(
              _groupSummary,
              style: TextStyle(
                color: _hasGroupMatch
                    ? FlixieColors.success
                    : FlixieColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (!showFriendMatch)
            const Text(
              'Select a friend to compare your streaming services.',
              style: TextStyle(color: FlixieColors.medium, fontSize: 12),
            )
          else if (loadingFriend)
            const Text(
              'Checking your friend’s services…',
              style: TextStyle(color: FlixieColors.medium, fontSize: 12),
            )
          else
            Text(
              shared.isNotEmpty
                  ? 'You and ${friendName ?? 'your friend'} can both stream it on ${shared.map((provider) => provider.providerName).join(', ')}.'
                  : 'No shared streaming service for you and ${friendName ?? 'your friend'}.',
              style: TextStyle(
                color: shared.isNotEmpty
                    ? FlixieColors.success
                    : FlixieColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  bool get _hasGroupMatch => providers
      .any((provider) => _groupMatchCount(provider) == groupMemberCount);

  String get _groupSummary {
    if (groupMemberCount == 0) return 'No eligible group members found.';
    final everyone = providers
        .where(
          (provider) => _groupMatchCount(provider) == groupMemberCount,
        )
        .map((provider) => provider.providerName)
        .toList();
    if (everyone.isNotEmpty) {
      return 'Everyone can stream it on ${everyone.join(', ')}.';
    }
    final best = [...providers]..sort(
        (a, b) => _groupMatchCount(b).compareTo(_groupMatchCount(a)),
      );
    final provider = best.first;
    final count = _groupMatchCount(provider);
    return count == 0
        ? 'No group members have a matching streaming service.'
        : '$count of $groupMemberCount members have ${provider.providerName}.';
  }

  int _groupMatchCount(WatchProvider provider) =>
      groupProviderCounts[provider.id] ??
      groupProviderNameCounts[provider.matchKey] ??
      0;
}

class _ProviderPanel extends StatelessWidget {
  const _ProviderPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: FlixieColors.tabBarBorder),
        ),
        child: child,
      );
}

class _ProviderMatchLogo extends StatelessWidget {
  const _ProviderMatchLogo({
    required this.provider,
    required this.youHaveIt,
    required this.friendHasIt,
    required this.compareFriend,
    this.groupMatchCount = 0,
    this.groupMemberCount = 0,
  });

  final WatchProvider provider;
  final bool youHaveIt;
  final bool friendHasIt;
  final bool compareFriend;
  final int groupMatchCount;
  final int groupMemberCount;

  @override
  Widget build(BuildContext context) {
    final friendShared = compareFriend && youHaveIt && friendHasIt;
    final groupShared =
        groupMemberCount > 0 && groupMatchCount == groupMemberCount;
    final highlighted = friendShared || groupShared;
    return Tooltip(
      message: groupShared
          ? 'Everyone in the group has ${provider.providerName}'
          : groupMemberCount > 0 && groupMatchCount > 0
              ? '$groupMatchCount of $groupMemberCount group members have ${provider.providerName}'
              : friendShared
                  ? 'You both have ${provider.providerName}'
                  : youHaveIt
                      ? 'You have ${provider.providerName}'
                      : provider.providerName,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: highlighted
                    ? FlixieColors.success
                    : youHaveIt
                        ? FlixieColors.primary
                        : FlixieColors.tabBarBorder,
                width: highlighted ? 2 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: CachedNetworkImage(
                imageUrl: provider.logoUrl,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const Icon(
                  Icons.live_tv_outlined,
                  color: FlixieColors.medium,
                ),
              ),
            ),
          ),
          if (highlighted)
            const Positioned(
              right: -4,
              top: -4,
              child: Icon(
                Icons.check_circle_rounded,
                size: 15,
                color: FlixieColors.success,
              ),
            ),
        ],
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? FlixieColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 17,
                  color: selected ? Colors.black : FlixieColors.medium),
              const SizedBox(width: 7),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.black : FlixieColors.medium,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientOptionTile extends StatelessWidget {
  const _RecipientOptionTile({
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.group = false,
    this.avatar,
    this.avatarColor = FlixieColors.primary,
    this.groupModel,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final bool group;
  final ProfileAvatar? avatar;
  final Color avatarColor;
  final Group? groupModel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected
                ? FlixieColors.primary.withValues(alpha: 0.16)
                : FlixieColors.surfaceElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  selected ? FlixieColors.primary : FlixieColors.tabBarBorder,
            ),
          ),
          child: Row(
            children: [
              if (group && groupModel != null)
                GroupAvatar(group: groupModel!, radius: 18)
              else if (avatar != null)
                ProfileAvatarView(
                  avatar: avatar,
                  fallbackText: '',
                  fallbackColor: avatarColor,
                  size: 36,
                )
              else
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: avatarColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_outline_rounded,
                      size: 20, color: avatarColor),
                ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle?.isNotEmpty == true)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.medium,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? const Icon(Icons.check_circle_rounded,
                        key: ValueKey('selected'),
                        color: FlixieColors.primary,
                        size: 22)
                    : const Icon(Icons.circle_outlined,
                        key: ValueKey('unselected'),
                        color: FlixieColors.medium,
                        size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
