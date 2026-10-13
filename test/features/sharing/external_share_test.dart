import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/sharing/models/chat_share_media.dart';
import 'fixture.dart';
import 'journey.dart' show shareHost;

void main() {
  test('web links identify the movie/show without changing internal chat links',
      () {
    for (final isShow in [false, true]) {
      final media = ChatShareMedia(id: 348, title: 'Alien', isShow: isShow);
      final type = isShow ? 'shows' : 'movies';
      expect(mediaWebLink(media),
          'https://www.flixie.co.uk/$type/348?source=shared_link');
      expect(mediaDeepLink(media), 'flixie://$type/348?source=share');
    }
  });
  testWidgets(
      'members and guests share movie/show HTTPS links through native sharing',
      externalShareJourney);
}

Future<void> externalShareJourney(WidgetTester t) async {
  final calls = <MethodCall>[];
  const channel = MethodChannel('dev.fluttercommunity.plus/share');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    calls.add(call);
    return 'success';
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding
      .instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, null));
  for (final guest in [false, true]) {
    for (final show in [false, true]) {
      final auth = ShareAuth();
      if (guest) auth.change(null);
      await t.pumpWidget(shareHost(auth, show: show));
      await t.tap(find.text('Open share'));
      await t.pumpAndSettle();
      if (!guest) {
        expect(find.text('Share externally'), findsOneWidget);
        await t.tap(find.text('Share externally'));
        await t.pumpAndSettle();
      }
      final args = calls.last.arguments as Map;
      expect(
          args['text'],
          contains(
              'https://www.flixie.co.uk/${show ? 'shows' : 'movies'}/123?source=shared_link'));
      expect(args['text'], isNot(contains('flixie://')));
      expect(find.text('Share to friend'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    }
  }
}
