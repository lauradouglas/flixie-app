import 'package:flixie_app/features/social/presentation/widgets/chat_back_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final pushed in [true, false]) {
    testWidgets(
        pushed
            ? 'back returns to the previous page'
            : 'standalone chat returns Home', (tester) async {
      final router = GoRouter(
        initialLocation: pushed ? '/friend' : '/chat',
        routes: [
          GoRoute(
              path: '/friend',
              builder: (_, __) => const Scaffold(body: Text('Friend profile'))),
          GoRoute(
              path: '/',
              builder: (_, __) => const Scaffold(body: Text('Home'))),
          GoRoute(
              path: '/chat',
              builder: (_, __) => Scaffold(
                  appBar: AppBar(leading: const ChatBackButton()),
                  body: const Text('Chat'))),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      if (pushed) {
        router.push('/chat');
        await tester.pumpAndSettle();
      }
      expect(find.byType(ChatBackButton), findsOneWidget);
      await tester.tap(find.byType(ChatBackButton));
      await tester.pumpAndSettle();
      expect(find.text(pushed ? 'Friend profile' : 'Home'), findsOneWidget);
      expect(find.text('Chat'), findsNothing);
    });
  }
}
