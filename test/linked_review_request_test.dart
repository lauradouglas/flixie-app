import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/review.dart';

void main() {
  test(
      'submitting a linked review preserves the exact viewing ID through the API',
      () async {
    final requests = <Map<String, dynamic>>[];
    ApiClient.useClientForTesting(MockClient((request) async {
      final review = (jsonDecode(request.body)
          as Map<String, dynamic>)['review'] as Map<String, dynamic>;
      requests.add(review);
      return http.Response(
          jsonEncode(
              {...review, 'id': 'saved-review', 'movieId': review['mediaId']}),
          200);
    }));
    addTearDown(() => ApiClient.useClientForTesting(null));
    final draft = Review.fromJson({
      'id': '',
      'userId': 'test-user',
      'movieId': 42,
      'watchEntryId': 'chosen-rewatch',
      'rating': 8,
      'recommended': false,
      'title': 'My review',
      'body': 'My thoughts',
    });
    final saved = await UserService.addMovieReview(draft);
    expect(requests.single['watchEntryId'], 'chosen-rewatch');
    expect(saved.watchEntryId, 'chosen-rewatch');
    expect(saved.toJson()['watchEntryId'], 'chosen-rewatch');
    expect(saved.id, 'saved-review');
    await UserService.addMovieReview(
        Review.fromJson({...draft.toJson(), 'watchEntryId': null}));
    expect(requests.last.containsKey('watchEntryId'), isFalse);
  });
}
