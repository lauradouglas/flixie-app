import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import '../../data/friend_activity_service.dart';

class FriendActivityScreen extends StatefulWidget {
  const FriendActivityScreen(
      {super.key,
      required this.ownerId,
      required this.type,
      required this.postId,
      this.service = const FriendActivityService()});
  final String ownerId, type, postId;
  final FriendActivityService service;
  @override
  State<FriendActivityScreen> createState() => _FriendActivityScreenState();
}

class _FriendActivityScreenState extends State<FriendActivityScreen> {
  ActivityListItem? _post;
  final _draft = TextEditingController();
  final List<ActivityComment> _comments = [];
  final Set<String> _revealed = {}, _deleting = {};
  String? _cursor, _error, _commentError, _sendError;
  String _draftId = FriendActivityService.newCommentId();
  bool _loading = true, _more = false, _sending = false, _spoilers = false;
  int _generation = 0, _commentGeneration = 0;
  @override
  void initState() {
    super.initState();
    _load();
    SafetyService.changes.addListener(_blocked);
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_blocked);
    _draft.dispose();
    super.dispose();
  }

  void _blocked() {
    if (!mounted) return;
    if (SafetyService.isBlocked(widget.ownerId)) {
      ++_generation;
      ++_commentGeneration;
      setState(() {
        _post = null;
        _comments.clear();
        _loading = false;
        _error = 'This post is unavailable.';
      });
    } else {
      setState(() =>
          _comments.removeWhere((r) => SafetyService.isBlocked(r.author.id)));
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final post =
          await widget.service.post(widget.ownerId, widget.type, widget.postId);
      if (!mounted || generation != _generation) return;
      setState(() => _post = post);
      await _loadComments();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() {
          _post = null;
          _comments.clear();
          _error =
              'This post is unavailable or couldn’t load. You may no longer have access to it.';
        });
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadComments({bool more = false}) async {
    if (_post == null || (more && _more)) return;
    final generation = _generation;
    final commentGeneration = ++_commentGeneration;
    setState(() {
      _more = true;
      _commentError = null;
    });
    try {
      final page =
          await widget.service.comments(_post!, cursor: more ? _cursor : null);
      if (mounted &&
          generation == _generation &&
          commentGeneration == _commentGeneration) {
        setState(() {
          if (!more) _comments.clear();
          final ids = _comments.map((r) => r.id).toSet();
          _comments.addAll(page.items.where(
              (r) => !SafetyService.isBlocked(r.author.id) && ids.add(r.id)));
          _cursor = page.nextCursor;
        });
      }
    } catch (_) {
      if (mounted &&
          generation == _generation &&
          commentGeneration == _commentGeneration) {
        setState(() => _commentError = 'Couldn’t load comments.');
      }
    } finally {
      if (mounted &&
          generation == _generation &&
          commentGeneration == _commentGeneration) {
        setState(() => _more = false);
      }
    }
  }

  Future<void> _send() async {
    if (_sending || _post == null || _draft.text.trim().isEmpty) return;
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      await widget.service.comment(_post!,
          id: _draftId, body: _draft.text.trim(), spoilers: _spoilers);
      if (!mounted) return;
      _draft.clear();
      _draftId = FriendActivityService.newCommentId();
      setState(() => _spoilers = false);
      FocusScope.of(context).unfocus();
      await _loadComments();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Comment posted.')));
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _sendError = 'Couldn’t post. Your draft is still here; try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(ActivityComment comment) async {
    if (_deleting.contains(comment.id) || _post == null) return;
    setState(() => _deleting.add(comment.id));
    try {
      await widget.service.deleteComment(_post!, comment.id);
      if (mounted) {
        setState(() => _comments.removeWhere((r) => r.id == comment.id));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t delete this comment. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _deleting.remove(comment.id));
    }
  }

  @override
  Widget build(BuildContext context) => FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('Post'), centerTitle: true),
      body: LayoutBuilder(
          builder: (context, constraints) => Column(children: [
                Expanded(
                    child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              if (_loading)
                                const Center(child: CircularProgressIndicator())
                              else if (_error != null) ...[
                                Text(_error!),
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('Try again'))
                              ] else if (_post case final post?) ...[
                                ActivityTile(
                                    item: post,
                                    showComments: false,
                                    postDetail: true),
                                const SizedBox(height: 12),
                                Text(
                                    'Comments${_comments.isEmpty ? '' : ' · ${_comments.length}${_cursor != null ? '+' : ''}'}',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 8),
                                const Text(
                                    'Visible to the author and their friends.'),
                                const SizedBox(height: 12),
                                if (_comments.isEmpty &&
                                    _commentError == null &&
                                    !_more)
                                  const Text(
                                      'No comments yet. Start the conversation.'),
                                for (final comment in _comments)
                                  Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 20),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(children: [
                                              SizedBox(
                                                  width: 40,
                                                  height: 40,
                                                  child: Center(
                                                      child: ProfileAvatarView(
                                                          fallbackColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary,
                                                          avatar: comment
                                                              .author.avatar,
                                                          profileBadges: comment
                                                              .author
                                                              .profileBadges,
                                                          size: 32,
                                                          fallbackText: comment
                                                                  .author
                                                                  .username
                                                                  .isEmpty
                                                              ? '?'
                                                              : comment.author
                                                                      .username[
                                                                  0]))),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                  child: Text(
                                                      '${comment.author.username}${comment.createdAt == null ? '' : ' · ${_age(comment.createdAt!)}'}',
                                                      style: const TextStyle(
                                                          fontWeight: FontWeight
                                                              .w700))),
                                              if (comment.author.id ==
                                                  context
                                                      .read<AuthProvider?>()
                                                      ?.dbUser
                                                      ?.id)
                                                IconButton(
                                                    tooltip: 'Delete comment',
                                                    onPressed: _deleting.contains(
                                                            comment.id)
                                                        ? null
                                                        : () =>
                                                            _delete(comment),
                                                    icon: const Icon(
                                                        Icons.delete_outline))
                                              else
                                                IconButton(
                                                    tooltip:
                                                        'Report or block comment',
                                                    icon: const Icon(
                                                        Icons.more_horiz),
                                                    onPressed: () => SafetyActions.contentMenu(
                                                        context,
                                                        targetType:
                                                            'ACTIVITY_COMMENT',
                                                        targetId: comment.id,
                                                        reportedUserId:
                                                            comment.author.id,
                                                        username: comment
                                                            .author.username,
                                                        contentPreview:
                                                            comment.body)),
                                            ]),
                                            const SizedBox(height: 8),
                                            if (comment.containsSpoilers &&
                                                !_revealed.contains(comment.id))
                                              TextButton(
                                                  onPressed: () => setState(
                                                      () => _revealed
                                                          .add(comment.id)),
                                                  child: const Text(
                                                      'Show comment · contains spoilers'))
                                            else
                                              Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          left: 52),
                                                  child: Text(comment.body,
                                                      style: const TextStyle(
                                                          fontSize: 15,
                                                          height: 1.5))),
                                          ])),
                                if (_commentError != null) ...[
                                  Text(_commentError!),
                                  TextButton(
                                      onPressed: () =>
                                          _loadComments(more: _cursor != null),
                                      child: const Text('Retry comments'))
                                ],
                                if (_cursor != null || _more)
                                  TextButton(
                                      onPressed: _more
                                          ? null
                                          : () => _loadComments(more: true),
                                      child: Text(_more
                                          ? 'Loading comments…'
                                          : 'More comments')),
                              ],
                            ]))),
                if (!_loading && _error == null && _post != null)
                  ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * .45),
                      child: SingleChildScrollView(child: _composer())),
              ])));

  String _age(DateTime date) {
    final duration = DateTime.now().difference(date);
    if (duration.inMinutes < 1) return 'Just now';
    if (duration.inHours < 1) return '${duration.inMinutes}m';
    if (duration.inDays < 1) return '${duration.inHours}h';
    return '${duration.inDays}d';
  }

  Widget _composer() => SafeArea(
      top: false,
      child: Container(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          decoration: BoxDecoration(
              color: context.colors.background,
              border: Border(
                  top: BorderSide(
                      color: context.colors.medium.withValues(alpha: .35)))),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_sendError != null)
                  Semantics(
                      liveRegion: true,
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_sendError!,
                              style: TextStyle(
                                  color: context.colors.textPrimary)))),
                FilterChip(
                    label: const Text('Contains spoilers'),
                    selected: _spoilers,
                    onSelected: _sending
                        ? null
                        : (value) => setState(() => _spoilers = value)),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Expanded(
                      child: TextField(
                          controller: _draft,
                          onChanged: (_) => setState(() {}),
                          enabled: !_sending,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: InputDecoration(
                              hintText: 'Write a comment…',
                              counterText: '',
                              filled: true,
                              fillColor: context.colors.surface,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16))))),
                  const SizedBox(width: 10),
                  IconButton.filled(
                      tooltip: _sending ? 'Posting…' : 'Post comment',
                      onPressed:
                          _sending || _draft.text.trim().isEmpty ? null : _send,
                      icon: const Icon(Icons.send_outlined)),
                ]),
              ])));
}
