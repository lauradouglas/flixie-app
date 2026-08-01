import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/movie_list.dart';

class ListPickerItem {
  const ListPickerItem({
    required this.id,
    required this.name,
    required this.visibility,
    required this.posterUrls,
    required this.countLabel,
    this.scope = ListScope.personal,
    this.groupName,
    this.collaborators = const [],
  });

  final String id;
  final String name;
  final String visibility;
  final List<String> posterUrls;
  final String countLabel;
  final String scope;
  final String? groupName;
  final List<MovieListCollaborator> collaborators;
}

class ListPickerSheet extends StatefulWidget {
  const ListPickerSheet({
    super.key,
    required this.items,
    required this.selectedIds,
    required this.mediaLabel,
    required this.saving,
    required this.onToggle,
    required this.onCreate,
    required this.onDone,
    required this.onCancel,
  });

  final List<ListPickerItem> items;
  final Set<String> selectedIds;
  final String mediaLabel;
  final bool saving;
  final ValueChanged<String> onToggle;
  final VoidCallback onCreate;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  @override
  State<ListPickerSheet> createState() => _ListPickerSheetState();
}

class _ListPickerSheetState extends State<ListPickerSheet> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim().toLowerCase();
    final filtered = widget.items
        .where((item) => item.name.toLowerCase().contains(query))
        .toList(growable: false);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.9,
        decoration: const BoxDecoration(
          color: FlixieColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 14),
                decoration: BoxDecoration(
                  color: FlixieColors.medium.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Add to lists',
                            style: TextStyle(
                                color: FlixieColors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                            'Choose every list this ${widget.mediaLabel} belongs in.',
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 13)),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: widget.saving ? null : widget.onCreate,
                    icon: const Icon(Icons.add, size: 17),
                    label: const Text('New list'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: FlixieColors.primary,
                      side: const BorderSide(color: FlixieColors.primary),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  hintText: 'Search your lists',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: widget.items.isEmpty
                  ? const Center(
                      child: Text('You haven’t created any lists yet.',
                          style: TextStyle(color: FlixieColors.medium)))
                  : filtered.isEmpty
                      ? const Center(
                          child: Text('No matching lists.',
                              style: TextStyle(color: FlixieColors.medium)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(22, 0, 22, 16),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 9),
                          itemBuilder: (_, index) {
                            final item = filtered[index];
                            return _PickerListRow(
                              item: item,
                              selected: widget.selectedIds.contains(item.id),
                              onTap: widget.saving
                                  ? null
                                  : () => widget.onToggle(item.id),
                            );
                          },
                        ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 4),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: widget.saving ? null : widget.onDone,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: widget.saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(
                          'Done · Added to ${widget.selectedIds.length} ${widget.selectedIds.length == 1 ? 'list' : 'lists'}'),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: widget.saving ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PickerListRow extends StatelessWidget {
  const _PickerListRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final ListPickerItem item;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isGroup = item.scope == ListScope.group || item.groupName != null;
    final shared = isGroup ||
        item.scope == ListScope.friends ||
        item.collaborators.isNotEmpty;
    return Material(
      color: FlixieColors.surface.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: shared ? 104 : 90,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color:
                  selected ? FlixieColors.primary : FlixieColors.tabBarBorder,
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            children: [
              _Posters(urls: item.posterUrls),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: FlixieColors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(_visibilityIcon(item.visibility, isGroup, shared),
                            color: FlixieColors.medium, size: 14),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            '${item.countLabel} · ${_visibilityLabel(item.visibility, item.collaborators.length, item.groupName, isGroup, shared)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: FlixieColors.medium, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (shared && item.collaborators.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      _AvatarStack(collaborators: item.collaborators),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                width: 25,
                height: 25,
                decoration: BoxDecoration(
                  color: selected ? FlixieColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                      color: selected
                          ? FlixieColors.primary
                          : FlixieColors.medium),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        color: FlixieColors.white, size: 18)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Posters extends StatelessWidget {
  const _Posters({required this.urls});
  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final posters = urls.take(2).toList();
    return SizedBox(
      width: 92,
      height: 72,
      child: posters.isEmpty
          ? const ColoredBox(
              color: FlixieColors.surfaceElevated,
              child: Icon(Icons.movie_outlined, color: FlixieColors.medium))
          : Stack(
              children: posters.asMap().entries.map((entry) {
                return Positioned(
                  left: entry.key * 36,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: CachedNetworkImage(
                      imageUrl: entry.value,
                      width: 52,
                      height: 72,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: FlixieColors.surfaceElevated,
                        child: SizedBox(width: 52, height: 72),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.collaborators});
  final List<MovieListCollaborator> collaborators;

  @override
  Widget build(BuildContext context) {
    final people = collaborators.take(4).toList();
    return SizedBox(
      height: 25,
      width: 25 + (people.length - 1) * 17,
      child: Stack(
        clipBehavior: Clip.none,
        children: people.asMap().entries.map((entry) {
          final person = entry.value;
          return Positioned(
            left: entry.key * 17,
            child: Container(
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: FlixieColors.background,
                border: Border.all(color: FlixieColors.primary, width: 1.4),
              ),
              child: ProfileAvatarView(
                avatar: person.avatar,
                fallbackText: person.username.isEmpty
                    ? '?'
                    : person.username[0].toUpperCase(),
                fallbackColor: FlixieColors.primary,
                profileBadges: person.profileBadges,
                size: 22,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

String _visibilityLabel(String visibility, int people, String? groupName,
    bool isGroup, bool shared) {
  if (isGroup) return groupName ?? 'Group list';
  if (shared) return 'Shared with $people';
  return switch (visibility.toUpperCase()) {
    ListVisibility.public => 'Public',
    ListVisibility.friends => 'Friends',
    _ => 'Private',
  };
}

IconData _visibilityIcon(String visibility, bool isGroup, bool shared) {
  if (isGroup) return Icons.groups_outlined;
  if (shared) return Icons.people_outline_rounded;
  return visibility == ListVisibility.private
      ? Icons.lock_outline_rounded
      : Icons.public_rounded;
}
