import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/group_watch_request.dart'
    show WatchRequestStatus;

class RequestStatusBadge extends StatelessWidget {
  const RequestStatusBadge({super.key, this.status});

  final WatchRequestStatus? status;

  @override
  Widget build(BuildContext context) {
    final resolved = status ?? WatchRequestStatus.open;
    return FlixiePill.label(label: Text(resolved.statusLabel));
  }
}
