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
      final importLines = RegExp(r'^\s*import\s+[\'"].+[\'"];', multiLine: true)
          .allMatches(content)
          .map((m) => m.group(0) ?? '')
          .toList(growable: false);
      expect(
        importLines.any((line) => line.contains('services/user_service.dart')),
        isFalse,
        reason: '$path imports user_service directly',
      );
      expect(
        importLines.any((line) => line.contains('services/friend_service.dart')),
        isFalse,
        reason: '$path imports friend_service directly',
      );
    }
  });
}
