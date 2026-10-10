import 'package:firebase_core/firebase_core.dart';
import 'package:flixie_app/core/auth/push_notification_service.dart';
import 'package:flixie_app/core/navigation/current_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter makeRouter(GlobalKey<NavigatorState> key) => GoRouter(
      navigatorKey: key,
      routes: [
        GoRoute(
            path: '/', builder: (_, __) => const Scaffold(body: Text('Home'))),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const Scaffold(body: Text('Inbox'))),
      ],
    );

void main() {
  testWidgets('disposing an old root preserves the replacement router',
      (tester) async {
    final old = makeRouter(GlobalKey<NavigatorState>());
    final key = GlobalKey<NavigatorState>();
    final replacement = makeRouter(key);
    addTearDown(() {
      PushNotificationService.detachRouter(replacement);
      old.dispose();
      replacement.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: replacement));
    await expectLater(
        PushNotificationService.initialize(
            userId: 'fixture-router-replacement',
            databaseUserId: 'viewer',
            navigatorKey: key),
        throwsA(isA<FirebaseException>()));
    PushNotificationService.attachRouter(old);
    PushNotificationService.attachRouter(replacement);
    PushNotificationService.detachRouter(old);
    PushNotificationService.handleNotificationTap({'route': '/notifications'});
    await tester.pumpAndSettle();
    expect(currentRouterUri(replacement).path, '/notifications');
    expect(find.text('Inbox'), findsOneWidget);
  });

  testWidgets('detaching the active root stops navigation into it',
      (tester) async {
    final key = GlobalKey<NavigatorState>();
    final router = makeRouter(key);
    addTearDown(() {
      PushNotificationService.detachRouter(router);
      router.dispose();
    });
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await expectLater(
        PushNotificationService.initialize(
            userId: 'fixture-router-retired',
            databaseUserId: 'viewer',
            navigatorKey: key),
        throwsA(isA<FirebaseException>()));
    PushNotificationService.attachRouter(router);
    PushNotificationService.detachRouter(router);
    PushNotificationService.handleNotificationTap({'route': '/notifications'});
    await tester.pumpAndSettle();
    expect(currentRouterUri(router).path, '/');
    expect(find.text('Home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
