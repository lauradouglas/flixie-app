/// Summarises which streaming providers are saved by the selected group.
///
/// Each member contributes at most once per provider, even if an API response
/// happens to contain duplicates.
Map<T, int> countGroupProviderMatches<T>(Iterable<Iterable<T>> providerIds) {
  final counts = <T, int>{};
  for (final memberProviderIds in providerIds) {
    for (final providerId in memberProviderIds.toSet()) {
      counts[providerId] = (counts[providerId] ?? 0) + 1;
    }
  }
  return counts;
}

bool isProviderAvailableToWholeGroup<T>({
  required T providerId,
  required Map<T, int> providerCounts,
  required int memberCount,
}) =>
    memberCount > 0 && providerCounts[providerId] == memberCount;
