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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlixieSectionHeader(title: 'Show Info'),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: _cardDecoration(context),
          child: Wrap(
            runSpacing: 12,
            children: [
              _InfoCell(label: 'Status', value: show.status),
              _InfoCell(
                  label: 'First Air Date',
                  value: _dateLabel(show.firstAirDate)),
              _InfoCell(
                  label: 'Last Air Date', value: _dateLabel(show.lastAirDate)),
              _InfoCell(
                  label: 'Language',
                  value: show.originalLanguage?.toUpperCase()),
              _InfoCell(label: 'Country', value: show.originCountry.join(', ')),
              _InfoCell(label: 'Network', value: show.networks.join(', ')),
              _InfoCell(label: 'Created By', value: show.createdBy.join(', ')),
              _InfoCell(label: 'Directors', value: directors.join(', ')),
              _InfoCell(label: 'Writers', value: writers.join(', ')),
            ],
          ),
        ),
      ],
    );
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
    final castHeight = (castWidth * 1.5) + 72;
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

class _InfoCell extends StatelessWidget {
  const _InfoCell({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: context.colors.light,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            (value == null || value!.isEmpty) ? '-' : value!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
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
      borderRadius: BorderRadius.circular(18),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: width,
                height: width * 1.5,
                child: image == null
                    ? ColoredBox(color: context.colors.surface)
                    : CachedNetworkImage(imageUrl: image, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 36,
              child: Text(
                credit.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: context.colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.16),
              ),
            ),
            if ((credit.character ?? credit.role ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                credit.character ?? credit.role ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.colors.light, fontSize: 13),
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
  if (date == null || date.isEmpty) return '-';
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

BoxDecoration _cardDecoration(BuildContext context) => BoxDecoration(
    color: context.colors.surface.withValues(alpha: .85),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withValues(alpha: .1)));
