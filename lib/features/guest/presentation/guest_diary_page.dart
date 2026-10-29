import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/diary/diary_calendar_sheet.dart'
    show diaryPaper, diaryInk;
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../data/guest_diary_store.dart';
import '../models/guest_diary_draft.dart';
import 'widgets/guest_diary_editor.dart';
import 'guest_access.dart';

class GuestDiaryPage extends StatefulWidget {
  const GuestDiaryPage({super.key, this.draftId});
  final String? draftId;
  @override
  State<GuestDiaryPage> createState() => _GuestDiaryPageState();
}

class _GuestDiaryPageState extends State<GuestDiaryPage> {
  List<GuestDiaryDraft>? _drafts;
  GuestDiaryDraft? _selected;
  bool _preview = false, _busy = false;
  String? _error;
  String? _viewer;
  bool _viewerSet = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewer = context.watch<AuthProvider>().dbUser?.id;
    if (!_viewerSet || _viewer != viewer) {
      _viewerSet = true;
      _viewer = viewer;
      _drafts = null;
      _selected = null;
      _preview = false;
      _load();
    }
  }

  Future<void> _load() async {
    final viewer = _viewer;
    try {
      final drafts = await GuestDiaryStore.instance.list(viewer);
      if (!mounted || _viewer != viewer) return;
      if (mounted) {
        setState(() {
          _drafts = drafts;
          _error = null;
          _selected = drafts.where((d) => d.id == widget.draftId).firstOrNull;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t load your drafts. Please retry.');
      }
    }
  }

  Future<void> _account(GuestDiaryDraft draft, bool signIn) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await GuestDiaryStore.instance.beginSignup(draft.id);
      if (!mounted) return;
      GuestAccess.clear();
      if (draft.watchInviteToken != null) {
        await PendingWatchInviteStore.readyToLog(draft.watchInviteToken!);
        await PendingWatchInviteStore.referralConsent(
            draft.referralCode, draft.connectInviter);
        if (!mounted) return;
        GuestAccess.destination = '/watch-invites/${draft.watchInviteToken}';
        GuestAccess.awaitingAccount = true;
        context.go(context.read<AuthProvider>().dbUser != null
            ? '/watch-invites/${draft.watchInviteToken}'
            : signIn
                ? '/auth/login'
                : '/auth/signup');
        return;
      }
      GuestAccess.destination = '/movies/${draft.movieId}';
      GuestAccess.action = draft.logWatch ? 'log' : 'rate';
      GuestAccess.bookmarkTitle = draft.title;
      GuestAccess.diaryDraftId = draft.id;
      GuestAccess.awaitingAccount = true;
      context.go(context.read<AuthProvider>().dbUser != null
          ? '/signup-journey'
          : signIn
              ? '/auth/login'
              : '/auth/signup');
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Couldn’t prepare your entry. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _keepSeparate(GuestDiaryDraft draft) async {
    final confirmed = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheet) => FlixiePromptSheetContent(
                title: const Text('Keep your own diary entry?'),
                content: const Text(
                    'Your score, date and note stay here. This entry won’t be linked to the invitation, and their watch won’t change.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(sheet, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      child: const Text('Keep separate entry'))
                ]));
    if (confirmed != true || !mounted) return;
    final separate = GuestDiaryDraft.fromJson({
      ...draft.toJson(),
      'watchInviteToken': null,
      'inviterName': null,
      'referralCode': null,
      'connectInviter': false
    });
    try {
      await GuestDiaryStore.instance.save(separate);
      await GuestDiaryStore.instance.pause(draft.id);
      await PendingWatchInviteStore.clear();
      if (mounted) setState(() => _selected = separate);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t update your draft. Please retry.');
      }
    }
  }

  Future<void> _discard(GuestDiaryDraft draft) async {
    final remove = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (sheet) => FlixiePromptSheetContent(
                title: const Text('Discard this draft?'),
                content: Text(
                    'Your score and notes for ${draft.title} will be removed from this device.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(sheet, false),
                      child: const Text('Keep draft')),
                  FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      child: const Text('Discard draft'))
                ]));
    if (remove != true || !mounted) return;
    try {
      await GuestDiaryStore.instance
          .discard(draft.id, context.read<AuthProvider>().dbUser?.id);
      if (!mounted) return;
      setState(() {
        _selected = null;
        _preview = false;
      });
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t remove this draft. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
          title: const Text('Your film diary'),
          leading: BackButton(
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go('/'))),
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    if (_error != null) ...[
                      Text(_error!),
                      TextButton(onPressed: _load, child: const Text('Retry'))
                    ],
                    if (_drafts == null && _error == null)
                      const Center(child: CircularProgressIndicator()),
                    if (_selected case final draft?) ...[
                      if (draft.watchInviteToken != null)
                        Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Text(
                                'Your own take on a film with ${draft.inviterName ?? 'your film friend'}.')),
                      if (!_preview)
                        GuestDiaryEditor(
                            key: ValueKey(draft.id),
                            draft: draft,
                            onContinue: (saved) async {
                              if (mounted) {
                                setState(() {
                                  _selected = saved;
                                  _preview = true;
                                });
                              }
                            }),
                      if (_preview) ...[
                        Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                                color: diaryPaper,
                                borderRadius: BorderRadius.circular(14)),
                            child: DefaultTextStyle(
                                style: const TextStyle(
                                    color: diaryInk,
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    height: 1.4),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Dear film diary,',
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineMedium
                                              ?.copyWith(color: diaryInk)),
                                      const SizedBox(height: 24),
                                      Text(draft.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall
                                              ?.copyWith(color: diaryInk)),
                                      const SizedBox(height: 12),
                                      Text(draft.logWatch
                                          ? (draft.date.isEmpty
                                              ? 'Watched · date unknown'
                                              : 'Watched ${draft.date}')
                                          : 'Rating'),
                                      if (draft.rating != null)
                                        Text('${draft.rating}/10'),
                                      if (draft.recommended != null)
                                        Text(draft.recommended!
                                            ? 'Recommended'
                                            : 'Not recommended'),
                                      if (draft.note.isNotEmpty)
                                        Padding(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 16),
                                            child: Text(draft.note)),
                                    ]))),
                        const SizedBox(height: 24),
                        const Text(
                            'Your entry is kept on this device. Create an account to keep it in your diary across devices. You’ll check it before saving.'),
                        if (draft.watchInviteToken != null &&
                            draft.referralCode != null &&
                            _viewer == null)
                          CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                  'For a new account: connect with ${draft.inviterName ?? 'my inviter'} and credit their invite.'),
                              subtitle: const Text(
                                  'Optional. Your shared watch can still be saved without this.'),
                              value: draft.connectInviter,
                              onChanged: _busy
                                  ? null
                                  : (value) async {
                                      final updated = GuestDiaryDraft.fromJson({
                                        ...draft.toJson(),
                                        'connectInviter': value == true
                                      });
                                      try {
                                        await GuestDiaryStore.instance
                                            .save(updated);
                                        if (mounted) {
                                          setState(() => _selected = updated);
                                        }
                                      } catch (_) {
                                        if (mounted) {
                                          setState(() => _error =
                                              'Couldn’t keep your choice. Please try again.');
                                        }
                                      }
                                    }),
                        const SizedBox(height: 16),
                        FilledButton(
                            onPressed:
                                _busy ? null : () => _account(draft, false),
                            child: Text(
                                context.read<AuthProvider>().dbUser == null
                                    ? 'Create account & keep my entry'
                                    : 'Continue & save my entry')),
                        if (context.watch<AuthProvider>().dbUser == null)
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _account(draft, true),
                              child: const Text(
                                  'Already have an account? Sign in')),
                        TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() => _preview = false),
                            child: const Text('Edit my entry')),
                        if (draft.watchInviteToken != null && !draft.submitted)
                          TextButton(
                              onPressed:
                                  _busy ? null : () => _keepSeparate(draft),
                              child:
                                  const Text('Keep as a separate diary entry')),
                        if (!draft.submitted)
                          TextButton(
                              onPressed: _busy ? null : () => _discard(draft),
                              child: const Text('Discard draft')),
                        TextButton(
                            onPressed: _busy ? null : () => context.go('/'),
                            child: const Text('Keep browsing')),
                      ],
                    ] else if (_drafts != null) ...[
                      const Text(
                          'Your drafts stay on this device. Pick one to carry on.'),
                      if (_drafts!.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                                'Find a film you’ve watched to start your diary.')),
                      for (final draft in _drafts!)
                        ListTile(
                            title: Text(draft.title),
                            subtitle: Text(
                                '${draft.rating == null ? 'No score yet' : '${draft.rating}/10'} · ${!draft.logWatch ? 'Rating draft' : draft.date.isEmpty ? 'Date unknown' : draft.date}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => setState(() {
                                  _selected = draft;
                                  _preview = true;
                                })),
                      TextButton(
                          onPressed: () => context.go('/search?focus=1'),
                          child: const Text('Find a film to rate or log')),
                    ],
                  ])))));
}
