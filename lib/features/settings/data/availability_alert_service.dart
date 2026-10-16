import 'package:flixie_app/core/api/api_client.dart';

class AvailabilityAlertSettings {
  const AvailabilityAlertSettings(
      {required this.enabled, this.countryName, this.services = const []});
  final bool enabled;
  final String? countryName;
  final List<String> services;
  bool get ready => countryName != null && services.isNotEmpty;

  factory AvailabilityAlertSettings.fromJson(Map<String, dynamic> json) =>
      AvailabilityAlertSettings(
        enabled: json['enabled'] == true,
        countryName: json['countryName'] as String?,
        services: (json['services'] as List? ?? const [])
            .whereType<Map>()
            .map((p) => p['providerName'].toString())
            .toList(),
      );
}

class AvailabilityAlertService {
  const AvailabilityAlertService();
  Future<AvailabilityAlertSettings> load() async =>
      AvailabilityAlertSettings.fromJson(Map<String, dynamic>.from(
          await ApiClient.get('/availability-alerts') as Map));
  Future<AvailabilityAlertSettings> save(bool enabled) async =>
      AvailabilityAlertSettings.fromJson(Map<String, dynamic>.from(
          await ApiClient.post('/availability-alerts',
              body: {'enabled': enabled}) as Map));
}
