import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_favourites_teaser.dart';

void main() {
  for (final (width, scale) in [(320.0, 2.0), (430.0, 1.0), (834.0, 1.0)]) {
    testWidgets('example switches films shows people at $width/$scale',
        (t) async {
      t.view.physicalSize = Size(width, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 1000),
                  textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: GuestFavouritesTeaser()))))));
      await t.pumpAndSettle();
      expect(find.text('Se7en'), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      await t.ensureVisible(find.text('Shows'));
      await t.tap(find.text('Shows'));
      await t.pumpAndSettle();
      expect(find.text('Attack on Titan'), findsOneWidget);
      expect(find.text('Se7en'), findsNothing);
      await t.ensureVisible(find.text('People'));
      await t.tap(find.text('People'));
      await t.pumpAndSettle();
      expect(find.text('Denzel Washington'), findsOneWidget);
      expect(find.text('Actor'), findsOneWidget);
      expect(find.text('Favourite actor'), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
