import 'package:flixie_app/models/person.dart';
import 'person_service.dart';

/// Injectable Person Detail boundary using the existing API contract.
class PersonDetailService {
  const PersonDetailService();
  Future<(Person, PersonCredits)> details(int id) async {
    final result = await Future.wait<Object>([
      PersonService.getPersonById(id),
      PersonService.getPersonCredits(id),
    ]);
    return (result[0] as Person, result[1] as PersonCredits);
  }

  Future<List<PersonImage>> images(int id) => PersonService.getPersonImages(id);
  Future<void> setFavorite(int id, String viewerId, {required bool favorite}) =>
      favorite
          ? PersonService.favoritePerson(id, viewerId)
          : PersonService.unfavoritePerson(id, viewerId);
}
