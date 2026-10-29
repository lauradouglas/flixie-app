import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../models/curated_list.dart';

class CuratedRulesSheet extends StatelessWidget {
  const CuratedRulesSheet({super.key, required this.list});
  final CuratedList list;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = context.colors.primaryText;
    final start = list.startsAt == null ? null : londonDate(list.startsAt!);
    final end = list.endsAt == null
        ? null
        : londonDate(list.endsAt!.subtract(const Duration(milliseconds: 1)));
    final endLabel =
        end == null ? 'the challenge closes' : DateFormat('d MMMM').format(end);
    final rewardNames = list.rewards.map((reward) => reward.name).toList();
    final names = rewardNames.length < 2
        ? rewardNames.join()
        : '${rewardNames.take(rewardNames.length - 1).join(', ')} and ${rewardNames.last}';
    return Center(
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Challenge rules',
                      style: theme.textTheme.titleLarge?.copyWith(
                          fontSize: 24,
                          height: 1.2,
                          color: accent,
                          fontWeight: FontWeight.w800,
                          fontVariations: const [FontVariation('wght', 800)])),
                  const SizedBox(height: 8),
                  Text(list.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontSize: 17,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)])),
                  const SizedBox(height: 18),
                  LayoutBuilder(builder: (context, box) {
                    final number = Text('${list.requiredCount}',
                        style: theme.textTheme.headlineLarge?.copyWith(
                            fontSize: 72,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            fontVariations: const [FontVariation('wght', 800)],
                            color: accent));
                    final explanation = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('films to watch & rate',
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 19,
                                  height: 1.2,
                                  fontWeight: FontWeight.w800,
                                  fontVariations: const [
                                    FontVariation('wght', 800)
                                  ],
                                  color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 6),
                          Text(
                              list.completionTarget == null
                                  ? 'Complete all ${list.filmCount} films.'
                                  : 'Choose any ${list.requiredCount} from ${list.filmCount} films.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                  fontSize: 14,
                                  height: 1.3,
                                  color: context.colors.light)),
                        ]);
                    if (box.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                      return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            number,
                            const SizedBox(height: 10),
                            explanation
                          ]);
                    }
                    return Row(children: [
                      number,
                      const SizedBox(width: 18),
                      Expanded(child: explanation)
                    ]);
                  }),
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                          color: accent.withValues(alpha: .08),
                          borderRadius: BorderRadius.circular(14),
                          border:
                              Border.all(color: accent.withValues(alpha: .16))),
                      child: Column(children: [
                        LayoutBuilder(builder: (context, box) {
                          final starts = _date(context, 'Starts', start);
                          final ends = _date(context, 'Ends', end);
                          if (box.maxWidth < 300 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3) {
                            return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  starts,
                                  const SizedBox(height: 14),
                                  ends
                                ]);
                          }
                          return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                    padding: const EdgeInsets.only(top: 9),
                                    child: Icon(Icons.calendar_today_outlined,
                                        size: 24, color: accent)),
                                const SizedBox(width: 12),
                                Expanded(child: starts),
                                Container(
                                    width: 1,
                                    height: 44,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    color: accent.withValues(alpha: .25)),
                                Expanded(child: ends)
                              ]);
                        }),
                        const SizedBox(height: 12),
                        Text(
                            '${start != null && end != null ? start.year == end.year ? '${start.year} · ' : '${start.year}–${end.year} · ' : ''}UK time',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                height: 1.25,
                                color: context.colors.light)),
                      ])),
                  const SizedBox(height: 16),
                  _step(
                      context,
                      1,
                      'Watch and rate',
                      list.watchRule == 'ANY_WATCH'
                          ? 'Rated diary watches count, including previous watches and entries without a known date.'
                          : 'Save a rated diary watch dated within the challenge.'),
                  _step(context, 2, '${list.requiredCount} different films',
                      'Rewatches of the same film count once.'),
                  _step(context, 3, 'Join before it closes',
                      'Join and save your logs ${end == null ? 'before' : 'by'} $endLabel.'),
                  if (list.rewards.isNotEmpty)
                    _step(
                        context,
                        4,
                        list.rewards.length == 2
                            ? 'Keep both rewards'
                            : list.rewards.length == 1
                                ? 'Keep your reward'
                                : 'Keep every reward',
                        'Earn $names.'),
                  Divider(color: accent.withValues(alpha: .16)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Icon(Icons.lock_outline,
                        size: 18, color: context.colors.light),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text('Your progress is private.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: context.colors.light)))
                  ]),
                  const SizedBox(height: 14),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: context.colors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontVariations: [FontVariation('wght', 800)])),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Got it')),
                ])));
  }

  Widget _date(BuildContext context, String label, DateTime? date) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.2,
                color: context.colors.light,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(
            date == null
                ? 'To be announced'
                : DateFormat('d MMMM').format(date),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w800,
                fontVariations: const [FontVariation('wght', 800)])),
      ]);

  Widget _step(BuildContext context, int number, String title, String body) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 13),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.colors.primaryText.withValues(alpha: .12)),
                child: Text('$number',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.primaryText,
                        fontSize: 17,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        fontVariations: const [FontVariation('wght', 800)]))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          fontVariations: const [FontVariation('wght', 800)])),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 14,
                          color: context.colors.light,
                          height: 1.35)),
                ])),
          ]));
}
