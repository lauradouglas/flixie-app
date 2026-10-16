import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/video_card.dart';
import 'package:flixie_app/models/movie_video.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

void main() {
  patrolTest('trailer card opens native player and dismisses back to catalogue',
      ($) async {
    // Public YouTube API demo video; no account or database required.
    final video = MovieVideo.fromJson({
      'name': 'Trailer playback fixture',
      'key': 'M7lc1UVf-VE',
    });
    await $.pumpWidgetAndSettle(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(body: SafeArea(child: VideoCard(video: video))),
    ));
    await $(find.text(video.name)).tap();
    await $.pump(const Duration(seconds: 2));
    expect(find.byType(YoutubePlayer), findsOneWidget);
    expect(find.text('Open in YouTube'), findsOneWidget);
    await $(find.byTooltip('Close trailer')).tap();
    await $.pumpAndSettle();
    expect(find.byType(YoutubePlayer), findsNothing);
    expect(find.text(video.name), findsOneWidget);
    expect($.tester.takeException(), isNull);
  });
}
