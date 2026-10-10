import 'dart:async';
import '../widgets/watch_requests/watch_requests_list.dart';
import 'package:flixie_app/features/social/data/watch_request_cache.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/watch_request.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/features/watch_plans/presentation/pages/group_watch_plan_v2_screen.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_display_state.dart';
import 'package:flixie_app/features/watch_plans/presentation/utils/watch_plan_formatters.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_watch_plan_flow.dart';

import '../controllers/watch_requests_controller.dart';
import '../watch_requests/watch_request_actions.dart';
import '../watch_requests/watch_request_schedule_flow.dart';
import '../watch_requests/watch_request_completion_flow.dart';
import '../watch_requests/watch_request_choice_flow.dart';
import '../widgets/watch_requests/watch_request_controls.dart';
export 'watch_request_detail_screen.dart' show WatchRequestDetailScreen;

class WatchRequestsScreen extends StatelessWidget {
  const WatchRequestsScreen({super.key, this.initialRequestId});
  final String? initialRequestId;
  @override
  Widget build(BuildContext context) {
    final viewer =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    return _WatchRequestsPage(
        key: ValueKey((viewer, initialRequestId)),
        initialRequestId: initialRequestId);
  }
}

class _WatchRequestsPage extends StatefulWidget {
  const _WatchRequestsPage({super.key, this.initialRequestId});
  final String? initialRequestId;
  @override
  State<_WatchRequestsPage> createState() => _WatchRequestsPageState();
}

