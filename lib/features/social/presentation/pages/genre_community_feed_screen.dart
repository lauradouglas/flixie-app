import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/community_watchlist_button.dart';
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
      this.embedded = false,
      this.service = const GenreCommunityService()});
  final int genreId;
  final bool embedded;
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
  String _filter = 'all';
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
      final page = await widget.service.feed(widget.genreId,
          sort: _sort, filter: _filter, cursor: more ? _cursor : null);
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
        appBar: widget.embedded
            ? null
            : AppBar(title: Text(_community?.name ?? 'Community')),
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
                            Text('What members thought',
                                style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: context.colors.white)),
                            const SizedBox(height: 6),
                            if (!widget.embedded)
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
                                  if (_community != null && !widget.embedded)
                                    FilledButton.tonal(
                                        onPressed: _saving ? null : _join,
                                        child: Text(_saving
                                            ? 'Saving…'
                                            : _community!.joined
                                                ? 'Leave community'
                                                : 'Join community')),
                                  if (widget.genreId == -1)
                                    for (final filter in [
                                      'all',
                                      'movie',
                                      'show'
                                    ])
                                      FlixiePill.choice(
                                          showCheckmark: false,
                                          label: Text(filter == 'all'
                                              ? 'All'
                                              : filter == 'movie'
                                                  ? 'Films'
                                                  : 'Series'),
                                          selected: _filter == filter,
                                          onSelected: (_) {
                                            if (_filter != filter) {
                                              setState(() {
                                                _filter = filter;
                                                _items.clear();
                                                _cursor = null;
                                              });
                                              _load();
                                            }
                                          }),
                                ]),
                            const SizedBox(height: 10),
                            Row(children: [
                              Text('Sort',
                                  style:
                                      TextStyle(color: context.colors.light)),
                              const SizedBox(width: 12),
                              Flexible(
                                  child: DropdownButton<String>(
                                value: _sort,
                                underline: const SizedBox.shrink(),
                                borderRadius: BorderRadius.circular(10),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'latest', child: Text('Latest')),
                                  DropdownMenuItem(
                                      value: 'popular', child: Text('Popular')),
                                ],
                                onChanged: _saving
                                    ? null
                                    : (sort) {
                                        if (sort == null || sort == _sort) {
                                          return;
                                        }
                                        setState(() {
                                          _sort = sort;
                                          _items.clear();
                                          _ratings.clear();
                                          _showRatings.clear();
                                          _cursor = null;
                                        });
                                        _load();
                                      },
                              )),
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
                            padding: const EdgeInsets.symmetric(horizontal: 16),
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
    final hidden = hideMovieRatings(context, item.showId ?? item.movieId,
        ownerId: item.userId, isShow: item.showId != null);
    final hideAverage = hideMovieRatings(context, item.showId ?? item.movieId,
        isShow: item.showId != null);
    final review = item.reviewData;
    Future<void> openReview() async {
      await context.push(
          '/community/posts/${Uri.encodeComponent(item.userId)}/${item.type.value}/${Uri.encodeComponent(item.id)}');
      if (context.mounted) await onReturn?.call();
    }

    final date = DateTime.tryParse(item.createdAt);
    final age = date == null ? null : DateTime.now().difference(date);
    final time = age == null
        ? null
        : age.inMinutes < 1
            ? 'Just now'
            : age.inHours < 1
                ? '${age.inMinutes}m ago'
                : age.inDays < 1
                    ? '${age.inHours}h ago'
                    : age.inDays == 1
                        ? 'Yesterday'
                        : '${age.inDays}d ago';
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextButton(
          onPressed: openReview,
          style: TextButton.styleFrom(
              padding: EdgeInsets.zero, alignment: Alignment.centerLeft),
          child: Text(item.mediaTitle ?? 'Review',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                  color: context.colors.white))),
      Text(item.showId != null ? 'Series' : 'Film',
          style: TextStyle(fontSize: 12, color: context.colors.light)),
      const SizedBox(height: 14),
      Text(
          review?.containsSpoilers == true
              ? 'Review contains spoilers'
              : review?.title ?? 'Read review',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              height: 1.5,
              color: context.colors.white)),
      if (review?.containsSpoilers != true &&
          review?.body.isNotEmpty == true) ...[
        const SizedBox(height: 10),
        Text(review!.body,
            style: TextStyle(
                fontSize: 15, height: 1.6, color: context.colors.light)),
      ],
      if (rating != null && !hideAverage) ...[
        const SizedBox(height: 16),
        Text(
            '$genreName members’ rating · ${rating!.average.toStringAsFixed(1)}/10 · ${rating!.count} ${rating!.count == 1 ? 'member' : 'members'}',
            style: TextStyle(
                color: context.colors.secondary, fontSize: 13, height: 1.5)),
      ],
    ]);
    return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Padding(
                padding: const EdgeInsets.all(4),
                child: ProfileAvatarView(
                    avatar: item.avatar,
                    profileBadges: item.profileBadges,
                    size: 36,
                    fallbackText:
                        item.username.isEmpty ? '?' : item.username[0],
                    fallbackColor: FlixieColors.primary)),
            const SizedBox(width: 10),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      item.firstName.trim().isEmpty
                          ? item.username
                          : item.firstName,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text('${time == null ? '' : '$time · '}Public review',
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: context.colors.light)),
                ])),
            const SizedBox(width: 8),
            Text(
                hidden
                    ? 'Rated'
                    : '${review?.rating ?? item.mediaRating?.toInt() ?? '–'}/10',
                style: TextStyle(
                    color: context.colors.warning,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 14),
          LayoutBuilder(builder: (context, constraints) {
            if (constraints.maxWidth < 300 ||
                MediaQuery.textScalerOf(context).scale(15) > 22) {
              return content;
            }
            final poster = item.mediaPosterPath;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ExcludeSemantics(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                          width: 75,
                          height: 112.5,
                          child: poster == null || poster.isEmpty
                              ? ColoredBox(
                                  color: context.colors.surface,
                                  child: const Icon(Icons.movie_outlined))
                              : CachedNetworkImage(
                                  imageUrl: poster.startsWith('http')
                                      ? poster
                                      : 'https://image.tmdb.org/t/p/w185$poster',
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      const Icon(Icons.movie_outlined))))),
              const SizedBox(width: 13),
              Expanded(child: content),
            ]);
          }),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            final actions = [
              TextButton.icon(
                  onPressed: openReview,
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: const Text('Read & discuss')),
              if (item.movieId != null || item.showId != null)
                CommunityWatchlistButton(item: item),
            ];
            return constraints.maxWidth < 340 ||
                    MediaQuery.textScalerOf(context).scale(14) > 20
                ? Wrap(spacing: 12, runSpacing: 4, children: actions)
                : Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: actions);
          }),
          const SizedBox(height: 10),
          Divider(
              height: 1,
              thickness: 0.5,
              color: context.colors.medium.withValues(alpha: 0.4)),
        ]));
  }
}
