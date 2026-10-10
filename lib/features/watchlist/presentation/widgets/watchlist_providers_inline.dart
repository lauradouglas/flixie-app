import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/models/watch_provider.dart';

import 'watchlist_detail_sheet.dart';

class WatchlistProvidersInline extends StatelessWidget {
  const WatchlistProvidersInline(
      {super.key,
      required this.providers,
      required this.userWatchProviderIds,
      required this.userWatchProviderMatchKeys,
      required this.isLoading,
      this.failed = false,
      this.region = 'GB',
      this.onEditPreferences,
      this.onRetry});
  final List<WatchProvider> providers;
  final Set<int> userWatchProviderIds;
  final Set<String> userWatchProviderMatchKeys;
  final bool isLoading, failed;
  final String region;
  final VoidCallback? onRetry, onEditPreferences;

  bool _included(WatchProvider p) =>
      p.isIncludedOffer &&
      (p.isFree ||
          userWatchProviderIds.contains(p.id) ||
          userWatchProviderMatchKeys.contains(p.matchKey));
  String _label(WatchProvider p) => [
        if (p.isIncludedOffer)
          p.isFree
              ? 'Included · Free${p.availabilityTypes.contains('ads') ? ' with ads' : ''}'
              : _included(p)
                  ? 'Included'
                  : 'Subscription',
        if (p.isRental) 'Rent',
        if (p.isPurchase) 'Buy',
        if (!p.hasExplicitAvailabilityType) 'Availability unconfirmed',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Loading watch options…',
            style: TextStyle(color: context.colors.light, fontSize: 12)),
        const ContentPlaceholder(
            label: 'Loading availability',
            style: ContentPlaceholderStyle.providers),
      ]);
    }
    if (failed) {
      return TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Availability couldn’t load · Retry'));
    }
    final canStream = providers.any(_included);
    final streamIcon = Icon(
      Icons.play_arrow_outlined,
      size: 18,
      color:
          canStream ? context.colors.providerIncluded : context.colors.danger,
      semanticLabel: canStream
          ? 'Streaming available to you'
          : 'No streaming option on your services',
    );
    final sorted = [...providers]..sort((a, b) {
        if (_included(a) != _included(b)) return _included(a) ? -1 : 1;
        return a.displayPriority.compareTo(b.displayPriority);
      });
    const labelStyle = TextStyle(fontSize: 13, fontWeight: FontWeight.w700);
    final optionsStyle = TextStyle(color: context.colors.light, fontSize: 12);
    Widget logo(WatchProvider provider) => Tooltip(
          message: '${provider.providerName} · ${_label(provider)}',
          excludeFromSemantics: true,
          child: Semantics(
            image: true,
            label: '${provider.providerName} · ${_label(provider)}',
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: userWatchProviderIds.contains(provider.id) ||
                          userWatchProviderMatchKeys.contains(provider.matchKey)
                      ? context.colors.providerIncluded
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: provider.logoPath.isEmpty
                    ? const _ProviderLogoFallback()
                    : CachedNetworkImage(
                        imageUrl: provider.logoUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) => const _ProviderLogoFallback(),
                        errorWidget: (_, __, ___) =>
                            const _ProviderLogoFallback(),
                      ),
              ),
            ),
          ),
        );
    final grouped = <String, WatchProvider>{};
    for (final provider in sorted) {
      final key = '${provider.id}:${provider.providerName}';
      final previous = grouped[key];
      grouped[key] = previous == null
          ? provider
          : WatchProvider(
              id: previous.id,
              providerName: previous.providerName,
              displayPriority: previous.displayPriority,
              logoPath: previous.logoPath,
              tvShows: previous.tvShows,
              movies: previous.movies,
              isVisible: previous.isVisible,
              supportsGb: previous.supportsGb,
              supportsUs: previous.supportsUs,
              watchUrl: previous.verifiedWatchUri != null
                  ? previous.watchUrl
                  : provider.watchUrl,
              availabilityTypes: {
                ...previous.availabilityTypes,
                ...provider.availabilityTypes
              },
            );
    }
    final offers = grouped.values.toList();
    final countryName = switch (region) {
      'GB' => 'United Kingdom',
      'US' => 'United States',
      _ => region,
    };
    Future<void> openProvider(WatchProvider provider) async {
      try {
        final opened = await launchUrl(provider.verifiedWatchUri!,
            mode: LaunchMode.externalApplication);
        if (opened) return;
      } catch (_) {}
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t open watch options. Try again.')));
      }
    }

    void openOptions() => showWatchlistDetailSheet(context, 'Where to watch', [
          Row(children: [
            Icon(Icons.location_on_outlined,
                size: 18, color: context.colors.light),
            const SizedBox(width: 8),
            Expanded(
                child: Text(countryName,
                    style:
                        TextStyle(color: context.colors.white, fontSize: 14))),
            if (onEditPreferences != null)
              TextButton(
                  onPressed: onEditPreferences, child: const Text('Change')),
          ]),
          const SizedBox(height: 12),
          if (offers.isEmpty)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No providers found in this country.',
                    style: TextStyle(color: context.colors.light))),
          for (final provider in offers) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                logo(provider),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(provider.providerName,
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(_label(provider),
                          style: TextStyle(
                              fontSize: 13,
                              color: _included(provider)
                                  ? context.colors.providerIncluded
                                  : context.colors.light)),
                      if (provider.isAddOn && provider.isIncludedOffer) ...[
                        const SizedBox(height: 4),
                        Text('Separate add-on subscription',
                            style: TextStyle(
                                color: context.colors.light, fontSize: 12)),
                      ],
                    ])),
                if (provider.verifiedWatchUri != null)
                  IconButton(
                      tooltip: 'View ${provider.providerName} watch options',
                      onPressed: () => openProvider(provider),
                      icon: Icon(Icons.open_in_new,
                          size: 20, color: context.colors.primaryText)),
              ]),
            ),
            Divider(height: 1, color: context.colors.tabBarBorder),
          ],
          const SizedBox(height: 20),
          Text(
              'Availability via TMDB / JustWatch. Confirm prices and plans with the service.',
              style: TextStyle(color: context.colors.light, fontSize: 12)),
        ]);
    return Semantics(
      button: true,
      label: 'All watch options',
      child: InkWell(
        onTap: openOptions,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: LayoutBuilder(builder: (context, constraints) {
              double textWidth(String text, TextStyle style) {
                final painter = TextPainter(
                  text: TextSpan(
                      text: text,
                      style: DefaultTextStyle.of(context).style.merge(style)),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                )..layout();
                final width = painter.width.ceilToDouble();
                painter.dispose();
                return width;
              }

              String heading(int count) {
                if (sorted.isEmpty) return 'No providers found';
                final firstLabel = _label(sorted.first);
                return sorted.take(count).every((p) => _label(p) == firstLabel)
                    ? firstLabel
                    : 'Watch on';
              }

              String remaining(int count) => count < sorted.length
                  ? '+${sorted.length - count} options'
                  : 'View options';

              // Measure the actual labels at the current text scale, reserving
              // the overflow count before choosing how many logos can fit.
              var visibleCount = 0;
              for (var count = 1; count <= sorted.length; count++) {
                final width = 26 +
                    textWidth(heading(count), labelStyle) +
                    8 +
                    count * 40 +
                    (count - 1) * 7 +
                    12 +
                    textWidth(remaining(count), optionsStyle);
                if (width <= constraints.maxWidth) {
                  visibleCount = count;
                }
              }
              final stacked = visibleCount == 0;
              if (stacked && sorted.isNotEmpty) {
                visibleCount = 1;
                for (var count = 1; count <= sorted.length; count++) {
                  if (count * 40 +
                          (count - 1) * 7 +
                          12 +
                          textWidth(remaining(count), optionsStyle) <=
                      constraints.maxWidth) {
                    visibleCount = count;
                  }
                }
              }
              final label = heading(visibleCount);
              final title = Text(label,
                  style: labelStyle.copyWith(
                    color: label.startsWith('Included')
                        ? context.colors.providerIncluded
                        : context.colors.light,
                  ));
              final logos = sorted.take(visibleCount).map(logo).toList();
              final more = Text(remaining(visibleCount), style: optionsStyle);
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      streamIcon,
                      const SizedBox(width: 8),
                      Expanded(child: title),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(
                        spacing: 7,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [...logos, more]),
                  ],
                );
              }
              return Row(children: [
                streamIcon,
                const SizedBox(width: 8),
                title,
                const SizedBox(width: 8),
                for (var i = 0; i < logos.length; i++) ...[
                  if (i > 0) const SizedBox(width: 7),
                  logos[i],
                ],
                const Spacer(),
                const SizedBox(width: 12),
                more,
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

class _ProviderLogoFallback extends StatelessWidget {
  const _ProviderLogoFallback();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: context.colors.surfaceElevated,
        child: Icon(Icons.tv_rounded, size: 18, color: context.colors.light),
      );
}
