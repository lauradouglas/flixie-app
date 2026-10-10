import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../person_filmography_selection.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

class PersonFilmographyControls extends StatefulWidget {
  const PersonFilmographyControls(
      {super.key,
      required this.credits,
      required this.library,
      required this.filters,
      required this.onChanged});
  final List<PersonFilmCredit> credits;
  final PersonLibraryStatus library;
  final PersonFilmographyFilters filters;
  final ValueChanged<PersonFilmographyFilters> onChanged;
  @override
  State<PersonFilmographyControls> createState() =>
      _PersonFilmographyControlsState();
}

class _PersonFilmographyControlsState extends State<PersonFilmographyControls> {
  bool _showAdvancedCreditFilters = false;
  final _filmographySearchController = TextEditingController();
  PersonFilmographyFilters get filters => widget.filters;
  @override
  void didUpdateWidget(covariant PersonFilmographyControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_filmographySearchController.text != filters.query) {
      _filmographySearchController.text = filters.query;
    }
  }

  @override
  void dispose() {
    _filmographySearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCredits = widget.credits;
    final years = allCredits
        .map((credit) => credit.year)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final roleFilters = <PersonRoleFilter>[
      PersonRoleFilter.all,
      if (allCredits.any((credit) => credit.isCast)) PersonRoleFilter.actor,
      if (allCredits.any((credit) => credit.isDirector))
        PersonRoleFilter.director,
      if (allCredits.any((credit) => credit.isWriter)) PersonRoleFilter.writer,
      if (allCredits.any((credit) => credit.isProducer))
        PersonRoleFilter.producer,
    ];
    final personalFilters = <PersonPersonalFilter>[
      PersonPersonalFilter.all,
      if (allCredits.any(
        (credit) =>
            credit.isMovie && widget.library.watched.contains(credit.id),
      ))
        PersonPersonalFilter.watched,
      if (allCredits.any(
        (credit) =>
            credit.isMovie && widget.library.watchlist.contains(credit.id),
      ))
        PersonPersonalFilter.watchlist,
      if (allCredits.any(
        (credit) =>
            credit.isMovie && widget.library.favourites.contains(credit.id),
      ))
        PersonPersonalFilter.favourites,
    ];
    final advancedFilterCount = [
      filters.role != PersonRoleFilter.all,
      filters.personal != PersonPersonalFilter.all,
      filters.year != null,
      filters.sort != PersonCreditSort.newest,
    ].where((active) => active).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _filmographySearchController,
          onChanged: (value) =>
              widget.onChanged(filters.copyWith(query: value)),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: TextStyle(color: context.colors.white),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search titles or roles',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: filters.query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _filmographySearchController.clear();
                      widget.onChanged(filters.copyWith(query: ''));
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final segment = Container(
            height: 42 * scale.clamp(1.0, 3.0),
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: context.colors.surface.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: context.colors.tabBarBorder),
            ),
            child: Row(
              children: PersonMediaFilter.values.map((filter) {
                final selected = filters.media == filter;
                return Expanded(
                  child: InkWell(
                    onTap: () =>
                        widget.onChanged(filters.copyWith(media: filter)),
                    borderRadius: BorderRadius.circular(19),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? FlixieColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: Text(
                        filter.label,
                        style: TextStyle(
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : context.colors.medium,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(growable: false),
            ),
          );
          final filtersButton = FlixiePill.action(
            onPressed: () => setState(
                () => _showAdvancedCreditFilters = !_showAdvancedCreditFilters),
            selected: advancedFilterCount > 0,
            avatar: const Icon(Icons.tune_rounded),
            label: Text(advancedFilterCount > 0
                ? 'Filters $advancedFilterCount'
                : 'Filters'),
          );
          if (constraints.maxWidth < 320 || scale > 1.2) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  segment,
                  const SizedBox(height: 8),
                  filtersButton,
                ]);
          }
          return Row(children: [
            Expanded(child: segment),
            const SizedBox(width: 8),
            filtersButton
          ]);
        }),
        if (_showAdvancedCreditFilters) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roleFilters.map((filter) {
                final selected = filters.role == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FlixiePill.choice(
                      label: Text(filter.label),
                      selected: selected,
                      onSelected: (_) =>
                          widget.onChanged(filters.copyWith(role: filter))),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: personalFilters.map((filter) {
                final selected = filters.personal == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FlixiePill.choice(
                      avatar: Icon(filter.icon, size: 16),
                      label: Text(filter.label),
                      selected: selected,
                      showCheckmark: false,
                      onSelected: (_) =>
                          widget.onChanged(filters.copyWith(personal: filter))),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _creditSortMenu(),
              PopupMenuButton<String>(
                initialValue: filters.year ?? '',
                onSelected: (year) => widget.onChanged(
                    filters.copyWith(year: year, clearYear: year.isEmpty)),
                color: context.colors.surface,
                itemBuilder: (context) => [
                  const PopupMenuItem<String>(
                    value: '',
                    child: Text('All years'),
                  ),
                  ...years.map(
                    (year) => PopupMenuItem<String>(
                      value: year,
                      child: Text(year),
                    ),
                  ),
                ],
                child: _controlChip(
                  Icons.calendar_month_outlined,
                  filters.year ?? 'All years',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _creditSortMenu() {
    return PopupMenuButton<PersonCreditSort>(
      initialValue: filters.sort,
      onSelected: (sort) => widget.onChanged(filters.copyWith(sort: sort)),
      color: context.colors.surface,
      itemBuilder: (context) => PersonCreditSort.values
          .map(
            (sort) => PopupMenuItem(
              value: sort,
              child: Text(sort.label),
            ),
          )
          .toList(),
      child: _controlChip(Icons.sort_rounded, filters.sort.label),
    );
  }

  Widget _controlChip(IconData icon, String label) {
    return FlixiePill.label(
        compact: false,
        avatar: Icon(icon),
        label: Row(mainAxisSize: MainAxisSize.min, children: [
          Flexible(child: Text(label)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16)
        ]));
  }
}

extension _PersonalFilterIcon on PersonPersonalFilter {
  IconData get icon => switch (this) {
        PersonPersonalFilter.all => Icons.movie_filter_outlined,
        PersonPersonalFilter.watched => Icons.check_circle_outline_rounded,
        PersonPersonalFilter.watchlist => Icons.bookmark_outline_rounded,
        PersonPersonalFilter.favourites => Icons.favorite_outline_rounded,
      };
}
