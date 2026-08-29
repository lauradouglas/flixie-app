import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/movies/utils/group_provider_match.dart';

void main() {
  test('counts a shared provider once for each group member', () {
    final counts = countGroupProviderMatches([
      [1899, 29, 1899],
      [1899, 29],
    ]);

    expect(counts[1899], 2);
    expect(counts[29], 2);
  });

  test('recognises providers available to every accepted member', () {
    final counts = countGroupProviderMatches([
      [1899, 29],
      [1899],
    ]);

    expect(
      isProviderAvailableToWholeGroup(
        providerId: 1899,
        providerCounts: counts,
        memberCount: 2,
      ),
      isTrue,
    );
    expect(
      isProviderAvailableToWholeGroup(
        providerId: 29,
        providerCounts: counts,
        memberCount: 2,
      ),
      isFalse,
    );
  });
}
