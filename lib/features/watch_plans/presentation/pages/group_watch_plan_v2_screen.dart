import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/watch_plan_movie_options.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/group_plan/group_watch_plan_recap.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/calendar/watch_calendar_service.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/features/movies/presentation/widgets/rewatch_log_sheet.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_schedule_sheet.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/movie_short.dart';

/// The shared group Watch Plan flow, used by the overview, group pages,
/// and standalone routes.
class GroupWatchPlanV2Screen extends StatefulWidget {
  const GroupWatchPlanV2Screen({
    super.key,
    this.groupId,
    this.groupName,
    this.initialRequestId,
    this.embedded = false,
    this.onCountChanged,
    this.onActiveCountChanged,
  });

  final String? groupId;
  final String? groupName;
  final String? initialRequestId;
  final bool embedded;
  final ValueChanged<int>? onCountChanged;
  final ValueChanged<int>? onActiveCountChanged;

  @override
  State<GroupWatchPlanV2Screen> createState() => _GroupWatchPlanV2ScreenState();
}

class _GroupWatchPlanV2ScreenState extends State<GroupWatchPlanV2Screen> {
  List<GroupWatchRequest> _requests = const [];
  List<GroupMember> _members = const [];
  final Map<String, List<GroupMember>> _membersByRequest = {};
  final Map<String, String> _groupNamesByRequest = {};
  String? _selectedId;
  bool _past = false;
  bool _loading = true;
  bool _processing = false;
  String? _error;
  final Map<String, Set<String>> _drafts = {};

  String get _userId => context.read<AuthProvider>().dbUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialRequestId;
    TabRefreshController.social.addListener(_onSocialRefresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    TabRefreshController.social.removeListener(_onSocialRefresh);
    super.dispose();
  }

  void _onSocialRefresh() {
    if (mounted && !_processing) _load();
  }

