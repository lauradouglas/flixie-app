import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/media_lists_section.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';

class ListsPreviewSection extends StatefulWidget {
  const ListsPreviewSection({
    super.key,
    required this.userId,
    required this.title,
    required this.emptyMessage,
    this.allowManage = false,
    this.embedded = false,
    this.publicOnly = false,
  });

  final String userId;
  final String title;
  final String emptyMessage;
  final bool allowManage;
  final bool embedded;
  final bool publicOnly;

  @override
  State<ListsPreviewSection> createState() => _ListsPreviewSectionState();
}

class _ListsPreviewSectionState extends State<ListsPreviewSection> {
  late Future<List<MovieList>> _listsFuture;

  @override
  void initState() {
    super.initState();
    _listsFuture = UserService.getMovieLists(widget.userId);
  }

  @override
  void didUpdateWidget(covariant ListsPreviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _listsFuture = UserService.getMovieLists(widget.userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isOwnProfile = auth.dbUser?.id == widget.userId;
    final cachedLists = isOwnProfile ? auth.cachedMovieLists : null;
    return FutureBuilder<List<MovieList>>(
      future: cachedLists == null ? _listsFuture : null,
      initialData: cachedLists,
      builder: (context, snapshot) {
        final loadedLists = (snapshot.data ?? const <MovieList>[])
            .where((list) =>
                isOwnProfile ||
                list.userId == null ||
                list.userId == widget.userId)
            .toList(growable: false);
        final lists = widget.publicOnly
            ? loadedLists
                .where((list) => list.visibility == ListVisibility.public)
                .toList(growable: false)
            : loadedLists;
        final previewLists =
            (widget.allowManage ? lists.take(4) : lists).map((list) {
          final posters = list.previewPosterUrls.map(_posterUrl).toList();
          return MediaDetailListItem(
            id: list.id,
            name: list.scope == ListScope.group && list.groupName != null
                ? '${list.name} · ${list.groupName}'
                : list.name,
            visibility: list.visibility,
            posterUrls: posters,
            itemCount: list.itemCount ??
                (list.movieCount ?? 0) + (list.showCount ?? 0),
            ownerId: list.userId,
          );
        }).toList(growable: false);

        final content = snapshot.connectionState == ConnectionState.waiting &&
                snapshot.data == null
            ? MediaListsSection(
                ownLists: const [],
                friendLists: const [],
                loading: true,
                itemLabel: 'items',
                title: widget.title,
                onEdit: () {},
                onOpenList: (_) {},
              )
            : lists.isEmpty
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(
                          color: FlixieColors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(widget.emptyMessage,
                          style: const TextStyle(color: FlixieColors.medium)),
                    ],
                  )
                : MediaListsSection(
                    ownLists: previewLists,
                    friendLists: const [],
                    loading: false,
                    itemLabel: 'items',
                    title: widget.title,
                    ownSummary:
                        '${lists.length} ${lists.length == 1 ? 'list' : 'lists'}',
                    editLabel: 'Manage',
                    showOwnItemCount: true,
                    showEdit: widget.allowManage,
                    onEdit: () => context.push('/movie-lists'),
                    onSeeAll: widget.allowManage
                        ? () => context.push('/movie-lists')
                        : null,
                    onOpenList: (item) {
                      final list =
                          lists.firstWhere((list) => list.id == item.id);
                      context.push(
                        '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&owner=${Uri.encodeComponent(list.userId ?? widget.userId)}&isOwner=${list.isOwner}&canEdit=${list.canEdit}',
                      );
                    },
                  );

        if (widget.embedded) {
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

String _posterUrl(String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  return 'https://image.tmdb.org/t/p/w342$path';
}
