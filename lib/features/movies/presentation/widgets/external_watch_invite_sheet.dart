import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flixie_app/features/movies/data/external_watch_invite_service.dart';
import 'package:flixie_app/features/movies/models/external_watch_invite.dart';

Future<void> showExternalWatchInviteSheet(
        BuildContext context, ExternalWatchInvite invite, String movieTitle) =>
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) =>
            ExternalWatchInviteContent(invite: invite, movieTitle: movieTitle));

class ExternalWatchInviteContent extends StatefulWidget {
  const ExternalWatchInviteContent(
      {super.key,
      required this.invite,
      required this.movieTitle,
      this.onDone,
      this.embedded = false});
  final ExternalWatchInvite invite;
  final String movieTitle;
  final VoidCallback? onDone;
  final bool embedded;
  @override
  State<ExternalWatchInviteContent> createState() =>
      _ExternalWatchInviteContentState();
}

class _ExternalWatchInviteContentState
    extends State<ExternalWatchInviteContent> {
  bool _busy = false;
  String? _error;
  Future<void> _send(bool copy) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final url = await ExternalWatchInviteService.shareUrl(widget.invite.id);
      if (!mounted) return;
      final text =
          'We watched ${widget.movieTitle} together! Join me on Flixie and log your watch.\n\n$url\n\nIf you need to install Flixie, open this link again afterwards. This invite is just for you.';
      if (copy) {
        await Clipboard.setData(ClipboardData(text: text));
        if (mounted) setState(() => _error = 'Invite copied');
      } else {
        final box = context.findRenderObject() as RenderBox?;
        await Share.share(text,
            subject: 'Log our watch on Flixie',
            sharePositionOrigin:
                box == null ? null : box.localToGlobal(Offset.zero) & box.size);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t prepare the invite. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: BoxConstraints(
          maxHeight: widget.embedded
              ? double.infinity
              : MediaQuery.sizeOf(context).height * .85,
          maxWidth: 560),
      child: SingleChildScrollView(
          padding: widget.embedded ? EdgeInsets.zero : const EdgeInsets.all(24),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Invite ${widget.invite.displayName}',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 12),
                Text(
                    'Your watch is saved. Share this invite so they can create an account and log ${widget.movieTitle} with you.'),
                const SizedBox(height: 8),
                const Text(
                    'Only share it with the person you watched with. Their date, rating and review are theirs to choose.'),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!, semanticsLabel: _error)),
                const SizedBox(height: 24),
                FilledButton.icon(
                    onPressed: _busy ? null : () => _send(false),
                    icon: const Icon(Icons.ios_share),
                    label: Text(
                        _busy ? 'Preparing invite…' : 'Share watch invite')),
                TextButton.icon(
                    onPressed: _busy ? null : () => _send(true),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy invite')),
                if (!widget.embedded)
                  TextButton(
                      onPressed: widget.onDone ?? () => Navigator.pop(context),
                      child: const Text('Done')),
              ])));
}
