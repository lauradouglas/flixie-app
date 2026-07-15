import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/features/profile/data/avatar_service.dart';
import 'package:flixie_app/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/models/user.dart';

const avatar = ProfileAvatar(
  id: 1,
  key: 'spaniel',
  displayName: 'Spaniel',
  storagePath: 'avatars/spaniel.png',
  imageUrl: 'https://example.com/spaniel.png',
);

void main() {
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
  });
}

Map<String, dynamic> avatarToJson() => {
      'id': 1,
      'key': 'spaniel',
      'displayName': 'Spaniel',
      'storagePath': 'avatars/spaniel.png',
    };
