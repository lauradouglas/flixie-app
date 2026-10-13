import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/guest/presentation/guest_community_feed.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../support/api_fixture.dart';

void main() {
  testWidgets(
      'guest browses ratings, comment totals and paging without account requests',
      (t) async {
    final paths = <String>[];
    useApiFixture(MockClient((r) async {
      paths.add(r.url.path);
      expect(r.url.path, '/guest/community/activity');
      final more = r.url.queryParameters.containsKey('cursor');
      return http.Response(
          jsonEncode({
            'items': [
              {
                'id': more ? 'show-rating' : 'movie-rating',
                'userId': 'fixture',
                'username': 'AlienFan',
                'type': more ? 'show-rating' : 'movie-rating',
                'rating': 9,
                'createdAt': '2026-10-12T12:00:00Z',
                'updatedAt': '',
                'profileBadges': ['FOUNDER'],
                'commentCount': 3,
                if (more) 'showId': 1 else 'movieId': 348,
                if (more)
                  'show': {'title': 'Spider-Man'}
                else
                  'movie': {'title': 'Alien'},
              }
            ],
            'nextCursor': more ? null : 'page2'
          }),
          200);
    }));
    await t.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme, home: const GuestCommunityFeed()));
    await t.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    expect(find.text('9/10'), findsOneWidget);
    expect(find.text('3 comments'), findsOneWidget);
    expect(
        t
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        ['FOUNDER']);
    await t.tap(find.text('Load more'));
    await t.pumpAndSettle();
    expect(find.text('Spider-Man'), findsOneWidget);
    expect(paths, ['/guest/community/activity', '/guest/community/activity']);
    expect(t.takeException(), isNull);
  });
}
