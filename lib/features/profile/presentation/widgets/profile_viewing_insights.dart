import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class ProfileViewingInsights extends StatelessWidget {
  const ProfileViewingInsights(
      {super.key,
      required this.insights,
      required this.year,
      required this.movies});
  final int movies;
  final Map<String, dynamic> insights;
  final int year;

  void _showBreakdown(BuildContext context, String title, List<dynamic> rows,
      {bool ratings = false}) {
    showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) => SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Expanded(
                          child: Text(title,
                              style: Theme.of(context).textTheme.titleLarge)),
                      IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close)),
                    ])),
                Expanded(
                    child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                      Text(
                          ratings
                              ? 'All-time movie ratings · Minimum 3 ratings per genre'
                              : 'Unique movies watched in $year',
                          style: TextStyle(color: context.colors.medium)),
                      if (rows.isEmpty)
                        const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Text('Not enough logged data yet.')),
                      for (final row in rows)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${row['name']}'),
                          subtitle:
                              ratings ? Text('${row['count']} ratings') : null,
                          trailing: Text(ratings
                              ? '${(row['average'] as num).toStringAsFixed(1)}/10'
                              : '${row['count']}'),
                        ),
                    ])),
              ]),
            ));
  }

  @override
  Widget build(BuildContext context) {
    final first = (insights['firstWatches'] as num).toInt();
    final repeat = (insights['rewatches'] as num).toInt();
    final distribution = (insights['distribution'] as List).cast<num>();
    final peak = distribution.fold<num>(1, (a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 20),
      Text('Your viewing',
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: context.colors.white)),
      const SizedBox(height: 4),
      Text('Based on your watch logs · $year',
          style: TextStyle(color: context.colors.medium, fontSize: 13)),
      const SizedBox(height: 18),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: _ViewingTotal('$movies', 'Movies')),
        Container(width: 1, height: 36, color: context.colors.tabBarBorder),
        Expanded(child: _ViewingTotal('${insights['episodes']}', 'Episodes')),
        Container(width: 1, height: 36, color: context.colors.tabBarBorder),
        Expanded(child: _ViewingTotal('${insights['shows']}', 'Shows')),
      ]),
      const SizedBox(height: 22),
      Divider(color: context.colors.tabBarBorder),
      const SizedBox(height: 16),
      const Text('First watches & rewatches',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Semantics(
          label: '$first first watches and $repeat rewatches',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
                height: 24,
                child: first + repeat == 0
                    ? ColoredBox(color: context.colors.surfaceElevated)
                    : Row(children: [
                        if (first > 0)
                          Expanded(
                              flex: first,
                              child: const ColoredBox(
                                  color: FlixieColors.primary,
                                  child: SizedBox.expand())),
                        if (repeat > 0)
                          Expanded(
                              flex: repeat,
                              child: ColoredBox(
                                  color: context.colors.primaryText,
                                  child: const SizedBox.expand())),
                      ])),
          )),
      const SizedBox(height: 12),
      Wrap(spacing: 20, runSpacing: 8, children: [
        _WatchLegend(
            color: FlixieColors.primary, label: '$first first watches'),
        _WatchLegend(
            color: context.colors.primaryText, label: '$repeat rewatches'),
      ]),
      const SizedBox(height: 12),
      SizedBox(
          width: double.infinity,
          child: OverflowBar(
              alignment: MainAxisAlignment.spaceBetween,
              overflowAlignment: OverflowBarAlignment.end,
              spacing: 12,
              children: [
                Text('Based on your recorded movie history.',
                    style:
                        TextStyle(color: context.colors.medium, fontSize: 12)),
                Text('${first + repeat} total',
                    style:
                        TextStyle(color: context.colors.medium, fontSize: 12)),
              ])),
      const SizedBox(height: 22),
      Divider(color: context.colors.tabBarBorder),
      const SizedBox(height: 16),
      const Text('How you rate · All time',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < distribution.length; i++)
              Semantics(
                  label: '${i + 1} out of 10: ${distribution[i]} ratings',
                  child: ExcludeSemantics(
                      child: Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: Column(children: [
                            Text('${distribution[i]}',
                                style: const TextStyle(fontSize: 12)),
                            SizedBox(
                                width: 26,
                                height: 65,
                                child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                        height: distribution[i] == 0
                                            ? 2
                                            : distribution[i] / peak * 65,
                                        color: FlixieColors.primary))),
                            Text('${i + 1}',
                                style: TextStyle(color: context.colors.medium)),
                          ])))),
          ])),
      const SizedBox(height: 12),
      for (final entry in const {
        'Highest-rated genres': 'highestRatedGenres',
        'Movies by decade': 'decades',
        'Original languages explored': 'languages'
      }.entries)
        ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.key),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showBreakdown(
                context, entry.key, insights[entry.value] as List? ?? [],
                ratings: entry.value == 'highestRatedGenres')),
      const SizedBox(height: 12),
      Divider(color: context.colors.tabBarBorder),
      ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        title: Text('Watch plans',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.colors.white)),
        subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
                '${insights['confirmedPlans']} confirmed watches · $year')),
        trailing: Icon(Icons.chevron_right_rounded,
            color: context.colors.primaryText),
        onTap: () => context.push('/watch-requests'),
      ),
    ]);
  }
}

class _ViewingTotal extends StatelessWidget {
  const _ViewingTotal(this.value, this.label);
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: context.colors.white)),
        const SizedBox(height: 3),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.colors.light)),
      ]);
}

class _WatchLegend extends StatelessWidget {
  const _WatchLegend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 7),
        Flexible(
            child: Text(label,
                style: TextStyle(color: context.colors.light, fontSize: 13))),
      ]);
}
