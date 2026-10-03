import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'support/watchlist_auth.dart';

class _Auth extends TestAuth {
  @override
  int get unreadNotificationCount => 0;
}

void main() {
  testWidgets('Library does not fetch full reviews or stats until Stats opens',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    final paths = <String>[];
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => const ProfileScreen()),
      GoRoute(path: '/stats', builder: (_, __) => const Scaffold(body: Text('Detailed stats destination'))),
    ]);
    addTearDown(router.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth, child: MaterialApp.router(routerConfig: router)));
      await tester.pumpAndSettle();
      expect(paths.where((p) => p.contains('/wrapped/')), isEmpty);
      expect(paths.where((p) => p.endsWith('/reviews')), isEmpty);
      await tester.scrollUntilVisible(find.text('Stats').first, 250,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Activity').first);
      await tester.pumpAndSettle();
      final filters = find.byKey(const PageStorageKey('profile-activity-filters'));
      final filterScroll = tester.state<ScrollableState>(find.descendant(
          of: filters, matching: find.byType(Scrollable)));
      expect(filterScroll.position.pixels, 0,
          reason: 'Filters must not restore the outer profile scroll offset');
      expect(tester.getTopLeft(find.text('All')).dx,
          greaterThan(tester.getTopLeft(filters).dx));
      await tester.tap(find.text('Stats').first);
      await tester.pumpAndSettle();
      expect(paths.where((p) => p.contains('/wrapped/')), hasLength(1));
      expect(paths.where((p) => p.endsWith('/reviews')), hasLength(1));
      await tester.tap(find.text('Library').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stats').first);
      await tester.pumpAndSettle();
      expect(paths.where((p) => p.contains('/wrapped/')), hasLength(1));
      final tabs = find.ancestor(of: find.text('Library'), matching: find.byType(Row)).first;
      expect(tester.getRect(tabs).left, 0);
      expect(tester.getSize(tabs).width, tester.view.physicalSize.width / tester.view.devicePixelRatio);
      expect(tester.getTopLeft(find.text('This month')).dx, 20);
      await Scrollable.ensureVisible(tester.element(find.text('View stats')), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('View stats'));
      await tester.pumpAndSettle();
      expect(find.text('Detailed stats destination'), findsOneWidget);
    },
        () => MockClient((request) async {
              paths.add(request.url.path);
              Object data = [];
              if (request.url.path.endsWith('/activity'))
                data = {'items': [], 'nextCursor': null};
              if (request.url.path.startsWith('/friends/'))
                data = {
                  'friendships': [],
                  'requestedFriends': [],
                  'pendingFriends': []
                };
              if (request.url.path.contains('/wrapped/')) data = {'year': 2026, 'insights': {'firstWatches': 2, 'rewatches': 0, 'distribution': List.filled(10, 0), 'episodes': 0, 'shows': 0, 'monthMovies': 2, 'monthEpisodes': 0, 'milestone': {'count': 10}}};
              return http.Response(jsonEncode(data), 200);
            }));
  });
}
