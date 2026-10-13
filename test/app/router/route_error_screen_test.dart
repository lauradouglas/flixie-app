import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/router/route_error_screen.dart';

Widget stillPip(BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: child!);

void main() {
  testWidgets('unknown invitation hides tokens and recovers home',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/private-communities?invitation=secret-token',
      errorBuilder: (_, state) =>
          RouteErrorScreen(unknownLink: state.error is GoException),
      routes: [
        GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: Text('Home recovered')))
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
        MaterialApp.router(routerConfig: router, builder: stillPip));
    await tester.pumpAndSettle();
    expect(find.text('Pip couldn’t find this page'), findsOneWidget);
    expect(find.text('Check for an update'), findsOneWidget);
    expect(find.textContaining('secret-token'), findsNothing);
    expect(find.textContaining('GoException'), findsNothing);
    await tester.tap(find.text('Go home'));
    await tester.pumpAndSettle();
    expect(find.text('Home recovered'), findsOneWidget);
  });

  testWidgets('failed store launch explains manual recovery', (tester) async {
    await tester.pumpWidget(MaterialApp(
        builder: stillPip,
        home: RouteErrorScreen(
          unknownLink: true,
          openStore: () async => false,
        )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Check for an update'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Search for Flixie'), findsOneWidget);
  });

  testWidgets('unexpected failure does not claim an update fixes it',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: MediaQuery(
      data: MediaQueryData(
          textScaler: TextScaler.linear(2), disableAnimations: true),
      child: RouteErrorScreen(unknownLink: false),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Check for an update'), findsNothing);
    await tester.ensureVisible(find.text('Go home'));
    expect(tester.takeException(), isNull);
  });
}
