import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/core/api/api_client.dart';

class PersonService {
  static Future<Person> getPersonById(int id) async {
    final data = await ApiClient.get('/people/$id');
    return Person.fromJson(data as Map<String, dynamic>);
  }

  static Future<PersonCredits> getPersonCredits(int id) async {
    final data = await ApiClient.get('/people/$id/credits');
    return PersonCredits.fromJson(data as Map<String, dynamic>);
  }

  static Future<List<PersonImage>> getPersonImages(int id) async {
    final data = await ApiClient.get('/people/$id/images');
    return (data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PersonImage.fromJson)
        .where((image) => image.imageUrl.trim().isNotEmpty)
        .toList(growable: false);
  }

  static Future<void> favoritePerson(int personId, String userId) async {
    await ApiClient.post('/people/$personId/favorite/$userId', body: {});
  }

  static Future<void> unfavoritePerson(int personId, String userId) async {
    await ApiClient.delete('/people/$personId/favorite/$userId');
  }
}
