import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class ListsPreviewSection extends StatelessWidget {
  const ListsPreviewSection({
    super.key,
    required this.userId,
    required this.title,
    required this.emptyMessage,
    this.allowManage = false,
    this.embedded = false,
  });

  final String userId;
  final String title;
  final String emptyMessage;
  final bool allowManage;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MovieList>>(
      future: UserService.getMovieLists(userId),
      builder: (context, snapshot) {
        final lists = snapshot.data ?? const <MovieList>[];
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: FlixieColors.light,
                      ),
                ),
                const Spacer(),
                if (allowManage)
                  TextButton(
                    onPressed: () => context.push('/movie-lists'),
                    child: const Text('Manage'),
                  ),
              ],
            ),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (lists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyMessage,
                  style: const TextStyle(color: FlixieColors.medium),
                ),
              )
            else
              Column(
                children: lists.take(4).map((list) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(list.name),
                    subtitle: Text(_listCountLabel(list)),
                    trailing: Icon(
                      _privacyIcon(list.visibility),
                      size: 16,
                      color: FlixieColors.medium,
                    ),
                    onTap: () => context.push(
                      '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&owner=${Uri.encodeComponent(list.userId ?? userId)}',
                    ),
                  );
                }).toList(growable: false),
              ),
          ],
        );

        if (embedded) {
          return content;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBackgroundFocused,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: content,
        );
      },
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

String _listCountLabel(MovieList list) {
  final movies = list.movieCount ?? 0;
  final shows = list.showCount ?? 0;
  final total = list.itemCount ?? movies + shows;
  if (movies > 0 && shows > 0) {
    return '$total items · $movies films · $shows shows';
  }
  if (movies > 0) return '$movies films';
  if (shows > 0) return '$shows shows';
  return '$total items';
}
