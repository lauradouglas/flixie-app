import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/watch_provider.dart';
import 'package:flixie_app/features/watchlist/domain/tonight_filters.dart';
import 'package:flixie_app/features/settings/data/reference_data_service.dart';

class TonightFiltersPanel extends StatelessWidget {
  const TonightFiltersPanel(
      {super.key,
      this.avoid = const {},
      this.request = '',
      this.genre,
      this.genres = const [
        'Rom com',
        'Romance',
        'Comedy',
        'Drama',
        'Crime',
        'Science Fiction',
        'Fantasy',
        'Thriller',
        'Horror',
        'Adventure'
      ],
      this.onGenre,
      this.findingToday = false,
      this.onExperience,
      required this.minutes,
      required this.mood,
      required this.providers,
      required this.selectedProviders,
      required this.savedProviderIds,
      required this.servicesOnly,
      required this.rentals,
      required this.count,
      required this.loading,
      required this.region,
      required this.onTime,
      required this.onMood,
      required this.onServices,
      required this.onClear,
      required this.onPick,
      required this.onMore,
      required this.onSort,
      required this.sortLabel});
  final Set<String> avoid;
  final String request;
  final String? genre;
  final List<String> genres;
  final ValueChanged<String?>? onGenre;
  final bool findingToday;
  final void Function(WatchlistMood, Set<String>, String)? onExperience;
  final int? minutes;
  final WatchlistMood mood;
  final List<WatchProvider> providers;
  final Set<int> selectedProviders, savedProviderIds;
  final bool servicesOnly, rentals, loading;
  final int count;
  final String region, sortLabel;
  final ValueChanged<int?> onTime;
  final ValueChanged<WatchlistMood> onMood;
  final void Function(List<WatchProvider>, Set<int>, bool, bool) onServices;
  final VoidCallback onClear, onPick, onMore, onSort;

  Future<void> _sheet(BuildContext context, Widget child) =>
      showModalBottomSheet<void>(
          context: context,
          useRootNavigator: true,
          useSafeArea: true,
          isScrollControlled: true,
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .85),
          builder: (_) => child);

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, IconData icon, bool active, VoidCallback onTap) =>
        FlixiePill.action(
            selected: active,
            label: SizedBox(
                width: double.infinity,
                child: Text(label, textAlign: TextAlign.center)),
            onPressed: onTap);
    final controls = <Widget>[
      chip(
          minutes == null ? 'Time' : '≤ $minutes min',
          Icons.schedule,
          minutes != null,
          () => _sheet(
              context,
              _ChoiceSheet(
                  title: 'How much time?',
                  note:
                      'Movie runtime or estimated episode length. Unknown lengths are excluded with a time limit.',
                  children: [
                    for (final value in <int?>[30, 60, 90, 120, 150, null])
                      Builder(
                          builder: (sheetContext) => FlixiePill.choice(
                              label: Text(
                                  value == null ? 'No limit' : '$value min'),
                              selected: minutes == value,
                              onSelected: (_) {
                                onTime(value);
                                Navigator.pop(sheetContext);
                              }))
                  ]))),
      chip(
          genre ?? 'Genre',
          Icons.category_outlined,
          genre != null,
          () => _sheet(
              context,
              _ChoiceSheet(
                title: 'Choose a genre',
                note: 'Filter the titles in your watchlist.',
                children: [
                  for (final value in <String?>[null, ...genres])
                    Builder(
                        builder: (sheetContext) => FlixiePill.choice(
                            label: Text(value ?? 'All genres'),
                            selected: genre == value,
                            onSelected: (_) {
                              onGenre?.call(value);
                              Navigator.pop(sheetContext);
                            })),
                ],
              ))),
      chip(
          servicesOnly ? 'Services · ${selectedProviders.length}' : 'Services',
          Icons.tv,
          servicesOnly,
          () => _sheet(
              context,
              _SearchServicesSheet(
                  providers: providers,
                  selected: selectedProviders,
                  saved: savedProviderIds,
                  enabled: servicesOnly,
                  rentals: rentals,
                  region: region,
                  onApply: onServices))),
    ];
    final actions = Row(mainAxisSize: MainAxisSize.min, children: [
      TextButton.icon(
          onPressed: count == 0 || loading ? null : onPick,
          style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          icon: const Icon(Icons.shuffle, size: 16),
          label: const Text('Pick one')),
      IconButton(
          tooltip: 'More watchlist filters',
          onPressed: onMore,
          icon: const Icon(Icons.more_horiz, size: 20)),
    ]);
    return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(children: [
          LayoutBuilder(builder: (context, box) {
            if (MediaQuery.textScalerOf(context).scale(13) > 20) {
              return Wrap(spacing: 8, runSpacing: 4, children: [
                for (final control in controls)
                  SizedBox(width: (box.maxWidth - 8) / 2, child: control)
              ]);
            }
            return Row(children: [
              for (var i = 0; i < controls.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: controls[i]),
              ]
            ]);
          }),
          LayoutBuilder(builder: (context, box) {
            final sorting = TextButton(
                onPressed: onSort,
                style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                    textStyle: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                    foregroundColor: context.colors.light),
                child:
                    Text('$sortLabel · ${loading ? 'Checking…' : '$count'}'));
            if (MediaQuery.textScalerOf(context).scale(13) > 20) {
              return Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [sorting, actions]);
            }
            return Row(children: [Expanded(child: sorting), actions]);
          }),
        ]));
  }
}

