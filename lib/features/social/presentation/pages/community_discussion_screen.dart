import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/notification_opt_in.dart';
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
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

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
  Map<String, dynamic>? _thread;
  final _replies = <Map<String, dynamic>>[];
  final _body = TextEditingController();
  final _replyFocus = FocusNode();
  final _composerKey = GlobalKey();
  final _focusKey = GlobalKey();
  final Map<String, String> _mentions = {};
  Map<String, dynamic>? _replyTo, _focusedReply;
  bool _member = false, _joining = false, _postedReply = false;
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
    final targetContext = _replyKeys[id]?.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(targetContext,
          alignment: .3,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 220));
      _highlightReply(id);
      return;
    }
    try {
      final reply = await widget.service.get(widget.communityId, '/replies/$id',
          {'reveal': 'true', 'discussionId': widget.discussionId});
      if (mounted) {
        setState(() {
          _focusedReply = reply;
          _focusError = null;
        });
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _focusKey.currentContext != null) {
          Scrollable.ensureVisible(_focusKey.currentContext!);
          _highlightReply(id);
        }
      });
    } catch (_) {
      if (mounted) {
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

  String? _error, _replyError, _next, _sendError;
  bool _reveal = false,
      _loading = true,
      _sending = false,
      _more = false,
      _failedMore = false;
  int _generation = 0;
  String get _path => '/discussions/${widget.discussionId}';
  bool get _hidden => _thread?['spoiler'] != 'none' && !_reveal;
  @override
  void initState() {
    super.initState();
    _member = widget.joined ?? false;
    SafetyService.changes.addListener(_safetyChanged);
    _load();
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_safetyChanged);
    _highlightTimer?.cancel();
    _replyFocus.dispose();
    _body.dispose();
    super.dispose();
  }

  void _safetyChanged() {
    setState(() {
      _thread = null;
      _replies.clear();
      _focusedReply = null;
      _replyTo = null;
    });
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (widget.joined == null) {
        final membership = await widget.service.get(widget.communityId, '');
        if (mounted) _member = membership['joined'] == true;
      }
      final thread = await widget.service
          .get(widget.communityId, _path, {if (_reveal) 'reveal': 'true'});
      if (!mounted || generation != _generation) return;
      setState(() => _thread = thread);
      if (!_hidden) {
        await _loadReplies();
        if (widget.initialReplyId != null) {
          await _focusReply(widget.initialReplyId!);
        }
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error =
            'This discussion couldn’t be loaded. It may no longer be available.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadReplies({bool more = false}) async {
    if (more && (_more || _next == null)) return;
    final generation = _generation;
    setState(() {
      _more = true;
      _replyError = null;
    });
    try {
      final page = await widget.service.get(widget.communityId,
          '$_path/replies', {'reveal': 'true', if (more) 'cursor': _next!});
      if (!mounted || generation != _generation) return;
      setState(() {
        if (!more) _replies.clear();
        final ids = _replies.map((e) => e['id']).toSet();
        _replies.addAll((page['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .where((e) => ids.add(e['id'])));
        _next = page['nextCursor'];
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _failedMore = more;
          _replyError = 'Couldn’t load replies. Try again.';
        });
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _more = false);
    }
  }

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
      await _loadReplies();
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
        await _loadReplies();
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

  Widget _author(Map<String, dynamic> row, {bool reply = false}) {
    final user =
        FriendshipUser.fromJson(Map<String, dynamic>.from(row['user']));
    final own = user.id == context.read<AuthProvider>().dbUser?.id;
    return Row(children: [
      Padding(
          padding: const EdgeInsets.all(4),
          child: ProfileAvatarView(
              avatar: user.avatar,
              profileBadges: user.profileBadges,
              size: 32,
              fallbackColor: context.colors.primary,
              fallbackText: user.username.isEmpty ? '?' : user.username[0])),
      const SizedBox(width: 8),
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
            user.firstName?.trim().isNotEmpty == true
                ? user.firstName!
                : user.username,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        Text(
            [
              if (DateTime.tryParse(row['createdAt']?.toString() ?? '') != null)
                communityRelativeTime(DateTime.parse(row['createdAt'])),
              if (!reply) 'Started this discussion',
            ].join(' · '),
            style: TextStyle(fontSize: 11, color: context.colors.light)),
      ])),
      PopupMenuButton<String>(
          tooltip: 'Comment options',
          icon: const Icon(Icons.more_horiz),
          itemBuilder: (_) => [
                if (own)
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                if (!own) ...[
                  const PopupMenuItem(
                      value: 'mute', child: Text('Mute author')),
                  const PopupMenuItem(
                      value: 'report', child: Text('Report or block')),
                ]
              ],
          onSelected: (action) async {
            if (action == 'delete') {
              await _delete(row, reply: reply);
              return;
            }
            if (action == 'report') {
              SafetyActions.contentMenu(context,
                  targetType: reply
                      ? 'COMMUNITY_DISCUSSION_REPLY'
                      : 'COMMUNITY_DISCUSSION',
                  targetId: row['id'],
                  reportedUserId: user.id,
                  username: user.username,
                  contentPreview:
                      _hidden ? 'Spoiler discussion' : row['body'] ?? '');
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
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Couldn’t mute author. Try again.')));
              }
            }
          }),
    ]);
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

  ButtonStyle _threadLinkStyle({bool parent = false}) => TextButton.styleFrom(
        foregroundColor:
            parent ? context.colors.light : context.colors.primaryText,
        textStyle: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            height: 1.6,
            letterSpacing: 0),
        padding: EdgeInsets.zero,
        minimumSize: const Size(44, 44),
        alignment: Alignment.centerLeft,
        tapTargetSize: MaterialTapTargetSize.padded,
      );

  TextStyle get _bodyStyle => TextStyle(
      fontFamily: 'Manrope',
      fontSize: 15,
      height: 1.7,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      color: context.colors.light);

  Widget _comment(Map<String, dynamic> reply) => AnimatedContainer(
      key: ValueKey('reply-highlight-${reply['id']}'),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
          color: _highlightedReplyId == reply['id']
              ? context.colors.primaryText.withValues(alpha: .16)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10)),
      child: _commentContent(reply));

  Widget _commentContent(Map<String, dynamic> reply) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _author(reply, reply: true),
        if (reply['parentReply'] != null)
          TextButton.icon(
            style: _threadLinkStyle(parent: true),
            onPressed: () => _focusReply(reply['parentReply']['id']),
            icon: const Icon(Icons.reply, size: 16),
            label: Text.rich(TextSpan(children: [
              const TextSpan(text: 'Replying to '),
              TextSpan(
                  text: '@${reply['parentReply']['user']['username']}',
                  style: TextStyle(color: context.colors.primaryText))
            ])),
          )
        else if (reply['parentReplyId'] != null)
          const Text('Replying to an unavailable comment'),
        const SizedBox(height: 10),
        CommunityMentionText(reply['body'] ?? '', style: _bodyStyle),
        if (_member)
          TextButton.icon(
              style: _threadLinkStyle(),
              onPressed: () => _target(reply),
              icon: const Icon(Icons.reply, size: 17),
              label: const Text('Reply')),
      ]));

  Widget _replyComposer() => Container(
      key: _composerKey,
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
              top: BorderSide(
                  color: context.colors.light.withValues(alpha: .2)))),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .38),
          child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (_postedReply)
                  const NotificationOptIn(
                      message:
                          'Keep the conversation going. Enable notifications for replies and other Flixie updates. You can manage them in Settings.'),
                if (_replyTo != null)
                  Row(children: [
                    Icon(Icons.reply,
                        size: 18, color: context.colors.primaryText),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(
                            'Replying to @${_replyTo!['user']['username']}',
                            style: TextStyle(
                                fontSize: 12,
                                color: context.colors.primaryText))),
                    IconButton(
                        tooltip: 'Cancel reply target',
                        onPressed: _sending
                            ? null
                            : () => setState(() => _replyTo = null),
                        icon: const Icon(Icons.close, size: 18)),
                  ]),
                Material(
                    color: Colors.transparent,
                    child: CommunityMentionSuggestions(
                        discussionId: widget.discussionId,
                        controller: _body,
                        communityId: widget.communityId,
                        service: widget.service,
                        selected: _mentions)),
                if (_sendError != null)
                  Row(children: [
                    Expanded(
                        child: Text(_sendError!,
                            style: TextStyle(
                                color: context.colors.light, fontSize: 12))),
                    TextButton(
                        onPressed: _sending ? null : _send,
                        child: const Text('Try again')),
                  ]),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: TextField(
                          focusNode: _replyFocus,
                          controller: _body,
                          style: _bodyStyle,
                          enabled: !_sending,
                          maxLength: 3000,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Your reply',
                              hintText: 'Add to the conversation…',
                              labelStyle: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w400),
                              hintStyle: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w400),
                              counterText: '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false))),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _body,
                      builder: (_, value, __) => IconButton.filled(
                          tooltip: _sending ? 'Posting…' : 'Post reply',
                          onPressed: _sending || value.text.trim().isEmpty
                              ? null
                              : _send,
                          icon: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.arrow_upward))),
                ]),
                Text('@ a friend in this community or someone in this thread',
                    style:
                        TextStyle(fontSize: 11, color: context.colors.light)),
              ]))));

  @override
  Widget build(BuildContext context) {
    final title = _thread?['movie'] ?? _thread?['show'];
    final poster = title?['posterPath'] as String?;
    return Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
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
                                            style: _bodyStyle),
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

