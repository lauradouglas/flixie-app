import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_stream_builder.dart';

void main() {
  testWidgets(
      'search and send-state rebuilds retain one live chat subscription',
      (tester) async {
    var subscriptions = 0;
    var cancellations = 0;
    final streams = <StreamController<List<String>>>[];
    Stream<List<String>> open() {
      final controller = StreamController<List<String>>(
        onListen: () => subscriptions++,
        onCancel: () => cancellations++,
      );
      streams.add(controller);
      addTearDown(controller.close);
      return controller.stream;
    }

    late StateSetter rebuild;
    var source = ('casey', 'alien-chat', 0);
    var sending = false;
    await tester.pumpWidget(
        MaterialApp(home: StatefulBuilder(builder: (context, setState) {
      rebuild = setState;
      return Scaffold(
          body: Column(children: [
        TextField(onChanged: (_) => setState(() {})),
        TextButton(
          onPressed: () async {
            setState(() => sending = true);
            await Future<void>.delayed(const Duration(milliseconds: 10));
            setState(() => sending = false);
          },
          child: Text(sending ? 'Sending' : 'Send'),
        ),
        ChatStreamBuilder<List<String>>(
          source: source,
          createStream: open,
          builder: (context, snapshot) =>
              Text(snapshot.data?.join(',') ?? 'Loading'),
        ),
      ]));
    })));
    streams.single.add(['Want to watch Alien?']);
    await tester.pumpAndSettle();
    expect(find.text('Want to watch Alien?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Alien');
    await tester.pump();
    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(find.text('Sending'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Send'), findsOneWidget);
    // Unrelated parent/provider notifications must not resubscribe either.
    for (var i = 0; i < 10; i++) {
      rebuild(() {});
      await tester.pump();
    }
    expect(subscriptions, 1);
    expect(cancellations, 0);
    streams.single.add(['Want to watch Alien?', 'Yes!']);
    await tester.pumpAndSettle();
    expect(find.text('Want to watch Alien?,Yes!'), findsOneWidget);

    // Navigating to another conversation subscribes once and clears old content.
    rebuild(() => source = ('casey', 'odyssey-chat', 0));
    await tester.pump();
    expect(subscriptions, 2);
    expect(cancellations, 1);
    expect(find.text('Want to watch Alien?,Yes!'), findsNothing);
    streams.last.add(['The Odyssey']);
    await tester.pumpAndSettle();
    expect(find.text('The Odyssey'), findsOneWidget);

    // Account switches must not retain the previous account's snapshot.
    rebuild(() => source = ('robin', 'odyssey-chat', 0));
    await tester.pump();
    expect(subscriptions, 3);
    expect(cancellations, 2);
    expect(find.text('The Odyssey'), findsNothing);
    // An explicit pull-to-refresh can intentionally reconnect the same account.
    rebuild(() => source = ('robin', 'odyssey-chat', 1));
    await tester.pump();
    expect(subscriptions, 4);
    expect(cancellations, 3);
    await tester.pumpWidget(const SizedBox());
    expect(cancellations, 4);
  });
}
