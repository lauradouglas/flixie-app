import 'package:shared_preferences/shared_preferences.dart';

import 'analytics_consent.dart';

class SharedPreferencesAnalyticsConsentStore implements AnalyticsConsentStore {
  static const key = 'analytics_consent_v2';

  @override
  Future<AnalyticsConsent> read() async {
    final preferences = await SharedPreferences.getInstance();
    // A prior refusal remains a refusal. Existing acceptance needs a fresh
    // choice because v2 introduces PostHog as an additional provider.
    final value = preferences.getString(key) ??
        (preferences.getString('analytics_consent_v1') == 'declined'
            ? 'declined'
            : null);
    return switch (value) {
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
