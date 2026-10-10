import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/group_insights.dart';

void main() {
  test('watcher mappings preserve avatar and each badge border', () {
    final response = GroupInsightsResponse.fromJson({
      'mostWatchedThisMonth': [
        {
          'title': 'Alien',
          'watchers': [
            {
              'id': 'viewer',
              'username': 'Ellis',
              'profileBadges': [
                {'badge': 'FOUNDER'},
                'VERIFIED'
              ],
              'avatar': {
                'id': 1,
                'key': 'alien',
                'displayName': 'Alien',
                'storagePath': 'avatars/alien.png',
                'imageUrl': 'https://example.invalid/alien.png'
              }
            }
          ]
        }
      ],
    });
    final watcher = response.mostWatchedThisMonth.single.watchers.single;
    expect(watcher.avatar?.key, 'alien');
    expect(watcher.profileBadges, ['FOUNDER', 'VERIFIED']);
    expect(() => watcher.profileBadges.add('OTHER'), throwsUnsupportedError);
  });
  test('watcher legacy URL and missing optional fields stay supported', () {
    final watcher = GroupInsightUser.fromJson({
      'userId': 'legacy',
      'name': 'Casey',
      'avatarUrl': 'https://example.invalid/a.png'
    });
    expect(watcher.id, 'legacy');
    expect(watcher.username, 'Casey');
    expect(watcher.avatar, isNull);
    expect(watcher.profileBadges, isEmpty);
    expect(watcher.avatarUrl, 'https://example.invalid/a.png');
  });
}
