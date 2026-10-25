import 'package:flutter/widgets.dart';

/// Keeps one chat query subscribed while its account/conversation is unchanged.
/// A changed source gets fresh state, so another account's data is never retained.
class ChatStreamBuilder<T> extends StatefulWidget {
  const ChatStreamBuilder(
      {super.key,
      required this.source,
      required this.createStream,
      required this.builder});

  final Object source;
  final Stream<T> Function() createStream;
  final AsyncWidgetBuilder<T> builder;

  @override
  State<ChatStreamBuilder<T>> createState() => _ChatStreamBuilderState<T>();
}

class _ChatStreamBuilderState<T> extends State<ChatStreamBuilder<T>> {
  late Stream<T> _stream;

  @override
  void initState() {
    super.initState();
    _stream = widget.createStream();
  }

  @override
  void didUpdateWidget(covariant ChatStreamBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) _stream = widget.createStream();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
        key: ValueKey(widget.source),
        stream: _stream,
        builder: widget.builder,
      );
}