  @override
  void didUpdateWidget(covariant GroupWatchPlanV2Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId ||
        oldWidget.initialRequestId != widget.initialRequestId) {
      _selectedId = widget.initialRequestId;
      _load();
    }
  }

  Future<void> _load() async {
    final groupId = widget.groupId;
    if (_requests.isEmpty) setState(() => _loading = true);
    try {
      final loadedGroups = <_LoadedGroup>[];
      if (groupId != null && groupId.isNotEmpty) {
        final values = await Future.wait<Object>([
          GroupService.getGroupWatchRequests(groupId),
          GroupService.getGroupMembers(groupId),
        ]);
        loadedGroups.add(_LoadedGroup(
          name: widget.groupName ?? 'Group',
          requests: values[0] as List<GroupWatchRequest>,
          members: values[1] as List<GroupMember>,
        ));
      } else {
        final groups = await GroupService.getUserGroups(_userId);
        final results = await Future.wait(
          groups.where((group) => group.id?.isNotEmpty == true).map(
            (group) async {
              try {
                final values = await Future.wait<Object>([
                  GroupService.getGroupWatchRequests(group.id!),
                  GroupService.getGroupMembers(group.id!),
                ]);
                return _LoadedGroup(
                  name: group.name,
                  requests: values[0] as List<GroupWatchRequest>,
                  members: values[1] as List<GroupMember>,
                );
              } catch (_) {
                return _LoadedGroup(
                  name: group.name,
                  requests: const [],
                  members: const [],
                );
              }
            },
          ),
        );
        loadedGroups.addAll(results);
      }
      if (!mounted) return;
      setState(() {
        _membersByRequest.clear();
        _groupNamesByRequest.clear();
        _requests = loadedGroups
            .expand((group) => group.requests)
            .toList(growable: false);
        _members = loadedGroups
            .expand((group) => group.members)
            .where((member) => member.isOwner || member.isAccepted)
            .toList(growable: false);
        for (final group in loadedGroups) {
          final members = group.members
              .where((member) => member.isOwner || member.isAccepted)
              .toList(growable: false);
          for (final request in group.requests) {
            _membersByRequest[request.id] = members;
            _groupNamesByRequest[request.id] = group.name;
            final databaseId = request.databaseRequestId;
            if (databaseId != null) {
              _membersByRequest[databaseId] = members;
              _groupNamesByRequest[databaseId] = group.name;
            }
          }
        }
        _loading = false;
        _error = null;
        if (_selectedId != null &&
            !_requests.any((request) => request.matchesId(_selectedId!))) {
          _selectedId = null;
        }
      });
      widget.onActiveCountChanged?.call(
        _requests.where((request) => request.isActive).length,
      );
      widget.onCountChanged?.call(
        _requests
            .where((request) =>
                request.canRespond &&
                request.userId != _userId &&
                !_accepted(request))
            .length,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Couldn’t refresh these Watch Plans. Pull down to try again.';
      });
    }
  }

  GroupWatchRequest? get _selected => _selectedId == null
      ? null
      : _requests.where((item) => item.matchesId(_selectedId!)).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final request = _selected;
    return PopScope(
      canPop: request == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && request != null) setState(() => _selectedId = null);
      },
      child: widget.embedded
          ? _screenBody(request)
          : Scaffold(
              backgroundColor: FlixieColors.background,
              appBar: AppBar(
                backgroundColor: FlixieColors.background,
                foregroundColor: FlixieColors.textPrimary,
                leading: request == null
                    ? null
                    : IconButton(
                        tooltip: 'Back to Watch Plans',
                        onPressed: () => setState(() => _selectedId = null),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      ),
                title: Text(request == null
                    ? widget.groupId == null
                        ? 'Group Watch Plans'
                        : widget.groupName ?? 'Group Watch Plans'
                    : request.movieTitle ?? 'Group Watch Plan'),
                actions: [
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _processing ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              floatingActionButton: request == null
                  ? FloatingActionButton(
                      tooltip: 'Make a Watch Plan',
                      onPressed: _processing ? null : _create,
                      child: const Icon(Icons.add_rounded),
                    )
                  : null,
              body: _screenBody(request),
            ),
    );
  }

  Widget _screenBody(GroupWatchRequest? request) => RefreshIndicator(
        color: FlixieColors.primary,
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (_loading && _requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _requests.isEmpty)
              _empty('Watch Plans unavailable', _error!, onTap: _load)
            else if (request == null)
              _list()
            else
              _detail(request),
          ],
        ),
      );

  Future<void> _create() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: FlixieColors.surface,
      builder: (_) => MovieWatchRequestSheet(
        movieId: null,
        movieTitle: null,
        requesterId: _userId,
        friends: const [],
        initialGroupId: widget.groupId,
        onSuccess: _load,
        onError: () => _showError('Couldn’t create the Watch Plan.'),
      ),
    );
  }

  Widget _list() {
    final plans = _requests
        .where((item) => _past ? item.isArchived : item.isActive)
        .toList()
      ..sort((a, b) => _date(b).compareTo(_date(a)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final past in [false, true])
            ChoiceChip(
              label: Text(past
                  ? 'Past · ${_requests.where((plan) => plan.isArchived).length}'
                  : 'Active · ${_requests.where((plan) => plan.isActive).length}'),
              selected: _past == past,
              onSelected: (_) => setState(() => _past = past),
              showCheckmark: true,
              checkmarkColor: FlixieColors.medium,
              labelPadding: const EdgeInsets.symmetric(horizontal: 12),
              padding: EdgeInsets.zero,
              selectedColor: FlixieColors.primary.withValues(alpha: .22),
              backgroundColor: FlixieColors.tabBarBackgroundFocused,
              side: BorderSide(
                color: FlixieColors.primary.withValues(
                  alpha: _past == past ? 1 : .3,
                ),
              ),
              labelStyle: TextStyle(
                color: _past == past ? Colors.white : FlixieColors.medium,
                fontWeight: FontWeight.w700,
              ),
              shape: const StadiumBorder(),
            ),
        ],
      ),
      if (widget.embedded && (plans.isNotEmpty || _past)) ...[
        const SizedBox(height: 12),
        _primary('Make a Watch Plan', Icons.add_rounded, _create),
      ],
      const SizedBox(height: 16),
      if (plans.isEmpty)
        _empty(
          _past ? 'No past plans yet' : 'Plan your next movie night',
          _past
              ? 'Completed and closed Watch Plans will appear here.'
              : 'Choose some films, invite the group, and agree a time.',
          action: _past ? null : 'Make a Watch Plan',
          onTap: _past ? null : _create,
        )
      else
        ...plans.map((plan) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _planCard(plan),
            )),
    ]);
  }

  Widget _planCard(GroupWatchRequest request) {
    final state = _state(request);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () async {
        setState(() => _selectedId = request.id);
        await _load();
      },
      child: _surface(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (request.selectedCandidateId == null &&
              request.candidates.length > 1)
            WatchPlanPosterStack(posters: [
              for (final c in request.candidates.take(3))
                WatchPlanPoster(path: c.posterPath, title: c.title, width: 70),
            ])
          else
            _poster(request.moviePosterPath, request.movieTitle, 70),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _status(state),
              const SizedBox(height: 7),
              Text(request.movieTitle ?? _optionLabel(request),
                  style: const TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 19,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(_groupName(request),
                  style: const TextStyle(
                      color: FlixieColors.primaryText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(_timing(request), style: _body),
              if (request.isActive) ...[
                const SizedBox(height: 3),
                Text(_replyLabel(request), style: _body),
              ],
              const SizedBox(height: 9),
              _avatars(_activeMembers(request), 34),
            ]),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 36),
            child:
                Icon(Icons.chevron_right_rounded, color: FlixieColors.medium),
          ),
        ]),
        border: state.color.withValues(alpha: .45),
      ),
    );
  }

  Widget _detail(GroupWatchRequest request) {
    final members = _activeMembers(request);
    final stage = _state(request).stage;
    if (stage == _Stage.invite) {
      return _inviteDetail(request, members);
    }
    if (stage == _Stage.recap) return _recap(request);
    if (stage == _Stage.scheduled) {
      return _scheduledDetail(request, members);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _hero(request, members),
      _creationMessage(request),
      const Divider(height: 30, color: FlixieColors.tabBarBorder),
      _actionCard(request),
      const Divider(height: 30, color: FlixieColors.tabBarBorder),
      _progress(request, members),
    ]);
  }

  Widget _scheduledDetail(
      GroupWatchRequest request, List<GroupMember> members) {
    final selected = _selectedCandidate(request);
    final title =
        selected?.title ?? request.movieTitle ?? _optionLabel(request);
    final location = request.location?.trim();
    final date = DateTime.tryParse(request.scheduledFor ?? '')?.toLocal();
    final canUpdate =
        request.userId == _userId || request.canScheduleFor(_userId);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _detailPoster(
              selected?.posterPath ?? request.moviePosterPath, title, 96),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(_groupName(request),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: _body),
              const SizedBox(height: 12),
              _scheduleFact(
                  Icons.calendar_month_outlined, _format(request.scheduledFor)),
              const SizedBox(height: 8),
              _scheduleFact(
                  Icons.location_on_outlined,
                  location?.isNotEmpty == true
                      ? location!
                      : 'Location not set'),
              const SizedBox(height: 10),
              _scheduledPill(),
            ]),
          ),
        ]),
        _creationMessage(request),
        const Divider(height: 30, color: FlixieColors.tabBarBorder),
        Text('Confirmed attendees (${members.length})',
            style: const TextStyle(
                color: FlixieColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        ...members.map((member) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                _avatar(member, 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      member.memberId == _userId ? 'You' : member.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: FlixieColors.textPrimary,
                          fontWeight: FontWeight.w700)),
                ),
                const Icon(Icons.check_circle_rounded,
                    color: FlixieColors.success, size: 24),
              ]),
            )),
        const SizedBox(height: 8),
        _primary(
          'Add to calendar',
          Icons.event_available_rounded,
          date == null
              ? null
              : () => WatchCalendarService.addScheduledWatch(
                    title: request.movieTitle ?? 'Group watch',
                    scheduledFor: date,
                    location: request.location,
                    note: 'With ${_groupName(request)}',
                  ),
        ),
        if (canUpdate) ...[
          const SizedBox(height: 8),
          _outline('Update time', Icons.schedule_rounded,
              () => _propose(request, initialIso: request.scheduledFor)),
        ],
        const SizedBox(height: 16),
        if (request.hasMissedFor(_userId))
          _notice('You didn’t make it. No watch entry was added.')
        else if (request.hasLoggedFor(_userId) ||
            request.hasCurrentUserCompleted == true)
          _notice(
              'Your watch has been logged. Waiting for the rest of the group.')
        else if (request.canCompleteFor(_userId)) ...[
          _outline('Already watched? Log your watch',
              Icons.check_circle_outline, () => _logWatch(request)),
          const SizedBox(height: 6),
          const Text(
              'Went early? Record when you watched, your rating and an optional review.',
              style: _body),
        ],
      ]),
    );
  }

  Widget _scheduleFact(IconData icon, String label) => Row(children: [
        Icon(icon, size: 19, color: FlixieColors.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: _body),
        ),
      ]);

  Widget _scheduledPill() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: FlixieColors.success,
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_rounded,
                color: FlixieColors.background, size: 17),
            SizedBox(width: 6),
            Text('Scheduled',
                style: TextStyle(
                    color: FlixieColors.background,
                    fontSize: 12,
                    fontWeight: FontWeight.w900)),
          ]),
        ),
      );

  Widget _inviteDetail(GroupWatchRequest request, List<GroupMember> members) {
    final selected = _selectedCandidate(request);
    final title =
        selected?.title ?? request.movieTitle ?? _optionLabel(request);
    final multiple =
        request.candidates.length > 1 && request.selectedCandidateId == null;
    final location = request.location?.trim();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!multiple) ...[
            _detailPoster(
                selected?.posterPath ?? request.moviePosterPath, title, 96),
            const SizedBox(width: 14),
          ],
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                title,
                style: const TextStyle(
                    color: FlixieColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              _groupPlanPill(),
              const SizedBox(height: 12),
              _planFact(Icons.calendar_month_outlined, _timing(request)),
              const SizedBox(height: 8),
              _planFact(
                  Icons.location_on_outlined,
                  location?.isNotEmpty == true
                      ? location!
                      : 'Location not set'),
              const SizedBox(height: 8),
              _planFact(Icons.group_outlined, '${members.length} invited'),
            ]),
          ),
        ]),
        if (multiple) ...[
          const SizedBox(height: 20),
          WatchPlanMovieOptions(candidates: request.candidates),
        ],
        _creationMessage(request),
        const Divider(height: 30, color: FlixieColors.tabBarBorder),
        const Text('Group members',
            style: TextStyle(
                color: FlixieColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _memberRoster(members),
        const Divider(height: 30, color: FlixieColors.tabBarBorder),
        _invite(request),
      ]),
    );
  }

  Widget _creationMessage(GroupWatchRequest request) {
    final message = request.message?.trim();
    if (message == null || message.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(
        '“$message”',
        style: const TextStyle(
          color: FlixieColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _planFact(IconData icon, String label) => Row(children: [
        Icon(icon, size: 19, color: FlixieColors.primaryText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              maxLines: 2, overflow: TextOverflow.ellipsis, style: _body),
        ),
      ]);

  Widget _groupPlanPill() => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: FlixieColors.primary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
                color: FlixieColors.primaryText.withValues(alpha: .45)),
          ),
          child: const Text(
            'Group',
            style: TextStyle(
                color: FlixieColors.primaryText,
                fontSize: 12,
                fontWeight: FontWeight.w800),
          ),
        ),
      );

  Widget _detailPoster(String? path, String title, double width) {
    final poster = _poster(path, title, width);
    if (!widget.embedded) return poster;
    return Stack(children: [
      poster,
      Positioned(
        top: 4,
        left: 4,
        child: Material(
          color: FlixieColors.background.withValues(alpha: .86),
          shape: const CircleBorder(),
          child: IconButton(
            tooltip: 'Back to Watch Plans',
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
            onPressed: () => setState(() => _selectedId = null),
            icon: const Icon(Icons.arrow_back_rounded,
                color: FlixieColors.textPrimary, size: 23),
          ),
        ),
      ),
    ]);
  }

  Widget _memberRoster(List<GroupMember> members) {
    if (members.isEmpty) {
      return const Text('Member details unavailable', style: _body);
    }
    return Wrap(
      spacing: 18,
      runSpacing: 12,
      children: members
          .map((member) => SizedBox(
                width: 64,
                child: Column(children: [
                  _avatar(member, 48),
                  const SizedBox(height: 5),
                  Text(
                    member.memberId == _userId ? 'You' : member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: FlixieColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700),
                  ),
                ]),
              ))
          .toList(),
    );
  }

  Widget _hero(GroupWatchRequest request, List<GroupMember> members) {
    final selected = _selectedCandidate(request);
    final title =
        selected?.title ?? request.movieTitle ?? _optionLabel(request);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _detailPoster(
            selected?.posterPath ?? request.moviePosterPath, title, 88),
        const SizedBox(width: 14),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _status(_state(request)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                  color: FlixieColors.textPrimary,
                  fontSize: 25,
                  fontWeight: FontWeight.w900),
            ),
            if (widget.groupId == null) ...[
              const SizedBox(height: 2),
              Text(_groupName(request),
                  style: const TextStyle(
                      color: FlixieColors.primaryText,
                      fontWeight: FontWeight.w700)),
            ],
            const SizedBox(height: 6),
            Text(_timing(request), style: _body),
            if (request.location?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(request.location!, style: _body),
            ],
            const SizedBox(height: 10),
            _avatars(members, 38),
          ]),
        ),
      ]),
    );
  }

  Widget _actionCard(GroupWatchRequest request) =>
      switch (_state(request).stage) {
        _Stage.invite => _invite(request),
        _Stage.picking => _choices(request),
        _Stage.finalMovie => _finalChoice(request),
        _Stage.waitingMovie => _message('Waiting for the final movie',
            'The plan owner will choose from the group’s saved picks.'),
        _Stage.chooseTime => _message('Choose a time',
            'The movie is set. Propose when and where the group should watch.',
            action: 'Propose a time',
            icon: Icons.calendar_month_rounded,
            onTap: () => _propose(request)),
        _Stage.proposal => _proposal(request),
        _Stage.scheduled => _scheduled(request),
        _Stage.postWatch => _postWatch(request),
        _Stage.recap => _recap(request),
        _Stage.closed =>
          _message(request.statusLabel, 'This Watch Plan is no longer active.'),
      };

  Widget _invite(GroupWatchRequest request) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Will you join?', style: _sectionTitle),
        const SizedBox(height: 6),
        const Text(
          'Join to choose films. You’ll approve any proposed time separately.',
          style: _body,
        ),
        const SizedBox(height: 18),
        _primary('I’m in', Icons.check_rounded,
            () => _respond(request, WatchResponseDecision.accepted)),
        const SizedBox(height: 8),
        _outline('Can’t make it', Icons.person_remove_outlined,
            () => _respond(request, WatchResponseDecision.declined)),
        _text('Suggest another time', Icons.edit_calendar_outlined,
            () => _propose(request)),
      ]);

  Widget _choices(GroupWatchRequest request) {
    final choices = _drafts.putIfAbsent(
      request.id,
      () => request.candidates
          .where((item) => item.selectedByUserIds.contains(_userId))
          .map((item) => item.id)
          .toSet(),
    );
    final count = _activeMembers(request).length;
    return _detailSection(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('What could you watch?', style: _sectionTitle),
      const SizedBox(height: 6),
      const Text('Select every title you would happily watch.', style: _body),
      const SizedBox(height: 16),
      ...request.candidates.map((candidate) {
        final selected = choices.contains(candidate.id);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _candidate(
            candidate,
            count,
            selected: selected,
            onTap: () => setState(() => selected
                ? choices.remove(candidate.id)
                : choices.add(candidate.id)),
          ),
        );
      }),
      if (request.candidates.length < 5)
        _text('Add another option', Icons.add_circle_outline_rounded,
            () => _addCandidate(request)),
      const SizedBox(height: 8),
      _primary('Save my picks', Icons.playlist_add_check_rounded,
          () => _saveChoices(request, choices)),
    ]));
  }

  Widget _finalChoice(GroupWatchRequest request) {
    final count = _activeMembers(request).length;
    final candidates = [...request.candidates]..sort((a, b) =>
        b.selectedByUserIds.length.compareTo(a.selectedByUserIds.length));
    return _detailSection(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Choose the final movie', style: _sectionTitle),
      const SizedBox(height: 6),
      const Text('The group’s strongest matches are shown first.',
          style: _body),
      const SizedBox(height: 16),
      ...candidates.map((candidate) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _candidate(candidate, count,
                trailing: FilledButton(
                  onPressed: _processing
                      ? null
                      : () => _chooseMovie(request, candidate.id),
                  child: const Text('Choose'),
                )),
          )),
    ]));
  }

  Widget _proposal(GroupWatchRequest request) {
    final proposal = request.activeScheduleProposal;
    if (proposal != null && request.scheduledFor?.isNotEmpty == true) {
      return _replacementProposal(request, proposal);
    }
    final iso = proposal?.proposedFor ?? request.proposedDate;
    final response = proposal?.responseFor(_userId);
    final proposedByMe = proposal?.proposerId == _userId;
    final approved = response?.status.toUpperCase() == 'ACCEPTED';
    return _detailSection(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Does this time work?', style: _sectionTitle),
      const SizedBox(height: 10),
      Row(children: [
        const Icon(Icons.calendar_month_rounded, color: FlixieColors.secondary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(_format(iso),
              style: const TextStyle(
                  color: FlixieColors.secondary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800)),
        ),
      ]),
      const SizedBox(height: 18),
      if (proposedByMe || approved)
        _notice(proposedByMe
            ? 'Waiting for the group to respond.'
            : 'You approved this time.')
      else
        _primary('Works for me', Icons.check_circle_outline_rounded,
            () => _approveTime(request)),
      const SizedBox(height: 8),
      _outline('Suggest another time', Icons.edit_calendar_outlined,
          () => _propose(request, initialIso: iso)),
      if (!proposedByMe)
        _text('I can’t make it', Icons.person_remove_outlined,
            () => _declineTime(request)),
    ]));
  }

  Widget _replacementProposal(
      GroupWatchRequest request, GroupScheduleProposal proposal) {
    final response = proposal.responseFor(_userId);
    final responseStatus = response?.status.toUpperCase() ?? 'PENDING';
    final isCreator = request.userId == _userId;
    final allAccepted = proposal.responses.isNotEmpty &&
        proposal.responses
            .every((item) => item.status.toUpperCase() == 'ACCEPTED');
    return _detailSection(
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Review time change', style: _sectionTitle),
        const SizedBox(height: 6),
        const Text(
          'Your current schedule stays confirmed until everyone accepts the new time and the plan creator confirms it.',
          style: _body,
        ),
        const SizedBox(height: 16),
        _timeComparison(
          label: 'Current time',
          date: request.scheduledFor,
          location: request.location,
          icon: Icons.event_available_outlined,
        ),
        const SizedBox(height: 8),
        _timeComparison(
          label: 'Requested time',
          date: proposal.proposedFor,
          location: proposal.location ?? request.location,
          icon: Icons.update_rounded,
          highlighted: true,
        ),
        const SizedBox(height: 18),
        if (allAccepted && isCreator) ...[
          _notice('Everyone accepted. You have the final say.'),
          const SizedBox(height: 10),
          _primary('Confirm new time', Icons.check_circle_rounded,
              () => _finalizeReplacement(request, proposal, true)),
          const SizedBox(height: 8),
          _outline('Keep current time', Icons.history_rounded,
              () => _finalizeReplacement(request, proposal, false)),
        ] else if (responseStatus == 'ACCEPTED') ...[
          _notice(isCreator
              ? 'You accepted. Waiting for everyone else before you make the final decision.'
              : 'You accepted the requested time. The current schedule stays in place for now.'),
          if (isCreator) ...[
            const SizedBox(height: 8),
            _outline('Keep current time', Icons.history_rounded,
                () => _finalizeReplacement(request, proposal, false)),
          ],
        ] else ...[
          _primary('Accept new time', Icons.check_circle_outline_rounded,
              () => _approveTime(request)),
          const SizedBox(height: 8),
          _outline('Keep current time', Icons.history_rounded,
              () => _keepCurrentTime(request)),
        ],
        if (!allAccepted) ...[
          const SizedBox(height: 4),
          _text('Suggest a different time', Icons.edit_calendar_outlined,
              () => _propose(request, initialIso: proposal.proposedFor)),
        ],
      ]),
    );
  }

  Widget _timeComparison({
    required String label,
    required String? date,
    required String? location,
    required IconData icon,
    bool highlighted = false,
  }) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: highlighted
              ? FlixieColors.primary.withValues(alpha: .12)
              : FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon,
              size: 21,
              color:
                  highlighted ? FlixieColors.secondary : FlixieColors.medium),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: TextStyle(
                      color: highlighted
                          ? FlixieColors.secondary
                          : FlixieColors.medium,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(_format(date),
                  style: const TextStyle(
                      color: FlixieColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800)),
              if (location?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 2),
                Text(location!, style: _body),
              ],
            ]),
          ),
        ]),
      );

  Widget _scheduled(GroupWatchRequest request) {
    final date = DateTime.tryParse(request.scheduledFor ?? '')?.toLocal();
    return _detailSection(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('You’re all set', style: _sectionTitle),
      const SizedBox(height: 6),
      Text(
          '${request.movieTitle ?? 'Your movie'} is set for ${_format(request.scheduledFor)}.',
          style: _body),
      const SizedBox(height: 18),
      _primary(
        'Add to calendar',
        Icons.event_available_rounded,
        date == null
            ? null
            : () => WatchCalendarService.addScheduledWatch(
                  title: request.movieTitle ?? 'Group watch',
                  scheduledFor: date,
                  location: request.location,
                  note: 'With ${_groupName(request)}',
                ),
      ),
      if (request.userId == _userId || request.canScheduleFor(_userId)) ...[
        const SizedBox(height: 8),
        _outline('Update time', Icons.edit_calendar_outlined,
            () => _propose(request, initialIso: request.scheduledFor)),
      ],
    ]));
  }

  Widget _postWatch(GroupWatchRequest request) => _detailSection(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('How did ${request.movieTitle ?? 'it'} go?',
              style: _sectionTitle),
          const SizedBox(height: 6),
          const Text(
              'Log your viewing, or let the group know you couldn’t make it.',
              style: _body),
          const SizedBox(height: 18),
          if (request.hasMissedFor(_userId))
            _notice('You didn’t make it. No watch entry was added.')
          else if (request.hasCurrentUserCompleted == true ||
              request.hasLoggedFor(_userId))
            _notice('Your watch has been logged.')
          else ...[
            _primary('Log your watch', Icons.check_rounded,
                () => _logWatch(request)),
            const SizedBox(height: 8),
            _outline('I didn’t make it', Icons.event_busy_outlined,
                () => _missed(request)),
          ],
        ]),
      );

  Widget _recap(GroupWatchRequest request) => GroupWatchPlanRecap(
        request: request,
        currentUserId: _userId,
        members: _requestMembers(request),
        onOpenChat: () =>
            context.go('/groups/${widget.groupId ?? request.groupId}?tab=chat'),
      );

  Widget _progress(GroupWatchRequest request, List<GroupMember> members) {
    final proposal = request.activeScheduleProposal;
    final stage = _state(request).stage;
    final isScheduleResponse =
        stage == _Stage.proposal || stage == _Stage.scheduled;
    return _detailSection(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
          child: Text(isScheduleResponse ? 'Group responses' : 'Group progress',
              style: _sectionTitle),
        ),
        if (!isScheduleResponse)
          Text('${members.length} ${members.length == 1 ? 'person' : 'people'}',
              style: const TextStyle(
                  color: FlixieColors.medium, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 14),
      ...members.map((member) {
        final planResponse = request.memberStatuses
            .where((item) => item.memberId == member.memberId)
            .firstOrNull;
        final timeResponse = proposal?.responseFor(member.memberId);
        final progress =
            _progressLabel(request, member, planResponse, timeResponse);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            _avatar(member, 42),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                  member.memberId == _userId ? 'You' : member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: FlixieColors.textPrimary,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 8),
            Text(progress.$1,
                maxLines: 1,
                textAlign: TextAlign.end,
                style: TextStyle(
                    color: progress.$2,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Icon(progress.$3, color: progress.$2, size: 22),
          ]),
        );
      }),
    ]));
  }

  Future<void> _respond(
      GroupWatchRequest request, WatchResponseDecision decision) async {
    await _run(() async {
      final conversationId = request.conversationId;
      if (conversationId != null && conversationId.isNotEmpty) {
        await GroupService.respondToWatchRequest(
            conversationId, request.id, _userId, decision);
      } else {
        await GroupService.updateWatchRequestForMember(
            _requestId(request), _userId, '', decision.apiValue);
      }
      await _load();
    },
        success: decision == WatchResponseDecision.accepted
            ? 'You joined the Watch Plan.'
            : 'You left this screening.');
  }

  Future<void> _saveChoices(
      GroupWatchRequest request, Set<String> choices) async {
    if (choices.isEmpty) {
      _showError('Choose at least one movie you would watch.');
      return;
    }
    await _run(() async {
      await GroupService.saveWatchPlanChoices(
          _requestId(request), _userId, choices.toList());
      _drafts.remove(request.id);
      await _load();
    }, success: 'Your movie picks are saved.');
  }

  Future<void> _addCandidate(GroupWatchRequest request) async {
    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: FlixieColors.surface,
      builder: (_) => MovieSearchSheet(
        title: 'Add a movie option',
        searchMovies: (query) async {
          final result = await SearchService.search(query, type: 'movie');
          final existing =
              request.candidates.map((item) => item.movieId).toSet();
          return result.results
              .map((item) => item.movie)
              .whereType<MovieShort>()
              .where((item) => !existing.contains(item.id))
              .toList(growable: false);
        },
      ),
    );
    if (!mounted || movie == null) return;
    await _run(() async {
      final updated = await GroupService.addWatchPlanCandidate(
          _requestId(request), _userId, movie.id);
      final newOptions = updated.candidates.where((candidate) =>
          candidate.movieId == movie.id &&
          candidate.addedByUserId == _userId &&
          candidate.selectedByUserIds.contains(_userId));
      final draft = _drafts.putIfAbsent(
        request.id,
        () => request.candidates
            .where((candidate) => candidate.selectedByUserIds.contains(_userId))
            .map((candidate) => candidate.id)
            .toSet(),
      );
      draft.addAll(newOptions.map((candidate) => candidate.id));
      await _load();
    }, success: '${movie.name} was added.');
  }

  Future<void> _chooseMovie(GroupWatchRequest request, String id) async {
    await _run(() async {
      await GroupService.selectWatchPlanMovie(_requestId(request), _userId, id);
      await _load();
    }, success: 'The final movie is set.');
  }

  Future<void> _propose(GroupWatchRequest request, {String? initialIso}) async {
    final result = await showModalBottomSheet<
        ({DateTime proposedFor, String? message, String? location})>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WatchPlanScheduleSheet(
        initial: DateTime.tryParse(initialIso ?? '')?.toLocal(),
        initialLocation: request.location,
        showLocation: true,
      ),
    );
    if (!mounted || result == null) return;
    await _run(() async {
      await GroupService.proposeWatchPlanSchedule(
        _requestId(request),
        _userId,
        proposedFor: result.proposedFor.toUtc().toIso8601String(),
        location: result.location,
      );
      await _load();
    }, success: 'The new time was sent to the group.');
  }

  Future<void> _approveTime(GroupWatchRequest request) async {
    final proposal = request.activeScheduleProposal;
    final iso = proposal?.proposedFor ?? request.proposedDate;
    final time = DateTime.tryParse(iso ?? '')?.toLocal();
    if (time == null || !time.isAfter(DateTime.now())) {
      _showError('That proposed time has passed. Suggest a new time.');
      return;
    }
    await _run(() async {
      if (proposal == null) {
        await GroupService.acceptInitialWatchPlanSchedule(
            _requestId(request), _userId);
      } else {
        await GroupService.respondToWatchPlanSchedule(
            _requestId(request), proposal.id, _userId, 'accepted');
      }
      await _load();
    }, success: 'You approved ${_format(iso)}.');
  }

  Future<void> _declineTime(GroupWatchRequest request) async {
    if (request.activeScheduleProposal != null &&
        request.scheduledFor?.isNotEmpty == true) {
      await _keepCurrentTime(request);
      return;
    }
    await _respond(request, WatchResponseDecision.declined);
  }

  Future<void> _keepCurrentTime(GroupWatchRequest request) async {
    final proposal = request.activeScheduleProposal;
    if (proposal == null) return;
    if (request.userId == _userId) {
      await _finalizeReplacement(request, proposal, false);
      return;
    }
    await _run(() async {
      await GroupService.respondToWatchPlanSchedule(
          _requestId(request), proposal.id, _userId, 'declined');
      await _load();
    }, success: 'The current time stays confirmed.');
  }

  Future<void> _finalizeReplacement(GroupWatchRequest request,
      GroupScheduleProposal proposal, bool acceptNew) async {
    await _run(() async {
      await GroupService.finalizeWatchPlanSchedule(
        _requestId(request),
        proposal.id,
        _userId,
        acceptNew ? 'accept_new' : 'keep_current',
      );
      await _load();
    },
        success: acceptNew
            ? 'The new time is confirmed.'
            : 'The current time stays confirmed.');
  }

  Future<void> _logWatch(GroupWatchRequest request) async {
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewatchLogSheet(
        showReviewOption: false,
        onSubmit: ({
          required watchedAt,
          required rating,
          required recommended,
          required notes,
        }) async {
          await GroupService.logGroupWatchPlan(
            request,
            _userId,
            watchedAt: watchedAt,
            rating: rating?.round(),
            recommended: recommended,
            reviewText: notes,
          );
          await _load();
        },
      ),
    );
  }

  Future<void> _missed(GroupWatchRequest request) async {
    await _run(() async {
      await GroupService.logGroupWatchPlan(request, _userId, watched: false);
      await _load();
    }, success: 'Marked as missed. No watch entry, rating, or review added.');
  }

  Future<void> _run(Future<void> Function() action, {String? success}) async {
    if (_processing) return;
    setState(() => _processing = true);
    try {
      await action();
      TabRefreshController.requestSocialRefresh();
      TabRefreshController.requestHomeRefresh();
      if (mounted && success != null) _showSuccess(success);
    } catch (error) {
      if (mounted) _showError(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  _PlanState _state(GroupWatchRequest request) {
    if (request.isArchived) {
      return request.status == WatchRequestStatus.completed
          ? const _PlanState(_Stage.recap, 'Watched', FlixieColors.success,
              Icons.check_circle_rounded)
          : _PlanState(_Stage.closed, request.statusLabel, FlixieColors.medium,
              Icons.block_rounded);
    }
    if (request.selectedCandidateId != null &&
        request.activeScheduleProposal != null) {
      return const _PlanState(_Stage.proposal, 'Time proposal',
          FlixieColors.secondary, Icons.schedule_rounded);
    }
    final scheduled = DateTime.tryParse(request.scheduledFor ?? '')?.toLocal();
    if (scheduled != null) {
      return scheduled.isAfter(DateTime.now())
          ? const _PlanState(_Stage.scheduled, 'Scheduled',
              FlixieColors.success, Icons.event_available_rounded)
          : const _PlanState(_Stage.postWatch, 'Ready to log',
              FlixieColors.warning, Icons.rate_review_outlined);
    }
    if (!_accepted(request) && request.userId != _userId) {
      return const _PlanState(_Stage.invite, 'Needs a reply',
          FlixieColors.warning, Icons.mark_email_unread_outlined);
    }
    if (request.selectedCandidateId == null && request.candidates.isNotEmpty) {
      if (request.userId == _userId && _everyonePicked(request)) {
        return const _PlanState(_Stage.finalMovie, 'Choose final movie',
            FlixieColors.primaryText, Icons.movie_filter_rounded);
      }
      return const _PlanState(_Stage.picking, 'Picking movies',
          FlixieColors.primaryText, Icons.how_to_vote_outlined);
    }
    if (request.selectedCandidateId != null &&
        request.proposedDate?.isNotEmpty == true) {
      return const _PlanState(_Stage.proposal, 'Time proposal',
          FlixieColors.secondary, Icons.schedule_rounded);
    }
    if (request.selectedCandidateId != null && request.userId == _userId) {
      return const _PlanState(_Stage.chooseTime, 'Choose a time',
          FlixieColors.secondary, Icons.calendar_month_rounded);
    }
    return const _PlanState(_Stage.waitingMovie, 'Waiting for creator',
        FlixieColors.medium, Icons.hourglass_top_rounded);
  }

  bool _accepted(GroupWatchRequest request) =>
      request.userId == _userId ||
      request.hasCurrentUserAccepted == true ||
      request.currentUserResponse == WatchResponseDecision.accepted ||
      request.memberStatuses
          .any((item) => item.memberId == _userId && item.status == 'ACCEPTED');

  bool _everyonePicked(GroupWatchRequest request) {
    final active = _activeMembers(request).map((item) => item.memberId).toSet();
    final voters = request.candidates
        .expand((candidate) => candidate.selectedByUserIds)
        .toSet();
    return active.isNotEmpty && voters.containsAll(active);
  }

  List<GroupMember> _activeMembers(GroupWatchRequest request) {
    final declined = request.memberStatuses
        .where((item) => item.status == 'DECLINED')
        .map((item) => item.memberId)
        .toSet();
    return _requestMembers(request)
        .where((member) => !declined.contains(member.memberId))
        .toList(growable: false);
  }

  List<GroupMember> _requestMembers(GroupWatchRequest request) =>
      _membersByRequest[request.id] ??
      _membersByRequest[request.databaseRequestId] ??
      _members;

  GroupWatchPlanCandidate? _selectedCandidate(GroupWatchRequest request) =>
      request.candidates
          .where((item) => item.id == request.selectedCandidateId)
          .firstOrNull;

  (String, Color, IconData) _progressLabel(
    GroupWatchRequest request,
    GroupMember member,
    GroupRequestMemberStatus? response,
    GroupScheduleProposalResponse? timeResponse,
  ) {
    final stage = _state(request).stage;
    if (stage == _Stage.scheduled) {
      return ('Confirmed', FlixieColors.success, Icons.check_circle_rounded);
    }
    if (stage == _Stage.proposal) {
      return switch (timeResponse?.status.toUpperCase()) {
        'ACCEPTED' => (
            'Accepted',
            FlixieColors.success,
            Icons.check_circle_rounded
          ),
        'DECLINED' => (
            'Can’t make it',
            FlixieColors.warning,
            Icons.cancel_outlined
          ),
        _ => ('Pending', FlixieColors.warning, Icons.schedule_rounded),
      };
    }
    if (response?.missedAt != null) {
      return ('Didn’t make it', FlixieColors.medium, Icons.event_busy_outlined);
    }
    if (response?.watchedAt != null) {
      return ('Watched', FlixieColors.success, Icons.check_circle_rounded);
    }
    if (stage == _Stage.postWatch) {
      return ('Still to respond', FlixieColors.medium, Icons.schedule_rounded);
    }
    if (timeResponse != null) {
      return switch (timeResponse.status.toUpperCase()) {
        'ACCEPTED' => (
            'Time approved',
            FlixieColors.success,
            Icons.check_circle_rounded
          ),
        'DECLINED' => (
            'Needs another time',
            FlixieColors.warning,
            Icons.edit_calendar_outlined
          ),
        _ => ('Time pending', FlixieColors.medium, Icons.schedule_rounded),
      };
    }
    if (member.memberId == request.userId) {
      return ('Plan owner', FlixieColors.success, Icons.check_circle_rounded);
    }
    return switch (response?.status) {
      'ACCEPTED' => (
          'Joined',
          FlixieColors.success,
          Icons.check_circle_rounded
        ),
      'DECLINED' => (
          'Not attending',
          FlixieColors.medium,
          Icons.cancel_outlined
        ),
      'MAYBE' => ('Maybe', FlixieColors.warning, Icons.help_outline_rounded),
      _ => ('Pending', FlixieColors.medium, Icons.schedule_rounded),
    };
  }

  Widget _candidate(GroupWatchPlanCandidate candidate, int participantCount,
      {bool selected = false, VoidCallback? onTap, Widget? trailing}) {
    final approvals = candidate.selectedByUserIds.toSet().length;
    final unanimous = participantCount > 0 && approvals >= participantCount;
    return Material(
      color: unanimous
          ? FlixieColors.success.withValues(alpha: .08)
          : FlixieColors.background.withValues(alpha: .35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: unanimous
              ? FlixieColors.success
              : selected
                  ? FlixieColors.primary
                  : FlixieColors.tabBarBorder,
          width: unanimous || selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(children: [
            _poster(candidate.posterPath, candidate.title, 48),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(candidate.title ?? 'Movie option',
                        style: const TextStyle(
                            color: FlixieColors.textPrimary,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      unanimous
                          ? 'Everyone’s match'
                          : '$approvals of $participantCount would watch',
                      style: TextStyle(
                          color: unanimous
                              ? FlixieColors.success
                              : FlixieColors.medium,
                          fontSize: 12,
                          fontWeight: FontWeight.w700),
                    ),
                  ]),
            ),
            if (trailing != null)
              trailing
            else
              Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected ? FlixieColors.success : FlixieColors.medium),
          ]),
        ),
      ),
    );
  }

  Widget _avatars(List<GroupMember> members, double size) {
    if (members.isEmpty) {
      return const Text('Member details unavailable', style: _body);
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: members.map((member) => _avatar(member, size)).toList(),
    );
  }

  Widget _avatar(GroupMember member, double size) {
    const framed = {
      'FOUNDER',
      'OG_USER',
      'VERIFIED',
      'EARLY_ADOPTER',
      'FOUNDING_FILM_FRIEND',
    };
    final hasFrame = member.profileBadges.any(framed.contains);
    final name = member.displayName.trim();
    final avatar = ProfileAvatarView(
      avatar: member.avatar,
      fallbackText: name.isEmpty ? '?' : name[0].toUpperCase(),
      fallbackColor: FlixieColors.primary,
      size: size - (hasFrame ? 8 : 10),
      profileBadges: member.profileBadges,
    );
    return Semantics(
      image: true,
      label: member.memberId == _userId ? 'You' : member.displayName,
      child: SizedBox.square(
        dimension: size,
        child: hasFrame
            ? Center(child: avatar)
            : DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: member.isOwner
                        ? FlixieColors.warning
                        : FlixieColors.primary,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Center(child: avatar),
                ),
              ),
      ),
    );
  }

  Widget _poster(String? path, String? title, double width) =>
      WatchPlanPoster(path: path, title: title, width: width);

  Widget _surface(Widget child, {Color? border}) =>
      WatchPlanSurface(border: border, child: child);

  Widget _detailSection(Widget child) => SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: child,
        ),
      );

  Widget _message(String title, String body,
          {String? action, IconData? icon, FutureOr<void> Function()? onTap}) =>
      _detailSection(
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: _sectionTitle),
        const SizedBox(height: 6),
        Text(body, style: _body),
        if (action != null && icon != null && onTap != null) ...[
          const SizedBox(height: 18),
          _primary(action, icon, onTap),
        ],
      ]));

  Widget _empty(String title, String body,
          {String? action, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 72, horizontal: 24),
        child: Column(children: [
          const Icon(Icons.movie_filter_outlined,
              color: FlixieColors.primaryText, size: 38),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: _sectionTitle),
          const SizedBox(height: 7),
          Text(body, textAlign: TextAlign.center, style: _body),
          if (action != null && onTap != null) ...[
            const SizedBox(height: 20),
            FilledButton(onPressed: onTap, child: Text(action)),
          ],
        ]),
      );

  Widget _notice(String text) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: FlixieColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          const Icon(Icons.schedule_rounded,
              color: FlixieColors.medium, size: 20),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: _body)),
        ]),
      );

  Widget _status(_PlanState state) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(state.icon, color: state.color, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(state.label.toUpperCase(),
              style: TextStyle(
                  color: state.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7)),
        ),
      ]);

  Widget _primary(
          String label, IconData icon, FutureOr<void> Function()? onTap) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _processing || onTap == null ? null : () => onTap(),
          icon: _processing
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Icon(icon),
          label: Text(label),
        ),
      );

  Widget _outline(
          String label, IconData icon, FutureOr<void> Function() onTap) =>
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _processing ? null : () => onTap(),
          icon: Icon(icon),
          label: Text(label),
        ),
      );

  Widget _text(String label, IconData icon, FutureOr<void> Function() onTap) =>
      SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: _processing ? null : () => onTap(),
          icon: Icon(icon),
          label: Text(label),
        ),
      );

  String _optionLabel(GroupWatchRequest request) => request.candidates.isEmpty
      ? 'Group Watch Plan'
      : '${request.candidates.length} movie ${request.candidates.length == 1 ? 'option' : 'options'}';

  String _timing(GroupWatchRequest request) {
    final iso = request.scheduledFor ??
        request.activeScheduleProposal?.proposedFor ??
        request.proposedDate;
    return iso == null || iso.isEmpty ? 'Time not set' : _format(iso);
  }

  String _replyLabel(GroupWatchRequest request) {
    final members = _requestMembers(request);
    if (members.isEmpty) return '${request.responseCount} replied';
    final repliedIds = request.memberStatuses
        .where((item) =>
            item.status == 'ACCEPTED' ||
            item.status == 'DECLINED' ||
            item.status == 'MAYBE')
        .map((item) => item.memberId)
        .toSet()
      ..add(request.userId);
    final replied =
        members.where((member) => repliedIds.contains(member.memberId)).length;
    return '$replied of ${members.length} replied';
  }

  String _format(String? iso) {
    final date = DateTime.tryParse(iso ?? '')?.toLocal();
    if (date == null) return 'Time not set';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${date.day} ${months[date.month - 1]}, ${TimeOfDay.fromDateTime(date).format(context)}';
  }

  DateTime _date(GroupWatchRequest request) =>
      DateTime.tryParse(request.scheduledFor ??
          request.proposedDate ??
          request.updatedAt ??
          request.createdAt ??
          '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String _requestId(GroupWatchRequest request) =>
      request.databaseRequestId ?? request.id;

  String _groupName(GroupWatchRequest request) =>
      _groupNamesByRequest[request.id] ??
      _groupNamesByRequest[request.databaseRequestId] ??
      widget.groupName ??
      'your group';

  String _friendlyError(Object error) {
    final value = error.toString().replaceFirst('Exception: ', '').trim();
    return value.isEmpty ? 'That action couldn’t be completed.' : value;
  }

  void _showError(String message) =>
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: Text(message),
            backgroundColor: FlixieColors.danger),
      );

  void _showSuccess(String message) =>
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        backgroundColor: FlixieColors.surfaceElevated,
        content: Text(message),
      ));
}

class _LoadedGroup {
  const _LoadedGroup({
    required this.name,
    required this.requests,
    required this.members,
  });

  final String name;
  final List<GroupWatchRequest> requests;
  final List<GroupMember> members;
}

enum _Stage {
  invite,
  picking,
  finalMovie,
  waitingMovie,
  chooseTime,
  proposal,
  scheduled,
  postWatch,
  recap,
  closed,
}

class _PlanState {
  const _PlanState(this.stage, this.label, this.color, this.icon);

  final _Stage stage;
  final String label;
  final Color color;
  final IconData icon;
}

const _sectionTitle = TextStyle(
  color: FlixieColors.textPrimary,
  fontSize: 22,
  fontWeight: FontWeight.w900,
);

const _body = TextStyle(
  color: FlixieColors.light,
  height: 1.35,
);
