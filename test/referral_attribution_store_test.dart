import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flixie_app/core/auth/referral_attribution_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('pending referral survives a fresh store instance', () async {
    final first = SharedPreferencesReferralAttributionStore();
    await first.save(' flxabc123 ');

    final restored = await SharedPreferencesReferralAttributionStore().read();

    expect(restored, 'FLXABC123');
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
