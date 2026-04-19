import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/conversation.dart';
import '../../models/group.dart';
import '../../models/group_member.dart';
import '../../models/group_watch_request.dart';
import '../../models/notification.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/group_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import 'chat_bubble.dart';
import 'chat_input.dart';
import 'watch_request_chat_card.dart';

class GroupChatTab extends StatefulWidget {
  const GroupChatTab({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupChatTab> createState() => GroupChatTabState();
}

class GroupChatTabState extends State<GroupChatTab> {
  final TextEditingController _messageController = TextEditingController();
  String? _conversationId;
  bool _initLoading = true;
  bool _sending = false;
  String? _initError;
  AuthProvider? _authProvider;
  // userId → username, populated from the members subcollection
  Map<String, String> _memberUsernames = {};

  // Watch-request card state: postgres UUID → full GroupWatchRequest from API
  final Map<String, GroupWatchRequest> _requestCache = {};
  // Backward-compat: Firestore message doc ID → postgres UUID.
  // Only needed for legacy messages that don't carry pgGroupRequestId directly.
  // After the BE writes pgGroupRequestId on the message doc this becomes unused.
  final Map<String, String> _msgIdToReqId = {};
  final Set<String> _respondingIds = {};
  final Map<String, String> _respondMap =
      {}; // pgUUID → 'ACCEPTED'|'DECLINED'|'MAYBE'
  // True once the first successful API fetch has completed.
  // Prevents the itemBuilder from repeatedly triggering fetches on every rebuild.
  bool _requestsLoaded = false;
  bool _fetchingRequests = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_authProvider == null) {
      _authProvider = context.read<AuthProvider>();
      _authProvider!.addListener(_onAuthChanged);
    }
  }

