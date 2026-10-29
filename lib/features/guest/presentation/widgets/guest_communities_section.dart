import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/flixie_pill_style.dart';
import 'package:flixie_app/core/utils/genre_catalogue.dart';
import 'package:flixie_app/core/widgets/genre_icon.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_identity.dart';

typedef GuestCommunity = ({int id, String name});

/// A small, editorial preview of the existing catalogue, not a popularity rank.
class GuestCommunitiesSection extends StatelessWidget {
  const GuestCommunitiesSection(
      {super.key,
      required this.communities,
      required this.onSelect,
      this.loading = false,
      this.failed = false,
      this.onRetry});
  final List<GuestCommunity> communities;
  final ValueChanged<GuestCommunity> onSelect;
  final bool loading, failed;
  final VoidCallback? onRetry;

  List<GuestCommunity> get _visible {
    final ids = <int>{};
    return communities
        .where((c) => isVisibleGenre(c.name, id: c.id) && ids.add(c.id))
        .toList();
  }

  List<GuestCommunity> _preview(List<GuestCommunity> all) {
    const names = [
      'action',
      'comedy',
      'horror',
      'science fiction',
      'romance',
      'animation',
      'thriller',
      'anime'
    ];
    final result = <GuestCommunity>[];
    for (final name in names) {
      final matches = all.where((c) => c.name.trim().toLowerCase() == name);
      if (matches.isNotEmpty) result.add(matches.first);
    }
    for (final c in all) {
      if (result.length >= 8) break;
      if (!result.any((item) => item.id == c.id)) result.add(c);
    }
    return result.take(8).toList();
  }

  Color _tint(BuildContext context, GuestCommunity c) =>
      FlixiePillStyle.genreColors(c.name, Theme.of(context).brightness).$2;

  Future<void> _showAll(BuildContext context, List<GuestCommunity> all) async {
    final selected = await showFlixiePromptSheet<GuestCommunity>(
        context: context,
        maxHeightFraction: .85,
        builder: (sheetContext) =>
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Communities',
                  style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              const Text('Find people who love your kind of films.'),
              const SizedBox(height: 12),
              for (final community in all)
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: IconTheme(
                        data: IconThemeData(color: _tint(context, community)),
                        child: GenreIcon(community.name, size: 22)),
                    title: Text(community.name,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(CommunityIdentity.forId(community.id).blurb,
                            style: TextStyle(
                                color: context.colors.light,
                                fontSize: 14,
                                height: 1.5))),
                    minVerticalPadding: 10,
                    trailing: Icon(Icons.chevron_right,
                        color: context.colors.light, size: 20),
                    onTap: () => Navigator.pop(sheetContext, community)),
            ]));
    if (context.mounted && selected != null) onSelect(selected);
  }

  @override
  Widget build(BuildContext context) {
    final all = _visible, preview = _preview(all);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(
            child: Text('Communities',
                style: Theme.of(context).textTheme.titleLarge)),
        if (all.isNotEmpty && !loading && !failed)
          TextButton(
              onPressed: () => _showAll(context, all),
              style: TextButton.styleFrom(
                  foregroundColor: context.colors.primaryText,
                  minimumSize: const Size(44, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 4)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('See all', style: TextStyle(fontSize: 13)),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, size: 18)
              ])),
      ]),
      const Text('Find people who love your kind of films.',
          style: TextStyle(fontSize: 14, height: 1.5)),
      const SizedBox(height: 12),
      if (loading)
        const LinearProgressIndicator()
      else if (failed)
        TextButton(
            onPressed: onRetry,
            child: const Text('Couldn’t load communities. Retry'))
      else if (all.isEmpty)
        Text('Communities will appear here soon.',
            style: TextStyle(color: context.colors.light, fontSize: 14))
      else ...[
        LayoutBuilder(builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
          final columns = box.maxWidth < 300 || scale > 1.4
              ? 1
              : box.maxWidth >= 720
                  ? 4
                  : 2;
          return Column(children: [
            for (var start = 0; start < preview.length; start += columns) ...[
              if (start > 0) const SizedBox(height: 10),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 10),
                      Expanded(
                          child: start + column < preview.length
                              ? _tile(context, preview[start + column])
                              : const SizedBox.shrink()),
                    ],
                  ])),
            ],
          ]);
        }),
        const SizedBox(height: 10),
        Material(
            color: context.colors.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: context.colors.tabBarBorder)),
            child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showAll(context, all),
                child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Expanded(
                              child: Text(
                                  'Browse all ${all.length} communities',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: context.colors.primaryText,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 8),
                          Icon(Icons.arrow_forward,
                              size: 20, color: context.colors.primaryText)
                        ]))))),
      ],
    ]);
  }

  Widget _tile(BuildContext context, GuestCommunity community) => Semantics(
      button: true,
      child: Material(
          key: ValueKey('guest-community-${community.id}'),
          color: context.colors.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: context.colors.tabBarBorder)),
          child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onSelect(community),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 52),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
                      child: Row(children: [
                        IconTheme(
                            data:
                                IconThemeData(color: _tint(context, community)),
                            child: GenreIcon(community.name, size: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(community.name,
                                style: TextStyle(
                                    fontSize: 14,
                                    color: context.colors.white,
                                    fontWeight: FontWeight.w600))),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right,
                            size: 18, color: context.colors.medium)
                      ]))))));
}
