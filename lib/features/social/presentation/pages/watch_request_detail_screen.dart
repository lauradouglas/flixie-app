import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';

import 'watch_requests_screen.dart';

/// Dedicated full-page view for one Watch Plan.
class WatchRequestDetailScreen extends StatelessWidget {
  const WatchRequestDetailScreen({super.key, required this.requestId});
  final String requestId;
  @override
  Widget build(BuildContext context) {
    final viewer =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    return _WatchRequestDetailPage(
        key: ValueKey((viewer, requestId)), requestId: requestId);
  }
}

class _WatchRequestDetailPage extends StatefulWidget {
  const _WatchRequestDetailPage({super.key, required this.requestId});
  final String requestId;
  @override
  State<_WatchRequestDetailPage> createState() =>
      _WatchRequestDetailScreenState();
}

class _WatchRequestDetailScreenState extends State<_WatchRequestDetailPage> {
  String? _viewer;
  int _generation = 0;
  var _resolvingGroupPlan = true;

  @override
  void initState() {
    super.initState();
    _resolveGroupPlan();
  }

  /// Some older notification payloads identify a group plan only by request
  /// ID. Resolve those before falling back to the direct-plan screen, so a
  /// tap never strands someone on an empty Watch Plans page.
  Future<void> _resolveGroupPlan() async {
    try {
      final generation = ++_generation;
      final requestId = widget.requestId;
      final auth = context.read<AuthProvider>();
      final userId = auth.dbUser?.id;
      _viewer = userId;
      bool current() =>
          mounted &&
          generation == _generation &&
          widget.requestId == requestId &&
          context.read<AuthProvider>().dbUser?.id == userId;
      if (userId == null || userId.isEmpty) return;

      // Fetch fresh membership here. A notification can arrive before the
      // authenticated cache has refreshed after someone joined a group.
      final groups = await GroupService.getUserGroups(userId);

      if (!current()) return;
      for (final group in groups) {
        if (!current()) return;
        final groupId = group.id;
        if (groupId == null || groupId.isEmpty) continue;
        final requests = await GroupService.getGroupWatchRequests(groupId);
        if (requests.any((request) => request.id == widget.requestId)) {
          if (!mounted || !current()) return;
          context.pushReplacement(
              '/groups/$groupId?tab=requests&requestId=${widget.requestId}');
          return;
        }
      }
    } catch (error) {
      // A failed lookup must not prevent opening a valid direct watch plan.
      logger
          .w('Unable to resolve group watch plan ${widget.requestId}: $error');
    } finally {
      if (mounted) {
        setState(() => _resolvingGroupPlan = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewer =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    if (viewer != _viewer) return const SizedBox.shrink();
    if (_resolvingGroupPlan) {
      return const FlixiePageScaffold(
        appBar: FlixieTitleAppBar(
          title: Text('Watch Plan'),
          leading: FlixieBackButton(),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return WatchRequestsScreen(initialRequestId: widget.requestId);
  }
}