  void _onAuthChanged() {
    // Retry init if we were waiting for the user to load
    if (_initLoading && _authProvider?.dbUser != null) {
      _initConversation();
    }
  }

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback so context is fully ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initConversation();
    });
  }

  @override
  void dispose() {
    _authProvider?.removeListener(_onAuthChanged);
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _initConversation() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      // dbUser not ready yet — listener will retry once it loads
      return;
    }
    if (!_initLoading) return; // already resolved
    try {
      final results = await Future.wait([
        GroupService.getGroup(widget.groupId),
        GroupService.getGroupMembers(widget.groupId),
      ]);
      final group = results[0] as Group;
      final members = results[1] as List<GroupMember>;
      final memberIds = members.map((m) => m.memberId).toList();
      if (!memberIds.contains(userId)) memberIds.add(userId);

      final conversation = await ChatService.getOrCreateGroupConversation(
        creatorId: userId,
        pgGroupId: widget.groupId,
        name: group.name,
        memberIds: memberIds,
      );

      if (mounted) {
        // Fetch member usernames and watch requests in parallel so that
        // request cards render with correct state on first paint (no flicker).
        final conversationId = conversation.id;
        final parallelResults = await Future.wait([
          ChatService.fetchMemberUsernames(conversationId)
              .catchError((_) => <String, String>{}),
          GroupService.getConversationWatchRequests(
            conversationId,
            filter: WatchRequestFilter.all,
            userId: userId,
          ).catchError((_) => <GroupWatchRequest>[]),
        ]);
        if (mounted) {
          final usernames = parallelResults[0] as Map<String, String>;
          final requests = parallelResults[1] as List<GroupWatchRequest>;
          setState(() {
            _conversationId = conversationId;
            _memberUsernames = usernames;
            for (final r in requests) {
              _requestCache[r.id] = r;
            }
            _requestsLoaded = true;
            _initLoading = false;
          });
        }
        ChatService.markRead(conversationId, userId).catchError((_) {});
      }
    } catch (e) {
      logger.e('Chat init error: $e');
      if (mounted) {
        setState(() {
          _initLoading = false;
          _initError = 'Could not load chat';
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    final conversationId = _conversationId;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (text.isEmpty || conversationId == null || userId == null) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ChatService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        text: text,
      );
    } catch (e) {
      logger.e('Send message error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Loads all watch requests from the API and caches them by postgres UUID.
  /// Also builds a legacy messageId→pgUUID map from the Firestore watchRequests
  /// subcollection for messages that don't carry pgGroupRequestId directly.
  Future<void> _ensureRequests() async {
    if (_requestsLoaded || _fetchingRequests) return;
    final conversationId = _conversationId;
    if (conversationId == null) return;
    final userId = _authProvider?.dbUser?.id;
    _fetchingRequests = true;
    try {
      // Primary: fetch all data from postgres via the API.
      final requests = await GroupService.getConversationWatchRequests(
        conversationId,
        filter: WatchRequestFilter.all,
        userId: userId,
      );

      // Backward-compat: scan the Firestore watchRequests subcollection ONLY
      // to build the messageId → pgGroupRequestId mapping for legacy messages.
      // Once the BE writes pgGroupRequestId on the message doc itself, this
      // fetch is unnecessary and can be removed.
      // Wrapped in its own try/catch — permission errors here must not abort
      // the API results already fetched above.
      final newMsgMap = <String, String>{};
      try {
        final wrDocs = await ChatService.fetchWatchRequestDocs(conversationId);
        for (final doc in wrDocs.values) {
          final pgId = doc['pgGroupRequestId'] as String?;
          final linkedMsgId = doc['linkedMessageId'] as String?;
          if (pgId != null &&
              pgId.isNotEmpty &&
              linkedMsgId != null &&
              linkedMsgId.isNotEmpty) {
            newMsgMap[linkedMsgId] = pgId;
          }
        }
      } catch (e) {
        logger.w('[WR] Firestore watchRequests fetch failed (non-fatal): $e');
      }

      if (!mounted) return;
      if (!mounted) return;
      setState(() {
        for (final r in requests) {
          _requestCache[r.id] = r;
        }
        _msgIdToReqId.addAll(newMsgMap);
        _requestsLoaded = true;
        logger.d('[WR] requestCache: ${_requestCache.keys.toList()}');
        logger.d('[WR] msgIdToReqId: $_msgIdToReqId');
      });
      _fetchingRequests = false;
    } catch (e) {
      _fetchingRequests = false;
      logger.e('[WR] _ensureRequests error: $e');
    }
  }

  Future<void> _respondInChat(
      String pgId, WatchResponseDecision decision) async {
    final conversationId = _conversationId;
    final userId = _authProvider?.dbUser?.id;
    if (conversationId == null || userId == null) return;
    setState(() {
      _respondingIds.add(pgId);
      _respondMap[pgId] = decision.apiValue.toUpperCase();
    });
    try {
      await GroupService.respondToWatchRequest(
          conversationId, pgId, userId, decision);
      // Dismiss any watch-request notifications linked to this request.
      NotificationService.getNotifications(userId).then((notifs) {
        for (final n in notifs) {
          if ((n.type == FlixieNotification.movieWatchRequest ||
                  n.type == FlixieNotification.showWatchRequest) &&
              n.linkedRequestId == pgId &&
              n.closed != true) {
            NotificationService.updateNotification(n.id!, closed: true)
                .catchError((_) => FlixieNotification(
                    userId: userId, type: n.type, message: n.message));
          }
        }
      }).catchError((_) {});
      _requestsLoaded = false;
      await _ensureRequests();
    } catch (e) {
      if (mounted) {
        setState(() => _respondMap.remove(pgId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Failed to respond'),
              backgroundColor: FlixieColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _respondingIds.remove(pgId));
    }
  }

  Widget _modalCountPill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  void _showWatchRequestDetail(
    BuildContext context,
    ChatMessage msg,
    List<ChatMessage> allMessages,
    GroupWatchRequest? req,
    String? currentUserId,
  ) {
    final payload = msg.watchRequestPayload;
    final movieTitle =
        req?.movieTitle ?? payload?['movieTitle'] as String? ?? 'Watch Request';
    final posterPath = req?.moviePosterPath ??
        payload?['moviePosterPath'] as String? ??
        payload?['posterPath'] as String?;
    final requestMessage = req?.message ?? payload?['message'] as String?;
    final requesterUsername = req?.requesterUsername ??
        payload?['requesterUsername'] as String? ??
        msg.senderUsername;
    final posterUrl = posterPath != null
        ? 'https://image.tmdb.org/t/p/w500$posterPath'
        : null;
    final memberStatuses = req?.memberStatuses ?? <GroupRequestMemberStatus>[];

    // Collect thread replies (messages whose replyToMessageId = this message)
    final replies = allMessages
        .where((m) => m.replyToMessageId == msg.id)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    final replyController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.82,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) {
          bool isSendingReply = false;
          return StatefulBuilder(
            builder: (_, setSheetState) {
              return Column(
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    decoration: BoxDecoration(
                      color: FlixieColors.medium.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        // Poster + title row
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 80,
                                height: 120,
                                child: posterUrl != null
                                    ? CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(
                                            color: FlixieColors
                                                .tabBarBackgroundFocused),
                                        errorWidget: (_, __, ___) => Container(
                                          color: FlixieColors
                                              .tabBarBackgroundFocused,
                                          child: const Center(
                                              child: Icon(Icons.movie_outlined,
                                                  color: FlixieColors.medium,
                                                  size: 28)),
                                        ),
                                      )
                                    : Container(
                                        decoration: BoxDecoration(
                                          color: FlixieColors
                                              .tabBarBackgroundFocused,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: const Center(
                                            child: Icon(Icons.movie_outlined,
                                                color: FlixieColors.medium,
                                                size: 28)),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(movieTitle,
                                      style: const TextStyle(
                                          color: FlixieColors.white,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700)),
                                  if (requesterUsername != null) ...[
                                    const SizedBox(height: 4),
                                    Text('Requested by @$requesterUsername',
                                        style: const TextStyle(
                                            color: FlixieColors.medium,
                                            fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (requestMessage != null &&
                            requestMessage.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color:
                                  FlixieColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: FlixieColors.primary
                                      .withValues(alpha: 0.25)),
                            ),
                            child: Text(requestMessage,
                                style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic)),
                          ),
                        ],
                        // Responses — grouped by status
                        if (memberStatuses.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Text('RESPONSES',
                                  style: TextStyle(
                                      color: FlixieColors.medium,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8)),
                              const Spacer(),
                              if (req?.acceptedCount != null &&
                                  req!.acceptedCount > 0)
                                _modalCountPill('✓ ${req.acceptedCount}',
                                    FlixieColors.success),
                              if (req?.maybeCount != null &&
                                  req!.maybeCount > 0) ...[
                                const SizedBox(width: 4),
                                _modalCountPill('~ ${req.maybeCount}',
                                    FlixieColors.warning),
                              ],
                              if (req?.declinedCount != null &&
                                  req!.declinedCount > 0) ...[
                                const SizedBox(width: 4),
                                _modalCountPill('✗ ${req.declinedCount}',
                                    FlixieColors.danger),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          for (final group in [
                            (
                              'ACCEPTED',
                              FlixieColors.success,
                              Icons.check_circle_outline
                            ),
                            ('MAYBE', FlixieColors.warning, Icons.help_outline),
                            (
                              'DECLINED',
                              FlixieColors.danger,
                              Icons.cancel_outlined
                            ),
                          ]) ...[
                            ...memberStatuses
                                .where((s) => s.status == group.$1)
                                .map((s) {
                              final name = s.username?.isNotEmpty == true
                                  ? s.username!
                                  : s.memberId.substring(
                                      0, s.memberId.length.clamp(0, 6));
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor:
                                          group.$2.withValues(alpha: 0.15),
                                      child: Text(
                                          name.isNotEmpty
                                              ? name[0].toUpperCase()
                                              : '?',
                                          style: TextStyle(
                                              color: group.$2,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text('@$name',
                                          style: const TextStyle(
                                              color: FlixieColors.light,
                                              fontSize: 13)),
                                    ),
                                    Icon(group.$3, size: 14, color: group.$2),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                        // Thread replies
                        const SizedBox(height: 16),
                        Text(
                            replies.isEmpty
                                ? 'No replies yet'
                                : 'REPLIES (${replies.length})',
                            style: const TextStyle(
                                color: FlixieColors.medium,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 8),
                        if (replies.isEmpty)
                          const Text('Be the first to comment!',
                              style: TextStyle(
                                  color: FlixieColors.medium, fontSize: 13))
                        else
                          ...replies.map((r) {
                            final rUsername = r.senderUsername ??
                                _memberUsernames[r.senderId] ??
                                r.senderId.substring(
                                    0, r.senderId.length.clamp(0, 6));
                            final isMe = r.senderId == currentUserId;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor:
                                        FlixieColors.tabBarBackgroundFocused,
                                    child: Text(
                                        rUsername.isNotEmpty
                                            ? rUsername[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                            color: FlixieColors.light,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700)),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(isMe ? 'You' : '@$rUsername',
                                            style: const TextStyle(
                                                color: FlixieColors.medium,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(r.text,
                                            style: const TextStyle(
                                                color: FlixieColors.light,
                                                fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  // Reply input
                  Container(
                    padding: EdgeInsets.fromLTRB(12, 8, 12,
                        MediaQuery.of(sheetCtx).viewInsets.bottom + 8),
                    decoration: const BoxDecoration(
                      color: FlixieColors.tabBarBackgroundFocused,
                      border: Border(
                          top: BorderSide(color: FlixieColors.tabBarBorder)),
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: replyController,
                              style: const TextStyle(color: FlixieColors.light),
                              textInputAction: TextInputAction.send,
                              decoration: InputDecoration(
                                hintText: 'Reply to this request…',
                                hintStyle:
                                    const TextStyle(color: FlixieColors.medium),
                                filled: true,
                                fillColor: FlixieColors.tabBarBackground,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (isSendingReply)
                            const SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: FlixieColors.primary),
                            )
                          else
                            IconButton(
                              onPressed: () async {
                                final text = replyController.text.trim();
                                if (text.isEmpty) return;
                                final cId = _conversationId;
                                final uid = _authProvider?.dbUser?.id;
                                if (cId == null || uid == null) return;
                                setSheetState(() => isSendingReply = true);
                                replyController.clear();
                                try {
                                  await ChatService.sendMessage(
                                    conversationId: cId,
                                    senderId: uid,
                                    text: text,
                                    replyToMessageId: msg.id,
                                  );
                                  if (sheetCtx.mounted) {
                                    Navigator.pop(sheetCtx);
                                  }
                                } catch (_) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Failed to send reply'),
                                          backgroundColor: FlixieColors.danger),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setSheetState(() => isSendingReply = false);
                                  }
                                }
                              },
                              icon: const Icon(Icons.send_rounded,
                                  color: FlixieColors.primary),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initLoading) {
      return const Center(
          child: CircularProgressIndicator(color: FlixieColors.primary));
    }
    if (_initError != null) {
      return Center(
          child: Text(_initError!,
              style: const TextStyle(color: FlixieColors.medium)));
    }

    final conversationId = _conversationId!;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: ChatService.messagesStream(conversationId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(
                    child:
                        CircularProgressIndicator(color: FlixieColors.primary));
              }
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'No messages yet. Say hello!',
                    style: TextStyle(color: FlixieColors.medium),
                    textAlign: TextAlign.center,
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
                itemCount: messages.length,
                itemBuilder: (_, i) {
                  final msg = messages[i];
                  final isMe = msg.senderId == currentUserId;

                  if (msg.type == 'watch_request') {
                    // Resolve to a postgres UUID.
                    // After the BE sets pgGroupRequestId on the message doc,
                    // msg.watchRequestId IS the postgres UUID. Until then,
                    // fall back to the _msgIdToReqId map built from the
                    // Firestore watchRequests subcollection.
                    final pgId = msg.watchRequestId ?? _msgIdToReqId[msg.id];
                    if (!_requestsLoaded) {
                      _ensureRequests();
                    }
                    final cachedReq = pgId != null ? _requestCache[pgId] : null;
                    final respondKey = pgId ?? msg.id;
                    final optimisticStatus = _respondMap[respondKey];
                    String? myStatus = optimisticStatus;
                    if (myStatus == null &&
                        cachedReq != null &&
                        currentUserId != null) {
                      myStatus = cachedReq.memberStatuses
                              .where((s) => s.memberId == currentUserId)
                              .map((s) => s.status)
                              .where((s) =>
                                  s == 'ACCEPTED' ||
                                  s == 'DECLINED' ||
                                  s == 'MAYBE')
                              .firstOrNull ??
                          cachedReq.currentUserResponse?.apiValue;
                    }
                    return WatchRequestChatCard(
                      msg: msg,
                      cachedRequest: cachedReq,
                      currentUserId: currentUserId,
                      myStatus: myStatus,
                      memberUsernames: _memberUsernames,
                      isResponding: _respondingIds.contains(respondKey),
                      onAccept: () => _respondInChat(
                          respondKey, WatchResponseDecision.accepted),
                      onDecline: () => _respondInChat(
                          respondKey, WatchResponseDecision.declined),
                      onMaybe: () => _respondInChat(
                          respondKey, WatchResponseDecision.maybe),
                      onTap: () => _showWatchRequestDetail(
                          context, msg, messages, cachedReq, currentUserId),
                    );
                  }

                  // Regular text bubble
                  final sid = msg.senderId;
                  final username = msg.senderUsername ??
                      _memberUsernames[sid] ??
                      sid.substring(0, sid.length.clamp(0, 6));
                  return ChatBubble(
                    message: msg.text,
                    senderUsername: username,
                    isMe: isMe,
                    replyTo: msg.replyToMessageId != null ? '↩ replied' : null,
                  );
                },
              );
            },
          ),
        ),
        ChatInput(
          controller: _messageController,
          sending: _sending,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}
