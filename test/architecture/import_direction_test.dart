import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('priority screens do not import UserService or FriendService directly', () {
    const targets = <String>[
      'lib/screens/home_screen.dart',
      'lib/screens/movie_detail_screen.dart',
      'lib/screens/profile_screen.dart',
      'lib/screens/social_screen.dart',
      'lib/screens/settings_screen.dart',
    ];

    for (final path in targets) {
      final content = File(path).readAsStringSync();
      expect(
        content.contains("services/user_service.dart"),
        isFalse,
        reason: '$path imports user_service directly',
      );
      expect(
        content.contains("services/friend_service.dart"),
        isFalse,
        reason: '$path imports friend_service directly',
      );
    }
  });
}
