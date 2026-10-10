import '../controllers/community_discussion_controller.dart';
import '../widgets/discussion/discussion_reply.dart';
import '../widgets/discussion/discussion_reply_composer.dart';
export '../widgets/discussion/community_discussion_composer.dart'
    show CommunityDiscussionComposer;
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/models/friendship.dart';
import '../../data/community_space_service.dart';
import '../../data/genre_community_service.dart';
import 'community_space_screen.dart';
import '../widgets/community_mention_suggestions.dart';
import '../widgets/community_mention_text.dart';
import '../widgets/discussion/discussion_author.dart';

class CommunityDiscussionScreen extends StatefulWidget {
  const CommunityDiscussionScreen(
      {super.key,
      required this.communityId,
      required this.discussionId,
      required this.service,
      this.membership = const GenreCommunityService(),
      this.joined,
      this.initialReplyId});
  final int communityId;
  final String discussionId;
  final CommunitySpaceService service;
  final GenreCommunityService membership;
  final bool? joined;
  final String? initialReplyId;
  @override
  State<CommunityDiscussionScreen> createState() =>
      _CommunityDiscussionScreenState();
}

class _CommunityDiscussionScreenState extends State<CommunityDiscussionScreen> {
  late final CommunityDiscussionController _controller;
  Map<String, dynamic>? get _thread => _controller.thread;
  List<Map<String, dynamic>> get _replies => _controller.replies;
  bool get _member => _controller.member;
  set _member(bool value) => _controller.member = value;
  bool get _reveal => _controller.reveal;
  set _reveal(bool value) => _controller.reveal = value;
  bool get _loading => _controller.loading;
  bool get _more => _controller.loadingReplies;
  bool get _failedMore => _controller.failedMore;
  String? get _error => _controller.error;
  String? get _replyError => _controller.replyError;
  String? get _next => _controller.next;
  int get _generation => _controller.generation;
  int _focusRevision = 0;
  void _changed() {
    if (!mounted) return;
    final ids = _replies.map((r) => r['id']).toSet();
    _replyKeys.removeWhere((id, _) => !ids.contains(id));
    setState(() {});
  }

