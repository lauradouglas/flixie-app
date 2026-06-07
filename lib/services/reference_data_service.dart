import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/utils/app_logger.dart';

import '../models/country.dart';
import '../models/genre.dart';
import '../models/icon_color.dart';
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

  static Future<List<Genre>> getGenres() async {
    final data = await ApiClient.get('/utils/genres');
    return (data as List<dynamic>)
        .map((e) => Genre.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<IconColor>> getColors() async {
    final data = await ApiClient.get('/utils/colors');
    return (data as List<dynamic>)
        .map((e) => IconColor.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<WatchProvider>> getWatchProviders() async {
    final data = await ApiClient.get('/utils/watch-providers');
    final list = data['watchProviders'] as List<dynamic>;

    apiLogger.d(list);
    return list
        .map((item) => WatchProvider.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}
