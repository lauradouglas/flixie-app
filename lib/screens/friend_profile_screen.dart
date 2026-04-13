import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/review.dart';
import '../models/user.dart';
import '../models/watchlist_movie.dart';
import '../providers/auth_provider.dart';
import '../services/friend_service.dart';
import '../services/user_service.dart';
import '../theme/app_theme.dart';
import '../utils/app_logger.dart';
import 'my_reviews_screen.dart';
import 'profile/favorite_movies_section.dart';
import 'profile/movie_taste_badge.dart';
import 'profile/profile_stats_row.dart';

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
                    _TasteCompatibilityCard(
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
                    _MiniStats(watchedMovies: _user!.watchedMovies!),
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

// ── Mini stats widget ────────────────────────────────────────────────────────

class _MiniStats extends StatelessWidget {
  const _MiniStats({required this.watchedMovies});
  final List<dynamic> watchedMovies;

  List<WatchlistMovieDetails> get _movies {
    final out = <WatchlistMovieDetails>[];
    for (final m in watchedMovies.whereType<Map<String, dynamic>>()) {
      if (m['removed'] == true) continue;
      if (m['movie'] != null) {
        try {
          out.add(WatchlistMovieDetails.fromJson(
              m['movie'] as Map<String, dynamic>));
        } catch (_) {}
      }
    }
    return out;
  }

  String get _runtimeLabel {
    final mins = _movies.fold<int>(0, (s, m) => s + (m.runtime ?? 0));
    if (mins == 0) return '—';
    final d = mins ~/ (60 * 24);
    final h = (mins % (60 * 24)) ~/ 60;
    final m = mins % 60;
    if (d > 0) return '${d}d ${h}h ${m}m';
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  List<MapEntry<String, int>> get _topGenres {
    final counts = <String, int>{};
    for (final m in _movies) {
      for (final g in m.genres) {
        counts[g] = (counts[g] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final movies = _movies;
    final topGenres = _topGenres;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // section header
        Row(
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
              'STATS',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // runtime chip
        Row(
          children: [
            Expanded(
              child: _Chip(
                icon: Icons.schedule_outlined,
                label: _runtimeLabel,
                sublabel: 'total runtime',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _Chip(
                icon: Icons.movie_outlined,
                label: movies.isNotEmpty ? '${movies.length}' : '—',
                sublabel: 'movies watched',
              ),
            ),
          ],
        ),

        if (topGenres.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topGenres.map((e) => _GenreTag(name: e.key)).toList(),
          ),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
      {required this.icon, required this.label, required this.sublabel});
  final IconData icon;
  final String label;
  final String sublabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: FlixieColors.primary, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
              Text(sublabel,
                  style: const TextStyle(
                      color: FlixieColors.medium, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GenreTag extends StatelessWidget {
  const _GenreTag({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: FlixieColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.4)),
      ),
      child: Text(
        name,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Taste compatibility card
// ---------------------------------------------------------------------------

class _TasteCompatibilityCard extends StatelessWidget {
  const _TasteCompatibilityCard({
    required this.score,
    required this.sharedMovies,
    required this.sharedFavs,
    required this.friendName,
  });

  final int? score;
  final int sharedMovies;
  final int sharedFavs;
  final String friendName;

  Color get _color {
    if (score == null) return FlixieColors.medium;
    if (score! >= 75) return FlixieColors.success;
    if (score! >= 50) return FlixieColors.warning;
    return FlixieColors.danger;
  }

  IconData get _icon {
    if (score == null) return Icons.help_outline_rounded;
    if (score! >= 85) return Icons.favorite_rounded;
    if (score! >= 70) return Icons.thumb_up_rounded;
    if (score! >= 55) return Icons.thumbs_up_down_rounded;
    if (score! >= 40) return Icons.swap_horiz_rounded;
    return Icons.contrast_rounded;
  }

  String get _label {
    if (score == null) return 'Not enough data';
    if (score! >= 85) return 'Movie Soulmates';
    if (score! >= 70) return 'Great Taste Match';
    if (score! >= 55) return 'Pretty Compatible';
    if (score! >= 40) return 'Some Overlap';
    return 'Very Different Taste';
  }

  String _buildSubtitle() {
    final parts = <String>[];
    if (sharedMovies > 0) {
      parts.add(
          '$sharedMovies movie${sharedMovies == 1 ? '' : 's'} rated together');
    }
    if (sharedFavs > 0) {
      parts.add('$sharedFavs shared favourite${sharedFavs == 1 ? '' : 's'}');
    }
    if (parts.isEmpty) return 'No movies rated or favourited in common yet';
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = _color;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
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
                'TASTE COMPATIBILITY',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        // Badge card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FlixieColors.tabBarBackgroundFocused,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Icon circle with score ring
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: CircularProgressIndicator(
                      value: score != null ? score! / 100.0 : 0,
                      backgroundColor: Colors.transparent,
                      color: color.withValues(alpha: 0.7),
                      strokeWidth: 3,
                    ),
                  ),
                  if (score != null)
                    Text(
                      '$score%',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    )
                  else
                    Icon(_icon, color: color, size: 24),
                ],
              ),
              const SizedBox(width: 16),
              // Label + subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _label,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _buildSubtitle(),
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
