import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/presentation/widgets/video_card.dart';
import 'package:flixie_app/models/movie_video.dart';

void main() {
  for (final width in [320.0, 844.0, 1024.0]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('trailer titles fit at width $width and text scale $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final video = MovieVideo.fromJson({
          'name': 'Official extended trailer with a long title that should remain '
              'fully readable when accessibility text sizes are enabled',
          'key': 'fixture',
        });
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Builder(builder: (context) {
                return SingleChildScrollView(
                  child: SizedBox(
                    height: VideoCard.carouselHeight(context, [video]),
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [VideoCard(video: video)],
                    ),
                  ),
                );
              }),
            ),
          ),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
        final title = tester.widget<Text>(find.text(video.name));
        expect(title.maxLines, isNull);
        expect(title.overflow, isNot(TextOverflow.ellipsis));
        final titleRect = tester.getRect(find.text(video.name));
        final cardRect = tester.getRect(find.byType(VideoCard));
        expect(titleRect.bottom, lessThanOrEqualTo(cardRect.bottom));
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
