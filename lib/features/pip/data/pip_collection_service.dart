import 'package:flixie_app/core/api/api_client.dart';
import '../models/pip_collection.dart';

class PipCollectionService {
  Future<PipCollection> load() async =>
      PipCollection.fromJson(Map<String, dynamic>.from(
          await ApiClient.get('/users/me/pip-collection')));
  Future<PipCollection> update(Map<String, dynamic> body) async =>
      PipCollection.fromJson(Map<String, dynamic>.from(
          await ApiClient.patch('/users/me/pip-collection', body: body)));
}
