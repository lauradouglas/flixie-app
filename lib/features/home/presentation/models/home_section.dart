import 'package:flutter/foundation.dart';

/// One independently loading Home section; errors retain its last usable data.
class HomeSectionState<T> {
  const HomeSectionState(this.data, {this.loading = false, this.error});
  final T data;
  final bool loading;
  final String? error;
}

class HomeSection<T> extends ValueNotifier<HomeSectionState<T>> {
  HomeSection(T data, {bool loading = false})
      : super(HomeSectionState(data, loading: loading));

  void update(
      {T? data, bool? loading, String? error, bool clearError = false}) {
    value = HomeSectionState(data ?? value.data,
        loading: loading ?? value.loading,
        error: clearError ? null : error ?? value.error);
  }
}

class HomeWatchlistState {
  HomeWatchlistState({Set<int> ids = const {}, Set<int> pending = const {}})
      : ids = Set.unmodifiable(ids),
        pending = Set.unmodifiable(pending);
  final Set<int> ids;
  final Set<int> pending;
}
