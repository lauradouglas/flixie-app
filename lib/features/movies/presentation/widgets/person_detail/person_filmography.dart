import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../person_filmography_selection.dart';
import 'person_empty_section.dart';
import 'person_credit_card.dart';
import 'person_filmography_controls.dart';

class PersonFilmographySection extends StatefulWidget {
  const PersonFilmographySection(
      {super.key,
      required this.credits,
      required this.library,
      required this.viewerId,
      required this.onOpen,
      required this.onViewAll});
  final List<PersonFilmCredit> credits;
  final PersonLibraryStatus library;
  final String? viewerId;
  final void Function(int, String) onOpen;
  final void Function(List<PersonFilmCredit>, String) onViewAll;
  @override
  State<PersonFilmographySection> createState() =>
      _PersonFilmographySectionState();
}

class _PersonFilmographySectionState extends State<PersonFilmographySection> {
  PersonFilmographyFilters _filters = const PersonFilmographyFilters();
  @override
  void didUpdateWidget(covariant PersonFilmographySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewerId != widget.viewerId) {
      _filters = _filters.copyWith(personal: PersonPersonalFilter.all);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filmography = selectPersonCredits(widget.credits,
        filters: _filters, library: widget.library);
    final allCredits = widget.credits;

    if (allCredits.isEmpty) {
      return const PersonEmptySection(
        'No credits yet',
        'Credits will appear here once they are available.',
        Icons.local_movies_outlined,
      );
    }

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: context.colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Filmography ---------------------------------------------
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: sectionTitle('Filmography')),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                '${allCredits.length} credits',
                style: TextStyle(
                  color: context.colors.medium,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        PersonFilmographyControls(
            credits: allCredits,
            library: widget.library,
            filters: _filters,
            onChanged: (value) => setState(() => _filters = value)),
        const SizedBox(height: 12),
        if (filmography.isEmpty)
          const PersonEmptySection(
            'No matches',
            'Try another role filter or sorting option.',
            Icons.filter_alt_off_outlined,
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: filmography.length > 12 ? 12 : filmography.length,
            separatorBuilder: (_, __) => Divider(
              color: context.colors.tabBarBorder,
              height: 1,
            ),
            itemBuilder: (context, i) => PersonCreditRow(
                item: filmography[i],
                library: widget.library,
                onOpen: () =>
                    widget.onOpen(filmography[i].id, filmography[i].type)),
          ),
          if (filmography.length > 12) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => widget.onViewAll(filmography, _filters.role.label),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: context.colors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.colors.tabBarBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                        child: Text(
                      'View All ${filmography.length} Credits',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down,
                        color: FlixieColors.primary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class PersonCreditsSheet extends StatelessWidget {
  const PersonCreditsSheet(
      {super.key,
      required this.credits,
      required this.library,
      required this.roleLabel,
      required this.scrollController,
      required this.onOpen});
  final List<PersonFilmCredit> credits;
  final PersonLibraryStatus library;
  final String roleLabel;
  final ScrollController scrollController;
  final void Function(int, String) onOpen;
  @override
  Widget build(BuildContext context) => Column(children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: context.colors.medium.withValues(alpha: .45),
                borderRadius: BorderRadius.circular(2))),
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
            child: Row(children: [
              Expanded(
                  child: Text('$roleLabel Credits',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: context.colors.white,
                          fontWeight: FontWeight.bold))),
              IconButton(
                  tooltip: 'Close credits',
                  onPressed: () => Navigator.of(context).pop(),
                  icon:
                      Icon(Icons.close_rounded, color: context.colors.medium)),
            ])),
        Expanded(
            child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: credits.length,
                separatorBuilder: (_, __) =>
                    Divider(color: context.colors.tabBarBorder, height: 1),
                itemBuilder: (_, i) => PersonCreditRow(
                    item: credits[i],
                    library: library,
                    onOpen: () => onOpen(credits[i].id, credits[i].type)))),
      ]);
}
