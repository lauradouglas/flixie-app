import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';

class MovieListGridCard extends StatelessWidget {
  const MovieListGridCard({
    super.key,
    required this.list,
    required this.onOpen,
    required this.onMenu,
  });

  final MovieList list;
  final VoidCallback onOpen;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final shared = list.scope != ListScope.personal;
    final group = list.scope == ListScope.group;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 22),
          decoration: BoxDecoration(
            border:
                Border(bottom: BorderSide(color: context.colors.tabBarBorder)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: 165,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Row(children: [
                      if (list.previewPosterUrls.isEmpty)
                        Expanded(
                            child: ColoredBox(
                                color: context.colors.surfaceElevated,
                                child: const Center(
                                    child:
                                        Icon(Icons.movie_outlined, size: 32)))),
                      for (final url in list.previewPosterUrls.take(3))
                        SizedBox(
                            width: ((MediaQuery.sizeOf(context).width - 32) / 3)
                                .clamp(0.0, 110.0),
                            child: Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: Image.network(
                                  url.startsWith('http')
                                      ? url
                                      : 'https://image.tmdb.org/t/p/w342$url',
                                  height: 165,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Center(
                                      child: Icon(Icons.movie_outlined))),
                            )),
                    ]),
                  )),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      list.name,
                      style: TextStyle(
                        color: context.colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: context.colors.light, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      '${_compactListCountLabel(list)} · ${_visibilityName(list.visibility)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 11.5),
                    ),
                  ),
                  Icon(_privacyIcon(list.visibility),
                      color: context.colors.medium, size: 15),
                ],
              ),
              if (shared) ...[
                const SizedBox(height: 7),
                Row(
                  children: [
                    _CollaboratorStack(
                      collaborators: list.participants.isNotEmpty
                          ? list.participants
                          : list.collaborators,
                      group: group,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        group
                            ? list.groupName ?? 'Group list'
                            : 'Shared with ${list.collaborators.length}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _updatedLabel(list.updatedAt ?? list.createdAt),
                      style: TextStyle(
                          color: context.colors.medium, fontSize: 10.5),
                    ),
                  ),
                  if (list.isOwner)
                    PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      iconSize: 18,
                      onSelected: onMenu,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CollaboratorStack extends StatelessWidget {
  const _CollaboratorStack({
    required this.collaborators,
    required this.group,
  });
  final List<MovieListCollaborator> collaborators;
  final bool group;

  @override
  Widget build(BuildContext context) {
    final people = collaborators.take(3).toList();
    if (people.isEmpty) {
      return Icon(group ? Icons.groups_rounded : Icons.people_outline_rounded,
          color: FlixieColors.primary, size: 20);
    }
    return SizedBox(
      width: 25 + (people.length - 1) * 16,
      height: 27,
      child: Stack(
        clipBehavior: Clip.none,
        children: people.asMap().entries.map((entry) {
          final username = entry.value.username;
          return Positioned(
            left: entry.key * 16,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                color: context.colors.background,
                shape: BoxShape.circle,
              ),
              child: ProfileAvatarView(
                avatar: entry.value.avatar,
                fallbackText:
                    username.isEmpty ? '?' : username[0].toUpperCase(),
                fallbackColor: FlixieColors.primary,
                profileBadges: entry.value.profileBadges,
                size: 22,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

IconData _privacyIcon(String visibility) {
  switch (visibility.toUpperCase()) {
    case ListVisibility.public:
      return Icons.public;
    case ListVisibility.friends:
      return Icons.group;
    default:
      return Icons.lock_outline;
  }
}

String _visibilityName(String visibility) {
  switch (visibility.toUpperCase()) {
    case ListVisibility.public:
      return 'Public';
    case ListVisibility.friends:
      return 'Shared';
    default:
      return 'Private';
  }
}

String _compactListCountLabel(MovieList list) {
  final movies = list.movieCount ?? 0;
  final shows = list.showCount ?? 0;
  final total = list.itemCount ?? movies + shows;
  if (movies > 0 && shows > 0) {
    return '$movies ${movies == 1 ? 'movie' : 'movies'} & '
        '$shows ${shows == 1 ? 'show' : 'shows'}';
  }
  if (movies > 0) return '$movies ${movies == 1 ? 'movie' : 'movies'}';
  if (shows > 0) return '$shows ${shows == 1 ? 'show' : 'shows'}';
  return '$total ${total == 1 ? 'title' : 'titles'}';
}

String _updatedLabel(String? date) {
  if (date == null || date.isEmpty) return 'Updated recently';
  final parsed = DateTime.tryParse(date);
  if (parsed == null) return 'Updated recently';
  final diff = DateTime.now().difference(parsed);
  if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes}m ago';
  if (diff.inHours < 24) return 'Updated ${diff.inHours}h ago';
  if (diff.inDays < 7) return 'Updated ${diff.inDays}d ago';
  return 'Updated ${parsed.month}/${parsed.day}/${parsed.year}';
}
