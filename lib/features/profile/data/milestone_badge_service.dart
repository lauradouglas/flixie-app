import 'package:flixie_app/core/api/api_client.dart';
import '../models/milestone_badge.dart';

class MilestoneBadgeService {
  const MilestoneBadgeService();
  List<MilestoneBadge> _parse(dynamic json) => (json['badges'] as List)
      .map((item) => MilestoneBadge.fromJson(item as Map<String, dynamic>))
      .toList();
  Future<List<MilestoneBadge>> load(String userId) async =>
      _parse(await ApiClient.get(
          '/users/${Uri.encodeComponent(userId)}/milestone-badges'));
  Future<List<MilestoneBadge>> save(String userId, List<String> ids) async =>
      _parse(await ApiClient.put(
          '/users/${Uri.encodeComponent(userId)}/milestone-badges',
          body: {'badgeIds': ids}));
}
