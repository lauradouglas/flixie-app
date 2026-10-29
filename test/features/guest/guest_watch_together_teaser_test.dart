import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_watch_together_teaser.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

void main() {
  for (final (width, scale) in [
    (320.0, 2.0),
    (430.0, 1.0),
    (844.0, 2.0),
    (834.0, 1.0)
  ]) {
    testWidgets(
        'fictional plan keeps complete poster and individual avatar borders at $width/$scale',
        (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(size: Size(width, 900), textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: GuestWatchTogetherTeaser()))))));
      await t.pumpAndSettle();
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Jurassic Park'), findsOneWidget);
      expect(find.text('1993'), findsOneWidget);
      expect(find.text('Friday film night'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      expect(find.text('Jamie'), findsOneWidget);
      final avatars = t
          .widgetList<ProfileAvatarView>(find.byType(ProfileAvatarView))
          .toList();
      expect(avatars.map((a) => a.profileBadges), [
        ['EARLY_ADOPTER'],
        ['FOUNDER']
      ]);
      expect(find.byType(SpecialAvatarFrame), findsNWidgets(2));
      final poster = t.widget<Image>(find.byWidgetPredicate(
          (w) => w is Image && w.semanticLabel == 'Jurassic Park poster'));
      expect(poster.width! / poster.height!, 2 / 3);
      expect(poster.fit, BoxFit.contain);
      await t.ensureVisible(find.text('See how watch plans work'));
      await t.tap(find.text('See how watch plans work'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('Watch plans, together'), findsOneWidget);
      expect(
          find.text(
              'The plan shown here is an example. You’ll need an account to make plans with other people.'),
          findsOneWidget);
      await t.scrollUntilVisible(find.text('Got it'), 150,
          scrollable: find.byType(Scrollable).last);
      await t.pumpAndSettle();
      await Scrollable.ensureVisible(t.element(find.text('Got it')),
          alignment: .5);
      await t.pumpAndSettle();
      expect(find.text('Got it').hitTestable(), findsOneWidget);
      await t.tap(find.text('Got it'));
      await t.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(t.takeException(), isNull);
    });
  }
}
