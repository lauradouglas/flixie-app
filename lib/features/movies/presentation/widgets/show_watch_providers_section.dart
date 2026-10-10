import 'package:flixie_app/features/movies/presentation/widgets/watch_provider_header.dart';
import 'package:flixie_app/features/movies/presentation/widgets/provider_tab_label.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart'
    show showSettingsEditDetailsSheet;
import 'package:flixie_app/features/movies/presentation/widgets/watch_provider_link.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

enum _ShowProviderTab { stream, rent, buy }

class ShowWatchProvidersSection extends StatefulWidget {
  const ShowWatchProvidersSection(
      {super.key,
      required this.providers,
      required this.userProviderIds,
      required this.userProviderMatchKeys,
      required this.region,
      required this.loading,
      required this.loaded,
      required this.failed,
      required this.onRetry,
      required this.onRegionChanged});
  final List<WatchProvider> providers;
  final Set<int> userProviderIds;
  final Set<String> userProviderMatchKeys;
  final String region;
  final bool loading, loaded, failed;
  final Future<void> Function() onRetry, onRegionChanged;
  @override
  State<ShowWatchProvidersSection> createState() =>
      _ShowWatchProvidersSectionState();
}

class _ShowWatchProvidersSectionState extends State<ShowWatchProvidersSection> {
  _ShowProviderTab _watchProviderTab = _ShowProviderTab.stream;
  List<WatchProvider> get _watchProviders => widget.providers;
  Set<int> get _userProviderIds => widget.userProviderIds;
  Set<String> get _userProviderMatchKeys => widget.userProviderMatchKeys;
  @override
  Widget build(BuildContext context) {
    if (widget.loading && !widget.loaded) {
      return const ContentPlaceholder(
          label: 'Loading watch options',
          style: ContentPlaceholderStyle.providers);
    }
    if (widget.failed) {
      return Row(children: [
        const Expanded(child: Text('Watch options couldn’t load.')),
        TextButton(onPressed: widget.onRetry, child: const Text('Retry')),
      ]);
    }
    final providers = _providersForTab(_watchProviderTab);
    final hasOptions =
        _ShowProviderTab.values.any((tab) => _providersForTab(tab).isNotEmpty);
    final region = widget.region;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      WatchProviderHeader(
          region: region,
          onChange: () async {
            await showSettingsEditDetailsSheet(context);
            if (mounted) await widget.onRegionChanged();
          }),
      if (hasOptions)
        Row(
            children: _ShowProviderTab.values
                .map((tab) => Expanded(child: _providerTabButton(tab)))
                .toList()),
      for (final provider in providers.take(2))
        _buildCompactProviderCard(provider),
      if (providers.isEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
                hasOptions
                    ? 'No ${_providerTabLabel(_watchProviderTab).toLowerCase()} options listed. Check the other options above.'
                    : 'No watch options listed yet.',
                style: TextStyle(
                    color: context.colors.light, fontSize: 14, height: 1.7))),
      if (providers.length > 2)
        TextButton(
            onPressed: () => _showAllProviderOptions(providers),
            child: Text('See all ${providers.length} options')),
    ]);
  }

  Widget _providerTabButton(_ShowProviderTab tab) {
    final selected = _watchProviderTab == tab;
    return Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: () => setState(() => _watchProviderTab = tab),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(
                        color: selected
                            ? context.colors.primaryText
                            : context.colors.tabBarBorder,
                        width: selected ? 3 : 1))),
            alignment: Alignment.center,
            child: ProviderTabLabel(
                label: _providerTabLabel(tab),
                count: _providersForTab(tab).length,
                selected: selected),
          ),
        ));
  }

  String _providerTabLabel(_ShowProviderTab tab) => switch (tab) {
        _ShowProviderTab.stream => 'Stream',
        _ShowProviderTab.rent => 'Rent',
        _ShowProviderTab.buy => 'Buy',
      };

  List<WatchProvider> _providersForTab(_ShowProviderTab tab) {
    final matching = switch (tab) {
      _ShowProviderTab.stream =>
        _watchProviders.where((provider) => provider.isStreaming),
      _ShowProviderTab.rent =>
        _watchProviders.where((provider) => provider.isRental),
      _ShowProviderTab.buy =>
        _watchProviders.where((provider) => provider.isPurchase),
    };
    return _sortedProviders(
      _dedupeProviders(matching),
      prioritiseSavedProviders: tab == _ShowProviderTab.stream,
    );
  }

  Iterable<WatchProvider> _dedupeProviders(Iterable<WatchProvider> providers) {
    final byId = <int, WatchProvider>{};
    for (final provider in providers) {
      byId.putIfAbsent(provider.id, () => provider);
    }
    return byId.values;
  }

  List<WatchProvider> _sortedProviders(
    Iterable<WatchProvider> providers, {
    required bool prioritiseSavedProviders,
  }) {
    return providers.toList()
      ..sort((a, b) {
        if (!prioritiseSavedProviders) {
          return a.displayPriority.compareTo(b.displayPriority);
        }
        final aMatches = _isUserProvider(a);
        final bMatches = _isUserProvider(b);
        if (aMatches != bMatches) return aMatches ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
  }

  bool _isUserProvider(WatchProvider provider) =>
      _userProviderIds.contains(provider.id) ||
      _userProviderMatchKeys.contains(provider.matchKey);

  Widget _buildCompactProviderCard(WatchProvider provider) {
    final owned = _isUserProvider(provider) &&
        _watchProviderTab == _ShowProviderTab.stream;
    final label = _watchProviderTab == _ShowProviderTab.rent
        ? 'Available to rent'
        : _watchProviderTab == _ShowProviderTab.buy
            ? 'Available to buy'
            : owned
                ? 'Your subscription'
                : provider.isAddOn
                    ? 'Separate add-on required'
                    : 'Subscription required';
    return WatchProviderLink(
        provider: provider,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: context.colors.tabBarBorder))),
          child: Row(children: [
            Container(
                width: 40,
                height: 40,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                        color: owned
                            ? context.colors.success
                            : context.colors.tabBarBorder,
                        width: owned ? 2 : 1)),
                child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: provider.logoPath.isEmpty
                        ? Icon(Icons.tv, color: context.colors.light)
                        : CachedNetworkImage(
                            imageUrl: provider.logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                Icon(Icons.tv, color: context.colors.light)))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(provider.providerName,
                      style: TextStyle(
                          color: context.colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(label,
                      style: TextStyle(
                          color: owned
                              ? context.colors.success
                              : context.colors.light,
                          fontSize: 12)),
                ])),
            if (owned)
              Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(Icons.check_circle,
                      color: context.colors.success, size: 20)),
            if (provider.verifiedWatchUri != null)
              Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Icon(Icons.open_in_new,
                      color: context.colors.primaryText, size: 18)),
          ]),
        ));
  }

  void _showAllProviderOptions(List<WatchProvider> providers) {
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      constraints:
          BoxConstraints.tightFor(width: MediaQuery.sizeOf(context).width),
      backgroundColor: context.colors.background,
      showDragHandle: true,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8),
        child: SizedBox(
          width: double.infinity,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                16, 4, 16, 24 + MediaQuery.paddingOf(sheetContext).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_providerTabLabel(_watchProviderTab)} options',
                    style: TextStyle(
                        color: context.colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Column(
                  children: providers.map(_buildCompactProviderCard).toList(),
                ),
                Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text('Availability by JustWatch · Opens TMDB',
                        style: TextStyle(
                            color: context.colors.light, fontSize: 12))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
