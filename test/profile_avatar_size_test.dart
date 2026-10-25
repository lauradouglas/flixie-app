import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';
import 'package:flixie_app/models/profile_avatar.dart';

void main() {
  testWidgets(
      'bundled avatar keeps its own border without resolving remote storage',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Center(
            child: ProfileAvatarView(
      avatar: ProfileAvatar(
          id: 0,
          key: 'fictional-casey',
          displayName: 'Casey',
          storagePath: 'never-resolve-this'),
      imageProvider: AssetImage('assets/icon/pip_emote_thumbs_up.png'),
      fallbackText: 'C',
      fallbackColor: Colors.purple,
      profileBadges: ['FOUNDING_FILM_FRIEND'],
      size: 44,
    ))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
        tester.getSize(find.byType(ProfileAvatarView)), const Size.square(44));
    expect(tester.getSize(find.byType(Image)), const Size.square(38));
    expect(
        tester
            .widget<SpecialAvatarFrame>(find.byType(SpecialAvatarFrame))
            .badges,
        ['FOUNDING_FILM_FRIEND']);
  });
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
