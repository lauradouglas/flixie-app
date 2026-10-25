import 'package:flutter/material.dart';
import 'package:flixie_app/models/conversation.dart';
import '../controllers/chat_message_history.dart';

/// Owns one live query and one scroll-driven history cursor per chat/account.
class PagedChatBuilder extends StatefulWidget {
  const PagedChatBuilder(
      {super.key,
      required this.source,
      required this.createStream,
      required this.loadPage,
      required this.builder});
  final Object source;
  final Stream<List<ChatMessage>> Function() createStream;
  final Future<List<ChatMessage>> Function(ChatMessage) loadPage;
  final Widget Function(BuildContext, ChatMessageHistory, ScrollController)
      builder;
  @override
  State<PagedChatBuilder> createState() => _PagedChatBuilderState();
}

class _PagedChatBuilderState extends State<PagedChatBuilder> {
  late ChatMessageHistory _history;
  final _scroll = ScrollController();
  void _bind() => _history = ChatMessageHistory(
      live: widget.createStream(), loadPage: widget.loadPage);
  @override
  void initState() {
    super.initState();
    _bind();
  }

  @override
  void didUpdateWidget(covariant PagedChatBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) {
      _history.dispose();
      _bind();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
      });
    }
  }

  @override
  void dispose() {
    _history.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth != 0) return false;
          _history.holdLive = notification.metrics.pixels > 40;
          if (notification is ScrollUpdateNotification &&
              (notification.scrollDelta ?? 0) > 0 &&
              notification.metrics.extentAfter < 120 &&
              _history.olderError == null) {
            _history.loadOlder();
          }
          return false;
        },
        child: ListenableBuilder(
            listenable: _history,
            builder: (context, _) =>
                widget.builder(context, _history, _scroll)),
      );
}

class ChatHistoryFooter extends StatelessWidget {
  const ChatHistoryFooter({super.key, required this.history});
  final ChatMessageHistory history;
  @override
  Widget build(BuildContext context) {
    if (history.loadingOlder) {
      return const Padding(
          padding: EdgeInsets.all(12),
          child: Center(
              child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Loading older messages'))));
    }
    if (!history.hasOlder) return const SizedBox.shrink();
    return Center(
        child: TextButton(
            onPressed: history.loadOlder,
            child: Text(history.olderError != null
                ? 'Could not load older messages · Retry'
                : 'Load older messages')));
  }
}
