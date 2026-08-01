import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_section_header.dart';

class MediaDetailListItem {
  const MediaDetailListItem({
    required this.id,
    required this.name,
    required this.visibility,
    required this.posterUrls,
    required this.itemCount,
    this.ownerId,
    this.ownerUsername,
    this.ownerAvatar,
  });

  final String id;
  final String name;
  final String visibility;
  final List<String> posterUrls;
  final int itemCount;
  final String? ownerId;
  final String? ownerUsername;
  final ProfileAvatar? ownerAvatar;
}

class MediaListsSection extends StatelessWidget {
  const MediaListsSection({
    super.key,
    required this.ownLists,
    required this.friendLists,
    required this.loading,
    required this.itemLabel,
    required this.onEdit,
    required this.onOpenList,
    this.onSeeAll,
    this.title = 'Lists',
    this.ownSummary,
    this.editLabel = 'Edit',
    this.showOwnItemCount = false,
    this.showEdit = true,
  });

  final List<MediaDetailListItem> ownLists;
  final List<MediaDetailListItem> friendLists;
  final bool loading;
  final String itemLabel;
  final VoidCallback onEdit;
  final VoidCallback? onSeeAll;
  final void Function(MediaDetailListItem item) onOpenList;
  final String title;
  final String? ownSummary;
  final String editLabel;
  final bool showOwnItemCount;
  final bool showEdit;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SkeletonBox(width: 86, height: 20),
            Spacer(),
            SkeletonBox(width: 58, height: 28, borderRadius: 14),
          ]),
          SizedBox(height: 8),
          SkeletonBox(width: 128, height: 13),
          SizedBox(height: 12),
          SkeletonBox(height: 86, borderRadius: 14),
          SizedBox(height: 10),
          SkeletonBox(height: 86, borderRadius: 14),
        ],
      );
    }

    final friendCount = friendLists
        .map((item) => item.ownerId)
        .whereType<String>()
        .toSet()
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlixieSectionHeader(
          title: title,
          uppercase: false,
          accentHeight: 22,
          titleStyle: const TextStyle(
            color: FlixieColors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: .5,
          ),
          trailingLabel: onSeeAll == null ? null : 'See all',
          trailingColor: FlixieColors.primary,
          onTrailingTap: onSeeAll,
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                ownSummary ??
                    (ownLists.isEmpty
                        ? 'Not in any of your lists'
                        : 'In ${ownLists.length} of your lists'),
                style: const TextStyle(color: FlixieColors.light, fontSize: 13),
              ),
            ),
            if (showEdit)
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 15),
                label: Text(editLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlixieColors.light,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        if (ownLists.isNotEmpty) ...[
          const SizedBox(height: 10),
          ...ownLists.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ListRow(
                  item: item,
                  itemLabel: itemLabel,
                  showOwner: false,
                  showItemCount: showOwnItemCount,
                  onTap: () => onOpenList(item),
                ),
              )),
        ],
        if (friendLists.isNotEmpty) ...[
          const SizedBox(height: 8),
          Divider(color: Colors.white.withValues(alpha: 0.09)),
          const SizedBox(height: 10),
          const Text('Saved by friends',
              style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              _FriendAvatarStack(items: friendLists),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$friendCount ${friendCount == 1 ? 'friend' : 'friends'} added this to ${friendLists.length} lists',
                  style: const TextStyle(
                      color: FlixieColors.light, fontSize: 12.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...friendLists.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ListRow(
                  item: item,
                  itemLabel: itemLabel,
                  showOwner: true,
                  showItemCount: true,
                  onTap: () => onOpenList(item),
                ),
              )),
        ],
      ],
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.item,
    required this.itemLabel,
    required this.showOwner,
    required this.showItemCount,
    required this.onTap,
  });

  final MediaDetailListItem item;
  final String itemLabel;
  final bool showOwner;
  final bool showItemCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibility = _visibilityLabel(item.visibility);
    return Material(
      color: FlixieColors.surface.withValues(alpha: 0.58),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 86,
          child: Row(
            children: [
              _PosterStack(urls: item.posterUrls),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    if (showOwner &&
                        (item.ownerUsername?.isNotEmpty ?? false)) ...[
                      const SizedBox(height: 3),
                      Text('by ${item.ownerUsername}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: FlixieColors.medium, fontSize: 12)),
                    ],
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(_visibilityIcon(item.visibility),
                            color: FlixieColors.medium, size: 14),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            showOwner || showItemCount
                                ? '${item.itemCount} $itemLabel · $visibility'
                                : visibility,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: FlixieColors.light, size: 22),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterStack extends StatelessWidget {
  const _PosterStack({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final posters = urls.take(3).toList();
    return SizedBox(
      width: 140,
      height: 86,
      child: posters.isEmpty
          ? const ColoredBox(
              color: FlixieColors.surfaceElevated,
              child: Icon(Icons.movie_outlined,
                  color: FlixieColors.medium, size: 28),
            )
          : Stack(
              children: posters.asMap().entries.map((entry) {
                return Positioned(
                  left: entry.key * 42,
                  top: entry.key.isOdd ? 5 : 0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: entry.value,
                      width: 58,
                      height: 86,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: FlixieColors.surfaceElevated,
                        child: SizedBox(width: 58, height: 86),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _FriendAvatarStack extends StatelessWidget {
  const _FriendAvatarStack({required this.items});
  final List<MediaDetailListItem> items;

  @override
  Widget build(BuildContext context) {
    final unique = <String, MediaDetailListItem>{};
    for (final item in items) {
      if (item.ownerId != null) unique[item.ownerId!] = item;
    }
    final people = unique.values.take(4).toList();
    return SizedBox(
      width: people.isEmpty ? 0 : 28 + ((people.length - 1) * 19),
      height: 30,
      child: Stack(
        children: people.asMap().entries.map((entry) {
          final name = entry.value.ownerUsername ?? '?';
          return Positioned(
            left: entry.key * 19,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: const BoxDecoration(
                  color: FlixieColors.background, shape: BoxShape.circle),
              child: ProfileAvatarView(
                avatar: entry.value.ownerAvatar,
                fallbackText: name.isEmpty ? '?' : name[0].toUpperCase(),
                fallbackColor: FlixieColors.primary,
                size: 27,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

String _visibilityLabel(String value) => switch (value.toUpperCase()) {
      'PUBLIC' => 'Public',
      'FRIENDS' => 'Shared',
      _ => 'Private',
    };

IconData _visibilityIcon(String value) => switch (value.toUpperCase()) {
      'PRIVATE' => Icons.lock_outline_rounded,
      _ => Icons.public_rounded,
    };
