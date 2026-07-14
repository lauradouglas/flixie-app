import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('priority screens do not import UserService or FriendService directly', () {
    const targets = <String>[
      'lib/features/home/presentation/pages/home_screen.dart',
      'lib/features/movies/presentation/pages/movie_detail_screen.dart',
      'lib/features/profile/presentation/pages/profile_screen.dart',
      'lib/features/social/presentation/pages/social_screen.dart',
      'lib/features/settings/presentation/pages/settings_screen.dart',
    ];

    for (final path in targets) {
      final content = File(path).readAsStringSync();
      final importLines = RegExp(r'^\s*import\s+[\'"].+['"]', multiLine: true)
          .allMatches(content)
          .map((m) => m.group(0) ?? '')
          .toList(growable: false);
      expect(
        importLines.any((line) => line.contains('profile/data/user_service.dart')),
        isFalse,
        reason: '$path imports user_service directly',
      );
      expect(
        importLines.any((line) => line.contains('social/data/friend_service.dart')),
        isFalse,
        reason: '$path imports friend_service directly',
      );
    }
  });
}
