import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/pages/social_screen.dart';
import 'package:flixie_app/features/social/presentation/widgets/segmented_toggle.dart';
import 'support/watchlist_auth.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('Social destinations stay usable on small phones at scale $scale', (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final auth = TestAuth();
      final client = MockClient((_) async => http.Response('{}', 503));
      ApiClient.useClientForTesting(client);
      addTearDown(() {ApiClient.useClientForTesting(null); client.close(); auth.dispose();});
      final router = GoRouter(initialLocation: '/social', routes: [
        GoRoute(path: '/social', builder: (_, __) => const SocialScreen()),
        for (final path in ['/messages', '/plans'])
          GoRoute(path: path, builder: (context, _) => Scaffold(appBar: AppBar(), body: Text('Destination $path'))),
      ]);
      addTearDown(router.dispose);
      await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(value: auth,
        child: MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router,
          builder: (_, child) => MediaQuery(data: MediaQueryData(size: const Size(320, 740), textScaler: TextScaler.linear(scale)), child: child!))));
      await t.pumpAndSettle();
      expect(t.widget<SocialSegmentedToggle>(find.byType(SocialSegmentedToggle)).labels,
        ['Activity', 'People', 'Groups', 'Communities']);
      expect(find.text('Chats'), findsNothing);
      expect(find.text('Invite'), findsNothing);
      await t.tap(find.text('Messages'));
      await t.pumpAndSettle();
      expect(find.text('Destination /messages'), findsOneWidget);
      router.pop(); await t.pumpAndSettle();
      await t.tap(find.text('Plans')); await t.pumpAndSettle();
      expect(find.text('Destination /plans'), findsOneWidget);
      router.pop(); await t.pumpAndSettle();
      await t.tap(find.text('People')); await t.pumpAndSettle();
      expect(find.text('Invite'), findsOneWidget);
      expect(find.text('Find friends'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
