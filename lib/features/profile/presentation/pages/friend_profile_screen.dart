import 'package:flixie_app/models/movie_rating.dart';
import 'package:flixie_app/models/favorite_movie.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';
import 'package:flixie_app/features/movies/data/search_service.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/movie_short.dart';
import 'package:flixie_app/models/review.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/profile/presentation/widgets/mini_stats.dart';
import 'package:flixie_app/features/profile/presentation/widgets/taste_compatibility_card.dart';
import 'package:flixie_app/features/movies/presentation/pages/my_reviews_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/favorite_movies_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'package:flixie_app/features/profile/presentation/widgets/movie_taste_badge.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_stats_row.dart';
import 'package:flixie_app/features/movies/presentation/widgets/watch_request_sheet.dart';
import 'package:flixie_app/core/safety/safety_actions.dart';
import 'package:flixie_app/features/social/presentation/utils/activity_reply_payload.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart'
    show showReviewDetailSheet;
import 'package:flixie_app/features/movies/presentation/widgets/review_card.dart'
    as shared;

enum _FriendshipStatus { none, pending, requested, friends }

class FriendProfileScreen extends StatefulWidget {
  final String userId;
  final bool previewMode;

  const FriendProfileScreen({
    super.key,
    required this.userId,
    this.previewMode = false,
  });

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _EmptyProfileTab extends StatelessWidget {
  const _EmptyProfileTab({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(icon, color: context.colors.medium, size: 40),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(color: context.colors.medium)),
          ],
        ),
      );
}

class _FriendRecentReviewCard extends StatefulWidget {
  const _FriendRecentReviewCard({
    required this.review,
    required this.username,
    required this.onTap,
    required this.onViewReview,
    // ignore: unused_element_parameter
    this.onReply,
  });

  final Review review;
  final String username;
  final VoidCallback onTap;
  final VoidCallback onViewReview;
  final VoidCallback? onReply;

  @override
  State<_FriendRecentReviewCard> createState() =>
      _FriendRecentReviewCardState();
}

class _FriendRecentReviewCardState extends State<_FriendRecentReviewCard> {
  bool _spoilerRevealed = false;

