import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

void main() {
  testWidgets('regular and special avatars share the same outer size',
      (tester) async {
    for (final size in [28.0, 38.0, 58.0, 100.0]) {
      for (final badges in <List<String>>[
        [],
        ['PEACH_USER'],
        ['FOUNDER'],
        ['VERIFIED'],
        ['EARLY_ADOPTER'],
        ['FOUNDING_FILM_FRIEND']
      ]) {
        await tester.pumpWidget(MaterialApp(
            home: Center(
                child: ProfileAvatarView(
          avatar: null,
          fallbackText: 'A',
          fallbackColor: Colors.purple,
          size: size,
          profileBadges: badges,
        ))));
        expect(
            tester.getSize(find.byType(ProfileAvatarView)), Size.square(size));
        if (badges.isEmpty || badges.contains('PEACH_USER')) {
          expect(tester.getSize(find.byType(CircleAvatar)), Size.square(size));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });
}
