import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';

class FavoritePeopleSection extends StatelessWidget {
  const FavoritePeopleSection({
    super.key,
    required this.favoritePeople,
  });

  final List<dynamic> favoritePeople;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w185';

  void _showAllPeopleSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AllFavoritePeopleSheet(favoritePeople: favoritePeople),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final top12 = favoritePeople.take(12).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FAVORITE CAST',
                style: textTheme.titleMedium?.copyWith(
                  color: FlixieColors.tertiary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              TextButton(
                onPressed: () => _showAllPeopleSheet(context),
                child: const Text(
                  'See All',
                  style: TextStyle(color: FlixieColors.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (top12.isEmpty)
            Text(
              'No favourite people yet.',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            )
          else
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: top12.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (_, i) {
                  final person = _parsePerson(top12[i]);
                  return _PersonAvatar(
                    personId: person.$1,
                    name: person.$2,
                    profilePath: person.$3,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  (int?, String, String?) _parsePerson(dynamic item) {
    if (item is Map<String, dynamic>) {
      final person = item['person'] as Map<String, dynamic>?;
      final id = (item['personId'] as num?)?.toInt()
          ?? (person?['id'] as num?)?.toInt();
      final name = person?['name'] as String? ?? 'Unknown';
      final profile = person?['profileImgUrl'] as String?;
      return (id, name, profile);
    }
    return (null, 'Unknown', null);
  }
}

class _PersonAvatar extends StatelessWidget {
  const _PersonAvatar({
    required this.personId,
    required this.name,
    this.profilePath,
  });

  final int? personId;
  final String name;
  final String? profilePath;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w185';

  String get _shortName {
    final parts = name.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}. ${parts.last}';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: personId != null ? () => context.push('/people/$personId') : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: FlixieColors.tabBarBorder,
            backgroundImage: profilePath != null
                ? CachedNetworkImageProvider('$_imgBase$profilePath')
                : null,
            child: profilePath == null
                ? const Icon(Icons.person, color: FlixieColors.medium, size: 28)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              _shortName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllFavoritePeopleSheet extends StatelessWidget {
  const _AllFavoritePeopleSheet({required this.favoritePeople});
  final List<dynamic> favoritePeople;

  static const String _imgBase = 'https://image.tmdb.org/t/p/w185';

  (int?, String, String?) _parsePerson(dynamic item) {
    if (item is Map<String, dynamic>) {
      final person = item['person'] as Map<String, dynamic>?;
      final id = (item['personId'] as num?)?.toInt()
          ?? (person?['id'] as num?)?.toInt();
      final name = person?['name'] as String? ?? 'Unknown';
      final profile = person?['profileImgUrl'] as String?;
      return (id, name, profile);
    }
    return (null, 'Unknown', null);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: FlixieColors.medium.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  'Favourite Cast',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: FlixieColors.tertiary.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${favoritePeople.length}',
                    style: const TextStyle(
                      color: FlixieColors.tertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              controller: scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 8,
                childAspectRatio: 0.7,
              ),
              itemCount: favoritePeople.length,
              itemBuilder: (_, i) {
                final person = _parsePerson(favoritePeople[i]);
                return _PersonAvatar(
                  personId: person.$1,
                  name: person.$2,
                  profilePath: person.$3,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
