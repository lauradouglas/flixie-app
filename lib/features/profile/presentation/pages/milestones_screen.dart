import 'package:flixie_app/features/profile/data/milestone_cache.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/models/profile_milestone.dart';

class MilestonesScreen extends StatefulWidget {
  const MilestonesScreen(
      {super.key,
      required this.userId,
      this.displayName,
      this.earnedOnly = false});
  final String userId;
  final String? displayName;
  final bool earnedOnly;
  @override
  State<MilestonesScreen> createState() => _MilestonesScreenState();
}

class _MilestonesScreenState extends State<MilestonesScreen> {
  late Future<ProfileMilestones> _load;
  @override
  void initState() {
    super.initState();
    _load = _fetch();
  }

  Future<ProfileMilestones> _fetch({bool refresh = false}) =>
      MilestoneCache.instance.load(widget.userId, refresh: refresh);
  Future<void> _refresh() async {
    final next = _fetch(refresh: true);
    setState(() => _load = next);
    try {
      await next;
    } catch (_) {/* FutureBuilder displays the retry. */}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
            title: const Text('Milestones'),
            backgroundColor: context.colors.background),
        body: SafeArea(
            child: FutureBuilder<ProfileMilestones>(
                future: _load,
                initialData: MilestoneCache.instance.peek(widget.userId),
                builder: (context, snapshot) {
                  if (snapshot.hasError && !snapshot.hasData) {
                    final private = snapshot.error is ApiException &&
                        (snapshot.error as ApiException).statusCode == 403;
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                      private
                                          ? Icons.people_outline
                                          : Icons.cloud_off_outlined,
                                      size: 32,
                                      color: context.colors.primaryText),
                                  const SizedBox(height: 12),
                                  Text(
                                      private
                                          ? 'Milestones are visible to friends only.'
                                          : 'Couldn’t load milestones. Try again.',
                                      textAlign: TextAlign.center),
                                  if (!private)
                                    TextButton(
                                        onPressed: _refresh,
                                        child: const Text('Retry')),
                                ])));
                  }
                  if (!snapshot.hasData) {
                    return ListView(
                        padding: const EdgeInsets.all(20),
                        children: List.generate(
                            5,
                            (index) => Container(
                                  height: index == 0 ? 44 : 88,
                                  margin: const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                      color: context.colors.surfaceElevated,
                                      borderRadius: BorderRadius.circular(14)),
                                )));
                  }
                  final data = snapshot.data!;
                  return RefreshIndicator(
                      onRefresh: _refresh,
                      child: MilestonesContent(
                        data: widget.earnedOnly
                            ? ProfileMilestones(
                                items: data.earned, owner: false)
                            : data,
                        displayName: widget.displayName,
                      ));
                })),
      );
}

class MilestonesContent extends StatefulWidget {
  const MilestonesContent({super.key, required this.data, this.displayName});
  final ProfileMilestones data;
  final String? displayName;
  @override
  State<MilestonesContent> createState() => _MilestonesContentState();
}

