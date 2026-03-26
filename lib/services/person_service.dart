import '../models/person.dart';
import 'api_client.dart';

class PersonService {
  static Future<Person> getPersonById(int id) async {
    final data = await ApiClient.get('/people/$id');
    return Person.fromJson(data as Map<String, dynamic>);
  }

  static Future<PersonCredits> getPersonCredits(int id) async {
    final data = await ApiClient.get('/people/$id/credits');
    return PersonCredits.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> favoritePerson(int personId, String userId) async {
    await ApiClient.post('/people/$personId/favorite/$userId', body: {});
  }

  static Future<void> unfavoritePerson(int personId, String userId) async {
    await ApiClient.delete('/people/$personId/favorite/$userId');
  }
}
