import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/guest/data/guest_diary_store.dart';
import 'package:flixie_app/features/guest/models/guest_diary_draft.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_diary_editor.dart';
import 'package:flixie_app/features/movies/data/external_watch_invite_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
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
  bool _initialized = false, _busy = false;
  GuestDiaryDraft? _draft;
  String? _error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewer = context.watch<AuthProvider>().dbUser?.id;
    if (!_initialized || viewer != _viewer) {
      _initialized = true;
      _viewer = viewer;
      _draft = null;
      _busy = false;
      _error = null;
      _preview = _load(viewer);
    }
  }

  Future<Map<String, dynamic>> _load(String? viewer) async {
    final drafts = await GuestDiaryStore.instance.list(viewer);
    if (!mounted || viewer != _viewer) throw StateError('Session changed');
    _draft =
        drafts.where((d) => d.watchInviteToken == widget.token).firstOrNull;
    try {
      return viewer == null
          ? await ExternalWatchInviteService.publicPreview(widget.token)
          : await ExternalWatchInviteService.preview(widget.token);
    } catch (_) {
      // A claimed request has its own access-controlled retry path even if the
      // original one-person link has expired since the first save attempt.
      if (_draft?.owner == viewer &&
          viewer != null &&
          _draft?.watchRequestId != null) {
        return {
          'movie': {'id': _draft!.movieId, 'title': _draft!.title}
        };
      }
      rethrow;
    }
  }

  Future<void> _start(Map<String, dynamic> data) async {
    if (_busy) return;
    final viewer = _viewer;
    setState(() => _busy = true);
    try {
      final movie = data['movie'] as Map, owner = data['owner'] as Map;
      var draft = _draft ??
          GuestDiaryDraft(
              id: const Uuid().v4(),
              movieId: movie['id'] as int,
              title: movie['title'] as String,
              poster: movie['posterPath'] as String?,
              owner: viewer,
              watchInviteToken: widget.token,
              inviterName: (owner['firstName'] ?? owner['username']) as String?,
              referralCode: data['referralCode'] as String?);
      await GuestDiaryStore.instance.save(draft);
      if (!mounted || viewer != _viewer) return;
      if (viewer != null && draft.owner == null) {
        await GuestDiaryStore.instance.beginSignup(draft.id);
        draft = (await GuestDiaryStore.instance.claim(viewer))!;
      }
      if (!mounted || viewer != _viewer) return;
      if (viewer == null) {
        context.push('/guest-diary?draft=${draft.id}');
      } else {
        setState(() => _draft = draft);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t open your entry. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(GuestDiaryDraft draft) async {
    final viewer = _viewer;
    if (viewer == null || viewer != draft.owner) {
      throw StateError('Session changed');
    }
    final stored = await GuestDiaryStore.instance.read(draft.id, viewer);
    final requestId = stored?.watchRequestId ??
        await ExternalWatchInviteService.claim(widget.token);
    if (!mounted || _viewer != viewer) throw StateError('Session changed');
    await GuestDiaryStore.instance.save(GuestDiaryDraft.fromJson(
        {...draft.toJson(), 'watchRequestId': requestId}));
    final saved = await RequestService.confirmWatchRequest(
        watchRequestId: requestId,
        userId: viewer,
        watched: true,
        rating: draft.rating,
        recommended: draft.recommended,
        watchedAt: draft.date.isEmpty
            ? null
            : DateTime.parse(draft.date).toUtc().toIso8601String(),
        reviewText: draft.note,
        watchComment: draft.note,
        publishReview: false);
    if (!mounted || _viewer != viewer) throw StateError('Session changed');
    await PendingWatchInviteStore.beginLog(requestId, viewer);
    await GuestDiaryStore.instance.finish(draft.id, viewer);
    if (!mounted || _viewer != viewer) return;
    context.read<AuthProvider>().markActivityChanged();
    GuestAccess.clear();
    context.go('/watch-entry-saved/$requestId', extra: {
      'movieTitle': draft.title,
      'rating': draft.rating,
      'watchState': saved
    });
  }

  Future<void> _leave({bool drafts = false}) async {
    if (_busy) return;
    if (_draft != null) await GuestDiaryStore.instance.pause(_draft!.id);
    await PendingWatchInviteStore.clear();
    GuestAccess.clear();
    if (mounted) context.go(drafts ? '/guest-diary' : '/');
  }

  Future<void> _decline() async {
    final leave = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheet) => FlixiePromptSheetContent(
                title: const Text('Not your movie night?'),
                content: const Text(
                    'You won’t confirm a watch. Your inviter’s own diary entry stays as it is.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(sheet, false),
                      child: const Text('Go back')),
                  FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      child: const Text('Leave invitation'))
                ]));
    if (leave == true && mounted) await _leave();
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
              title: const FlixieWordmark(),
              leading: IconButton(
                  tooltip: 'Close invite',
                  onPressed: _busy ? null : () => _leave(),
                  icon: const Icon(Icons.close))),
          body: SafeArea(
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 600),
                      child: FutureBuilder<Map<String, dynamic>>(
                          future: _preview,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState !=
                                ConnectionState.done) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            if (snapshot.hasError || !snapshot.hasData) {
                              final error = snapshot.error;
                              final closed = error is ApiException &&
                                  [404, 409, 410].contains(error.statusCode);
                              return ListView(
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    Text(
                                        closed
                                            ? 'This watch invite is unavailable.'
                                            : 'Couldn’t load this invitation.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall),
                                    const SizedBox(height: 16),
                                    Text(closed
                                        ? 'It may have expired or been used. Ask your film friend for a fresh invite.'
                                        : 'Check your connection and try again. Your draft hasn’t been lost.'),
                                    FilledButton(
                                        onPressed: () => setState(
                                            () => _preview = _load(_viewer)),
                                        child: const Text('Try again')),
                                    if (_draft != null)
                                      TextButton(
                                          onPressed: () => _leave(drafts: true),
                                          child: const Text(
                                              'Keep my diary draft')),
                                    TextButton(
                                        onPressed: () => _leave(),
                                        child: const Text('Continue to Flixie'))
                                  ]);
                            }
                            if (_draft != null &&
                                _viewer != null &&
                                _draft!.owner == _viewer) {
                              return ListView(
                                  padding: const EdgeInsets.all(24),
                                  children: [
                                    const Text('Same film. Your own take.'),
                                    const SizedBox(height: 12),
                                    GuestDiaryEditor(
                                        key: ValueKey(_draft!.id),
                                        draft: _draft!,
                                        signedIn: true,
                                        onBusyChanged: (busy) {
                                          if (mounted) {
                                            setState(() => _busy = busy);
                                          }
                                        },
                                        onContinue: _save),
                                    TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => _leave(drafts: true),
                                        child: const Text('Finish later'))
                                  ]);
                            }
                            final data = snapshot.data!,
                                movie = data['movie'] as Map;
                            final owner = FriendshipUser.fromJson(
                                Map<String, dynamic>.from(
                                    data['owner'] as Map));
                            final poster = movie['posterPath'] as String?;
                            return ListView(
                                padding: const EdgeInsets.all(24),
                                children: [
                                  Align(
                                      alignment: Alignment.centerLeft,
                                      child: ProfileAvatarView(
                                          avatar: owner.avatar,
                                          profileBadges: owner.profileBadges,
                                          fallbackText: owner.displayName,
                                          fallbackColor:
                                              avatarColorFromIconColor(
                                                  owner.iconColor),
                                          size: 56)),
                                  const SizedBox(height: 20),
                                  Text('Same film. Your own take.',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium),
                                  const SizedBox(height: 16),
                                  Text(
                                      '${owner.displayName} invited you to remember ${movie['title']} together.'),
                                  if (poster != null)
                                    Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 20),
                                        child: Align(
                                            alignment: Alignment.centerLeft,
                                            child: SizedBox(
                                                width: 110,
                                                child: AspectRatio(
                                                    aspectRatio: 2 / 3,
                                                    child: Image.network(
                                                        'https://image.tmdb.org/t/p/w342$poster',
                                                        fit: BoxFit.contain,
                                                        errorBuilder: (_, __,
                                                                ___) =>
                                                            const Icon(
                                                                Icons
                                                                    .movie_outlined,
                                                                size: 48)))))),
                                  const SizedBox(height: 16),
                                  Text(_viewer == null
                                      ? 'Choose your score and make a little diary entry. You can try it before creating an account.'
                                      : 'Choose your own date, rating and note. Saving confirms your viewing; your opinions don’t have to match.'),
                                  if (_error != null)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 16),
                                        child: Text(_error!)),
                                  const SizedBox(height: 24),
                                  FilledButton(
                                      onPressed:
                                          _busy ? null : () => _start(data),
                                      child: Text(_busy
                                          ? 'Opening your entry…'
                                          : 'Add my take')),
                                  const SizedBox(height: 12),
                                  const Text(
                                      'Flixie helps you track and discover films. Films aren’t streamed here.'),
                                  TextButton(
                                      onPressed: _busy ? null : _decline,
                                      child: const Text('I wasn’t there'))
                                ]);
                          }))))));
}