  final _body = TextEditingController();
  final _replyFocus = FocusNode();
  final _composerKey = GlobalKey();
  final _focusKey = GlobalKey();
  final Map<String, String> _mentions = {};
  Map<String, dynamic>? _replyTo, _focusedReply;
  bool _joining = false, _postedReply = false;
  final _replyKeys = <String, GlobalKey>{};
  String? _focusError, _highlightedReplyId;
  Timer? _highlightTimer;
  void _highlightReply(String id) {
    if (!mounted) return;
    _highlightTimer?.cancel();
    setState(() => _highlightedReplyId = id);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightedReplyId = null);
    });
  }

  Future<void> _focusReply(String id) async {
    final revision = ++_focusRevision;
    final generation = _generation;
    bool current() =>
        mounted && revision == _focusRevision && generation == _generation;
    final cached = _replies.where((row) => row['id'] == id).firstOrNull;
    if (cached != null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!current()) return;
    }
    if (!mounted || !current()) return;
    final targetContext = _replyKeys[id]?.currentContext;
    if (targetContext != null && targetContext.mounted) {
      await Scrollable.ensureVisible(targetContext,
          alignment: .3,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220));
      if (current()) _highlightReply(id);
      return;
    }
    try {
      final reply = cached ??
          await widget.service.get(widget.communityId, '/replies/$id',
              {'reveal': 'true', 'discussionId': widget.discussionId});
      if (current()) {
        setState(() {
          _focusedReply = reply;
          _focusError = null;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (current() && _focusKey.currentContext != null) {
          Scrollable.ensureVisible(_focusKey.currentContext!);
          _highlightReply(id);
        }
      });
    } catch (_) {
      if (current()) {
        setState(() => _focusError = 'That comment is no longer available.');
      }
    }
  }

  void _target(Map<String, dynamic> reply) {
    setState(() => _replyTo = reply);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _composerKey.currentContext;
      if (target != null) Scrollable.ensureVisible(target);
      _replyFocus.requestFocus();
    });
  }

  String? _sendError;
  bool _sending = false;
  String get _path => _controller.path;
  bool get _hidden => _controller.hidden;
  @override
  void initState() {
    super.initState();
    _controller = CommunityDiscussionController(
        communityId: widget.communityId,
        discussionId: widget.discussionId,
        service: widget.service,
        joined: widget.joined)
      ..addListener(_changed);
    SafetyService.changes.addListener(_safetyChanged);
    _load();
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_safetyChanged);
    _highlightTimer?.cancel();
    _controller.dispose();
    _replyFocus.dispose();
    _body.dispose();
    super.dispose();
  }

  void _safetyChanged() {
    _focusRevision++;
    setState(() {
      _focusedReply = null;
      _replyTo = null;
      _focusError = null;
    });
    _controller.load(clear: true);
  }

  Future<void> _load() async {
    final pending = _controller.load();
    final generation = _generation;
    await pending;
    if (!mounted || generation != _generation || _hidden || _error != null) {
      return;
    }
    if (widget.initialReplyId != null) {
      await _focusReply(widget.initialReplyId!);
    }
  }

  Future<void> _loadReplies({bool more = false, bool force = false}) =>
      _controller.loadReplies(more: more, force: force);

  Future<void> _send() async {
    if (_sending || _body.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await widget.service.post(widget.communityId, '$_path/replies', {
        'body': _body.text.trim(),
        'reveal': _reveal,
        'mentionIds': activeCommunityMentions(_mentions, _body.text),
        if (_replyTo != null) 'parentReplyId': _replyTo!['id']
      });
      if (!mounted) return;
      _body.clear();
      _mentions.clear();
      setState(() {
        _replyTo = null;
        _postedReply = true;
      });
      FocusScope.of(context).unfocus();
      await _loadReplies(force: true);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Reply posted.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sendError = 'Couldn’t send. Your reply is still here.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(Map<String, dynamic> row, {bool reply = false}) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: Text(
                    reply ? 'Delete your reply?' : 'Delete this discussion?'),
                content: Text(reply
                    ? 'This removes your reply.'
                    : 'This removes the discussion and its replies from the community.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'))
                ]));
    if (ok != true || !mounted) return;
    try {
      await widget.service
          .delete(widget.communityId, reply ? '/replies/${row['id']}' : _path);
      if (!mounted) return;
      if (reply) {
        await _loadReplies(force: true);
      } else {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t delete. Try again.')));
      }
    }
  }

  Widget _author(Map<String, dynamic> row, {bool reply = false}) =>
      DiscussionAuthor(
          row: row,
          reply: reply,
          currentUserId: context.read<AuthProvider>().dbUser?.id,
          onAction: (action) => _authorAction(action, row, reply));

  Future<void> _authorAction(
      String action, Map<String, dynamic> row, bool reply) async {
    final user =
        FriendshipUser.fromJson(Map<String, dynamic>.from(row['user']));

    if (action == 'delete') {
      await _delete(row, reply: reply);
      return;
    }
    if (action == 'report') {
      SafetyActions.contentMenu(context,
          targetType:
              reply ? 'COMMUNITY_DISCUSSION_REPLY' : 'COMMUNITY_DISCUSSION',
          targetId: row['id'],
          reportedUserId: user.id,
          username: user.username,
          contentPreview: _hidden ? 'Spoiler discussion' : row['body'] ?? '');
      return;
    }
    try {
      await widget.service.mute(user.id);
      if (!mounted) return;
      SafetyService.changes.value++;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Author muted. Manage muted authors in Community settings.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t mute author. Try again.')));
      }
    }
  }

  Future<void> _join() async {
    final confirmed = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (ctx) => FlixiePromptSheetContent(
                title: const Text('Join this community?'),
                content: const Text(
                    'Your public reviews can appear here. Private reviews stay private. Joining won’t follow anyone for you.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Join'))
                ]));
    if (confirmed != true || !mounted) return;
    setState(() => _joining = true);
    try {
      await widget.membership.setJoined(widget.communityId, true);
      if (mounted) setState(() => _member = true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Couldn’t join. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Widget _line() =>
      Divider(height: 1, color: context.colors.light.withValues(alpha: .16));

  Widget _comment(Map<String, dynamic> reply) => DiscussionReply(
      reply: reply,
      author: _author(reply, reply: true),
      member: _member,
      highlighted: _highlightedReplyId == reply['id'],
      onFocus: _focusReply,
      onReply: () => _target(reply));

  Widget _replyComposer() => DiscussionReplyComposer(
      key: _composerKey,
      postedReply: _postedReply,
      replyTo: _replyTo,
      sending: _sending,
      sendError: _sendError,
      onSend: _send,
      onCancelTarget: () => setState(() => _replyTo = null),
      replyFocus: _replyFocus,
      body: _body,
      mentions: _mentions,
      discussionId: widget.discussionId,
      communityId: widget.communityId,
      service: widget.service);

  @override
  Widget build(BuildContext context) {
    final title = _thread?['movie'] ?? _thread?['show'];
    final poster = title?['posterPath'] as String?;
    return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          leading: const FlixieBackButton(),
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.communityId == -1 ? 'Anime' : 'Community',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Discussion',
                style: TextStyle(fontSize: 12, color: context.colors.light)),
          ]),
          actions: [
            IconButton(
                tooltip: 'Close discussion',
                icon: const Icon(Icons.close),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/genre-communities/${widget.communityId}');
                  }
                })
          ],
          bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1), child: _line()),
        ),
        body: SafeArea(
            child: Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Column(children: [
                      Expanded(
                          child: RefreshIndicator(
                              onRefresh: _load,
                              child: ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  children: [
                                    if (_loading)
                                      const LinearProgressIndicator(),
                                    if (_error != null)
                                      CommunityRetry(
                                          message: _error!, onRetry: _load),
                                    if (_thread != null && _error == null) ...[
                                      const SizedBox(height: 20),
                                      Row(children: [
                                        if (poster != null &&
                                            poster.isNotEmpty) ...[
                                          ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                              child: Image.network(
                                                  poster.startsWith('http')
                                                      ? poster
                                                      : 'https://image.tmdb.org/t/p/w185$poster',
                                                  width: 34,
                                                  height: 50,
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) =>
                                                      const SizedBox(
                                                          width: 34,
                                                          height: 50,
                                                          child: Icon(Icons
                                                              .movie_outlined)))),
                                          const SizedBox(width: 12),
                                        ],
                                        Expanded(
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                              if (title != null)
                                                Text(title['title'],
                                                    style: const TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w700)),
                                              Text(discussionBoundary(_thread!),
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: _hidden
                                                          ? const Color(
                                                              0xffefcd88)
                                                          : const Color(
                                                              0xff80ddcc))),
                                            ])),
                                      ]),
                                      const SizedBox(height: 18),
                                      if (_hidden) ...[
                                        const Text(
                                            'This conversation contains spoilers.',
                                            style: TextStyle(
                                                fontSize: 25,
                                                fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 12),
                                        const Text(
                                            'The post and replies stay hidden until you’re ready. Keep replies within the spoiler boundary above.'),
                                        const SizedBox(height: 20),
                                        FilledButton(
                                            onPressed: () {
                                              setState(() => _reveal = true);
                                              _load();
                                            },
                                            child: const Text(
                                                'Reveal discussion')),
                                      ] else ...[
                                        _author(_thread!),
                                        const SizedBox(height: 16),
                                        Text(_thread!['title'],
                                            style: const TextStyle(
                                                fontSize: 25,
                                                height: 1.32,
                                                fontWeight: FontWeight.w800,
                                                letterSpacing: -.5)),
                                        const SizedBox(height: 12),
                                        CommunityMentionText(
                                            _thread!['body'] ?? '',
                                            style:
                                                discussionBodyStyle(context)),
                                        const SizedBox(height: 24),
                                        _line(),
                                        const SizedBox(height: 20),
                                        Wrap(
                                            alignment:
                                                WrapAlignment.spaceBetween,
                                            spacing: 20,
                                            crossAxisAlignment:
                                                WrapCrossAlignment.center,
                                            children: [
                                              Text('Replies',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800)),
                                              Text('Oldest first',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      color: context
                                                          .colors.light)),
                                            ]),
                                        if (_more)
                                          const LinearProgressIndicator(
                                              semanticsLabel:
                                                  'Loading replies'),
                                        if (_focusError != null)
                                          Text(_focusError!),
                                        if (_focusedReply != null) ...[
                                          const SizedBox(height: 16),
                                          Row(key: _focusKey, children: [
                                            const Expanded(
                                                child:
                                                    Text('Selected comment')),
                                            IconButton(
                                                tooltip:
                                                    'Close selected comment',
                                                onPressed: () => setState(
                                                    () => _focusedReply = null),
                                                icon: const Icon(Icons.close)),
                                          ]),
                                          _comment(_focusedReply!),
                                          _line(),
                                        ],
                                        for (final reply in _replies) ...[
                                          KeyedSubtree(
                                              key: _replyKeys.putIfAbsent(
                                                  reply['id'],
                                                  () => GlobalKey()),
                                              child: _comment(reply)),
                                          _line()
                                        ],
                                        if (_replies.isEmpty &&
                                            !_more &&
                                            _replyError == null)
                                          const Padding(
                                              padding: EdgeInsets.symmetric(
                                                  vertical: 24),
                                              child: Text(
                                                  'No replies yet. Add the first thought.')),
                                        if (_replyError != null)
                                          CommunityRetry(
                                              message: _replyError!,
                                              onRetry: () => _loadReplies(
                                                  more: _failedMore)),
                                        if (_next != null)
                                          TextButton(
                                              onPressed: _more
                                                  ? null
                                                  : () =>
                                                      _loadReplies(more: true),
                                              child: LoadingActionLabel(
                                                  loading: _more,
                                                  text: 'More replies')),
                                        const SizedBox(height: 20),
                                      ],
                                    ],
                                  ]))),
                      if (_thread != null && _error == null && !_hidden)
                        if (_member)
                          _replyComposer()
                        else
                          Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(children: [
                                const Text('Join this community to reply.'),
                                FilledButton(
                                    onPressed: _joining ? null : _join,
                                    child: Text(_joining
                                        ? 'Joining…'
                                        : 'Join community')),
                              ])),
                    ])))));
  }
}