  void _handleCardTap() {
    if (widget.review.containsSpoilers && !_spoilerRevealed) {
      setState(() => _spoilerRevealed = true);
      return;
    }
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.review;
    final parsedDate = DateTime.tryParse(review.createdAt)?.toLocal();
    final date = parsedDate == null
        ? ''
        : '${parsedDate.day}/${parsedDate.month}/${parsedDate.year.toString().substring(2)}';
    final posterPath = review.moviePosterPath?.trim() ?? '';
    final posterUrl = posterPath.isEmpty || posterPath.startsWith('http')
        ? posterPath
        : 'https://image.tmdb.org/t/p/w342$posterPath';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleCardTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colors.tabBarBorder),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 76,
                  height: 114,
                  child: posterUrl.isEmpty
                      ? Container(
                          color: context.colors.surfaceElevated,
                          child: Icon(
                            Icons.movie_outlined,
                            color: context.colors.medium,
                          ),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: context.colors.surfaceElevated,
                            child: Icon(
                              Icons.movie_outlined,
                              color: context.colors.medium,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            review.movieTitle ?? 'Movie review',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                        ),
                        if (date.isNotEmpty)
                          Text(
                            date,
                            style: TextStyle(
                              color: context.colors.medium,
                              fontSize: 10.5,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 5,
                            children: [
                              Text(
                                '★ ${review.rating}/10',
                                style: TextStyle(
                                  color: context.colors.warning,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${review.recommended ? '👍' : '👎'} ${review.recommended ? 'Recommends' : 'Doesn’t recommend'}',
                                style: TextStyle(
                                  color: review.recommended
                                      ? context.colors.success
                                      : context.colors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (widget.onReply != null)
                          TextButton.icon(
                            onPressed: widget.onReply,
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.primaryTint,
                              minimumSize: const Size(0, 28),
                              padding: const EdgeInsets.only(left: 6),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.reply_rounded, size: 15),
                            label: const Text(
                              'Reply',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      review.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ImageFiltered(
                      imageFilter: review.containsSpoilers && !_spoilerRevealed
                          ? ImageFilter.blur(sigmaX: 4, sigmaY: 4)
                          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                      child: Text(
                        review.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: review.containsSpoilers && !_spoilerRevealed
                              ? context.colors.light.withValues(alpha: .72)
                              : context.colors.light,
                          fontSize: 12.5,
                          height: 1.3,
                        ),
                      ),
                    ),
                    if (review.containsSpoilers && !_spoilerRevealed) ...[
                      const SizedBox(height: 5),
                      TextButton(
                        onPressed: _handleCardTap,
                        style: TextButton.styleFrom(
                          foregroundColor: context.colors.warning,
                          minimumSize: const Size(0, 24),
                          padding: EdgeInsets.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '⚠ Contains spoilers · tap to reveal',
                          style: TextStyle(
                              fontSize: 10.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    TextButton.icon(
                      onPressed: widget.onViewReview,
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.primaryTint,
                        minimumSize: const Size(0, 28),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: const Text(
                        'View full review',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  User? _user;
  bool _userLoading = true;

  List<Review> _reviews = [];
  bool _reviewsLoading = true;
  List<ActivityListItem> _activity = const [];
  bool _activityLoading = true;
  bool _showAllReviews = false;
  static const int _initialReviewCount = 5;

  _FriendshipStatus _friendshipStatus = _FriendshipStatus.none;
  String? _friendshipId;
  bool _friendshipStatusLoading = true;
  bool _actionLoading = false;

  int? _compatibilityScore;
  int _sharedMovieCount = 0;
  int _sharedFavCount = 0;
  bool _compatibilityLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _useCachedFriendshipStatus();
    _loadAll();
  }

  void _useCachedFriendshipStatus() {
    final cached = context.read<AuthProvider>().cachedFriends;
    if (cached == null) return;
    _applyFriendshipStatus(cached, cachedOnly: true);
  }

  bool _applyFriendshipStatus(FriendsData data, {bool cachedOnly = false}) {
    for (final friendship in data.friendships) {
      if (friendship.friendUser?.id == widget.userId) {
        _friendshipStatus = _FriendshipStatus.friends;
        _friendshipId = friendship.id;
        _friendshipStatusLoading = false;
        return true;
      }
    }
    for (final friendship in data.pendingFriends) {
      if (friendship.friendUser?.id == widget.userId) {
        _friendshipStatus = _FriendshipStatus.pending;
        _friendshipId = friendship.id;
        _friendshipStatusLoading = false;
        return true;
      }
    }
    for (final friendship in data.requestedFriends) {
      if (friendship.friendUser?.id == widget.userId) {
        _friendshipStatus = _FriendshipStatus.requested;
        _friendshipId = friendship.id;
        _friendshipStatusLoading = false;
        return true;
      }
    }
    if (!cachedOnly) {
      _friendshipStatus = _FriendshipStatus.none;
      _friendshipId = null;
      _friendshipStatusLoading = false;
    }
    return false;
  }

  bool get _isSelf => context.read<AuthProvider>().dbUser?.id == widget.userId;
  bool _bioExpanded = false;
  String? _activityCursor;
  bool _activityFailed = false;
  bool _reviewsFailed = false;
  int _reviewLimit = 10;
  List<MovieRating> _sharedRatings = [];
  Map<int, int> _myRatingValues = {};

  Future<void> _loadAll() async {
    // _loadUser must complete first: compatibility uses _user.favoriteMovies
    await _loadUser();
    await Future.wait([
      _loadReviews(),
      _loadActivity(),
      _loadFriendshipStatus(),
      _loadCompatibility(),
    ]);
  }

  Future<void> _loadUser() async {
    try {
      final user = await UserService.getUserById(widget.userId);
      if (mounted) {
        setState(() {
          _user = user;
          _userLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] user load error: $e');
      if (mounted) setState(() => _userLoading = false);
    }
  }

  Future<void> _loadReviews() async {
    _reviewsFailed = false;
    try {
      final reviews = await UserService.getUserReviews(widget.userId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewsLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] reviews load error: $e');
      _reviewsFailed = true;
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadActivity({bool more = false}) async {
    if (more && _activityLoading) return;
    if (mounted) {
      setState(() {
        _activityLoading = true;
        _activityFailed = false;
      });
    }
    try {
      final page = await UserService.getUserActivityPage(widget.userId,
          cursor: more ? _activityCursor : null);
      final activity = page.items;
      if (!mounted) return;
      setState(() {
        _activity = [
          ...(more ? _activity : <ActivityListItem>[]),
          ...activity.where((item) => !item.removed)
        ];
        _activityCursor = page.nextCursor;
        _activityLoading = false;
      });
    } catch (e) {
      logger.e('[FriendProfileScreen] activity load error: $e');
      _activityFailed = true;
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadCompatibility() async {
    final currentUser = context.read<AuthProvider>().dbUser;
    final myId = currentUser?.id;
    final myFavoriteMovies = currentUser?.favoriteMovies;
    if (myId == null || myId == widget.userId) {
      if (mounted) setState(() => _compatibilityLoading = false);
      return;
    }
    try {
      final results = await Future.wait([
        UserService.getUserMovieRatings(myId),
        UserService.getUserMovieRatings(widget.userId),
      ]);
      final myRatings = results[0];
      final friendRatings = results[1];
      final myMap = {for (final r in myRatings) r.movieId: r.rating};
      final friendMap = {for (final r in friendRatings) r.movieId: r.rating};
      final sharedIds = myMap.keys.where(friendMap.containsKey).toList();

      // Factor in favourite movies
      final myFavIds = _extractFavMovieIds(myFavoriteMovies);
      final friendFavIds = _extractFavMovieIds(_user?.favoriteMovies);
      final sharedFavIds = myFavIds.intersection(friendFavIds);

      // Score: rating agreement + shared favourites weighted at 2× each
      int? score;
      final sharedFavCount = sharedFavIds.length;
      if (sharedIds.isNotEmpty || sharedFavCount > 0) {
        double numerator = 0;
        for (final id in sharedIds) {
          numerator += (9 - (myMap[id]! - friendMap[id]!).abs()) / 9.0;
        }
        // Each shared favourite = perfect agreement, double-weighted
        numerator += sharedFavCount * 2.0;
        final denominator = sharedIds.length + sharedFavCount * 2;
        score = (numerator / denominator * 100).round();
      }
      if (mounted) {
        setState(() {
          _sharedRatings =
              friendRatings.where((r) => myMap.containsKey(r.movieId)).toList();
          _myRatingValues = myMap;
          _compatibilityScore = score;
          _sharedMovieCount = sharedIds.length;
          _sharedFavCount = sharedFavCount;
          _compatibilityLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] compatibility load error: $e');
      if (mounted) setState(() => _compatibilityLoading = false);
    }
  }

  static Set<int> _extractFavMovieIds(List<dynamic>? favorites) {
    if (favorites == null) return {};
    final ids = <int>{};
    for (final item in favorites) {
      if (item is FavoriteMovie) {
        if (item.removed != true) ids.add(item.movieId);
      } else if (item is Map<String, dynamic> && item['removed'] != true) {
        final id = item['movieId'] ?? item['id'];
        if (id is int) ids.add(id);
      } else if (item is int) {
        ids.add(item);
      }
    }
    return ids;
  }

  Future<void> _loadFriendshipStatus() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    if (myId == null) {
      if (mounted) setState(() => _friendshipStatusLoading = false);
      return;
    }

    try {
      // Always fetch fresh data - the cache may be stale after sending a request.
      final data = await FriendService.getFriends(myId);

      if (!mounted) return;

      setState(() {
        _applyFriendshipStatus(data);
      });
    } catch (e) {
      logger.e('[FriendProfileScreen] friendship status load error: $e');
      if (mounted) setState(() => _friendshipStatusLoading = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    if (myId == null || _user == null) return;

    setState(() => _actionLoading = true);
    try {
      await FriendService.sendFriendRequest({
        'requesterId': myId,
        'recipientId': widget.userId,
        'responderUsername': _user!.username,
        'message': '',
        'type': 'FRIEND_REQUEST',
      });
      if (mounted) {
        setState(() {
          _friendshipStatus = _FriendshipStatus.requested;
          _actionLoading = false;
        });
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content:
                  Text('Friend request sent to ${_user?.username ?? 'user'}')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] send friend request error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to send friend request')),
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    if (myId == null) return;

    final confirmed = await showFlixiePromptSheet<bool>(
      context: context,
      builder: (dialogContext) => FlixiePromptSheetContent(
        title: const Text('Remove Friend'),
        content:
            Text('Remove ${_user?.username ?? 'this user'} from your friends?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child:
                Text('Remove', style: TextStyle(color: context.colors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _actionLoading = true);
    try {
      await FriendService.removeFriend(myId, widget.userId);
      if (mounted) {
        setState(() {
          _friendshipStatus = _FriendshipStatus.none;
          _friendshipId = null;
          _actionLoading = false;
        });
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content:
                  Text('${_user?.username ?? 'User'} removed from friends')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] remove friend error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to remove friend')),
        );
      }
    }
  }

  Future<List<MovieShort>> _searchMovies(String query) async {
    final results = await SearchService.search(query, type: 'movie');
    return results.results
        .where((item) => !item.isPerson && item.movie != null)
        .map((item) => item.movie!)
        .toList(growable: false);
  }

  Future<void> _inviteToWatch() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    final user = _user;
    if (myId == null || user == null) return;

    final movie = await showModalBottomSheet<MovieShort>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: MovieSearchSheet(searchMovies: _searchMovies),
      ),
    );
    if (!mounted || movie == null) return;

    final selectedFriend = Friendship(
      id: 'friend:${user.id}',
      friend: FriendshipUser(
        id: user.id,
        username: user.username,
        firstName: user.firstName,
        lastName: user.lastName,
        initials: user.initials,
        iconColor: user.iconColor,
        avatar: user.avatar,
        profileBadges: user.profileBadges,
      ),
      createdAt: '',
      updatedAt: '',
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MovieWatchRequestSheet(
        movieId: movie.id,
        movieTitle: movie.name,
        requesterId: myId,
        friends: [selectedFriend],
        initialFriendId: user.id,
        onSuccess: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.success,
                  content: const Text('Watch invite sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showFlixieToast(
              FlixieToast(
                  type: FlixieToastType.error,
                  content: const Text('Failed to send invite')),
            );
          }
        },
      ),
    );
  }

  Future<void> _acceptRequest() async {
    if (_friendshipId == null) return;
    setState(() => _actionLoading = true);
    try {
      await FriendService.updateRequest(_friendshipId!, 'ACCEPTED');
      if (mounted) {
        setState(() {
          _friendshipStatus = _FriendshipStatus.friends;
          _actionLoading = false;
        });
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.success,
              content: Text(
                  'You are now friends with ${_user?.username ?? 'this user'}')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] accept request error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to accept friend request')),
        );
      }
    }
  }

  Future<void> _declineRequest() async {
    if (_friendshipId == null) return;
    setState(() => _actionLoading = true);
    try {
      await FriendService.updateRequest(_friendshipId!, 'DECLINED');
      if (mounted) {
        setState(() {
          _friendshipStatus = _FriendshipStatus.none;
          _friendshipId = null;
          _actionLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] decline request error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to decline friend request')),
        );
      }
    }
  }

  Widget _buildFriendshipButton() {
    if (_actionLoading) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    switch (_friendshipStatus) {
      case _FriendshipStatus.none:
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlixieColors.primary,
            foregroundColor: Colors.white,
          ),
          onPressed: _sendFriendRequest,
        );

      case _FriendshipStatus.requested:
        return OutlinedButton.icon(
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('Request Pending'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.warning,
            side: BorderSide(color: context.colors.warning),
          ),
          onPressed: null,
        );

      case _FriendshipStatus.pending:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.success,
                foregroundColor: Colors.black,
              ),
              onPressed: _acceptRequest,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: context.colors.danger,
                side: BorderSide(color: context.colors.danger),
              ),
              onPressed: _declineRequest,
              icon: const Icon(Icons.close_rounded),
              label: const Text('Decline'),
            ),
          ],
        );

      case _FriendshipStatus.friends:
        return OutlinedButton.icon(
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('Remove Friend'),
          style: OutlinedButton.styleFrom(
            foregroundColor: context.colors.danger,
            side: BorderSide(color: context.colors.danger),
          ),
          onPressed: _removeFriend,
        );
    }
  }

  Color get _avatarColor {
    final hex = _user?.iconColor?['hexCode'] as String?;
    if (hex != null) {
      try {
        return Color(int.parse(hex.replaceFirst('#', 'FF'), radix: 16));
      } catch (_) {}
    }
    return FlixieColors.primary;
  }

  String get _memberSinceLabel {
    final joined = DateTime.tryParse(_user?.createdAt ?? '');
    if (joined == null) return 'Member';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return 'Member since ${months[joined.month - 1]} ${joined.year}';
  }

  void _openWrappedSheet() {
    final user = _user;
    if (user == null) return;
    context.push('/wrapped/${user.id}');
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    if (_userLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (user == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('This profile is unavailable.')),
      );
    }

    final watched =
        (user.watchedMovies?.length ?? 0) + (user.watchedShows?.length ?? 0);
    final watchlist =
        (user.movieWatchlist?.length ?? 0) + (user.showWatchlist?.length ?? 0);
    final favourites =
        (user.favoriteMovies?.length ?? 0) + (user.favoriteShows?.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSelf ? 'Public profile preview' : 'Profile'),
        centerTitle: true,
        actions: [
          if (!widget.previewMode && !_isSelf)
            PopupMenuButton<String>(
              tooltip: 'Profile actions',
              onSelected: (action) async {
                if (action == 'wrapped') {
                  _openWrappedSheet();
                } else if (action == 'report') {
                  await SafetyActions.report(
                    context,
                    targetType: 'USER',
                    targetId: widget.userId,
                    reportedUserId: widget.userId,
                  );
                } else if (action == 'block') {
                  final blocked = await SafetyActions.block(
                    context,
                    userId: widget.userId,
                    username: user.username,
                  );
                  if (blocked && context.mounted) context.pop();
                } else if (action == 'remove_friend') {
                  await _removeFriend();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'wrapped',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.auto_awesome_outlined),
                    title: Text('View Wrapped'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Report user'),
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block, color: context.colors.danger),
                    title: Text('Block user',
                        style: TextStyle(color: context.colors.danger)),
                  ),
                ),
                if (_friendshipStatus == _FriendshipStatus.friends)
                  PopupMenuItem(
                    value: 'remove_friend',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.person_remove_outlined,
                          color: context.colors.danger),
                      title: Text('Remove friend',
                          style: TextStyle(color: context.colors.danger)),
                    ),
                  ),
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 32),
          children: [
            _modernHeader(user),
            // Notification deep links use preview mode to suppress ordinary
            // profile actions. An incoming friend request is an exception:
            // its recipient still needs the Accept / Decline decision here.
            if (!_isSelf &&
                (!widget.previewMode ||
                    _friendshipStatus == _FriendshipStatus.pending)) ...[
              const SizedBox(height: 18),
              _profileActions(),
              if (_friendshipStatus == _FriendshipStatus.friends) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check,
                        size: 17, color: FlixieColors.primary),
                    const SizedBox(width: 7),
                    Text('Friends',
                        style: TextStyle(color: context.colors.medium)),
                  ],
                ),
              ],
            ],
            const SizedBox(height: 20),
            _modernStats(watched, watchlist, favourites),
            const SizedBox(height: 12),
            _profileTabs(),
            const SizedBox(height: 18),
            if (_selectedTab == 0) ..._overviewContent(user),
            if (_selectedTab == 1) ..._activityContent(user),
            if (_selectedTab == 2) ..._reviewsContent(),
          ]
              .map((child) => child.key == const ValueKey('profile-totals')
                  ? child
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: child))
              .toList(),
        ),
      ),
    );
  }

  Widget _modernHeader(User user) {
    final showFirstName = user.firstName?.trim().isNotEmpty == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        ProfileAvatarView(
            avatar: user.avatar,
            fallbackText: user.initials ??
                (user.username.isEmpty ? '?' : user.username[0]),
            fallbackColor: _avatarColor,
            size: 76,
            profileBadges: user.profileBadges),
        const SizedBox(width: 16),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(showFirstName ? user.firstName! : user.username,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: context.colors.white)),
          Text('@${user.username}',
              style: TextStyle(color: context.colors.medium)),
          if (user.profileBadges.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: ProfileBadgePills(
                    badges: user.profileBadges, compact: true)),
        ])),
      ]),
      if (user.bio?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 14),
        Text(user.bio!.trim(),
            maxLines: _bioExpanded ? null : 2,
            overflow:
                _bioExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(color: context.colors.light, height: 1.4)),
        TextButton(
            onPressed: () => setState(() => _bioExpanded = !_bioExpanded),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.light,
              textStyle:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
              padding: EdgeInsets.zero,
              alignment: Alignment.centerLeft,
              minimumSize: const Size(48, 40),
            ),
            child: Text(_bioExpanded ? 'Read less' : 'Read more')),
      ],
      Text(_memberSinceLabel,
          style: TextStyle(color: context.colors.medium, fontSize: 12)),
    ]);
  }

  Widget _profileActions() {
    if (_actionLoading) {
      return Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(24),
        ),
        child: const SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_friendshipStatusLoading) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: context.colors.surface.withValues(alpha: .55),
          borderRadius: BorderRadius.circular(24),
        ),
      );
    }
    if (_friendshipStatus != _FriendshipStatus.friends) {
      return SizedBox(width: double.infinity, child: _buildFriendshipButton());
    }
    return Row(children: [
      Expanded(
          child: OutlinedButton.icon(
        onPressed: () => context.push('/chat/${widget.userId}'),
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
        label: const Text('Message'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
      )),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton.icon(
          onPressed: _inviteToWatch,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Plan a watch'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ),
    ]);
  }

  Widget _modernStats(int watched, int watchlist, int favourites) {
    final user = _user;
    final breakdowns = [
      '${user?.watchedMovies?.length ?? 0} movies · ${user?.watchedShows?.length ?? 0} shows',
      '${user?.movieWatchlist?.length ?? 0} movies · ${user?.showWatchlist?.length ?? 0} shows',
      '${user?.favoriteMovies?.length ?? 0} movies · ${user?.favoriteShows?.length ?? 0} shows',
    ];
    final values = [
      (watched, 'Watched', Icons.visibility_outlined),
      (watchlist, 'Watchlist', Icons.bookmark_border_rounded),
      (favourites, 'Favourites', Icons.favorite_border_rounded),
    ];
    return Padding(
        key: const ValueKey('profile-totals'),
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          for (var i = 0; i < values.length; i++) ...[
            Expanded(
                child: Column(children: [
              Text('${values[i].$1}',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: context.colors.white)),
              Text(values[i].$2,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colors.medium, fontSize: 13)),
              const SizedBox(height: 5),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(breakdowns[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: context.colors.light))),
            ])),
            if (i < values.length - 1)
              Container(
                  width: 1, height: 36, color: context.colors.tabBarBorder),
          ],
        ]));
  }

  Widget _profileTabs() {
    const labels = ['Overview', 'Activity', 'Reviews'];
    return Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _selectedTab = i),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(labels[i],
                    style: TextStyle(
                      color: _selectedTab == i
                          ? FlixieColors.primary
                          : context.colors.light,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                margin: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: _selectedTab == i
                      ? FlixieColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ]),
          ),
        ),
    ]);
  }

  void _showSharedRatings() {
    final friendName = _user?.username ?? 'Friend';
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surface,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .8),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 12),
              child: Row(children: [
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('You both rated',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: context.colors.white)),
                      const SizedBox(height: 4),
                      Text(
                          '${_sharedRatings.length} films in common · Scores out of 10',
                          style: TextStyle(
                              fontSize: 12, color: context.colors.medium)),
                    ])),
                IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(sheetContext),
                    icon: const Icon(Icons.close)),
              ])),
          Flexible(
              child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            itemCount: _sharedRatings.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: context.colors.tabBarBorder),
            itemBuilder: (_, index) {
              final rating = _sharedRatings[index];
              final mine = _myRatingValues[rating.movieId]!;
              final path = rating.movie?.posterPath;
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.push(movieDetailPath(rating.movieId));
                },
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: SizedBox(
                                  width: 48,
                                  height: 72,
                                  child: path == null
                                      ? ColoredBox(
                                          color: context.colors.surfaceElevated,
                                          child:
                                              const Icon(Icons.movie_outlined))
                                      : CachedNetworkImage(
                                          imageUrl: path.startsWith('http')
                                              ? path
                                              : 'https://image.tmdb.org/t/p/w185$path',
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              const Icon(Icons.movie_outlined),
                                        ))),
                          const SizedBox(width: 12),
                          Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text(rating.movie?.title ?? 'Movie',
                                    style: TextStyle(
                                        color: context.colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15)),
                                const SizedBox(height: 8),
                                Wrap(spacing: 8, runSpacing: 6, children: [
                                  _ComparisonScore(
                                      label: 'You', score: mine, isYou: true),
                                  _ComparisonScore(
                                      label: friendName, score: rating.rating),
                                ]),
                                if (mine == rating.rating) ...[
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    Icon(Icons.auto_awesome_rounded,
                                        size: 14,
                                        color: context.colors.primaryText),
                                    const SizedBox(width: 5),
                                    Flexible(
                                        child: Text('Taste twins',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: context
                                                    .colors.primaryText))),
                                  ]),
                                ],
                              ])),
                          const SizedBox(width: 4),
                          Icon(Icons.chevron_right_rounded,
                              size: 18, color: context.colors.medium),
                        ])),
              );
            },
          )),
        ]),
      ),
    );
  }

  List<Widget> _sharedWatchlist(User user) {
    if (_isSelf || _friendshipStatus != _FriendshipStatus.friends) return [];
    final mine = context.read<AuthProvider>().dbUser?.movieWatchlist ?? [];
    final ids = mine
        .where((entry) => entry.removed != true)
        .map((entry) => entry.movieId)
        .toSet();
    final shared = (user.movieWatchlist ?? [])
        .where((entry) => entry.removed != true && ids.contains(entry.movieId))
        .toList();
    if (shared.isEmpty) return [];
    return [
      const Text('Watch together',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('Films you both want to see',
          style: TextStyle(color: context.colors.medium, fontSize: 13)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in shared)
              _profilePoster(
                  entry.movie?.title ?? 'Movie',
                  entry.movie?.posterPath,
                  () => context.push(movieDetailPath(entry.movieId))),
          ])),
      const SizedBox(height: 18),
    ];
  }

  Widget _profilePoster(String title, String? path, VoidCallback onTap) =>
      Padding(
          padding: const EdgeInsets.only(right: 12),
          child: SizedBox(
              width: 100,
              child: InkWell(
                  onTap: onTap,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                                width: 100,
                                height: 150,
                                child: path == null
                                    ? ColoredBox(
                                        color: context.colors.surface,
                                        child: const Icon(Icons.movie_outlined))
                                    : CachedNetworkImage(
                                        imageUrl: path.startsWith('http')
                                            ? path
                                            : 'https://image.tmdb.org/t/p/w342$path',
                                        fit: BoxFit.cover))),
                        const SizedBox(height: 6),
                        Text(title,
                            style: TextStyle(
                                fontSize: 13, color: context.colors.light)),
                      ]))));

  Widget _friendShows(User user) {
    final shows = (user.favoriteShows ?? [])
        .whereType<Map<String, dynamic>>()
        .where((entry) => entry['removed'] != true)
        .toList()
      ..sort((a, b) =>
          ((a['rank'] as num?) ?? 999).compareTo((b['rank'] as num?) ?? 999));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Favourite shows',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 10),
      SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final entry in shows.take(10))
              Builder(builder: (_) {
                final show = entry['show'] as Map<String, dynamic>? ?? entry;
                final id = entry['showId'] ?? show['id'];
                return _profilePoster(
                    '${show['name'] ?? show['title'] ?? 'Show'}',
                    show['posterPath'] as String?,
                    () => context.push(showDetailPath(id as int)));
              })
          ])),
    ]);
  }

  Widget _sharedTasteLine(IconData icon, String label, Color color) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: color)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 14, height: 1.4, color: context.colors.light))),
        ],
      );

  List<Widget> _overviewContent(User user) => [
        if (!_isSelf &&
            !_compatibilityLoading &&
            _sharedRatings.isNotEmpty) ...[
          Material(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: _showSharedRatings,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('In common',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.colors.textPrimary)),
                      const SizedBox(height: 10),
                      _sharedTasteLine(
                          Icons.star_rounded,
                          '${_sharedRatings.length} films rated by both',
                          context.colors.warning),
                      if (_sharedFavCount > 0) ...[
                        const SizedBox(height: 8),
                        _sharedTasteLine(
                            Icons.favorite_rounded,
                            '$_sharedFavCount shared favourites',
                            context.colors.danger),
                      ],
                    ],
                  )),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded,
                      color: context.colors.primaryText),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
        ..._sharedWatchlist(user),
        ListsPreviewSection(
          userId: widget.userId,
          title: 'Shared lists',
          hideWhenEmpty: true,
          emptyMessage: 'No lists shared with you yet.',
          embedded: true,
          publicOnly: widget.previewMode,
        ),
        if (user.favoriteMovies?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          FavoriteMoviesSection(favoriteMovies: user.favoriteMovies!),
        ],
        if ((user.favoriteShows ?? [])
            .whereType<Map>()
            .any((entry) => entry['removed'] != true)) ...[
          const SizedBox(height: 18),
          _friendShows(user),
        ],
        if (_reviews.isNotEmpty) ...[
          const SizedBox(height: 18),
          shared.ReviewCard(
              review: _reviews.first,
              currentUserId: context.read<AuthProvider>().dbUser?.id),
        ],
      ];

  List<Widget> _activityContent(User user) {
    if (_activityLoading && _activity.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 56),
          child: Center(
            child: CircularProgressIndicator(color: FlixieColors.primary),
          ),
        ),
      ];
    }
    if (_activityFailed && _activity.isEmpty) {
      return [
        TextButton(
            onPressed: _loadActivity,
            child: const Text('Couldn’t load activity. Retry'))
      ];
    }
    if (_activity.isEmpty) {
      return const [
        _EmptyProfileTab(
          icon: Icons.timeline_outlined,
          text: 'No public activity yet.',
        ),
      ];
    }
    return [
      if (user.watchedMovies?.isNotEmpty == true) ...[
        FriendMiniStats(watchedMovies: user.watchedMovies!),
        const SizedBox(height: 14),
      ],
      for (var index = 0; index < _activity.length; index++) ...[
        ActivityTile(
          item: _activity[index],
          compact: true,
          detailSource: DetailSource.friendActivity,
        ),
        if (index != _activity.length - 1) const SizedBox(height: 10),
      ],
      if (_activityCursor != null || _activityFailed)
        TextButton(
            onPressed:
                _activityLoading ? null : () => _loadActivity(more: true),
            child: Text(_activityFailed ? 'Retry' : 'Load more')),
    ];
  }

  List<Widget> _reviewsContent() {
    if (_reviewsFailed) {
      return [
        TextButton(
            onPressed: _loadReviews,
            child: const Text('Couldn’t load reviews. Retry'))
      ];
    }
    if (_reviewsLoading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_reviews.isEmpty) {
      return const [
        _EmptyProfileTab(icon: Icons.reviews_outlined, text: 'No reviews yet.'),
      ];
    }
    return [
      for (final review in _reviews.take(_reviewLimit))
        Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: shared.ReviewCard(
                review: review,
                currentUserId: context.read<AuthProvider>().dbUser?.id)),
      if (_reviews.length > _reviewLimit)
        TextButton(
            onPressed: () => setState(() => _reviewLimit += 10),
            child: const Text('Load more reviews')),
    ];
  }

  String _reviewPosterUrl(String? path) => path == null
      ? ''
      : path.startsWith('http')
          ? path
          : 'https://image.tmdb.org/t/p/w342$path';

  // ignore: unused_element
  void _replyToReview(Review review) {
    if (review.movieId == null) return;
    context.push(
      '/chat/${widget.userId}',
      extra: ActivityReplyPayload(
        username: _user?.username ?? 'Friend',
        activityLabel: 'review',
        title: review.movieTitle ?? 'Movie review',
        link: 'flixie://movies/${review.movieId}',
        posterUrl: _reviewPosterUrl(review.moviePosterPath),
        rating: review.rating.toDouble(),
        recommended: review.recommended,
        reviewTitle: review.title,
        reviewBody: review.body,
        containsSpoilers: review.containsSpoilers,
      ),
    );
  }

  // ignore: unused_element
  void _openReview(Review review) {
    showReviewDetailSheet(
      context,
      review: review,
      currentUserId: context.read<AuthProvider>().dbUser?.id,
    );
  }

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final profileName = _user?.username ?? 'Profile';
    final visibleFirstName = !widget.previewMode &&
            _friendshipStatus == _FriendshipStatus.friends &&
            _user?.firstName?.trim().isNotEmpty == true
        ? _user!.firstName!.trim()
        : null;
    final visibleReviews = _showAllReviews
        ? _reviews
        : _reviews.take(_initialReviewCount).toList();
    final watchedCount = (_user?.watchedMovies?.length ?? 0) +
        (_user?.watchedShows?.length ?? 0);
    final watchlistCount = (_user?.movieWatchlist?.length ?? 0) +
        (_user?.showWatchlist?.length ?? 0);
    final favoritesCount = (_user?.favoriteMovies?.length ?? 0) +
        (_user?.favoriteShows?.length ?? 0);

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.previewMode ? 'Public profile preview' : profileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (!widget.previewMode && _user != null)
            PopupMenuButton<String>(
              tooltip: 'Profile actions',
              onSelected: (action) async {
                if (action == 'report') {
                  await SafetyActions.report(
                    context,
                    targetType: 'USER',
                    targetId: widget.userId,
                    reportedUserId: widget.userId,
                  );
                } else if (action == 'block') {
                  final blocked = await SafetyActions.block(
                    context,
                    userId: widget.userId,
                    username: _user!.username,
                  );
                  if (blocked && context.mounted) context.pop();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'report',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.flag_outlined),
                    title: Text('Report user'),
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.block, color: context.colors.danger),
                    title: Text(
                      'Block user',
                      style: TextStyle(color: context.colors.danger),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: _userLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: context.colors.surface,
                      border: Border.all(
                        color:
                            context.colors.tabBarBorder.withValues(alpha: 0.9),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfileAvatarView(
                              avatar: _user?.avatar,
                              fallbackText: _user?.initials ??
                                  (_user?.username.isNotEmpty == true
                                      ? _user!.username[0].toUpperCase()
                                      : '?'),
                              fallbackColor: _avatarColor,
                              size: 88,
                              profileBadges: _user?.profileBadges ?? const [],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '@${_user?.username ?? 'user'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.headlineSmall?.copyWith(
                                      color: context.colors.light,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  if (_user?.profileBadges.isNotEmpty ==
                                      true) ...[
                                    const SizedBox(height: 7),
                                    ProfileBadgePills(
                                      badges: _user!.profileBadges,
                                      compact: true,
                                      featuredOnly: true,
                                    ),
                                  ],
                                  if (visibleFirstName != null) ...[
                                    const SizedBox(height: 7),
                                    Text(
                                      visibleFirstName,
                                      style: textTheme.bodyLarge?.copyWith(
                                        color: context.colors.light,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.calendar_month_outlined,
                                        size: 15,
                                        color: context.colors.medium,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _memberSinceLabel,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: context.colors.medium,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_user?.bio case final bioText
                            when bioText != null && bioText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            bioText,
                            style: textTheme.bodyMedium?.copyWith(
                              color: context.colors.light,
                              height: 1.45,
                            ),
                            maxLines: 4,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (!widget.previewMode) ...[
                    const SizedBox(height: 14),
                    SizedBox(
                        width: double.infinity,
                        child: _buildFriendshipButton()),
                  ],
                  const SizedBox(height: 16),

                  ProfileStatsRow(
                    watched: watchedCount,
                    watchlist: watchlistCount,
                    favorites: favoritesCount,
                  ),

                  const SizedBox(height: 16),
                  ListsPreviewSection(
                    userId: widget.userId,
                    title: "${_user?.username ?? 'Friend'}'s Lists",
                    emptyMessage:
                        "No visible lists yet or this friend hasn't created one.",
                    publicOnly: widget.previewMode,
                  ),

                  // Taste compatibility
                  if (!_compatibilityLoading) ...[
                    const SizedBox(height: 16),
                    TasteCompatibilityCard(
                      score: _compatibilityScore,
                      sharedMovies: _sharedMovieCount,
                      sharedFavs: _sharedFavCount,
                      friendName: _user?.username ?? 'them',
                    ),
                  ],

                  // Favourite genres badge
                  if ((_user?.favoriteGenres ?? []).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MovieTasteBadge(favoriteGenres: _user!.favoriteGenres!),
                  ],

                  // Mini stats
                  if (_user?.watchedMovies != null) ...[
                    const SizedBox(height: 24),
                    FriendMiniStats(watchedMovies: _user!.watchedMovies!),
                  ],

                  // Friend's wrapped
                  if (_user != null) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _openWrappedSheet,
                        icon: const Icon(Icons.auto_awesome),
                        label: Text(
                          "View ${_user!.username}'s Wrapped",
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: context.colors.primaryText,
                          side: const BorderSide(color: FlixieColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 16),

                  // Favourite Movies
                  if (_user?.favoriteMovies?.isNotEmpty ?? false) ...[
                    FavoriteMoviesSection(
                        favoriteMovies: _user!.favoriteMovies!),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],

                  // Reviews section header
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
                          'RECENT REVIEWS',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.5,
                          ),
                        ),
                        if (!_reviewsLoading && _reviews.isNotEmpty) ...[
                          const Spacer(),
                          Text(
                            '${_reviews.length} total',
                            style: textTheme.bodySmall
                                ?.copyWith(color: context.colors.medium),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (_reviewsLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_reviews.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No reviews yet.',
                        style: textTheme.bodySmall
                            ?.copyWith(color: context.colors.medium),
                      ),
                    )
                  else ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleReviews.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => ReviewCard(
                        review: visibleReviews[i],
                        onTap: () {
                          if (visibleReviews[i].movieId != null) {
                            context
                                .push('/movies/${visibleReviews[i].movieId}');
                          }
                        },
                      ),
                    ),
                    if (_reviews.length > _initialReviewCount) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () => setState(
                              () => _showAllReviews = !_showAllReviews),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: context.colors.light,
                            side:
                                BorderSide(color: context.colors.tabBarBorder),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _showAllReviews ? 'SHOW LESS' : 'VIEW ALL REVIEWS',
                            style: const TextStyle(
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }
}

class _ComparisonScore extends StatelessWidget {
  const _ComparisonScore(
      {required this.label, required this.score, this.isYou = false});
  final bool isYou;
  final String label;
  final int score;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
            color: isYou
                ? context.colors.primaryText.withValues(alpha: .10)
                : const Color(0xFFFFAD66).withValues(alpha: .18),
            borderRadius: BorderRadius.circular(10)),
        child: Text.rich(
            TextSpan(children: [
              TextSpan(
                  text: '$label  ',
                  style: TextStyle(color: context.colors.light)),
              TextSpan(
                  text: '$score',
                  style: TextStyle(
                      color: context.colors.primaryText,
                      fontWeight: FontWeight.w800)),
            ]),
            style: const TextStyle(fontSize: 12)),
      );
}
