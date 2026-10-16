import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import '../../data/popcorn_service.dart';
import '../../models/popcorn_challenge.dart';
import 'popcorn_arena.dart';
import 'popcorn_action_button.dart';
import 'popcorn_share_sheet.dart';

class PopcornChallengeCard extends StatefulWidget {
  const PopcornChallengeCard(
      {super.key,
      required this.challenge,
      required this.currentUserId,
      this.result = false,
      this.service});
  final PopcornChallenge challenge;
  final String currentUserId;
  final bool result;
  final PopcornService? service;
  @override
  State<PopcornChallengeCard> createState() => _PopcornChallengeCardState();
}

class _PopcornChallengeCardState extends State<PopcornChallengeCard> {
  bool busy = false;
  String? error;
  Future<void> _act() async {
    if (busy) return;
    final owner = widget.currentUserId;
    setState(() => busy = true);
    try {
      final service = widget.service ?? PopcornService();
      final c = await service.challenge(widget.challenge.id);
      if (!mounted || widget.currentUserId != owner) return;
      if (widget.result) {
        final roundId =
            owner == c.senderId ? c.sourceRoundId : c.attemptRoundId;
        if (roundId == null) throw StateError('Round unavailable');
        await showPopcornShareSheet(context,
            roundId: roundId,
            userId: owner,
            service: service,
            isCurrent: () => mounted && widget.currentUserId == owner);
      } else {
        if (owner != c.recipientId) {
          throw StateError('Waiting for your friend to play.');
        }
        final pending = await service.pendingReply(owner, c.id);
        if (!mounted || widget.currentUserId != owner) return;
        if (pending != null) {
          await service.reply(c.id, pending);
          await service.clearReply(owner, c.id);
          if (mounted) {
            setState(
                () => error = 'Your first result has been sent back in chat.');
          }
          return;
        }
        if (c.resultScore != null) {
          setState(() => error = 'Your first result is already in chat.');
          return;
        }
        if (c.attemptStarted) {
          throw StateError(
              'Your first attempt already started. Continue in the open game; it cannot be replaced.');
        }
        final yes = await showFlixiePromptSheet<bool>(
            context: context,
            builder: (ctx) => FlixiePromptSheetContent(
                    title: Text('Ready to challenge ${c.senderName}?'),
                    content: Text(
                        'Your first result will be sent back to ${c.senderName}. Same treats, one first attempt. Leaving the game does not give you another attempt.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Not now')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Start my attempt'))
                    ]));
        if (yes == true && mounted && widget.currentUserId == owner) {
          await context.push(
              '/play/popcorn-catch?challenge=${Uri.encodeComponent(c.id)}',
              extra: true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e is StateError
            ? e.message
            : 'Challenge unavailable. Check your connection and try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.challenge, result = widget.result;
    final lost = result && c.resultScore != null && c.resultScore! < c.score;
    final image = lost
        ? 'sad'
        : result
            ? (c.resultScore == c.score ? 'land' : 'dance')
            : 'catch';
    final canAct = result || widget.currentUserId == c.recipientId;
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF301842), Color(0xFF241133)]),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF795099))),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(result ? c.resultLabel : 'Pip’s Popcorn Catch',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (ctx, box) {
              final score = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!result)
                      Text('${c.senderName} scored',
                          style: const TextStyle(color: Color(0xFFE8D9F2))),
                    Text('${result ? c.resultScore : c.score}',
                        style: const TextStyle(
                            color: popcornGold,
                            fontSize: 46,
                            height: 1.05,
                            fontWeight: FontWeight.w900)),
                    if (c.version >= 3)
                      Text(
                          'Round ${result ? c.resultRoundReached ?? 1 : c.roundReached}',
                          style: const TextStyle(color: Colors.white)),
                    const Text('points',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                  ]);
              final art = Image.asset('assets/icon/pip_popcorn_$image.png',
                  width: 120,
                  height: 145,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true);
              return box.maxWidth < 240 ||
                      MediaQuery.textScalerOf(ctx).scale(16) > 24
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [score, art])
                  : Row(children: [
                      Expanded(child: score),
                      const SizedBox(width: 12),
                      art
                    ]);
            }),
            const SizedBox(height: 12),
            Text(
                result
                    ? '${widget.currentUserId == c.recipientId ? 'Your' : c.recipientName} ${c.resultScore} · ${widget.currentUserId == c.senderId ? 'Your' : c.senderName} ${c.score}'
                    : 'Think you can beat me?',
                style: const TextStyle(color: Colors.white, fontSize: 15)),
            if (result) ...[
              const SizedBox(height: 10),
              const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.star, size: 16, color: popcornGold),
                SizedBox(width: 6),
                Text('First attempt',
                    style: TextStyle(color: Color(0xFFE8D9F2)))
              ])
            ],
            const SizedBox(height: 16),
            if (canAct)
              SizedBox(
                  width: double.infinity,
                  child: PopcornActionButton(
                      onPressed: busy ? null : _act,
                      gold: !result,
                      label: busy
                          ? 'Loading…'
                          : result
                              ? 'Challenge back'
                              : 'Take the challenge'))
            else
              Text('Waiting for ${c.recipientName}',
                  style: const TextStyle(color: Color(0xFFD2BEE4))),
            if (!result)
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('Same treats. One first attempt.',
                      style:
                          TextStyle(color: Color(0xFFD2BEE4), fontSize: 12))),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(error!,
                      style: const TextStyle(color: Color(0xFFFFC7B7)))),
          ]),
    );
  }
}
