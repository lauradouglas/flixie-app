import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/genre_community_service.dart';
import 'package:flixie_app/features/social/presentation/pages/genre_communities_screen.dart';
import 'package:flixie_app/features/social/presentation/pages/genre_community_feed_screen.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class _GenresFixture extends GenreCommunityService {
  bool joined = false;
  _GenresFixture(this.anime);
  final bool anime;
  GenreCommunity get horror => GenreCommunity(
      id: anime ? -1 : 27, name: anime ? 'Anime' : 'Horror', joined: joined);
  @override
  Future<List<GenreCommunity>> list() async => [horror];
  @override
  Future<void> setJoined(int id, bool value) async {
    joined = value;
  }

  @override
  Future<GenreCommunityPage> feed(int id,
          {String sort = 'latest',
          String? cursor,
          String filter = 'all'}) async =>
      GenreCommunityPage(community: horror, items: [
        ActivityListItem.fromJson({
          'id': 'fixture-review',
          'userId': 'fixture-member',
          'username': 'Fixture member',
          'type': anime ? 'show-review' : 'movie-review',
          if (anime) 'showId': 1429 else 'movieId': 348,
          if (anime)
            'show': {'title': 'Attack on Titan'}
          else
            'movie': {'title': 'Alien'},
          'rating': 4,
          'containsSpoilers': true,
          'title': 'Hidden spoiler title',
          'body': 'Private ending'
        })
      ], ratings: {
        348: const GenreMemberRating(6, 2)
      });
}

void main() {
  for (final anime in [false, true]) {
    patrolTest(
        'join ${anime ? 'Anime' : 'Horror'}, read member review and leave',
        ($) async {
      final service = _GenresFixture(anime);
      final router = GoRouter(routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => Scaffold(
                body: SafeArea(child: GenreCommunitiesView(service: service)))),
        GoRoute(
            path: '/genre-communities/:id',
            builder: (_, __) => GenreCommunityFeedScreen(
                genreId: anime ? -1 : 27, service: service)),
        GoRoute(
            path: '/community/posts/:owner/:type/:id',
            builder: (_, __) => Scaffold(
                appBar: AppBar(title: const Text('Original public review')),
                body: const Text('Review destination'))),
      ]);
      addTearDown(router.dispose);
      await $.pumpWidgetAndSettle(
          MaterialApp.router(theme: AppTheme.darkTheme, routerConfig: router));
      await $('Join').tap();
      expect(service.joined, true);
      await $(anime ? 'Anime' : 'Horror').tap();
      await $('Leave community').waitUntilVisible();
      expect(find.text('Hidden spoiler title'), findsNothing);
      await $(anime ? 'Attack on Titan · Series' : 'Alien · Film')
          .scrollTo()
          .tap();
      await $('Original public review').waitUntilVisible();
      await $(find.byType(BackButton)).tap();
      await $('Leave community').waitUntilVisible();
      await $('Leave community').tap();
      expect(service.joined, false);
      await $('Join community').waitUntilVisible();
    });
  }
}
