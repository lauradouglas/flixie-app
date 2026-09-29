// Local visual sandbox. No authentication, real accounts or API calls.
// flutter run -t tool/preview_pick_journey.dart -d <dedicated-device>
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/pick_for_us/pick_for_us_screen.dart';
import '../test/support/pick_fixture.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';

// Keep this standalone preview strictly offline: watch-plan creation is not connected.
class _SoloPreviewService extends FixturePickService {
  @override
  Future<FriendsData> friends(String id) async => const FriendsData(
      friendships: [], pendingFriends: [], requestedFriends: []);
  @override
  Future<List<Group>> groups(String id) async => [];
}

void main() {
  final service = _SoloPreviewService();
  final router = GoRouter(initialLocation: '/pick', routes: [
    GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
            appBar: AppBar(title: const Text('Local picker preview')),
            body: Center(
                child: FilledButton(
                    onPressed: () => context.push('/pick'),
                    child: const Text('Open picker')))),
        routes: [
          GoRoute(
              path: 'pick',
              builder: (_, __) =>
                  PickForUsScreen(userId: 'fixture-casey', service: service)),
        ]),
    GoRoute(
        path: '/movies/:id',
        builder: (_, state) => Scaffold(
            appBar: AppBar(title: const Text('Preview destination')),
            body: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    'Movie ${state.pathParameters['id']}\n\nFictional preview. No real accounts, streaming availability or plans are connected.')))),
  ]);
  runApp(MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
}
