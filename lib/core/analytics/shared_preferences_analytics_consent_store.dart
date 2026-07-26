import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_consent.dart';

class SharedPreferencesAnalyticsConsentStore implements AnalyticsConsentStore {
  static const key = 'analytics_consent_v1';

  @override
  Future<AnalyticsConsent> read() async {
    final preferences = await SharedPreferences.getInstance();
    return switch (preferences.getString(key)) {
      'accepted' => AnalyticsConsent.accepted,
      'declined' => AnalyticsConsent.declined,
      _ => AnalyticsConsent.unknown,
    };
  }

  @override
  Future<void> write(AnalyticsConsent consent) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(key, consent.name);
  }
}
