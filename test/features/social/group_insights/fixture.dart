import 'dart:convert';
import 'package:http/http.dart' as http;

Map<String, dynamic> insightFixture(
        {String title = 'Alien', String reviewId = 'review-1'}) =>
    {
      'mostWatchedThisMonth': [
        {
          'movieId': 348,
          'title': title,
          'watchCount': 12,
          'averageRating': 8.8,
          'watchers': [
            {
              'userId': 'watcher',
              'username': 'Ellis',
              'profileBadges': [
                {'badge': 'FOUNDER'}
              ]
            }
          ]
        },
      ],
      'highestRatedMovies': [
        {'movieId': 348, 'title': title, 'ratingCount': 8}
      ],
      'mostDiscussedMovies': [
        {'movieId': 348, 'title': title, 'discussionCount': 14}
      ],
      'recentReviews': [
        {
          'id': reviewId,
          'userId': 'reviewer',
          'reviewerUsername': 'film_friend',
          'displayName': 'Film friend',
          'movieId': 348,
          'movieTitle': title,
          'profileBadges': [
            {'badge': 'EARLY_ADOPTER'}
          ],
          'rating': 8.8,
          'snippet': 'The fictional ending is revealed here.',
          'containsSpoilers': true,
          'recommended': true,
          'createdAt': '2026-10-01T12:00:00Z'
        },
      ],
      'mostActiveMembers': [
        {
          'userId': 'contributor',
          'username': 'movie_friend',
          'profileBadges': [
            {'badge': 'VERIFIED'}
          ],
          'rank': 1,
          'activityCount': 123,
          'badge': 'Film enthusiast'
        },
      ],
    };
http.Response insightsResponse(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});
