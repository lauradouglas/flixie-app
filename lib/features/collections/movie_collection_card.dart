import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'collection_screen.dart';

/// Uses the movie's existing metadata; does not fetch a catalogue on detail load.
class MovieCollectionCard extends StatelessWidget {
  const MovieCollectionCard(
      {super.key, required this.collection, this.onReturn});
  final Map<String, dynamic> collection;
  final VoidCallback? onReturn;
  @override
  Widget build(BuildContext context) {
    final id = int.tryParse('${collection['id']}');
    if (id == null) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Part of a collection',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Material(
          color: context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: Icon(Icons.collections_bookmark_outlined,
                  color: context.colors.primaryText),
              title: Text(collection['name'] as String? ?? 'Movie collection',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('View all films and your progress'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => CollectionScreen(collectionId: id)));
                onReturn?.call();
              })),
    ]);
  }
}
