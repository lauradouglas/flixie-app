import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import '../../data/group_watch_plan_service.dart';
import '../controllers/group_watch_plan_controller.dart';
import '../group_watch_plan_actions.dart';
import '../widgets/shared/watch_plan_components.dart';
import '../widgets/group_plan/group_plan_components.dart';
import '../widgets/group_plan/group_plan_detail.dart';
import '../widgets/group_plan/group_plan_list.dart';

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
    this.onBackdropChanged,
    this.onActiveCountChanged,
    this.service = const GroupWatchPlanService(),
  });

  final GroupWatchPlanService service;
  final String? groupId;
  final String? groupName;
  final String? initialRequestId;
  final bool embedded;
  final ValueChanged<int>? onCountChanged;
  final ValueChanged<String?>? onBackdropChanged;
  final ValueChanged<int>? onActiveCountChanged;

  @override
  State<GroupWatchPlanV2Screen> createState() => _GroupWatchPlanV2ScreenState();
}

class _GroupWatchPlanV2ScreenState extends State<GroupWatchPlanV2Screen> {
  late final GroupWatchPlanController _controller;
  String? _publishedBackdrop;
  int? _publishedActive, _publishedResponses;
  GroupWatchPlanActions get _actions =>
      GroupWatchPlanActions(context, _controller, groupId: widget.groupId);

  @override
  void initState() {
    super.initState();
    _controller = GroupWatchPlanController(service: widget.service);
    TabRefreshController.social.addListener(_socialRefresh);
    TabRefreshController.watchPlans.addListener(_controller.requestRefresh);
  }

  void _socialRefresh() {
    if (!_controller.processing) _controller.requestRefresh();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bind(Provider.of<AuthProvider>(context).dbUser?.id ?? '');
  }

  void _bind(String userId) => _controller.bind(
        userId: userId,
        groupId: widget.groupId,
        groupName: widget.groupName,
        initialId: widget.initialRequestId,
      );
  @override
  void didUpdateWidget(covariant GroupWatchPlanV2Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bind(context.read<AuthProvider>().dbUser?.id ?? '');
  }

  @override
  void dispose() {
    TabRefreshController.social.removeListener(_socialRefresh);
    TabRefreshController.watchPlans.removeListener(_controller.requestRefresh);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final request = _controller.selected;
    final active = _controller.activeCount,
        responses = _controller.responseCount;
    if (_publishedActive != active || _publishedResponses != responses) {
      _publishedActive = active;
      _publishedResponses = responses;
      final epoch = _controller.epoch;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_controller.isCurrent(epoch)) return;
        if (_publishedActive == active) {
          widget.onActiveCountChanged?.call(active);
        }
        if (_publishedResponses == responses) {
          widget.onCountChanged?.call(responses);
        }
      });
    }
    final backdrop = request?.selectedBackdropPath;
    if (_publishedBackdrop != backdrop) {
      _publishedBackdrop = backdrop;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _publishedBackdrop == backdrop) {
          widget.onBackdropChanged?.call(backdrop);
        }
      });
    }
    return PopScope(
      canPop: request == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && request != null) _controller.select(null);
      },
      child: widget.embedded
          ? (widget.onBackdropChanged == null && backdrop != null
              ? Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 420,
                      child: WatchPlanBackdrop(path: backdrop),
                    ),
                    _screenBody(request),
                  ],
                )
              : _screenBody(request))
          : Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: context.colors.background),
                ),
                if (backdrop != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 520 + MediaQuery.paddingOf(context).top,
                    child: WatchPlanBackdrop(path: backdrop),
                  ),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    backgroundColor: backdrop == null
                        ? context.colors.background
                        : Colors.transparent,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    scrolledUnderElevation: 0,
                    foregroundColor: context.colors.textPrimary,
                    leading: request == null
                        ? const FlixieBackButton()
                        : IconButton(
                            tooltip: 'Back to Watch Plans',
                            onPressed: () => _controller.select(null),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                    title: Text(
                      request == null
                          ? widget.groupId == null
                              ? 'Group Watch Plans'
                              : widget.groupName ?? 'Group Watch Plans'
                          : request.movieTitle ?? 'Group Watch Plan',
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed:
                            _controller.processing ? null : _controller.load,
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  floatingActionButton: request == null
                      ? FloatingActionButton(
                          tooltip: 'Make a Watch Plan',
                          onPressed:
                              _controller.processing ? null : _actions.create,
                          child: const Icon(Icons.add_rounded),
                        )
                      : null,
                  body: _screenBody(request),
                ),
              ],
            ),
    );
  }

  Widget _screenBody(GroupWatchRequest? request) => FlixieRefresh(
        color: FlixieColors.primary,
        onRefresh: _controller.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            if (_controller.loading && _controller.requests.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_controller.error != null && _controller.requests.isEmpty)
              groupPlanEmpty(
                context,
                'Watch Plans unavailable',
                _controller.error!,
                action: 'Try again',
                onTap: _controller.load,
              )
            else if (request == null)
              GroupPlanList(
                controller: _controller,
                actions: _actions,
                embedded: widget.embedded,
              )
            else
              GroupPlanDetail(
                view: _controller.view(request),
                actions: _actions,
                embedded: widget.embedded,
                groupId: widget.groupId,
                onBack: () => _controller.select(null),
              ),
          ],
        ),
      );
}
