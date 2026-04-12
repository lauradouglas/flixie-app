import 'package:flutter/material.dart';

import '../../models/group_watch_request.dart' show WatchRequestStatus;
import '../../theme/app_theme.dart';

class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge({super.key, this.status});

  final WatchRequestStatus? status;

  @override
  Widget build(BuildContext context) {
    final resolved = status ?? WatchRequestStatus.open;
    final Color color;
    switch (resolved) {
      case WatchRequestStatus.expired:
      case WatchRequestStatus.cancelled:
        color = FlixieColors.danger;
      case WatchRequestStatus.completed:
        color = FlixieColors.success;
      case WatchRequestStatus.scheduled:
        color = FlixieColors.secondary;
      case WatchRequestStatus.open:
        color = FlixieColors.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        resolved.statusLabel.toUpperCase(),
        style: TextStyle(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5),
      ),
    );
  }
}
