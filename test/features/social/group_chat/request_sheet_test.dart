import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/models/conversation.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_chat/group_chat_request_sheet.dart';
import '../../../support/api_fixture.dart';

void main() {
  testWidgets(
      'request reply sheet fits narrow, landscape and tablet with large text',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in [
      const Size(320, 640),
      const Size(844, 390),
      const Size(1024, 1366)
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: MediaQuery(
                  data: MediaQueryData(
                      size: size, textScaler: const TextScaler.linear(2)),
                  child: GroupChatRequestSheet(
                      message: ChatMessage(
                          id: 'plan',
                          senderId: 'friend',
                          text: '',
                          createdAt: DateTime(2026),
                          type: 'watch_request',
                          watchRequestPayload: const {
                            'movieTitle': 'The Odyssey',
                            'message': 'Alien next week?'
                          }),
                      messages: const [],
                      request: null,
                      currentUserId: 'viewer',
                      conversationId: 'club',
                      memberUsernames: const {},
                      members: const {},
                      isCurrent: () => true)))));
      await tester.pumpAndSettle();
      expect(find.text('The Odyssey'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('dismissing a pending reply safely disposes its composer',
      (tester) async {
    final result = Completer<http.Response>();
    var sends = 0;
    useApiFixture(MockClient((request) {
      sends++;
      expect(request.url.path, '/conversations/club/messages');
      expect(request.body, contains('replyToMessageId'));
      return result.future;
    }));
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: GroupChatRequestSheet(
                message: ChatMessage(
                    id: 'plan',
                    senderId: 'friend',
                    text: '',
                    createdAt: DateTime(2026)),
                messages: const [],
                request: null,
                currentUserId: 'viewer',
                conversationId: 'club',
                memberUsernames: const {},
                members: const {},
                isCurrent: () => true))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'The Odyssey!');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    expect(sends, 1);
    await tester.pumpWidget(const SizedBox());
    result.complete(http.Response('{}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
