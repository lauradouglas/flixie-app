import 'dart:async';
import 'package:flutter/material.dart';
import 'community_poll_deadline.dart';

/// Read-only results in the feed; voting remains in the full discussion.
class CommunityPollPreview extends StatefulWidget {
  const CommunityPollPreview(
      {super.key, required this.poll, required this.onOpen});
  final Map<String, dynamic> poll;
  final VoidCallback onOpen;

  @override
  State<CommunityPollPreview> createState() => _CommunityPollPreviewState();
}

class _CommunityPollPreviewState extends State<CommunityPollPreview> {
  Timer? _timer;
  Map<String, dynamic> get poll => widget.poll;
  VoidCallback get onOpen => widget.onOpen;

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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final options = (poll['options'] as List? ?? [])
        .map((o) => Map<String, dynamic>.from(o as Map))
        .toList()
      ..sort((a, b) {
        final votes = (b['votes'] as int).compareTo(a['votes'] as int);
        return votes != 0 ? votes : '${a['title']}'.compareTo('${b['title']}');
      });
    final total = poll['totalVotes'] as int? ?? 0;
    final closed = pollVotingClosed(poll);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (final option in options.take(3))
        TextButton(
            onPressed: onOpen,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 9),
                foregroundColor: scheme.onSurface,
                alignment: Alignment.centerLeft),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text('${option['title']}',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Text(
                    '${total == 0 ? 0 : ((option['votes'] as int) / total * 100).round()}%',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ]),
              if (poll['selectedOptionId'] == option['id'])
                Text('Your pick',
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
              const SizedBox(height: 7),
              ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total == 0 ? 0 : (option['votes'] as int) / total,
                    minHeight: 5,
                    color: scheme.primary,
                    backgroundColor: scheme.primaryContainer,
                    semanticsLabel: '${option['title']} share of votes',
                    semanticsValue:
                        '${total == 0 ? 0 : ((option['votes'] as int) / total * 100).round()}',
                  )),
            ])),
      if (options.length > 3)
        Text('+${options.length - 3} more titles',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      for (final option in options.skip(3))
        if (option['id'] == poll['selectedOptionId'])
          Text('Your pick: ${option['title']}',
              style: TextStyle(
                  color: scheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(
          total == 0
              ? 'No votes yet'
              : '$total ${total == 1 ? 'vote' : 'votes'}',
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
      const SizedBox(height: 8),
      CommunityPollDeadline(poll: poll),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: FilledButton(
              onPressed: onOpen,
              child: Text(closed ? 'View results' : 'Vote or add a title'))),
    ]);
  }
}
