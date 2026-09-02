import 'package:flixie_app/features/home/presentation/models/home_watch_plan_state.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watch_plan_card.dart';
import 'package:flixie_app/models/watch_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('narrow card keeps a long action readable at large text size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const request = WatchRequest(
      id: 'plan',
      requesterId: 'friend',
      recipientId: 'me',
      status: 'accepted',
      type: 'MOVIE_WATCH_REQUEST',
      movie: WatchRequestMovieDetails(
        id: 1,
        title: 'A deliberately very long movie title that needs several lines',
      ),
    );
    final state = HomeWatchPlanState(
      plan: request,
      type: HomeWatchPlanStateType.chooseFinalMovie,
      priority: 1,
      eyebrow: 'READY TO FINALISE',
      title: request.watchPlanTitle,
      supportingText: 'Everyone has chosen their movies',
      actionLabel: 'Choose final movie',
      requiresAttention: true,
    );

    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: Scaffold(
          body: HomeWatchPlanCard(state: state, onOpen: () {}),
        ),
      ),
    ));

    expect(find.text('Choose final movie'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing poster uses a meaningful placeholder', (tester) async {
    const request = WatchRequest(
      id: 'plan',
      requesterId: 'friend',
      recipientId: 'me',
      status: 'accepted',
      type: 'MOVIE_WATCH_REQUEST',
    );
    const state = HomeWatchPlanState(
      plan: request,
      type: HomeWatchPlanStateType.planning,
      priority: 1,
      eyebrow: 'PLANNING TOGETHER',
      title: 'Watch Plan',
      supportingText: 'With @Jamie',
      actionLabel: 'View plan',
      requiresAttention: false,
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomeWatchPlanCard(state: state, onOpen: () {})),
    ));

    expect(find.byIcon(Icons.movie_filter_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
