import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/movies/data/external_watch_invite_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/friendship.dart';

class ExternalWatchInviteScreen extends StatefulWidget {
  const ExternalWatchInviteScreen({super.key, required this.token});
  final String token;
  @override
  State<ExternalWatchInviteScreen> createState() =>
      _ExternalWatchInviteScreenState();
}

class _ExternalWatchInviteScreenState extends State<ExternalWatchInviteScreen> {
  late Future<Map<String, dynamic>> _preview;
  String? _viewer;
  bool _busy = false, _resumed = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _viewer = context.read<AuthProvider>().dbUser?.id;
    _preview = _viewer == null
        ? ExternalWatchInviteService.publicPreview(widget.token)
        : ExternalWatchInviteService.preview(widget.token);
  }

  Future<void> _resume() async {
    if (_viewer == null || _resumed) return;
    final viewer = _viewer;
    if (await PendingWatchInviteStore.shouldResume(widget.token) &&
        mounted &&
        _viewer == viewer &&
        !_busy) {
      _resumed = true;
      await _claim();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewer = context.watch<AuthProvider>().dbUser?.id;
    if (viewer != _viewer) {
      _viewer = viewer;
      _preview = _viewer == null
          ? ExternalWatchInviteService.publicPreview(widget.token)
          : ExternalWatchInviteService.preview(widget.token);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _resume();
    });
  }

  Future<void> _claim() async {
    final viewer = _viewer;
    if (viewer == null) {
      GuestAccess.destination = '/watch-invites/${widget.token}';
      GuestAccess.awaitingAccount = true;
      GuestAccess.action = null;
      await PendingWatchInviteStore.readyToLog(widget.token);
      if (mounted) context.go('/auth/signup');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final requestId = await ExternalWatchInviteService.claim(widget.token);
      if (!mounted || context.read<AuthProvider>().dbUser?.id != viewer) return;
      await PendingWatchInviteStore.beginLog(requestId, viewer);
      GuestAccess.clear();
      if (mounted) context.go('/watch-requests/$requestId?log=true');
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t open this watch. The invite may have expired or been used. Try again or ask for a new invite.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    await PendingWatchInviteStore.clear();
    GuestAccess.clear();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          title: const FlixieWordmark(),
          leading: IconButton(
              tooltip: 'Close invite',
              onPressed: _busy ? null : _leave,
              icon: const Icon(Icons.close))),
      body: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: FutureBuilder<Map<String, dynamic>>(
                  future: _preview,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const CircularProgressIndicator();
                    }
                    if (!snapshot.hasData || snapshot.hasError) {
                      return SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            const Text(
                                'This watch invite is unavailable. It may have expired or already been used.'),
                            const SizedBox(height: 16),
                            FilledButton(
                                onPressed: () => setState(() => _preview =
                                    _viewer == null
                                        ? ExternalWatchInviteService
                                            .publicPreview(widget.token)
                                        : ExternalWatchInviteService.preview(
                                            widget.token)),
                                child: const Text('Try again')),
                            TextButton(
                                onPressed: _leave,
                                child: const Text('Continue to Flixie'))
                          ]));
                    }
                    final data = snapshot.data!, movie = data['movie'] as Map;
                    final owner = FriendshipUser.fromJson(
                        Map<String, dynamic>.from(data['owner'] as Map));
                    return ListView(
                        padding: const EdgeInsets.all(24),
                        shrinkWrap: true,
                        children: [
                          Align(
                              alignment: Alignment.centerLeft,
                              child: ProfileAvatarView(
                                  avatar: owner.avatar,
                                  profileBadges: owner.profileBadges,
                                  fallbackText: owner.displayName,
                                  fallbackColor:
                                      avatarColorFromIconColor(owner.iconColor),
                                  size: 56)),
                          const SizedBox(height: 20),
                          Text(
                              '${owner.displayName} says you watched ${movie['title']} together.',
                              style:
                                  Theme.of(context).textTheme.headlineMedium),
                          const SizedBox(height: 16),
                          const Text(
                              'Add it to your own watch history. You can change the date and choose whether to add a rating or review.'),
                          if (_error != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Text(_error!)),
                          const SizedBox(height: 28),
                          FilledButton(
                              onPressed: _busy ? null : _claim,
                              child: Text(_busy
                                  ? 'Opening watch…'
                                  : _viewer == null
                                      ? 'Rate now'
                                      : 'Log my watch')),
                          if (_viewer == null) ...[
                            const SizedBox(height: 12),
                            const Text('New here? Create your account first.',
                                textAlign: TextAlign.center),
                            TextButton(
                                onPressed: () async {
                                  await PendingWatchInviteStore.readyToLog(
                                      widget.token);
                                  if (!context.mounted) return;
                                  GuestAccess.destination =
                                      '/watch-invites/${widget.token}';
                                  GuestAccess.awaitingAccount = true;
                                  context.go('/auth/login');
                                },
                                child:
                                    const Text('Already on Flixie? Sign in')),
                          ],
                          TextButton(
                              onPressed: _busy ? null : _leave,
                              child: const Text('I wasn’t there'))
                        ]);
                  }))));
}
