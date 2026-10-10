import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../controllers/group_insights_controller.dart';
import 'group_insights/group_insights_content.dart';
import 'group_insights/group_insights_loading.dart';

/// Group Insights composition; loading and period ownership live in the controller.
class GroupInsightsTab extends StatefulWidget {
  const GroupInsightsTab({super.key, required this.groupId});
  final String groupId;
  @override
  State<GroupInsightsTab> createState() => _GroupInsightsTabState();
}

class _GroupInsightsTabState extends State<GroupInsightsTab> {
  final _controller = GroupInsightsController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider?>();
    unawaited(
      _controller.bind(
        widget.groupId,
        viewerId: auth?.dbUser?.id,
        enabled: auth == null || auth.dbUser != null,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant GroupInsightsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groupId != widget.groupId) {
      final auth = context.read<AuthProvider?>();
      unawaited(
        _controller.bind(
          widget.groupId,
          viewerId: auth?.dbUser?.id,
          enabled: auth == null || auth.dbUser != null,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _controller,
        builder: (_, __) => _controller.loading
            ? const GroupInsightsLoading()
            : GroupInsightsContent(controller: _controller),
      );
}
