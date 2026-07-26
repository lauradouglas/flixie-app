enum AnalyticsConsent { unknown, accepted, declined }

abstract interface class AnalyticsConsentStore {
  Future<AnalyticsConsent> read();
  Future<void> write(AnalyticsConsent consent);
}
