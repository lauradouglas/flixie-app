import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/person.dart';
import '../../person_filmography_selection.dart';
import 'person_empty_section.dart';
import 'person_credit_card.dart';

class PersonKnownForSection extends StatelessWidget {
  const PersonKnownForSection(
      {super.key,
      required this.credits,
      required this.library,
      required this.onOpen});
  final PersonCredits credits;
  final PersonLibraryStatus library;
  final void Function(int, String) onOpen;
  @override
  Widget build(BuildContext context) {
    final knownFor = credits.knownForCredits;
    if (knownFor.isEmpty) {
      return const PersonEmptySection(
        'No known titles yet',
        'Recognisable titles will appear here once they are available.',
        Icons.local_movies_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Known For',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: context.colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              '${knownFor.length} titles',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 286 +
              150 *
                  (MediaQuery.textScalerOf(context).scale(1) - 1)
                      .clamp(0.0, 3.0),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: knownFor.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => PersonKnownForCard(
                item: knownFor[index],
                library: library,
                role: _knownForRole(knownFor[index]),
                onOpen: () => onOpen(knownFor[index].id, knownFor[index].type)),
          ),
        ),
      ],
    );
  }

  String? _knownForRole(PersonCreditItem item) {
    if (item.characters.isNotEmpty) return item.characters.first;
    final jobs = credits.crewCredits
        .where((credit) => credit.id == item.id && credit.type == item.type)
        .map((credit) => credit.job)
        .where((job) => job.trim().isNotEmpty)
        .toSet()
        .toList();
    if (jobs.isEmpty) return null;
    return jobs.take(2).join(' • ');
  }
}
