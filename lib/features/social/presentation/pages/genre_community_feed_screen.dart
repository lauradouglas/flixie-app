import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import '../../data/genre_community_service.dart';

class GenreCommunityFeedScreen extends StatefulWidget {
  const GenreCommunityFeedScreen(
      {super.key,
      required this.genreId,
      this.service = const GenreCommunityService()});
  final int genreId;
  final GenreCommunityService service;
  @override
  State<GenreCommunityFeedScreen> createState() =>
      _GenreCommunityFeedScreenState();
}

class _GenreCommunityFeedScreenState extends State<GenreCommunityFeedScreen> {
  GenreCommunity? _community;
  final _items = <ActivityListItem>[];
  final _showRatings = <int, GenreMemberRating>{};
  final _ratings = <int, GenreMemberRating>{};
  String _sort = 'latest';
  String? _cursor, _error;
  bool _loading = true, _more = false, _saving = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    SafetyService.changes.addListener(_safetyChanged);
    _load();
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_safetyChanged);
    super.dispose();
  }

  void _safetyChanged() {
    if (mounted) {
      setState(() {
        _items.removeWhere((i) => SafetyService.isBlocked(i.userId));
        _ratings.clear();
        _showRatings.clear();
      });
      _load();
    }
  }

  @override
  void didUpdateWidget(covariant GenreCommunityFeedScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.genreId != widget.genreId) {
      _community = null;
      _items.clear();
      _ratings.clear();
      _showRatings.clear();
      _cursor = null;
      _load();
    }
  }

  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _more || _cursor == null)) return;
    final generation = more ? _generation : ++_generation;
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _more = false;
      }
    });
    try {
      final page = await widget.service
          .feed(widget.genreId, sort: _sort, cursor: more ? _cursor : null);
      if (!mounted || generation != _generation) return;
      setState(() {
        _community = page.community;
        if (!more) {
          _items.clear();
          _ratings.clear();
          _showRatings.clear();
        }
        final ids = _items.map((i) => '${i.type.value}:${i.id}').toSet();
        _items.addAll(page.items.where((i) =>
            ids.add('${i.type.value}:${i.id}') &&
            !SafetyService.isBlocked(i.userId)));
        _ratings.addAll(page.ratings);
        _showRatings.addAll(page.showRatings);
        _cursor = page.nextCursor;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Couldn’t load reviews. Try again.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  Future<void> _join() async {
    if (_saving || _community == null) return;
    final joined = !_community!.joined;
    _generation++;
    setState(() {
      _saving = true;
      _loading = false;
      _more = false;
    });
    try {
      await widget.service.setJoined(widget.genreId, joined);
      if (!mounted) return;
      setState(() => _community = _community!.withJoined(joined));
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t change membership. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_community?.name ?? 'Community')),
        body: RefreshIndicator(
            onRefresh: () => _load(),
            child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      sliver: SliverToBoxAdapter(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                'Reviews from people who joined ${_community?.name ?? 'this genre'}.',
                                style: TextStyle(color: context.colors.light)),
                            const SizedBox(height: 6),
                            Text(
                                'Joining includes your existing and future public reviews. Private reviews stay private. Leaving removes your reviews here.',
                                style: TextStyle(
                                    color: context.colors.medium,
                                    fontSize: 12)),
                            const SizedBox(height: 8),
                            Wrap(
                                spacing: 8,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_community != null)
                                    FilledButton.tonal(
                                        onPressed: _saving ? null : _join,
                                        child: Text(_saving
                                            ? 'Saving…'
                                            : _community!.joined
                                                ? 'Leave community'
                                                : 'Join community')),
                                  for (final sort in ['latest', 'popular'])
                                    ChoiceChip(
                                        label: Text(sort == 'latest'
                                            ? 'Latest'
                                            : 'Popular'),
                                        selected: _sort == sort,
                                        onSelected: _saving
                                            ? null
                                            : (_) {
                                                if (_sort != sort) {
                                                  setState(() {
                                                    _sort = sort;
                                                    _items.clear();
                                                    _ratings.clear();
                                                    _showRatings.clear();
                                                  });
                                                  _load();
                                                }
                                              }),
                                ]),
                          ]))),
                  if (_loading)
                    const SliverToBoxAdapter(
                        child: Center(
                            child: Padding(
                                padding: EdgeInsets.all(24),
                                child: CircularProgressIndicator())))
                  else if (_items.isEmpty && _error == null)
                    const SliverToBoxAdapter(
                        child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                                'No public reviews from members yet. Join and share a review to start the conversation.')))
                  else
                    SliverList.builder(
                        itemCount: _items.length,
                        itemBuilder: (context, index) => Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: GenreReviewCard(
                                item: _items[index],
                                genreName: _community?.name ?? 'Community',
                                onReturn: () => _load(),
                                rating: _items[index].showId != null
                                    ? _showRatings[_items[index].showId]
                                    : _ratings[_items[index].movieId]))),
                  SliverToBoxAdapter(
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(
                              child: _error != null
                                  ? TextButton(
                                      onPressed: () => _load(
                                          more: _items.isNotEmpty &&
                                              _cursor != null),
                                      child: Text(_error!))
                                  : _more
                                      ? const CircularProgressIndicator()
                                      : _cursor != null && !_loading
                                          ? TextButton(
                                              onPressed: () =>
                                                  _load(more: true),
                                              child: const Text(
                                                  'Load more reviews'))
                                          : const SizedBox.shrink()))),
                ])),
      );
}

