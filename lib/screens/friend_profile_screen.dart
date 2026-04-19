import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/review.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'friend_profile/mini_stats.dart';
import 'friend_profile/taste_compatibility_card.dart';
import 'my_reviews_screen.dart';
import 'profile/favorite_movies_section.dart';
import 'profile/movie_taste_badge.dart';
import 'profile/profile_stats_row.dart';
import 'wrapped/friend_wrapped_section.dart';

enum _FriendshipStatus { none, pending, requested, friends }

class FriendProfileScreen extends StatefulWidget {
  final String userId;

  const FriendProfileScreen({super.key, required this.userId});

  @override
  State<FriendProfileScreen> createState() => _FriendProfileScreenState();
}

class _FriendProfileScreenState extends State<FriendProfileScreen> {
  User? _user;
  bool _userLoading = true;

  List<Review> _reviews = [];
  bool _reviewsLoading = true;
  bool _showAllReviews = false;
  static const int _initialReviewCount = 5;

  _FriendshipStatus _friendshipStatus = _FriendshipStatus.none;
  String? _friendshipId;
  bool _actionLoading = false;

  int? _compatibilityScore;
  int _sharedMovieCount = 0;
  int _sharedFavCount = 0;
  bool _compatibilityLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // _loadUser must complete first: compatibility uses _user.favoriteMovies
    await _loadUser();
    await Future.wait(
        [_loadReviews(), _loadFriendshipStatus(), _loadCompatibility()]);
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
    try {
      final reviews = await UserService.getUserMovieReviews(widget.userId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _reviewsLoading = false;
        });
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] reviews load error: $e');
      if (mounted) setState(() => _reviewsLoading = false);
    }
  }

  Future<void> _loadCompatibility() async {
    final myId = context.read<AuthProvider>().dbUser?.id;
    if (myId == null) {
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
      final myFavIds = _extractFavMovieIds(
          context.read<AuthProvider>().dbUser?.favoriteMovies);
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
      if (item is Map<String, dynamic>) {
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
    if (myId == null) return;

    try {
      // Always fetch fresh data — the cache may be stale after sending a request.
      final data = await FriendService.getFriends(myId);

      if (!mounted) return;

      for (final f in data.friendships) {
        if (f.friendUser?.id == widget.userId) {
          setState(() {
            _friendshipStatus = _FriendshipStatus.friends;
            _friendshipId = f.id;
          });
          return;
        }
      }
      // pending = requests sent TO the logged-in user (they are the recipient).
      for (final f in data.pendingFriends) {
        if (f.friendUser?.id == widget.userId) {
          setState(() {
            _friendshipStatus = _FriendshipStatus.pending;
            _friendshipId = f.id;
          });
          return;
        }
      }
      // requested = requests sent BY the logged-in user (they are the requester).
      for (final f in data.requestedFriends) {
        if (f.friendUser?.id == widget.userId) {
          setState(() {
            _friendshipStatus = _FriendshipStatus.requested;
            _friendshipId = f.id;
          });
          return;
        }
      }
      setState(() => _friendshipStatus = _FriendshipStatus.none);
    } catch (e) {
      logger.e('[FriendProfileScreen] friendship status load error: $e');
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('Friend request sent to ${_user?.username ?? 'user'}')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] send friend request error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send friend request')),
        );
      }
    }
  }

  Future<void> _removeFriend() async {
    final auth = context.read<AuthProvider>();
    final myId = auth.dbUser?.id;
    if (myId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: FlixieColors.tabBarBackgroundFocused,
        title: const Text('Remove Friend'),
        content:
            Text('Remove ${_user?.username ?? 'this user'} from your friends?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: FlixieColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _actionLoading = true);
    try {
      await FriendService.removeFriend(myId, widget.userId);
      if (mounted) {
        setState(() {
          _friendshipStatus = _FriendshipStatus.none;
          _friendshipId = null;
          _actionLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${_user?.username ?? 'User'} removed from friends')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] remove friend error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove friend')),
        );
      }
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'You are now friends with ${_user?.username ?? 'this user'}')),
        );
      }
    } catch (e) {
      logger.e('[FriendProfileScreen] accept request error: $e');
      if (mounted) {
        setState(() => _actionLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept friend request')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline friend request')),
        );
      }
    }
  }

  Widget _buildFriendshipButton() {
    if (_actionLoading) {
      return const SizedBox(
        height: 40,
        width: 40,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    switch (_friendshipStatus) {
      case _FriendshipStatus.none:
        return ElevatedButton.icon(
          icon: const Icon(Icons.person_add_outlined),
          label: const Text('Add Friend'),
          style: ElevatedButton.styleFrom(
            backgroundColor: FlixieColors.primary,
            foregroundColor: Colors.black,
          ),
          onPressed: _sendFriendRequest,
        );

      case _FriendshipStatus.requested:
        return OutlinedButton.icon(
          icon: const Icon(Icons.schedule_outlined),
          label: const Text('Request Pending'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlixieColors.warning,
            side: const BorderSide(color: FlixieColors.warning),
          ),
          onPressed: null,
        );

      case _FriendshipStatus.pending:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.check),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.success,
                foregroundColor: Colors.black,
              ),
              onPressed: _acceptRequest,
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.danger,
                side: const BorderSide(color: FlixieColors.danger),
              ),
              onPressed: _declineRequest,
              child: const Text('Decline'),
            ),
          ],
        );

      case _FriendshipStatus.friends:
        return OutlinedButton.icon(
          icon: const Icon(Icons.person_remove_outlined),
          label: const Text('Remove Friend'),
          style: OutlinedButton.styleFrom(
            foregroundColor: FlixieColors.danger,
            side: const BorderSide(color: FlixieColors.danger),
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

  void _openWrappedSheet() {
    final user = _user;
    if (user == null) return;
    final joinYear = user.createdAt != null
        ? (DateTime.tryParse(user.createdAt!)?.year ?? DateTime.now().year)
        : DateTime.now().year;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: true,
      backgroundColor: FlixieColors.background,
      useSafeArea: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.5,
          initialChildSize: 0.92,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return FriendWrappedSection(
              userId: user.id,
              joinYear: joinYear,
              username: user.username,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final visibleReviews = _showAllReviews
        ? _reviews
        : _reviews.take(_initialReviewCount).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_user?.username ?? 'Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _userLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Avatar
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: _avatarColor.withValues(alpha: 0.3),
                    child: Text(
                      _user?.initials ??
                          (_user?.username.isNotEmpty == true
                              ? _user!.username[0].toUpperCase()
                              : '?'),
                      style: TextStyle(
                        color: _avatarColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Username
                  Text(
                    _user?.username ?? '',
                    style: textTheme.headlineMedium,
                  ),

                  // Full name if available
                  if ((_user?.firstName != null || _user?.lastName != null) &&
                      '${_user?.firstName ?? ''} ${_user?.lastName ?? ''}'
                          .trim()
                          .isNotEmpty)
                    Text(
                      '${_user?.firstName ?? ''} ${_user?.lastName ?? ''}'
                          .trim(),
                      style: textTheme.bodySmall,
                    ),

                  // Bio
                  if (_user?.bio case final bioText
                      when bioText != null && bioText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        bioText,
                        textAlign: TextAlign.left,
                        style: textTheme.bodySmall
                            ?.copyWith(color: FlixieColors.light),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Add / Remove Friend button
                  _buildFriendshipButton(),

                  const SizedBox(height: 16),

                  const SizedBox(height: 24),

                  // Stats row
                  ProfileStatsRow(
                    watched: (_user?.watchedMovies?.length ?? 0) +
                        (_user?.watchedShows?.length ?? 0),
                    watchlist: (_user?.movieWatchlist?.length ?? 0) +
                        (_user?.showWatchlist?.length ?? 0),
                    favorites: (_user?.favoriteMovies?.length ?? 0) +
                        (_user?.favoriteShows?.length ?? 0),
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
                  if ((_user?.watchedMovies?.isNotEmpty ?? false)) ...[
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
                          foregroundColor: FlixieColors.primary,
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
                                ?.copyWith(color: FlixieColors.medium),
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
                            ?.copyWith(color: FlixieColors.medium),
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
                            foregroundColor: FlixieColors.light,
                            side: const BorderSide(
                                color: FlixieColors.tabBarBorder),
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
