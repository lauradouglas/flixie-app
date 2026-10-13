import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import '../../../data/community_space_service.dart';
import 'community_poll_title_picker.dart';
import 'community_poll_artwork.dart';
import 'community_poll_deadline.dart';

class CommunityPoll extends StatefulWidget {
  const CommunityPoll(
      {super.key,
      required this.poll,
      required this.communityId,
      required this.discussionId,
      required this.service,
      required this.member,
      required this.onChanged});
  final Map<String, dynamic> poll;
  final int communityId;
  final String discussionId;
  final CommunitySpaceService service;
  final bool member;
  final Future<void> Function() onChanged;
  @override
  State<CommunityPoll> createState() => _CommunityPollState();
}

class _CommunityPollState extends State<CommunityPoll> {
  bool _busy = false;
  String? _error;
  bool get _closed => pollVotingClosed(widget.poll);
  Timer? _deadlineTimer;
  @override
  void initState() {
    super.initState();
    _deadlineTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    super.dispose();
  }

  List<Map<String, dynamic>> get _options {
    final options = (widget.poll['options'] as List)
        .map((o) => Map<String, dynamic>.from(o))
        .toList();
    options.sort((a, b) {
      final votes = (b['votes'] as int).compareTo(a['votes'] as int);
      return votes != 0
          ? votes
          : (a['title'] as String).compareTo(b['title'] as String);
    });
    return options;
  }

  Future<void> _mutate(String action, Map<String, dynamic> data) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.post(widget.communityId,
          '/discussions/${widget.discussionId}/poll/$action', data);
      await widget.onChanged();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is ApiException
            ? e.message
            : 'Couldn’t save your choice. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _add() async {
    final title = await pickCommunityPollTitle(context,
        communityId: widget.communityId,
        service: widget.service,
        excluded: _options.map(pollMediaKey).toSet());
    if (title != null && mounted) {
      await _mutate('options', pollMediaInput(title));
    }
  }

  Future<void> _close() async {
    final yes = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (ctx) => FlixiePromptSheetContent(
                title: const Text('Close voting?'),
                content: const Text(
                    'The results stay visible. Members won’t be able to change votes or add titles.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Close voting'))
                ]));
    if (yes == true && mounted) await _mutate('close', {});
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.poll['totalVotes'] as int? ?? 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text(
          '${_closed ? 'Voting closed' : 'Choose one title'} · $total ${total == 1 ? 'vote' : 'votes'}',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      CommunityPollDeadline(poll: widget.poll),
      if (!_closed)
        Text(widget.member
            ? 'Tap a title to vote. You can change your pick.'
            : 'Join this community to vote or add a title.'),
      const SizedBox(height: 12),
      if (_closed) CommunityPollOutcome(options: _options, total: total),
      for (final option in _options) ...[
        _option(context, option, total),
        const SizedBox(height: 10)
      ],
      if (_busy) const LinearProgressIndicator(semanticsLabel: 'Saving poll'),
      if (_error != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!)),
      if (!_closed && widget.member)
        Wrap(spacing: 12, runSpacing: 8, children: [
          if (_options.length < 30)
            OutlinedButton.icon(
                onPressed: _busy ? null : _add,
                icon: const Icon(Icons.add),
                label: const Text('Add another title')),
          if (widget.poll['canClose'] == true)
            TextButton(
                onPressed: _busy ? null : _close,
                child: const Text('Close voting'))
        ])
    ]);
  }

  Widget _option(BuildContext context, Map<String, dynamic> option, int total) {
    final selected = widget.poll['selectedOptionId'] == option['id'];
    final votes = option['votes'] as int? ?? 0;
    final proportion = total == 0 ? 0.0 : (votes / total).clamp(0.0, 1.0);
    final percentage = (proportion * 100).round();
    return Semantics(
        selected: selected,
        child: Material(
            color: Colors.transparent,
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _closed || _busy || !widget.member
                    ? null
                    : () => _mutate('vote', {'optionId': option['id']}),
                child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CommunityPollPoster(
                              path: option['posterPath'] as String?),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                          child: Text(
                                              option['title'] ??
                                                  'Unavailable title',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 16,
                                                  color: selected
                                                      ? context.colors.secondary
                                                      : context.colors.white))),
                                      const SizedBox(width: 12),
                                      Text('$percentage%',
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: selected
                                                  ? context.colors.secondary
                                                  : context.colors.white))
                                    ]),
                                const SizedBox(height: 4),
                                Text(
                                    "${option['kind'] == 'show' ? 'Series' : 'Film'} · $votes ${votes == 1 ? 'vote' : 'votes'}",
                                    style: TextStyle(
                                        color: context.colors.light,
                                        fontSize: 13)),
                                if (selected)
                                  Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('Your pick',
                                          style: TextStyle(
                                              color: context.colors.secondary,
                                              fontWeight: FontWeight.w700))),
                                const SizedBox(height: 12),
                                LinearProgressIndicator(
                                    value: proportion,
                                    minHeight: 5,
                                    borderRadius: BorderRadius.circular(5),
                                    color: context.colors.primary,
                                    backgroundColor: context.colors.medium
                                        .withValues(alpha: .2),
                                    semanticsLabel: option['title'],
                                    semanticsValue: '$percentage'),
                              ]))
                        ])))));
  }
}
