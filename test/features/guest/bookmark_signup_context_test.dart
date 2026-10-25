import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flixie_app/features/guest/presentation/widgets/bookmark_signup_context.dart';

void main() {
  setUp(GuestAccess.clear);
  tearDown(GuestAccess.clear);
  for (final width in [320.0, 844.0, 1024.0]) {
    testWidgets('bookmark context wraps at $width with large text',
        (tester) async {
      tester.view.physicalSize = Size(width, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      GuestAccess.destination = '/movies/348';
      GuestAccess.action = 'watchlist';
      GuestAccess.bookmarkTitle = 'Alien';
      await tester.pumpWidget(const MaterialApp(
          home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
            body: SingleChildScrollView(child: BookmarkSignupContext())),
      )));
      expect(find.text('Your first save: Alien'), findsOneWidget);
      expect(tester.takeException(), isNull);
      GuestAccess.clear();
      await tester.pumpWidget(const MaterialApp(home: BookmarkSignupContext()));
      expect(find.text('Your first save: Alien'), findsNothing);
    });
  }
}
