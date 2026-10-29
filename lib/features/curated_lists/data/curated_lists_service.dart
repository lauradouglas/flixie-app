import 'package:flixie_app/core/api/api_client.dart';
import '../models/curated_list.dart';

class CuratedListsService {
  const CuratedListsService();
  Future<List<CuratedList>> lists({bool homepage = false, int page = 1}) async {
    final data = await ApiClient.get('/curated-lists',
        authenticated: false,
        queryParams: {'page': '$page', if (homepage) 'homepage': 'true'});
    return (data['items'] as List)
        .whereType<Map>()
        .map((row) => CuratedList.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<CuratedList> detail(String id) async =>
      CuratedList.fromJson(Map<String, dynamic>.from(
          await ApiClient.get('/curated-lists/$id', authenticated: false)));
  Future<CuratedProgress> progress(String id) async =>
      CuratedProgress.fromJson(Map<String, dynamic>.from(
          await ApiClient.get('/users/me/flixie-lists/$id/progress')));
  Future<void> join(String id) async {
    await ApiClient.post('/users/me/flixie-lists/$id/join', body: {});
  }

  Future<CuratedProgress> reconcile(String id) async =>
      CuratedProgress.fromJson(Map<String, dynamic>.from(await ApiClient.post(
          '/users/me/flixie-lists/$id/refresh-progress',
          body: {})));
}
