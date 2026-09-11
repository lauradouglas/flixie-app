import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/features/profile/data/avatar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/user.dart';

const avatar = ProfileAvatar(
  id: 1,
  key: 'spaniel',
  displayName: 'Spaniel',
  storagePath: 'avatars/spaniel.png',
  imageUrl: 'https://example.com/spaniel.png',
);

const avatarWithIcon = ProfileAvatar(
  id: 2,
  key: 'astronaut',
  displayName: 'Astronaut',
  storagePath: 'avatars/astronaut_avatar.png',
  imageUrl: 'https://example.com/astronaut.png',
  iconStoragePath: 'avatar-icons/astronaut_avatar_sm.WebP',
  iconImageUrl: 'https://example.com/astronaut.WebP',
);

void main() {
  test('icon paths and URLs survive parsing, persistence and copyWith', () {
    final parsed = ProfileAvatar.fromJson(avatarWithIcon.toJson());
    expect(parsed.iconStoragePath, avatarWithIcon.iconStoragePath);
    expect(parsed.iconImageUrl, avatarWithIcon.iconImageUrl);
    expect(
        parsed.copyWith(imageUrl: 'https://example.com/new.png').iconImageUrl,
        avatarWithIcon.iconImageUrl);
  });

  testWidgets(
      'small avatars use icons, larger avatars and selection use originals',
      (tester) async {
    Future<void> show(double size,
        {bool fullSize = false, ProfileAvatar? value}) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProfileAvatarView(
          avatar: value ?? avatarWithIcon,
          fallbackText: 'A',
          fallbackColor: Colors.purple,
          size: size,
          useFullSize: fullSize,
        )),
      ));
      await tester.pump();
    }

    String imageUrl() => tester
        .widget<CachedNetworkImage>(find.byType(CachedNetworkImage))
        .imageUrl;
    await show(44);
    expect(imageUrl(), avatarWithIcon.iconImageUrl);
    await show(76);
    expect(imageUrl(), avatarWithIcon.imageUrl);
    await show(44, fullSize: true);
    expect(imageUrl(), avatarWithIcon.imageUrl);
    await show(44, value: avatar);
    expect(imageUrl(), avatar.imageUrl);
  });

  testWidgets('an icon download failure falls back to the original',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: ProfileAvatarView(
      avatar: avatarWithIcon,
      fallbackText: 'A',
      fallbackColor: Colors.purple,
    ))));
    await tester.pump();
    final finder = find.byType(CachedNetworkImage);
    final icon = tester.widget<CachedNetworkImage>(finder);
    expect(icon.imageUrl, avatarWithIcon.iconImageUrl);
    icon.errorWidget!(
        tester.element(finder), icon.imageUrl, Exception('Missing icon'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(tester.widget<CachedNetworkImage>(finder).imageUrl,
        avatarWithIcon.imageUrl);
  });

  test('parses avatar JSON', () {
    final parsed = ProfileAvatar.fromJson({
      'id': 1,
      'key': 'spaniel',
      'displayName': 'Spaniel',
      'storagePath': 'avatars/spaniel.png',
    });
    expect(parsed.storagePath, 'avatars/spaniel.png');
    expect(parsed.imageUrl, isNull);
  });

  test('user avatar is nullable and parsed when returned', () {
    Map<String, dynamic> json([Object? avatar]) => {
          'id': 'u1',
          'username': 'laura',
          'email': 'l@example.com',
          'iconColorId': 1,
          'completedSetup': false,
          'darkMode': true,
          'avatar': avatar,
        };
    expect(User.fromJson(json()).avatar, isNull);
    expect(User.fromJson(json(avatarToJson())).avatar?.id, 1);
  });

  test('user parsing tolerates null required string fields', () {
    final parsed = User.fromJson({
      'id': null,
      'username': null,
      'email': null,
      'iconColorId': null,
      'completedSetup': null,
      'darkMode': null,
    });

    expect(parsed.id, '');
    expect(parsed.username, 'user');
    expect(parsed.email, '');
    expect(parsed.iconColorId, 0);
    expect(parsed.completedSetup, isFalse);
    expect(parsed.darkMode, isFalse);
  });

  test('uses the profile country for watch providers and defaults to GB', () {
    User userWithCountry(Map<String, dynamic>? country) => User.fromJson({
          'id': 'u1',
          'username': 'laura',
          'email': 'l@example.com',
          'iconColorId': 1,
          'completedSetup': true,
          'darkMode': true,
          'country': country,
        });

    expect(userWithCountry({'isoCode': 'us'}).watchProviderRegion, 'US');
    expect(userWithCountry({'abbreviation': 'UK'}).watchProviderRegion, 'GB');
    expect(userWithCountry(null).watchProviderRegion, 'GB');
  });

  test('download URLs are cached by storage path', () async {
    var calls = 0;
    final resolver = AvatarUrlResolver(loader: (path) async {
      calls++;
      return 'https://example.com/$path';
    });
    await resolver.resolve('avatars/a.png');
    await resolver.resolve('avatars/a.png');
    expect(calls, 1);
  });

  testWidgets('picker renders empty and selected states', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AvatarPicker(
          avatars: const [],
          selectedId: null,
          onSelected: (_) {},
        ),
      ),
    ));
    expect(find.textContaining('No profile avatars'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AvatarPicker(
          avatars: const [avatar],
          selectedId: 1,
          onSelected: (_) {},
        ),
      ),
    ));
    final selectedSemantics = tester
        .widgetList<Semantics>(find.byType(Semantics))
        .any((widget) =>
            widget.properties.selected == true &&
            widget.properties.label == 'Spaniel, selected');
    expect(selectedSemantics, isTrue);
    expect(
        tester
            .widget<ProfileAvatarView>(find.byType(ProfileAvatarView))
            .useFullSize,
        isTrue);
  });
}

Map<String, dynamic> avatarToJson() => {
      'id': 1,
      'key': 'spaniel',
      'displayName': 'Spaniel',
      'storagePath': 'avatars/spaniel.png',
    };
