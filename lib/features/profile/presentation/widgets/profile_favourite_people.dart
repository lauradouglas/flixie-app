import 'featured_person_sheet.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'favourite_poster_rail.dart';

class ProfileFavouritePeople extends StatelessWidget {
  const ProfileFavouritePeople(
      {super.key,
      required this.people,
      this.featured = const {},
      this.onChoose,
      this.saving = false});
  final List<dynamic> people;
  final Map<String, int> featured;
  final Future<void> Function(String role, int? person)? onChoose;
  final bool saving;

  List<Map> get entries => people
      .whereType<Map>()
      .map((p) => p['person'] is Map ? p['person'] as Map : p)
      .toList();
  int? id(Map p) => (p['id'] ?? p['personId']) as int?;
  String name(Map p) => (p['name'] ?? 'Person').toString();
  FavouriteDisplayItem display(Map p) => FavouriteDisplayItem(
      title: name(p),
      imagePath: (p['profileImgUrl'] ?? p['profilePath'])?.toString(),
      department: p['department']?.toString(),
      featuredRoles: [
        for (final role in ['director', 'actor', 'actress'])
          if (id(p) != null && featured[role] == id(p))
            '${role[0].toUpperCase()}${role.substring(1)}'
      ],
      route: id(p) == null ? null : '/people/${id(p)}');

  Future<void> choose(BuildContext context, String role) async {
    final auth = Provider.of<AuthProvider?>(context, listen: false);
    final viewer = auth?.dbUser?.id;
    await showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (_) => FeaturedPersonSheet(
          role: role,
          people: entries,
          initialId: featured[role],
          onSave: (person) async {
            if (!context.mounted ||
                (auth != null && auth.dbUser?.id != viewer)) {
              throw StateError('Your account changed. Reopen this sheet.');
            }
            await onChoose?.call(role, person);
          }),
    );
  }

  Widget portrait(Map? person, double size) {
    final raw = person == null
        ? null
        : (person['profileImgUrl'] ?? person['profilePath'])?.toString();
    return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
            width: size,
            height: size * 1.5,
            child: raw == null || raw.isEmpty
                ? const Icon(Icons.person_outline, size: 36)
                : Image.network(
                    raw.startsWith('http')
                        ? raw
                        : 'https://image.tmdb.org/t/p/w185$raw',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person_outline, size: 36))));
  }

  @override
  Widget build(BuildContext context) {
    final items = entries;
    // Retain the read-only collection variant for existing consumers.
    if (onChoose == null) {
      if (items.isNotEmpty) {
        return FavouritePosterRail(
            title: 'Favourite people',
            items: items.map(display).toList(),
            circular: true);
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const FlixieSectionHeader(title: 'Favourite people'),
        TextButton.icon(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.add),
            label: const Text('Add favourite people'))
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: FlixieSectionHeader(title: 'Favourite people')),
        TextButton(
            onPressed: () => FavouritePosterRail(
                    title: 'Favourite people',
                    items: items.map(display).toList(),
                    circular: true)
                .showAll(context),
            child: Text('All (${items.length})',
                style: TextStyle(
                    fontSize: 14, color: context.colors.primaryText))),
      ]),
      if (saving) const LinearProgressIndicator(),
      LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.4;
        final cards = <Widget>[];
        for (final role in ['director', 'actor', 'actress']) {
          final matches = items.where((p) => id(p) == featured[role]);
          final person = matches.isEmpty ? null : matches.first;
          final content = Column(children: [
            InkWell(
                onTap: person == null
                    ? (saving ? null : () => choose(context, role))
                    : () => context.push('/people/${id(person)}'),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(children: [
                      SizedBox(
                          width: 88,
                          height: 124,
                          child: Stack(children: [
                            Positioned(
                                top: 0, left: 0, child: portrait(person, 72)),
                            if (person != null)
                              Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: IconButton.filled(
                                      tooltip: 'Edit favourite $role',
                                      onPressed: saving
                                          ? null
                                          : () => choose(context, role),
                                      style: IconButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          foregroundColor: context.colors.light,
                                          minimumSize: const Size(48, 48),
                                          padding: const EdgeInsets.all(8)),
                                      icon: Container(
                                          width: 32,
                                          height: 32,
                                          decoration: BoxDecoration(
                                              color: context.colors.surface,
                                              shape: BoxShape.circle),
                                          child: const Icon(Icons.edit_outlined,
                                              size: 16)))),
                          ])),
                      const SizedBox(height: 8),
                      Text(person == null ? 'Choose your $role' : name(person),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (person != null)
                        Text(
                            role.isEmpty
                                ? ''
                                : '${role[0].toUpperCase()}${role.substring(1)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 13, color: context.colors.light)),
                    ]))),
          ]);
          cards.add(stacked ? content : Expanded(child: content));
        }
        return stacked
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch, children: cards)
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start, children: cards);
      }),
    ]);
  }
}
