import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_provider_example.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

void main() {
  for (final (width, scale) in [
    (320.0, 2.0),
    (430.0, 1.0),
    (834.0, 1.0),
    (844.0, 2.0)
  ]) {
    testWidgets('provider example reflows at $width/$scale', (t) async {
      t.view.physicalSize = Size(width, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(width, 1200),
                  textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: GuestProviderExample()))))));
      await t.pumpAndSettle();
      expect(find.text('The Dark Knight'), findsOneWidget);
      expect(find.text('HBO Max'), findsNWidgets(2));
      expect(find.text('Your service'), findsOneWidget);
      expect(find.text('Example'), findsOneWidget);
      expect(find.textContaining('Illustrative example.'), findsOneWidget);
      final avatar =
          t.widget<ProfileAvatarView>(find.byType(ProfileAvatarView));
      expect(avatar.profileBadges, contains('EARLY_ADOPTER'));
      final poster = t.widget<Image>(find.byType(Image).first);
      expect(poster.fit, BoxFit.contain);
      expect(poster.width! / poster.height!, closeTo(2 / 3, .001));
      expect(t.takeException(), isNull);
    });
  }
}
