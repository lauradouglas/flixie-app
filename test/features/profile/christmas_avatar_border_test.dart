import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
      'Christmas border follows the earned user badge and stays within the avatar at every size',
      (tester) async {
    for (final size in [28.0, 44.0, 72.0, 120.0]) {
      await tester.pumpWidget(MaterialApp(
          home: Center(
              child: ProfileAvatarView(
        avatar: null,
        fallbackText: 'A',
        fallbackColor: Colors.purple,
        size: size,
        profileBadges: const ['FOUNDER', 'BORDER_CHRISTMAS_LIGHTS'],
      ))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(ProfileAvatarView)), Size.square(size));
      expect(find.byKey(const ValueKey('christmas-lights-avatar-border')),
          findsOneWidget);
      expect(tester.getSize(find.byType(CircleAvatar)).width,
          closeTo(size * .82, .01));
      expect(
          tester
              .widget<SpecialAvatarFrame>(find.byType(SpecialAvatarFrame))
              .badges,
          contains('FOUNDER'));
    }
    await tester.pumpWidget(const MaterialApp(
        home: Center(
            child: ProfileAvatarView(
      avatar: null,
      fallbackText: 'B',
      fallbackColor: Colors.purple,
      profileBadges: ['EARLY_ADOPTER'],
    ))));
    expect(find.byKey(const ValueKey('christmas-lights-avatar-border')),
        findsNothing);
    expect(tester.getSize(find.byType(CircleAvatar)), const Size.square(38));
  });
}