class _ChoiceSheet extends StatelessWidget {
  const _ChoiceSheet(
      {required this.title, required this.note, required this.children});
  final String title, note;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: children),
            const SizedBox(height: 16),
            SizedBox(
                width: double.infinity,
                child: Text(note,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.light))),
          ]));
}

class _SearchServicesSheet extends StatefulWidget {
  const _SearchServicesSheet(
      {required this.providers,
      required this.selected,
      required this.saved,
      required this.enabled,
      required this.rentals,
      required this.region,
      required this.onApply});
  final List<WatchProvider> providers;
  final Set<int> selected, saved;
  final bool enabled, rentals;
  final String region;
  final void Function(List<WatchProvider>, Set<int>, bool, bool) onApply;
  @override
  State<_SearchServicesSheet> createState() => _SearchServicesSheetState();
}

class _SearchServicesSheetState extends State<_SearchServicesSheet> {
  late Set<int> selected = {...widget.selected};
  late bool rentals = widget.rentals;
  bool loading = true, failed = false, adding = false;
  String query = '';
  late List<WatchProvider> catalog = [...widget.providers];
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      failed = false;
    });
    try {
      final all = await ReferenceDataService.getWatchProviders();
      if (!mounted) return;
      setState(() {
        catalog = {
          for (final p in [...widget.providers, ...all]) p.id: p
        }.values.toList();
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = catalog
        .where((p) =>
            (selected.contains(p.id) ||
                widget.saved.contains(p.id) ||
                (adding &&
                    p.isVisible &&
                    (widget.region == 'GB'
                        ? p.supportsGb
                        : widget.region == 'US'
                            ? p.supportsUs
                            : true))) &&
            p.providerName.toLowerCase().contains(query.toLowerCase()))
        .toList()
      ..sort((a, b) => a.providerName.compareTo(b.providerName));
    return SizedBox(
        height: MediaQuery.sizeOf(context).height * .8,
        child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 8),
              child: Row(children: [
                Expanded(
                    child: Text('Where are you watching?',
                        style: Theme.of(context).textTheme.titleLarge)),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ])),
          Expanded(
              child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  children: [
                Text('For this search only · ${widget.region}',
                    style: TextStyle(color: context.colors.secondary)),
                const SizedBox(height: 8),
                const Text(
                    'At a friend’s house? Add their services here. Your saved subscriptions stay unchanged.'),
                const SizedBox(height: 12),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed: () => setState(() => adding = !adding),
                      icon: const Icon(Icons.add),
                      label: Text(adding
                          ? 'Show selected services'
                          : 'Add another service')),
                  TextButton(
                      onPressed: () =>
                          setState(() => selected = {...widget.saved}),
                      child: const Text('Use my services')),
                ]),
                if (adding)
                  TextField(
                      decoration: const InputDecoration(
                          labelText: 'Search services',
                          prefixIcon: Icon(Icons.search)),
                      onChanged: (value) => setState(() => query = value)),
                if (loading) const LinearProgressIndicator(),
                if (failed)
                  TextButton(
                      onPressed: _load,
                      child:
                          const Text('Couldn’t load other services · Retry')),
                for (final provider in visible)
                  CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(provider.logoUrl,
                            width: 42,
                            height: 42,
                            fit: BoxFit.contain,
                            excludeFromSemantics: true,
                            errorBuilder: (_, __, ___) => Container(
                                width: 42,
                                height: 42,
                                color: context.colors.surfaceElevated,
                                child: Icon(Icons.tv_outlined,
                                    color: context.colors.medium))),
                      ),
                      title: Text(provider.providerName),
                      subtitle: Text(widget.saved.contains(provider.id)
                          ? 'Your saved service'
                          : 'Just for this search${provider.isAddOn ? ' · Separate add-on subscription' : ''}'),
                      value: selected.contains(provider.id),
                      onChanged: (_) => setState(() {
                            if (!selected.remove(provider.id)) {
                              selected.add(provider.id);
                            }
                          })),
                if (!loading && visible.isEmpty)
                  const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                          'No services here. Try adding another service.')),
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Include paid rentals'),
                    subtitle: const Text(
                        'Also include rentals on other services. Fees apply.'),
                    value: rentals,
                    onChanged: (v) => setState(() => rentals = v)),
                Text(
                    'Titles only need to be available on one selected service. Availability follows the country above.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: context.colors.light)),
                const SizedBox(height: 16),
              ])),
          Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                        onPressed: () {
                          widget.onApply(catalog, selected, false, false);
                          Navigator.pop(context);
                        },
                        child: const Text('Any service')),
                    FilledButton(
                        onPressed: selected.isEmpty && !rentals
                            ? null
                            : () {
                                widget.onApply(
                                    catalog, selected, true, rentals);
                                Navigator.pop(context);
                              },
                        child: const Text('Use for this search')),
                  ])),
        ]));
  }
}
