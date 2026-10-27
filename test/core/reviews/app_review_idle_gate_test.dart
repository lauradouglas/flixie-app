import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/reviews/app_review_idle_gate.dart';
import 'package:flixie_app/core/reviews/app_review_policy.dart';
import 'package:flixie_app/core/reviews/app_review_service.dart';
import '../../features/profile/editor_safety_test.dart' show EditorAuth;

void main() {
  testWidgets(
      'review waits for idle Home and never overlays a sheet or another route',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final auth = EditorAuth();
    auth.current = auth.current.copyWith(completedSetup: true);
    final id = auth.dbUser.id;
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 5; i++) {
      await AppReviewPolicy.record(prefs, id, 'save:$i',
          DateTime.now().subtract(Duration(days: 10 - i)));
    }
    final calls = <String>[];
    const channel = MethodChannel('dev.britannio.in_app_review');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
        (call) async {
      calls.add(call.method);
      return call.method == 'isAvailable' ? true : null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    final router = GoRouter(routes: [
      ShellRoute(
          builder: (_, __, child) => AppReviewIdleGate(child: child),
          routes: [
            GoRoute(
                path: '/',
                builder: (context, _) => Scaffold(
                        body: Column(children: [
                      TextButton(onPressed: () {}, child: const Text('Browse')),
                      TextButton(
                          onPressed: () => showModalBottomSheet<void>(
                              context: context,
                              useRootNavigator: true,
                              useSafeArea: true,
                              builder: (_) => const SizedBox(
                                  height: 200, child: Text('A choice'))),
                          child: const Text('Open sheet')),
                    ]))),
            GoRoute(
                path: '/detail',
                builder: (_, __) => const Scaffold(body: Text('Film'))),
          ]),
    ]);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    await AppReviewService.recordMovieInteraction(id,
        hasCompletedSetup: true, eventId: 'watch:alien');
    await tester.pump(const Duration(seconds: 3));
    await tester.tap(find.text('Browse'));
    await tester.pump(const Duration(seconds: 3));
    expect(calls, isEmpty);
    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(calls, isEmpty);
    router.pop();
    await tester.pumpAndSettle();
    router.go('/detail');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    expect(calls, isEmpty);
    router.go('/');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(calls, isEmpty);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(calls, ['isAvailable', 'requestReview']);
    await tester.pumpWidget(const SizedBox());
    router.dispose();
    auth.dispose();
  });
}