class GenreReviewCard extends StatelessWidget {
  const GenreReviewCard(
      {super.key,
      required this.item,
      required this.genreName,
      this.rating,
      this.onReturn});
  final ActivityListItem item;
  final String genreName;
  final GenreMemberRating? rating;
  final Future<void> Function()? onReturn;
  @override
  Widget build(BuildContext context) {
    final hidden = hideMovieRatings(context, item.movieId,
        ownerId: item.userId, isShow: item.showId != null);
    final hideAverage =
        hideMovieRatings(context, item.movieId, isShow: item.showId != null);
    final review = item.reviewData;
    return Material(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            await context.push(
                '/community/posts/${Uri.encodeComponent(item.userId)}/${item.type.value}/${Uri.encodeComponent(item.id)}');
            if (context.mounted) await onReturn?.call();
          },
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      ProfileAvatarView(
                          avatar: item.avatar,
                          profileBadges: item.profileBadges,
                          size: 36,
                          fallbackText:
                              item.username.isEmpty ? '?' : item.username[0],
                          fallbackColor: FlixieColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(item.username,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      const SizedBox(width: 8),
                      Text(
                          hidden
                              ? 'Rated'
                              : '${review?.rating ?? item.mediaRating?.toInt() ?? '–'}/10',
                          style: TextStyle(
                              color: context.colors.warning,
                              fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 10),
                    Text(
                        '${item.mediaTitle ?? 'Review'} · ${item.showId != null ? 'Series' : 'Film'}',
                        style: TextStyle(
                            color: context.colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Row(children: [
                      Expanded(
                          child: Text(
                              review?.containsSpoilers == true
                                  ? 'Review contains spoilers'
                                  : review?.title ?? 'Read review',
                              style: TextStyle(color: context.colors.light))),
                      Icon(Icons.chevron_right_rounded,
                          color: context.colors.primaryText)
                    ]),
                    if (rating != null && !hideAverage) ...[
                      const SizedBox(height: 8),
                      Text(
                          '$genreName members’ rating · ${rating!.average.toStringAsFixed(1)}/10 · ${rating!.count} ${rating!.count == 1 ? 'member' : 'members'}',
                          style: TextStyle(
                              color: context.colors.medium, fontSize: 12)),
                    ],
                  ])),
        ));
  }
}
