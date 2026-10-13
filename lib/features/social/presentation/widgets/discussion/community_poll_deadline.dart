import 'dart:async';
import 'package:flutter/material.dart';

bool pollVotingClosed(Map<String, dynamic> poll, {DateTime? now}) {
  final deadline = DateTime.tryParse(poll['closesAt']?.toString() ?? '');
  return poll['closedAt'] != null ||
      (deadline != null && !deadline.isAfter(now ?? DateTime.now()));
}

String pollDeadlineLabel(Map<String, dynamic> poll, {DateTime? now}) {
  final current = now ?? DateTime.now();
  if (pollVotingClosed(poll, now: current)) return 'Voting closed';
  final deadline = DateTime.tryParse(poll['closesAt']?.toString() ?? '');
  if (deadline == null) return 'No deadline';
  final remaining = deadline.difference(current);
  final minutes = (remaining.inSeconds / 60).ceil();
  if (minutes < 1) return 'Closing in less than a minute';
  if (minutes < 60) {
    return 'Closing in $minutes ${minutes == 1 ? 'min' : 'mins'}';
  }
  final hours = (minutes / 60).ceil();
  if (hours < 24) return 'Closing in $hours ${hours == 1 ? 'hour' : 'hours'}';
  final days = (hours / 24).ceil();
  return 'Closing in $days ${days == 1 ? 'day' : 'days'}';
}

class CommunityPollDeadline extends StatefulWidget {
  const CommunityPollDeadline({super.key, required this.poll, this.now});
  final Map<String, dynamic> poll;
  final DateTime Function()? now;
  @override
  State<CommunityPollDeadline> createState() => _CommunityPollDeadlineState();
}

class _CommunityPollDeadlineState extends State<CommunityPollDeadline> {
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Text(pollDeadlineLabel(widget.poll, now: widget.now?.call()),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 12));
}