class CommunityDiscussionComposer extends StatefulWidget {
  const CommunityDiscussionComposer(
      {super.key, required this.communityId, required this.service});
  final int communityId;
  final CommunitySpaceService service;
  @override
  State<CommunityDiscussionComposer> createState() =>
      _CommunityDiscussionComposerState();
}

class _CommunityDiscussionComposerState
    extends State<CommunityDiscussionComposer> {
  final _form = GlobalKey<FormState>();
  final Map<String, String> _mentions = {};
  final _title = TextEditingController(),
      _body = TextEditingController(),
      _query = TextEditingController(),
      _season = TextEditingController(),
      _episode = TextEditingController();
  List<Map<String, dynamic>> _titles = [];
  Map<String, dynamic>? _selected;
  String _spoiler = 'none';
  String? _error, _searchError;
  bool _sending = false, _searching = false;
  int _searchRevision = 0;
  @override
  void dispose() {
    for (final c in [_title, _body, _query, _season, _episode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _searchError = 'Type at least two characters.');
      return;
    }
    final revision = ++_searchRevision;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final page =
          await widget.service.get(widget.communityId, '/titles', {'q': q});
      if (mounted && revision == _searchRevision) {
        setState(() => _titles = (page['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (_) {
      if (mounted && revision == _searchRevision) {
        setState(() => _searchError = 'Couldn’t search titles. Try again.');
      }
    } finally {
      if (mounted && revision == _searchRevision) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _publish() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.post(widget.communityId, '/discussions', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'spoiler': _spoiler,
        'mentionIds':
            activeCommunityMentions(_mentions, '${_title.text} ${_body.text}'),
        if (_selected != null)
          (_selected!['kind'] == 'show' ? 'showId' : 'movieId'):
              _selected!['id'],
        if (_spoiler == 'episode') 'season': int.parse(_season.text),
        if (_spoiler == 'episode') 'episode': int.parse(_episode.text)
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t publish. Your draft is kept. Check the selected title, episode and membership, then try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _required(String? value, int min) =>
      value == null || value.trim().length < min
          ? 'Enter at least $min characters.'
          : null;
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_sending,
      child: Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(title: const Text('Start a discussion')),
          body: SafeArea(
              child: Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    const Text(
                        'Published discussions are visible to people browsing this community. Keep the title spoiler-free; label any spoilers in the post.'),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _title,
                        enabled: !_sending,
                        maxLength: 180,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'What would you like to talk about?'),
                        validator: (v) => _required(v, 3)),
                    CommunityMentionSuggestions(
                        controller: _title,
                        additionalController: _body,
                        communityId: widget.communityId,
                        service: widget.service,
                        selected: _mentions),
                    const SizedBox(height: 12),
                    Text('About a title (optional)',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (_selected == null) ...[
                      TextField(
                          controller: _query,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                              labelText: 'Search films or series'),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search()),
                      TextButton(
                          onPressed: _searching || _sending ? null : _search,
                          child: Text(
                              _searching ? 'Searching…' : 'Search titles')),
                      if (_searchError != null) Text(_searchError!),
                      if (_titles.isEmpty &&
                          _query.text.length >= 2 &&
                          !_searching &&
                          _searchError == null)
                        const Text(
                            'No matching titles loaded. Try another search or start a general question.'),
                      for (final t in _titles)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t['title']),
                            subtitle:
                                Text(t['kind'] == 'show' ? 'Series' : 'Film'),
                            onTap: _sending
                                ? null
                                : () => setState(() {
                                      _selected = t;
                                      _titles = [];
                                    })),
                    ] else
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_selected!['title']),
                          subtitle: const Text('Selected title'),
                          trailing: IconButton(
                              tooltip: 'Remove title',
                              onPressed: _sending
                                  ? null
                                  : () => setState(() {
                                        _selected = null;
                                        _spoiler = 'none';
                                      }),
                              icon: const Icon(Icons.close))),
                    if (_selected != null)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: _spoiler,
                        decoration: const InputDecoration(
                            labelText: 'Spoiler boundary'),
                        items: [
                          const DropdownMenuItem(
                              value: 'none', child: Text('Spoiler-free')),
                          const DropdownMenuItem(
                              value: 'full',
                              child: Text('Full-title spoilers')),
                          if (_selected!['kind'] == 'show')
                            const DropdownMenuItem(
                                value: 'episode',
                                child: Text('Through an episode'))
                        ],
                        onChanged: _sending
                            ? null
                            : (v) => setState(() => _spoiler = v!),
                      ),
                    if (_spoiler == 'episode') ...[
                      TextFormField(
                          controller: _season,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Season number'),
                          validator: (v) =>
                              int.tryParse(v ?? '') == null || int.parse(v!) < 0
                                  ? 'Enter a valid season.'
                                  : null),
                      TextFormField(
                          controller: _episode,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Episode number'),
                          validator: (v) =>
                              int.tryParse(v ?? '') == null || int.parse(v!) < 1
                                  ? 'Enter a valid episode.'
                                  : null),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _body,
                        enabled: !_sending,
                        minLines: 5,
                        maxLines: 12,
                        maxLength: 5000,
                        decoration:
                            const InputDecoration(labelText: 'Your post'),
                        validator: (v) => _required(v, 1)),
                    CommunityMentionSuggestions(
                        controller: _body,
                        additionalController: _title,
                        communityId: widget.communityId,
                        service: widget.service,
                        selected: _mentions),
                    const Text(
                        'Type @ to mention a friend who joined this community.',
                        style: TextStyle(fontSize: 12)),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_error!)),
                    FilledButton(
                        onPressed: _sending ? null : _publish,
                        child: Text(
                            _sending ? 'Publishing…' : 'Publish discussion')),
                  ])))));
}
