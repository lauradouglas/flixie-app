import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/models/home_image_urls.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_hero_card.dart';
import 'package:flixie_app/features/home/presentation/widgets/continue_watching_carousel.dart';
import 'package:flixie_app/features/home/presentation/widgets/personalized_recommendation_card.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/continue_watching_show.dart';

const alien = MovieShort(id: 348, name: 'Alien', poster: '/alien.jpg');
const show = ContinueWatchingShow(
    showId: 1,
    name: 'Alien: Earth',
    watchedEpisodes: 1,
    totalEpisodes: 8,
    completionPercent: 12,
    posterPath: '/earth-poster.jpg',
    backdropPath: '/earth-backdrop.jpg');
void noop() {}

void main() {
  test('preload stays bounded and deduplicates exact display URLs', () {
    final urls = homeImageWarmupUrls(trending: [
      alien,
      alien,
      const MovieShort(id: 2, name: 'Offscreen', poster: '/offscreen.jpg')
    ], recommendations: [
      alien,
      alien
    ], continueWatching: [
      show,
      show
    ]);
    expect(urls, [
      'https://image.tmdb.org/t/p/w780/alien.jpg',
      'https://image.tmdb.org/t/p/w500/alien.jpg',
      'https://image.tmdb.org/t/p/w780/earth-backdrop.jpg',
    ]);
  });
  test('missing and absolute images preserve fallbacks and custom hosts', () {
    expect(homeHeroImageUrl(null), isNull);
    expect(homeHeroImageUrl('  '), isNull);
    expect(homeHeroImageUrl('https://example.com/image.jpg'),
        'https://example.com/image.jpg');
    expect(
        homeContinueWatchingImageUrl(const ContinueWatchingShow(
            showId: 1,
            name: 'TV',
            watchedEpisodes: 1,
            totalEpisodes: 2,
            completionPercent: 50,
            posterPath: '/poster.jpg')),
        'https://image.tmdb.org/t/p/w780/poster.jpg');
  });
  testWidgets('preloaded URLs match the images the actual cards display',
      (tester) async {
    final cards = <Widget>[
      const SizedBox(
          width: 360,
          height: 500,
          child: HomeHeroCard(
              movie: alien,
              posterHeight: 280,
              inWatchlist: false,
              isUpdating: false,
              interactions: [],
              friendActivityLoading: false,
              friendActivityFailed: false,
              onOpen: noop,
              onDetails: noop,
              onWatchlist: noop,
              onTrailer: noop,
              onFriendsRetry: noop)),
      const SizedBox(
          width: 700,
          child: PersonalizedRecommendationCard(
              movie: alien,
              reasons: [],
              isBookmarked: false,
              isBookmarkUpdating: false,
              isPreviouslyWatched: false,
              onTap: noop,
              onBookmarkTap: noop,
              onMarkWatched: noop,
              onNotInterested: noop)),
      const ContinueWatchingCard(show: show, onTap: noop),
    ];
    final displayed = <String>{};
    for (final card in cards) {
      await tester
          .pumpWidget(MaterialApp(home: Scaffold(body: Center(child: card))));
      displayed.addAll(tester
          .widgetList<CachedNetworkImage>(find.byType(CachedNetworkImage))
          .map((w) => w.imageUrl));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
    expect(
        homeImageWarmupUrls(
            trending: [alien],
            recommendations: [alien],
            continueWatching: [show]).toSet(),
        displayed);
    expect(displayed,
        isNot(contains('https://image.tmdb.org/t/p/w500/earth-poster.jpg')));
  });
}
