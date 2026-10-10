import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

class MovieCastSheet extends StatefulWidget {
  const MovieCastSheet(
      {super.key, required this.cast, required this.parentContentId});

  final List<MovieCastMember> cast;
  final int parentContentId;

  @override
  State<MovieCastSheet> createState() => _AllCastSheetState();
}

class _AllCastSheetState extends State<MovieCastSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _sortByName = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MovieCastMember> get _filteredCast {
    final query = _query.trim().toLowerCase();
    final cast = (query.isEmpty
            ? widget.cast
            : widget.cast.where((member) {
                return member.name.toLowerCase().contains(query) ||
                    member.character.toLowerCase().contains(query);
              }))
        .toList();
    if (_sortByName) {
      cast.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      cast.sort((a, b) => a.order.compareTo(b.order));
    }
    return cast;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCast;
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: context.colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: context.colors.medium.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 12, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cast',
                          style: TextStyle(
                            color: context.colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          '${widget.cast.length} cast members',
                          style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon:
                        Icon(Icons.close_rounded, color: context.colors.light),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                style: TextStyle(color: context.colors.white),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search actor or character',
                  hintStyle: TextStyle(color: context.colors.medium),
                  prefixIcon:
                      Icon(Icons.search_rounded, color: context.colors.medium),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                          icon: Icon(Icons.close_rounded,
                              color: context.colors.medium),
                        ),
                  filled: true,
                  fillColor: context.colors.surface.withValues(alpha: 0.72),
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: Colors.white.withValues(alpha: 0.07)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: FlixieColors.primary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 18, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'TOP BILLED',
                      style: TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  PopupMenuButton<bool>(
                    tooltip: 'Sort cast',
                    initialValue: _sortByName,
                    onSelected: (value) => setState(() => _sortByName = value),
                    color: context.colors.surfaceElevated,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: false, child: Text('Billing order')),
                      PopupMenuItem(value: true, child: Text('Actor name')),
                    ],
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _sortByName ? 'Actor name' : 'Billing order',
                          style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(Icons.keyboard_arrow_down_rounded,
                            color: context.colors.medium, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyCastSearch()
                  : ListView.separated(
                      controller: scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => SizedBox(
                        height: 9,
                        child: Center(
                          child: Divider(
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      itemBuilder: (context, index) => _FullCastCard(
                        member: filtered[index],
                        parentContentId: widget.parentContentId,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullCastCard extends StatelessWidget {
  const _FullCastCard({
    required this.member,
    required this.parentContentId,
  });

  final MovieCastMember member;
  final int parentContentId;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          final router = GoRouter.of(context);
          Navigator.pop(context);
          router.push(personDetailPath(
            member.id,
            source: DetailSource.personCredits,
            parentContentId: parentContentId,
            parentContentType: 'movie',
          ));
        },
        child: SizedBox(
          height: 94,
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  height: double.infinity,
                  child: member.profileImageUrl == null
                      ? ColoredBox(
                          color: context.colors.surfaceElevated,
                          child: Icon(Icons.person_rounded,
                              color: context.colors.medium, size: 36),
                        )
                      : CachedNetworkImage(
                          imageUrl: member.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => ColoredBox(
                            color: context.colors.surfaceElevated,
                            child: Icon(Icons.person_rounded,
                                color: context.colors.medium, size: 36),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.15,
                          height: 1.2,
                        ),
                      ),
                      if (member.character.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          member.character,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.colors.medium,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: context.colors.medium, size: 26),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyCastSearch extends StatelessWidget {
  const _EmptyCastSearch();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_search_rounded,
              color: context.colors.medium, size: 42),
          const SizedBox(height: 10),
          Text('No cast members found',
              style: TextStyle(
                  color: context.colors.light, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
