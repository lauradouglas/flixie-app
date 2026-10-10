import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import '../models/pick_for_us_result.dart';

class PickForUsService {
  Future<FriendsData> friends(String id) => FriendService.getFriends(id);
  Future<List<Group>> groups(String id) => GroupService.getUserGroups(id);
  Future<PickForUsResponse> pick(
      {String? friendId,
      String? groupId,
      String request = '',
      bool allowRewatches = false,
      Set<String> avoid = const {},
      Set<int> excludeMovieIds = const {},
      List<int> genreIds = const [],
      bool includePossible = true,
      bool includeUnknownContent = false,
      required int maxMinutes,
      required String mood,
      required String venue,
      required String watching,
      required bool openToRent}) async {
    final data = await ApiClient.post('/recommendations/pick-for-us',
        timeout: const Duration(seconds: 60),
        body: {
          if (friendId != null) 'friendId': friendId,
          if (groupId != null) 'groupId': groupId,
          'maxMinutes': maxMinutes,
          'mood': mood,
          'request': request,
          'allowRewatches': allowRewatches,
          'avoid': avoid.toList(),
          if (excludeMovieIds.isNotEmpty)
            'excludeMovieIds': excludeMovieIds.toList(),
          'genreIds': genreIds,
          'includePossible': includePossible,
          'includeUnknownContent': includeUnknownContent,
          'venue': venue,
          'watching': watching,
          'openToRent': openToRent,
        }) as Map<String, dynamic>;
    return PickForUsResponse(
        (data['choices'] as List)
            .map((e) => PickForUsResult.fromJson(e as Map<String, dynamic>))
            .toList(),
        data['message'] as String?);
  }
}
