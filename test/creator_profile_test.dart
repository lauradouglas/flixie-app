import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/models/creator_profile.dart';
import 'package:flixie_app/features/profile/presentation/widgets/creator_interview.dart';

void main() {
  test('ordinary badges cannot create a verified editorial profile', () {
    expect(
        CreatorProfile.parse({'role': 'director', 'verified': false}), isNull);
    expect(
        User.fromJson({
          'id': 'user',
          'profileBadges': ['VERIFIED']
        }).creatorProfile,
        isNull);
    final user = User.fromJson({
      'id': 'user',
      'creatorProfile': {
        'verified': true,
        'role': 'director',
        'answers': [
          {
            'question': 'Films that shaped me',
            'answer': 'It taught me to trust silence.',
            'movieId': 42,
            'title': 'A film'
          }
        ]
      }
    });
    expect(
        user.copyWith(username: 'new').creatorProfile!.answers.single.movieId,
        42);
  });
  testWidgets('creator answers wrap and linked films open movie details',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
              body: SingleChildScrollView(
                  child: MediaQuery(
                      data: const MediaQueryData(
                          textScaler: TextScaler.linear(2)),
                      child: CreatorInterview(
                          profile: CreatorProfile.parse({
                        'verified': true,
                        'role': 'director',
                        'answers': [
                          {
                            'question': 'Films that shaped me',
                            'answer':
                                'It taught me to trust silence and let the audience discover the story.',
                            'movieId': 42,
                            'title': 'A film with a longer title'
                          }
                        ]
                      })!))))),
      GoRoute(
          path: '/movies/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Film ${state.pathParameters['id']}'))),
    ]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A film with a longer title'));
    await tester.pumpAndSettle();
    expect(find.text('Film 42'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