class _MilestonesContentState extends State<MilestonesContent> {
  String _filter = 'All';
  String _group = 'All categories';
  static const groups = ['Watching', 'Exploring', 'Together', 'Your voice'];
  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final earned = data.earned;
    final selected = !data.owner || _filter == 'Earned'
        ? earned
        : _filter == 'Next up'
            ? data.next
            : data.items;
    final visible = selected
        .where((item) => _group == 'All categories' || item.group == _group)
        .toList();
    final overview =
        data.owner && _filter == 'All' && _group == 'All categories';
    return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
              data.owner
                  ? 'Your story so far'
                  : '${widget.displayName ?? 'Your friend'}’s movie moments',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: context.colors.white, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
              '${earned.length} earned · ${data.owner ? 'Earned milestones are visible to friends' : 'Visible to friends'}',
              style: TextStyle(color: context.colors.light)),
          if (data.owner) ...[
            const SizedBox(height: 24),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['All', 'Earned', 'Next up']
                    .map((label) => FlixiePill.choice(
                          label: Text(label),
                          selected: _filter == label,
                          onSelected: (_) => setState(() => _filter = label),
                        ))
                    .toList()),
          ],
          if (overview && earned.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Recent achievement',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _MilestoneRow(item: earned.first, showProgress: false),
          ],
          if (overview) ...[
            if (data.next.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Your next milestone',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              _MilestoneRow(item: data.next.first, showProgress: true),
            ],
            const SizedBox(height: 24),
            Text('Explore milestones',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            for (final group in groups)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: context.colors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Icon(
                        switch (group) {
                          'Watching' => Icons.movie_outlined,
                          'Exploring' => Icons.explore_outlined,
                          'Together' => Icons.people_outline,
                          _ => Icons.chat_bubble_outline,
                        },
                        color: context.colors.primaryText),
                    title: Text(group,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(switch (group) {
                      'Watching' => 'Films, series & comfort rewatches',
                      'Exploring' => 'Genres, countries, decades & collections',
                      'Together' => 'Movie mates & group nights',
                      _ => 'Reviews & recommendations',
                    }),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => setState(() => _group = group),
                  ),
                ),
              ),
          ],
          if (!overview) ...[
            const SizedBox(height: 18),
            DropdownButtonFormField<String>(
                key: ValueKey(_group),
                initialValue: _group,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Category'),
                items: ['All categories', ...groups]
                    .map((group) =>
                        DropdownMenuItem(value: group, child: Text(group)))
                    .toList(),
                onChanged: (group) =>
                    setState(() => _group = group ?? 'All categories')),
            if (visible.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                      data.owner
                          ? 'No milestones here yet. Keep enjoying your films and shows—there’s no rush.'
                          : 'No earned milestones to show yet.',
                      style: TextStyle(color: context.colors.light))),
            for (final group in groups)
              if (visible.any((item) => item.group == group)) ...[
                Padding(
                    padding: const EdgeInsets.only(top: 24, bottom: 12),
                    child: Text(group,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700))),
                if (data.owner && _filter == 'All')
                  ..._families(
                          visible.where((item) => item.group == group).toList())
                      .map((items) {
                    final next =
                        items.where((item) => !item.earned).firstOrNull ??
                            items.last;
                    return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: Icon(_icon(next.family),
                              color: context.colors.warning),
                          title: Text(next.title),
                          subtitle: Text(
                              '${items.where((item) => item.earned).length} of ${items.length} milestones earned'),
                          children: items
                              .map((item) =>
                                  _MilestoneRow(item: item, showProgress: true))
                              .toList(),
                        ));
                  })
                else
                  ...visible.where((item) => item.group == group).map((item) =>
                      Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MilestoneRow(
                              item: item, showProgress: data.owner))),
              ],
          ],
          if (data.owner && data.collectionsPending)
            Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Text(
                    'Some collection details couldn’t be verified yet. Pull to refresh to check again.',
                    style: TextStyle(color: context.colors.light))),
        ]);
  }

  List<List<ProfileMilestone>> _families(List<ProfileMilestone> items) {
    final result = <String, List<ProfileMilestone>>{};
    for (final item in items) {
      result.putIfAbsent(item.family, () => []).add(item);
    }
    return result.values.toList();
  }
}

IconData _icon(String family) => switch (family) {
      'films' => Icons.movie_outlined,
      'series' => Icons.tv_rounded,
      'together' || 'movie_mates' || 'group_nights' => Icons.people_outline,
      'countries' => Icons.public,
      'decades' => Icons.history,
      'collections' => Icons.collections_bookmark_outlined,
      'comfort' => Icons.favorite_outline,
      'reviews' => Icons.chat_bubble_outline,
      'recommendations' => Icons.thumb_up_outlined,
      _ => Icons.explore_outlined,
    };

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.item, required this.showProgress});
  final ProfileMilestone item;
  final bool showProgress;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(_icon(item.family), color: context.colors.warning, size: 28),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(item.title,
                    style: TextStyle(
                        color: context.colors.white,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(item.description,
                    style: TextStyle(color: context.colors.light)),
                if (item.earned && item.earnedAt != null) ...[
                  const SizedBox(height: 8),
                  Text(
                      'Earned ${MaterialLocalizations.of(context).formatMediumDate(item.earnedAt!.toLocal())}',
                      style: TextStyle(color: context.colors.light)),
                ] else if (!item.earned && showProgress) ...[
                  const SizedBox(height: 12),
                  Text('${item.progress} / ${item.target}',
                      style: TextStyle(color: context.colors.primaryText)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(
                      value: (item.progress / item.target).clamp(0.0, 1.0),
                      color: FlixieColors.primary,
                      backgroundColor: context.colors.surface,
                      borderRadius: BorderRadius.circular(4)),
                ],
              ])),
          if (item.earned) ...[
            const SizedBox(width: 8),
            Icon(Icons.check_circle,
                color: context.colors.success, semanticLabel: 'Earned')
          ],
        ]),
      );
}
