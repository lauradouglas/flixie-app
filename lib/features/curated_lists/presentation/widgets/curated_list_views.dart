import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../models/curated_list.dart';
import 'christmas_reward_frame.dart';

class CuratedPoster extends StatelessWidget {
  const CuratedPoster(
      {super.key, required this.film, this.width = 44, this.borderRadius = 6});
  final CuratedFilm film;
  final double width, borderRadius;
  @override
  Widget build(BuildContext context) {
    final path = film.poster;
    final url = path == null || path.isEmpty
        ? null
        : path.startsWith('https://')
            ? path
            : 'https://image.tmdb.org/t/p/w342$path';
    final fallback = ColoredBox(
        color: context.colors.surfaceElevated,
        child: const Center(child: Icon(Icons.movie_outlined)));
    return ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
            width: width,
            height: width * 1.5,
            child: url == null
                ? fallback
                : CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => fallback,
                    errorWidget: (_, __, ___) => fallback)));
  }
}

class CuratedRewardArt extends StatelessWidget {
  const CuratedRewardArt({super.key, required this.reward, this.size = 48});
  final CuratedReward reward;
  final double size;
  @override
  Widget build(BuildContext context) {
    final asset = reward.asset;
    if (asset == null) {
      return SizedBox.square(
          dimension: size, child: const Icon(Icons.card_giftcard_outlined));
    }
    return SizedBox.square(
        dimension: size,
        child: reward.isPip
            ? Image.asset(asset, fit: BoxFit.contain)
            : Stack(children: [
                Positioned.fill(
                    child: Padding(
                        padding: EdgeInsets.all(size * .09),
                        child: ClipOval(
                            child: Image.asset(
                                'assets/icon/pip_emote_thumbs_up.png',
                                fit: BoxFit.cover)))),
                Positioned.fill(child: SvgPicture.asset(asset))
              ]));
  }
}

class CuratedRewardsRow extends StatelessWidget {
  const CuratedRewardsRow({super.key, required this.rewards});
  final List<CuratedReward> rewards;
  @override
  Widget build(BuildContext context) => Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final reward in rewards)
              Tooltip(
                  message: reward.name,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    CuratedRewardArt(reward: reward, size: 40),
                    const SizedBox(width: 8),
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 190),
                        child: Text(reward.name,
                            style: Theme.of(context).textTheme.bodySmall))
                  ]))
          ]);
}

class CuratedListCard extends StatelessWidget {
  const CuratedListCard(
      {super.key, required this.list, required this.onTap, this.progress});
  final CuratedList list;
  final CuratedProgress? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final festive = list.theme == CuratedListTheme.christmas;
    return Material(
      color: context.colors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: context.colors.light.withValues(alpha: .16))),
      child: InkWell(
          onTap: onTap,
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.films.isNotEmpty ||
                    list.coverUrl?.startsWith('https://') == true)
                  ChristmasRewardFrame(
                      enabled: festive,
                      showSnow: false,
                      borderRadius: 0,
                      child: _CuratedCover(list: list)),
                Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(list.title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                  fontSize: 20,
                                  height: 1.25,
                                  fontWeight: FontWeight.w800,
                                  fontVariations: const [
                                    FontVariation('wght', 800)
                                  ])),
                          const SizedBox(height: 14),
                          _goalAndDates(context),
                          if (progress?.joined == true) ...[
                            const SizedBox(height: 14),
                            Text(
                                progress!.completedAt != null
                                    ? 'Goal complete'
                                    : progress!.label,
                                style: theme.textTheme.bodySmall),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                                value: progress!.completedAt != null
                                    ? 1
                                    : progress!.fraction,
                                minHeight: 5),
                          ],
                          const SizedBox(height: 14),
                          Divider(
                              height: 1,
                              color:
                                  context.colors.light.withValues(alpha: .16)),
                          const SizedBox(height: 10),
                          _footer(context),
                        ])),
              ])),
    );
  }

  Widget _goalAndDates(BuildContext context) {
    final theme = Theme.of(context);
    final goal =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${list.requiredCount}',
            style: theme.textTheme.headlineLarge?.copyWith(
                fontSize: 38,
                height: 1,
                color: context.colors.primaryText,
                fontWeight: FontWeight.w800,
                fontVariations: const [FontVariation('wght', 800)])),
        const SizedBox(width: 10),
        Expanded(
            child: Text('films to\nwatch & rate',
                style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.25,
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontVariations: const [FontVariation('wght', 800)]))),
      ]),
      const SizedBox(height: 4),
      Text(
          list.completionTarget == null
              ? 'Complete all ${list.filmCount} films'
              : 'Choose from ${list.filmCount} films',
          style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11, height: 1.3, color: context.colors.light)),
    ]);
    final dates = Row(children: [
      Icon(Icons.calendar_today_outlined,
          size: 18, color: context.colors.primaryText),
      const SizedBox(width: 8),
      Expanded(
          child: Text(list.dates,
              style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12, color: theme.colorScheme.onSurface))),
    ]);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 300 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [goal, const SizedBox(height: 12), dates]);
      }
      return Row(children: [
        Expanded(child: goal),
        Container(
            width: 1,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            color: context.colors.light.withValues(alpha: .18)),
        Expanded(child: dates)
      ]);
    });
  }

  Widget _footer(BuildContext context) {
    final action = FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
            backgroundColor: context.colors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w800,
                fontVariations: [FontVariation('wght', 800)])),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text('View list')),
          SizedBox(width: 4),
          Icon(Icons.chevron_right, size: 18)
        ]));
    if (list.rewards.isEmpty) {
      return Align(alignment: Alignment.centerRight, child: action);
    }
    final reward = list.rewards
        .firstWhere((reward) => reward.isPip, orElse: () => list.rewards.first);
    final summary = Row(children: [
      CuratedRewardArt(reward: reward, size: 42),
      const SizedBox(width: 10),
      Expanded(
          child: Text(
              '${list.rewards.length} ${list.rewards.length == 1 ? 'reward' : 'rewards'} to collect',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)]))),
    ]);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 290 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.3) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summary,
              const SizedBox(height: 8),
              Align(alignment: Alignment.centerRight, child: action)
            ]);
      }
      return Row(children: [
        Expanded(child: summary),
        const SizedBox(width: 12),
        action
      ]);
    });
  }
}

class _CuratedCover extends StatelessWidget {
  const _CuratedCover({required this.list});
  final CuratedList list;
  @override
  Widget build(BuildContext context) {
    final films = list.films.take(4).toList();
    return ExcludeSemantics(child: LayoutBuilder(builder: (context, box) {
      final width = (box.maxWidth - 6) / 4;
      return SizedBox(
          height: width * 1.5,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < films.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                CuratedPoster(film: films[i], width: width, borderRadius: 0),
              ],
            ],
          ));
    }));
  }
}
