import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/watch_provider.dart';

void main() {
  test('same named provider has a stable fallback match key', () {
    expect(canonicalWatchProviderName('HBO Max'), 'hbomax');
    expect(canonicalWatchProviderName('HBO-Max'), 'hbomax');
    expect(canonicalWatchProviderName('Sky Go'), 'skygo');
  });
}
