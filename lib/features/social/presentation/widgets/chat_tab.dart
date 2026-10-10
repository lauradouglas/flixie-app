import 'group_chat/group_chat_messages.dart';
import '../../data/group_chat_service.dart';
import '../controllers/group_chat_session.dart';
import 'group_chat/group_chat_request_sheet.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/models/group_watch_request.dart';
import 'package:flixie_app/models/notification.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/social/data/chat_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/profile/data/notification_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_input.dart';
import 'package:flixie_app/core/safety/safety_service.dart';

class GroupChatTab extends StatefulWidget {
  const GroupChatTab(
      {super.key,
      required this.groupId,
      this.active = true,
      this.service = const GroupChatService()});

  final String groupId;
  final bool active;
  final GroupChatService service;

  @override
  State<GroupChatTab> createState() => GroupChatTabState();
}

class GroupChatTabState extends State<GroupChatTab> {
  final TextEditingController _messageController = TextEditingController();
  late final GroupChatSession _session;
  String? get _conversationId => _session.conversationId;
  bool get _initLoading => _session.loading;
  String? get _initError => _session.error;
  bool _sending = false;
  AuthProvider? _authProvider;
  Map<String, String> get _memberUsernames => _session.usernames;
  Map<String, GroupMember> get _membersById => _session.members;

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
    final auth = context.read<AuthProvider>();
    if (_authProvider != auth) {
      _authProvider?.removeListener(_onAuthChanged);
      _authProvider = auth;
      auth.addListener(_onAuthChanged);
    }
    _onAuthChanged();
  }

  void _onAuthChanged() =>
      _session.bind(widget.groupId, _authProvider?.dbUser?.id);

  @override
  void didUpdateWidget(GroupChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _onAuthChanged();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    setState(() {
      _messageController.clear();
      _sending = false;
      _requestCache.clear();
      _msgIdToReqId.clear();
      _respondMap.clear();
      _respondingIds.clear();
      _fetchingRequests = false;
      _requestsLoaded = !_session.loading && _session.error == null;
      for (final r in _session.requests) {
        _requestCache[r.id] = r;
        if (r.databaseRequestId != null) {
          _requestCache[r.databaseRequestId!] = r;
        }
        if (r.linkedMessageId != null) _msgIdToReqId[r.linkedMessageId!] = r.id;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _session = GroupChatSession(service: widget.service)
      ..addListener(_onSessionChanged);
    SafetyService.changes.addListener(_onSafetyChanged);
    SafetyService.blockedUsers().then<void>((_) {
      if (mounted) setState(() {});
    }).catchError((_) {});
  }

  void _onSafetyChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_onSafetyChanged);
    _authProvider?.removeListener(_onAuthChanged);
    _session.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final generation = _session.generation;
    final text = _messageController.text.trim();
    final conversationId = _conversationId;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (_sending || text.isEmpty || conversationId == null || userId == null) {
      return;
    }
    final analytics = context.read<AnalyticsController>();

    setState(() => _sending = true);
    _messageController.clear();
    try {
      await ChatService.sendMessage(
        conversationId: conversationId,
        senderId: userId,
        text: text,
      );
      await analytics.groupMessageSent(groupType: 'unknown');
    } catch (e) {
      logger.e('Send message error: $e');
      if (mounted && _session.owns(generation)) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to send message')),
        );
      }
    } finally {
      if (mounted && _session.owns(generation)) {
        setState(() => _sending = false);
      }
    }
  }

  /// Loads all watch requests from the API and caches them by postgres UUID.
  /// Also builds a legacy messageId→pgUUID map from the Firestore watchRequests
  /// subcollection for messages that don't carry pgGroupRequestId directly.
  Future<void> _ensureRequests() async {
    final generation = _session.generation;
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

      if (!_session.owns(generation)) return;
      // Backward-compat: scan the Firestore watchRequests subcollection ONLY
      // to build the messageId → pgGroupRequestId mapping for legacy messages.
      // Once the BE writes pgGroupRequestId on the message doc itself, this
      // fetch is unnecessary and can be removed.
      // Wrapped in its own try/catch - permission errors here must not abort
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

      if (!mounted || !_session.owns(generation)) return;
      setState(() {
        for (final r in requests) {
          _requestCache[r.id] = r;
          if (r.databaseRequestId != null) {
            _requestCache[r.databaseRequestId!] = r;
          }
          if (r.linkedMessageId != null) {
            _msgIdToReqId[r.linkedMessageId!] = r.id;
          }
        }
        _msgIdToReqId.addAll(newMsgMap);
        _requestsLoaded = true;
        logger.d('[WR] requestCache: ${_requestCache.keys.toList()}');
        logger.d('[WR] msgIdToReqId: $_msgIdToReqId');
      });
      if (_session.owns(generation)) _fetchingRequests = false;
    } catch (e) {
      if (_session.owns(generation)) _fetchingRequests = false;
      logger.e('[WR] _ensureRequests error: $e');
    }
  }

  Future<void> _respondInChat(
      String pgId, WatchResponseDecision decision) async {
    final generation = _session.generation;
    if (_respondingIds.contains(pgId)) return;
    final conversationId = _conversationId;
    final userId = _authProvider?.dbUser?.id;
    final analytics = context.read<AnalyticsController>();
    if (conversationId == null || userId == null) return;
    setState(() {
      _respondingIds.add(pgId);
      _respondMap[pgId] = decision.apiValue.toUpperCase();
    });
    try {
      await GroupService.respondToWatchRequest(
          conversationId, pgId, userId, decision);
      if (!_session.owns(generation)) return;
      final request = _requestCache[pgId];
      if (decision == WatchResponseDecision.accepted && request != null) {
        await analytics.watchPlanAccepted(
          watchPlanId: request.databaseRequestId ?? request.id,
          contentId: request.mediaId,
          contentType: request.analyticsContentType,
          planType: 'group',
          participantCount: request.analyticsParticipantCount,
          source: 'group',
        );
      }
      if (!_session.owns(generation)) return;
      // Dismiss any watch-request notifications linked to this request.
      NotificationService.getNotifications(userId).then((notifs) {
        if (!_session.owns(generation)) return;
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
      if (!_session.owns(generation)) return;
      _requestsLoaded = false;
      await _ensureRequests();
    } catch (e) {
      if (mounted && _session.owns(generation)) {
        setState(() => _respondMap.remove(pgId));
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to respond'),
              backgroundColor: context.colors.danger),
        );
      }
    } finally {
      if (mounted && _session.owns(generation)) {
        setState(() => _respondingIds.remove(pgId));
      }
    }
  }

  void _showWatchRequestDetail(BuildContext context, ChatMessage msg,
      List<ChatMessage> messages, GroupWatchRequest? request, String? userId) {
    final generation = _session.generation;
    final conversationId = _conversationId!;
    final usernames = _memberUsernames;
    final members = _membersById;
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.tabBarBackground,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) => ListenableBuilder(
          listenable: _session,
          builder: (_, __) => !_session.owns(generation)
              ? SafeArea(
                  child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Chat session changed · Close')))
              : GroupChatRequestSheet(
                  message: msg,
                  messages: messages,
                  request: request,
                  currentUserId: userId,
                  conversationId: conversationId,
                  memberUsernames: usernames,
                  members: members,
                  isCurrent: () => _session.owns(generation))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_initLoading) {
      return const ChatContentSkeleton();
    }
    if (_initError != null) {
      return Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_initError!, style: TextStyle(color: context.colors.medium)),
        TextButton(onPressed: _session.retry, child: const Text('Retry chat')),
      ]));
    }

    final conversationId = _conversationId!;
    final currentUserId = context.read<AuthProvider>().dbUser?.id;

    return ColoredBox(
      color: context.colors.background,
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              key: ValueKey(_session.generation),
              stream: _session.messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const ChatContentSkeleton();
                }
                if (snapshot.hasError) {
                  return Center(
                      child: TextButton(
                          onPressed: _session.retry,
                          child:
                              const Text('Could not load messages · Retry')));
                }
                final messages = snapshot.data ?? [];
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet. Say hello!',
                      style: TextStyle(color: context.colors.medium),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return GroupChatMessages(
                    conversationId: conversationId,
                    groupId: widget.groupId,
                    currentUserId: currentUserId,
                    active: widget.active,
                    messages: messages,
                    members: _membersById,
                    memberUsernames: _memberUsernames,
                    requests: _requestCache,
                    messageRequestIds: _msgIdToReqId,
                    responses: _respondMap,
                    respondingIds: _respondingIds,
                    onRespond: _respondInChat,
                    onRequestDetail: (msg, all, request) =>
                        _showWatchRequestDetail(
                            context, msg, all, request, currentUserId));
              },
            ),
          ),
          ChatInput(
            controller: _messageController,
            sending: _sending,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
