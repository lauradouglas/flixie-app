import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/pages/profile_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_library_tab.dart';
import 'profile_controller_test.dart' show ProfileAuth;

class ProfileScreenFixture {
  final auth = ProfileAuth();
  final paths = <String>[];
  late final router = GoRouter(
      routes: [GoRoute(path: '/', builder: (_, __) => const ProfileScreen())]);
  late final client = MockClient((request) async {
    paths.add(request.url.path);
    Object value = [];
    if (request.url.path.endsWith('/watch-providers')) {
      value = {'watchProviders': []};
    }
    if (request.url.path.endsWith('/activity')) {
      value = {'items': [], 'nextCursor': null};
    }
    if (request.url.path.contains('/wrapped/')) {
      value = {
        'year': DateTime.now().year,
        'totalMoviesWatched': 20,
        'totalWatchCount': 25,
        'insights': {
          'firstWatches': 20,
          'rewatches': 5,
          'distribution': List.filled(10, 0),
          'episodes': 10,
          'shows': 2,
          'monthMovies': 2,
          'monthEpisodes': 4,
          'milestone': {'count': 10}
        }
      };
    }
    return http.Response(jsonEncode(value), 200);
  });
  Widget app(double scale) => ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!)));
  void dispose() {
    router.dispose();
    client.close();
    auth.dispose();
  }
}

Future<void> openProfileTab(WidgetTester tester, String name) async {
  final tab = find.text(name).first;
  for (var i = 0;
      i < 25 &&
          (find.text(name).evaluate().isEmpty ||
              tab.hitTestable().evaluate().isEmpty);
      i++) {
    await tester.drag(
        find.byType(CustomScrollView).first, const Offset(0, -140));
    await tester.pumpAndSettle();
  }
  expect(tab.hitTestable(), findsOneWidget);
  await tester.tap(tab.hitTestable());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'notification update preserves header/library and avoids unused friends reads',
      (tester) async {
    final f = ProfileScreenFixture();
    addTearDown(f.dispose);
    await http.runWithClient(() async {
      await tester.pumpWidget(f.app(1));
      await tester.pumpAndSettle();
      expect(f.paths.where((p) => p.startsWith('/friends/')), isEmpty);
      final header = tester.widget<ProfileHeader>(find.byType(ProfileHeader));
      final library =
          tester.widget<ProfileLibraryTab>(find.byType(ProfileLibraryTab));
      final calls = List.of(f.paths);
      f.auth.unreadNotificationCount = 7;
      f.auth.notifyOnly();
      await tester.pumpAndSettle();
      expect(tester.widget<ProfileHeader>(find.byType(ProfileHeader)),
          same(header));
      expect(tester.widget<ProfileLibraryTab>(find.byType(ProfileLibraryTab)),
          same(library));
      expect(find.text('7'), findsOneWidget);
      expect(f.paths, calls);
    }, () => f.client);
  });
  for (final size in [
    const Size(320, 800),
    const Size(390, 850),
    const Size(1024, 800),
    const Size(844, 390)
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Profile tabs ${size.width}x${size.height} scale $scale',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final f = ProfileScreenFixture();
        addTearDown(f.dispose);
        await http.runWithClient(() async {
          await tester.pumpWidget(f.app(scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await openProfileTab(tester, 'Activity');
          expect(tester.takeException(), isNull);
          await openProfileTab(tester, 'Stats');
          expect(tester.takeException(), isNull);
          await tester.drag(
              find.byType(CustomScrollView).first, const Offset(0, -300));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await openProfileTab(tester, 'Library');
          expect(tester.takeException(), isNull);
          expect(f.paths.where((p) => p.contains('/wrapped/')), hasLength(1));
        }, () => f.client);
      });
    }
  }
}
