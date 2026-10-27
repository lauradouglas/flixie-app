import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flixie_app/core/auth/referral_attribution_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'external invite consent never replaces an existing referral and can be withdrawn',
      () async {
    final store = SharedPreferencesReferralAttributionStore();
    await store.save('FLXFIRST');
    await PendingWatchInviteStore.referralConsent('FLXSECOND', true);
    expect(await store.read(), 'FLXFIRST');
    await PendingWatchInviteStore.clear();
    expect(await store.read(), 'FLXFIRST');
    await store.clear();
    await PendingWatchInviteStore.referralConsent('FLXSECOND', false);
    expect(await store.read(), isNull);
    await PendingWatchInviteStore.referralConsent('FLXSECOND', true);
    expect(await store.read(), 'FLXSECOND');
    await PendingWatchInviteStore.referralConsent('FLXSECOND', false);
    expect(await store.read(), isNull);
  });
  test('pending referral survives a fresh store instance', () async {
    final first = SharedPreferencesReferralAttributionStore();
    await first.save(' flxabc123 ');

    final restored = await SharedPreferencesReferralAttributionStore().read();

    expect(restored, 'FLXABC123');
  });

  test(
      'legacy GUID referral survives until the backend resolves its short alias',
      () async {
    final store = SharedPreferencesReferralAttributionStore();
    final code = 'FLX${'A' * 32}';
    await store.save(code);
    expect(await store.read(), code);
  });

  test('clearing removes completed referral attribution', () async {
    final store = SharedPreferencesReferralAttributionStore();
    await store.save('FLXABC123');
    await store.clear();

    expect(await store.read(), isNull);
  });

  test('invalid referral values are not persisted', () async {
    final store = SharedPreferencesReferralAttributionStore();
    await store.save('x');

    expect(await store.read(), isNull);
  });
}
