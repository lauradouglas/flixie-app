import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_bubble.dart';

void main() {
  for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
    for (final isMe in [true, false]) {
      for (final media in ['MOVIE', 'SHOW']) {
        testWidgets(
            '$media shares stay readable: ${theme.brightness}, own=$isMe',
            (tester) async {
          await tester.pumpWidget(MaterialApp(
              theme: theme,
              home: Scaffold(
                body: ChatBubble(
                  message:
                      '[FLIXIE_${media}_SHARE]\ntitle=Shared%20title\nlink=flixie%3A%2F%2F${media == 'MOVIE' ? 'movies' : 'shows'}%2F1\nmessage=Watch%20this%20with%20me\n[/FLIXIE_${media}_SHARE]',
                  senderUsername: 'LauraD',
                  isMe: isMe,
                  sentAt: DateTime(2026),
                ),
              )));
          final bubbleContext = tester.element(find.byType(ChatBubble));
          final background = bubbleContext.colors.surface.computeLuminance();
          for (final label in [
            'Shared title',
            'Watch this with me',
            media == 'MOVIE' ? 'View movie' : 'View show'
          ]) {
            final text = tester.widget<Text>(find.text(label));
            final foreground = text.style!.color!.computeLuminance();
            final contrast = foreground > background
                ? (foreground + .05) / (background + .05)
                : (background + .05) / (foreground + .05);
            expect(contrast, greaterThanOrEqualTo(4.5), reason: label);
          }
        });
      }
    }
  }

  testWidgets('shared titles reflow across phone and tablet sizes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final width in [320.0, 430.0, 768.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 1200);
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: SingleChildScrollView(
              child: ChatBubble(
            message:
                '[FLIXIE_SHOW_SHARE]\ntitle=The%20Newsroom%20and%20a%20long%20title\nlink=flixie%3A%2F%2Fshows%2F1\nmessage=You%20should%20watch%20this.\n[/FLIXIE_SHOW_SHARE]',
            senderUsername: 'LauraD',
            isMe: false,
            sentAt: DateTime(2026),
          )),
        ))));
        expect(find.text('View show'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
