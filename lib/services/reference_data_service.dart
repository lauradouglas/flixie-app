import '../models/country.dart';
import '../models/language.dart';
import 'api_client.dart';

class ReferenceDataService {
  static Future<List<Language>> getLanguages() async {
    final data = await ApiClient.get('/utils/languages');
    return (data as List<dynamic>)
        .map((e) => Language.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<Country>> getCountries() async {
    final data = await ApiClient.get('/utils/countries');
    return (data as List<dynamic>)
        .map((e) => Country.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
