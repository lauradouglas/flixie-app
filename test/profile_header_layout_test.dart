import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_header.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

void main() {
  testWidgets('profile header preserves borders and badges at large text',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const badges = ['EARLY_ADOPTER', 'SUPPORTER'];
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: ProfileHeader(
                    displayName: 'Laura with a long name',
                    username: 'LongUserName',
                    profileBadges: badges,
                    bio: 'A long biography about movies and shows. ' * 12,
                    onPreview: () {})))));
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .profileBadges,
        badges);
    expect(
        tester.widget<ProfileBadgePills>(find.byType(ProfileBadgePills)).badges,
        badges);
    await tester.ensureVisible(find.text('Read more'));
    await tester.tap(find.text('Read more'));
    await tester.pump();
    expect(find.text('Read less'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
