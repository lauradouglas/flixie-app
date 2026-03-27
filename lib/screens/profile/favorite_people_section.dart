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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 22,
                decoration: BoxDecoration(
                  color: FlixieColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'FAVOURITE CAST',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              if (favoritePeople.length > 12)
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward,
                    color: FlixieColors.primary,
                    size: 20,
                  ),
                  onPressed: () => _showAllPeopleSheet(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
        ),
        if (top12.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'No favourite people yet.',
              style: textTheme.bodySmall?.copyWith(color: FlixieColors.medium),
            ),
          )
        else
          SizedBox(
            height: 112,
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
    );
  }

  (int?, String, String?) _parsePerson(dynamic item) {
    if (item is Map<String, dynamic>) {
      // Data is directly on the item, not nested under 'person'
      final id = (item['id'] as num?)?.toInt();
      final name = item['name'] as String? ?? 'Unknown';
      final profile = item['profileImgUrl'] as String?;
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
            radius: 40,
            backgroundColor: FlixieColors.tabBarBorder,
            backgroundImage: profilePath != null
                ? CachedNetworkImageProvider('$_imgBase$profilePath')
                : null,
            child: profilePath == null
                ? const Icon(Icons.person, color: FlixieColors.medium, size: 34)
                : null,
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 80,
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

  (int?, String, String?) _parsePerson(dynamic item) {
    if (item is Map<String, dynamic>) {
      // Data is directly on the item, not nested under 'person'
      final id = (item['id'] as num?)?.toInt();
      final name = item['name'] as String? ?? 'Unknown';
      final profile = item['profileImgUrl'] as String?;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