class _WatchRequestsPageState extends State<_WatchRequestsPage>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();
  late final WatchRequestsController _controller;
  var _audience = WatchRequestAudience.friends;
  bool _refreshQueued = false;
  WatchRequestActions get _actions => WatchRequestActions(
      context: context,
      controller: _controller,
      groupMode: _audience == WatchRequestAudience.groups,
      onGroupCreated: () {
        if (mounted) setState(() => _audience = WatchRequestAudience.groups);
      });
  WatchRequestScheduleFlow get _schedule => WatchRequestScheduleFlow(
      context: context, controller: _controller, actions: _actions);
  WatchRequestCompletionFlow get _completion =>
      WatchRequestCompletionFlow(context: context, controller: _controller);
  WatchRequestChoiceFlow get _choices =>
      WatchRequestChoiceFlow(context: context, controller: _controller);
  @override
  void initState() {
    super.initState();
    _controller = WatchRequestsController(
        auth: context.read<AuthProvider>(),
        focusedId: widget.initialRequestId,
        cache: context.read<WatchRequestCache?>());
    _controller.addListener(_changed);
    _searchController.addListener(_searchChanged);
    WidgetsBinding.instance.addObserver(this);
    TabRefreshController.social.addListener(_refreshCurrentPlan);
    TabRefreshController.watchPlans.addListener(_refreshCurrentPlan);
    _controller.start();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _searchChanged() => _controller.setQuery(_searchController.text);
  void _refreshCurrentPlan() {
    if (!mounted || _refreshQueued) return;
    _refreshQueued = true;
    scheduleMicrotask(() {
      _refreshQueued = false;
      if (mounted && _controller.owns) _controller.load();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshCurrentPlan();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    TabRefreshController.social.removeListener(_refreshCurrentPlan);
    TabRefreshController.watchPlans.removeListener(_refreshCurrentPlan);
    _searchController.dispose();
    _controller.removeListener(_changed);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _controller.filtered;
    final isFocused = widget.initialRequestId?.isNotEmpty == true;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;
    final canDeleteFocusedPlan = isFocused &&
        !_controller.loading &&
        filtered.isNotEmpty &&
        filtered.first.requesterId == currentUserId;
    final focusedCompanion = isFocused && filtered.isNotEmpty
        ? (filtered.first.groupName?.trim().isNotEmpty == true
            ? filtered.first.groupName!
            : filtered.first.otherUser(currentUserId ?? '')?.username ??
                'Watch together')
        : null;
    final directBody = WatchRequestsList(
        controller: _controller,
        isFocused: isFocused,
        searchController: _searchController,
        buildCard: _buildRequestCard);
    final body = isFocused
        ? directBody
        : Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                child: WatchRequestAudienceSwitcher(
                  selected: _audience,
                  friendActiveCount: _controller.count(WatchPlanFilter.active),
                  groupActiveCount: _controller.groupActiveCount,
                  onChanged: (value) => setState(() => _audience = value),
                ),
              ),
              if (_audience == WatchRequestAudience.friends)
                _buildFriendFilters(),
              if (_audience == WatchRequestAudience.friends && !isFocused)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _actions.startNewWatchPlan,
                      icon: const Icon(Icons.add),
                      label: const Text('Make a Watch Plan'),
                      style: FilledButton.styleFrom(
                        backgroundColor: FlixieColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _audience == WatchRequestAudience.friends
                    ? directBody
                    : _controller.loadingGroups
                        ? const Center(child: CircularProgressIndicator())
                        : GroupWatchPlanV2Screen(
                            embedded: true,
                            onActiveCountChanged: (count) {
                              if (mounted &&
                                  count != _controller.groupActiveCount) {
                                _controller.setGroupActiveCount(count);
                              }
                            },
                          ),
              ),
            ],
          );
    final backdropBehindHeader = isFocused &&
        !_controller.loading &&
        _controller.error == null &&
        filtered.isNotEmpty &&
        filtered.first.hasSelectedTitle;
    final screen = FlixiePageScaffold(
      extendBodyBehindAppBar: backdropBehindHeader,
      appBar: FlixieTitleAppBar(
        leading: isFocused ? const FlixieBackButton() : null,
        backgroundColor: backdropBehindHeader
            ? Colors.transparent
            : context.colors.background,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isFocused ? 'Watch Plan' : 'Watch Plans',
                style: TextStyle(
                    color: context.colors.white,
                    fontSize: isFocused ? 20 : 22,
                    fontWeight: FontWeight.bold)),
            if (isFocused && focusedCompanion != null)
              Text('With $focusedCompanion',
                  style: TextStyle(color: context.colors.medium, fontSize: 12))
            else if (!_controller.loading && _controller.error == null)
              Text(
                  _audience == WatchRequestAudience.friends
                      ? '${_controller.requests.length} plans'
                      : 'Across ${_controller.groups.length} groups',
                  style: TextStyle(color: context.colors.medium, fontSize: 12)),
          ],
        ),
        actions: canDeleteFocusedPlan
            ? [
                PopupMenuButton<String>(
                  tooltip: 'Watch Plan options',
                  enabled: !_controller.busy(filtered.first.id),
                  icon: _controller.busy(filtered.first.id)
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.more_vert_rounded),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _actions.confirmDelete(filtered.first);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            color: context.colors.danger),
                        const SizedBox(width: 10),
                        Text('Delete watch plan',
                            style: TextStyle(color: context.colors.danger)),
                      ]),
                    ),
                  ],
                ),
              ]
            : isFocused
                ? null
                : [
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: IconButton(
                        tooltip: 'New Watch Plan',
                        onPressed: _actions.startNewWatchPlan,
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 30,
                          color: FlixieColors.primary,
                        ),
                      ),
                    ),
                  ],
        bottom: null,
      ),
      // Watch Plan actions deliberately share one shape.  Keeping this at the
      // screen boundary also carries into bottom sheets opened from here.
      body: Theme(
        data: Theme.of(context).copyWith(
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        child: body,
      ),
    );
    // Preserve the device text scale; this surface uses flexible and
    // scrollable layouts rather than overriding accessibility preferences.
    return isFocused
        ? MediaQuery(
            data: MediaQuery.of(context),
            child: screen,
          )
        : screen;
  }

  Widget _buildFriendFilters() {
    const filters = [WatchPlanFilter.active, WatchPlanFilter.completed];
    return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Wrap(spacing: 8, runSpacing: 8, children: [
          for (final filter in filters)
            FlixiePill.choice(
              label: Text(filter == WatchPlanFilter.active
                  ? 'Active · ${_controller.count(WatchPlanFilter.active)}'
                  : 'Past · ${_controller.count(WatchPlanFilter.completed)}'),
              selected: _controller.filter == filter,
              onSelected: (_) => _controller.setFilter(
                  _controller.filter == filter
                      ? WatchPlanFilter.active
                      : filter),
            ),
        ]));
  }

  Widget _buildRequestCard(
    WatchRequest request,
    bool isFocused,
    String myUserId,
  ) {
    return FriendWatchPlanFlow(
      request: request,
      compact: !isFocused,
      headerTopInset:
          isFocused ? MediaQuery.paddingOf(context).top + kToolbarHeight : 0,
      myUserId: myUserId,
      myAvatar: context.read<AuthProvider>().dbUser?.avatar,
      myProfileBadges:
          context.read<AuthProvider>().dbUser?.profileBadges ?? const [],
      scheduledLabel: formatWatchPlanDateTime(request.scheduledFor,
          dateOnly: request.scheduledDateOnly),
      busy: _controller.busy(request.id),
      onAccept: () => _actions.respond(request, 'ACCEPTED'),
      onDecline: () => _actions.respond(request, 'DECLINED'),
      onOpen: () => context.push('/watch-requests/${request.id}'),
      onSuggestSchedule: () =>
          _schedule.suggestSchedule(request, initial: request.scheduledFor),
      onRespondToProposal: (proposal, decision) =>
          _schedule.respondToProposal(request, proposal, decision),
      onConfirmWatched: () => _completion.confirmWatched(request),
      onClosePlan: () => _actions.closeWatchPlan(request),
      onNewPlan: () => _actions.startNewWatchPlan(
          initialFriendId: request.otherUser(myUserId)?.id),
      onCancelPlan: () => _actions.cancelPlan(request),
      candidateChoiceDraft: _controller.draft(request, myUserId),
      onToggleCandidateChoice: (id) =>
          _controller.toggle(request, myUserId, id),
      onSaveCandidateChoices: () =>
          _choices.saveCandidateChoices(request, myUserId),
      onAddCandidate: () => _choices.addCandidate(request, myUserId),
      onRemoveCandidate: (id) =>
          _choices.removeCandidate(request, myUserId, id),
      onSelectCandidate: (id) => _choices.selectFinalCandidate(request, id),
      onChangeMovie: () => _choices.reopenMovieChoices(request, myUserId),
      onNotThisTime: () => _actions.markNotThisTime(request),
    );
  }
}
