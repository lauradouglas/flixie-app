import 'show_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flixie_app/models/show.dart';
import '../utils/show_image_url.dart';

class ShowInfoSection extends StatelessWidget {
  const ShowInfoSection({super.key, required this.show, required this.credits});
  final TvShow show;
  final List<TvShowCredit> credits;
  @override
  Widget build(BuildContext context) {
    final crew = credits.isNotEmpty ? credits : show.crew;
    final directors = crew
        .where(
            (credit) => (credit.role ?? '').toLowerCase().contains('director'))
        .map((credit) => credit.name)
        .toSet()
        .toList();
    final writers = crew
        .where((credit) => (credit.role ?? '').toLowerCase().contains('writer'))
        .map((credit) => credit.name)
        .toSet()
        .toList();

    final facts = <(String, String?)>[
      ('Status', show.status),
      ('First aired', _dateLabel(show.firstAirDate)),
      ('Last aired', _dateLabel(show.lastAirDate)),
      ('Language', show.originalLanguage?.toUpperCase()),
      ('Country', show.originCountry.join(', ')),
      ('Network', show.networks.join(', ')),
      ('Created by', show.createdBy.join(', ')),
      ('Directors', directors.join(', ')),
      ('Writers', writers.join(', ')),
    ].where((fact) => fact.$2?.trim().isNotEmpty == true).toList();
    if (facts.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const FlixieSectionHeader(title: 'Show info'),
      const SizedBox(height: 10),
      for (final fact in facts) _InfoRow(label: fact.$1, value: fact.$2!),
    ]);
  }
}

class ShowCastSection extends StatelessWidget {
  const ShowCastSection({super.key, required this.show, required this.credits});
  final TvShow show;
  final List<TvShowCredit> credits;
  @override
  Widget build(BuildContext context) {
    final cast = credits.isNotEmpty ? credits : show.cast;
    if (cast.isEmpty) return const SizedBox.shrink();
    final castWidth = MediaQuery.sizeOf(context).width >= 700 ? 132.0 : 100.0;
    double textHeight(String text, double size, FontWeight weight) {
      final painter = TextPainter(
          text: TextSpan(
              text: text,
              style:
                  TextStyle(fontSize: size, fontWeight: weight, height: 1.3)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context))
        ..layout(maxWidth: castWidth);
      return painter.height;
    }

    final castHeight = cast
            .map((credit) =>
                castWidth * 1.3 +
                14 +
                textHeight(credit.name, 14, FontWeight.w600) +
                textHeight(credit.character ?? credit.role ?? '', 12,
                    FontWeight.normal))
            .reduce((a, b) => a > b ? a : b) +
        4;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Expanded(child: FlixieSectionHeader(title: 'Cast')),
          TextButton(
              onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    useSafeArea: true,
                    isScrollControlled: true,
                    backgroundColor: context.colors.surface,
                    showDragHandle: true,
                    builder: (sheetContext) => SizedBox(
                      width: double.infinity,
                      height: MediaQuery.sizeOf(sheetContext).height * .8,
                      child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            const FlixieSectionHeader(title: 'Cast'),
                            const SizedBox(height: 16),
                            Wrap(spacing: 16, runSpacing: 16, children: [
                              for (final credit in cast)
                                SizedBox(
                                    width: castWidth,
                                    height: castHeight,
                                    child: _CastTile(
                                        credit: credit,
                                        width: castWidth,
                                        onTap: credit.id <= 0
                                            ? null
                                            : () {
                                                Navigator.pop(sheetContext);
                                                context.push(personDetailPath(
                                                    credit.id,
                                                    source: DetailSource
                                                        .personCredits,
                                                    parentContentId: show.id,
                                                    parentContentType: 'show'));
                                              })),
                            ]),
                          ]),
                    ),
                  ),
              child: const Text('View all')),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: castHeight,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: cast.take(12).length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (context, index) => _CastTile(
              credit: cast[index],
              width: castWidth,
              onTap: cast[index].id <= 0
                  ? null
                  : () => context.push(personDetailPath(
                        cast[index].id,
                        source: DetailSource.personCredits,
                        parentContentId: show.id,
                        parentContentType: 'show',
                      )),
            ),
          ),
        ),
      ],
    );
  }
}

class ShowSimilarSection extends StatelessWidget {
  const ShowSimilarSection({super.key, required this.show});
  final TvShow show;
  @override
  Widget build(BuildContext context) {
    if (show.similarShows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlixieSectionHeader(title: 'More Like This'),
        const SizedBox(height: 12),
        SizedBox(
          height: 210,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: show.similarShows.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final similar = show.similarShows[index];
              return _SimilarShowCard(
                show: similar,
                onTap: () => context.push(showDetailPath(similar.id)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: context.colors.tabBarBorder))),
        child: LayoutBuilder(builder: (context, constraints) {
          final stacked = constraints.maxWidth < 300 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5;
          final labelText = Text(label,
              style: TextStyle(color: context.colors.light, fontSize: 13));
          final Widget valueText = label == 'Status'
              ? Align(
                  alignment: Alignment.centerRight,
                  child: ShowStatusBadge(status: value))
              : Text(value,
                  textAlign: stacked ? TextAlign.start : TextAlign.end,
                  style: TextStyle(
                      color: context.colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600));
          return stacked
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [labelText, const SizedBox(height: 4), valueText])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: labelText),
                  const SizedBox(width: 16),
                  Expanded(flex: 3, child: valueText)
                ]);
        }),
      );
}

class _CastTile extends StatelessWidget {
  const _CastTile({required this.credit, required this.width, this.onTap});

  final TvShowCredit credit;
  final double width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final image = showImageUrl(credit.profilePath, 'w185');
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: width,
                height: width * 1.3,
                child: image == null
                    ? ColoredBox(color: context.colors.surface)
                    : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            Text(credit.name,
                style: TextStyle(
                    color: context.colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    height: 1.3)),
            if ((credit.character ?? credit.role ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                credit.character ?? credit.role ?? '',
                style: TextStyle(
                    color: context.colors.light, fontSize: 12, height: 1.3),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SimilarShowCard extends StatelessWidget {
  const _SimilarShowCard({required this.show, required this.onTap});

  final TvShow show;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final backdrop = showImageUrl(show.backdropPath, 'w300');
    final fallbackPoster = showImageUrl(show.posterPath, 'w342');
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 180,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 180,
                height: 102,
                child: (backdrop ?? fallbackPoster) == null
                    ? ColoredBox(color: context.colors.surface)
                    : CachedNetworkImage(
                        imageUrl: backdrop ?? fallbackPoster!,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              show.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: context.colors.white, fontWeight: FontWeight.w900),
            ),
            Text(
              '${show.voteAverage?.toStringAsFixed(1) ?? '-'} • ${show.numberOfSeasons ?? show.seasons.length} Seasons',
              style: TextStyle(color: context.colors.light, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

String _dateLabel(String? date) {
  if (date == null || date.isEmpty) return '';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return date;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${parsed.day} ${months[parsed.month - 1]} ${parsed.year}';
}
