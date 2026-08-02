import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
            Icon(icon, color: FlixieColors.medium, size: 40),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: FlixieColors.medium)),
          ],
        ),
      );
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
  int _selectedTab = 0;

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
    final currentUser = context.read<AuthProvider>().dbUser;
    final myId = currentUser?.id;
    final myFavoriteMovies = currentUser?.favoriteMovies;
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
      backgroundColor: FlixieColors.surface,
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Watch invite sent!')),
            );
          }
        },
        onError: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to send invite')),
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
        title: Text(user.username),
        centerTitle: true,
        actions: [
          if (!widget.previewMode)
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
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'wrapped',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.auto_awesome_outlined),
                    title: Text('View Wrapped'),
                  ),
                ),
                PopupMenuItem(
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
                    leading: Icon(Icons.block, color: FlixieColors.danger),
                    title: Text('Block user',
                        style: TextStyle(color: FlixieColors.danger)),
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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _modernHeader(user),
            if (!widget.previewMode) ...[
              const SizedBox(height: 18),
              _profileActions(),
              if (_friendshipStatus == _FriendshipStatus.friends) ...[
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check, size: 17, color: FlixieColors.primary),
                    SizedBox(width: 7),
                    Text('Friends',
                        style: TextStyle(color: FlixieColors.medium)),
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
          ],
        ),
      ),
    );
  }

  Widget _modernHeader(User user) {
    final showFirstName = user.firstName?.trim().isNotEmpty == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ProfileAvatarView(
          avatar: user.avatar,
          fallbackText: user.initials ?? user.username[0].toUpperCase(),
          fallbackColor: _avatarColor,
          size: 116,
          profileBadges: user.profileBadges,
        ),
        const SizedBox(width: 22),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '@${user.username}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.white,
                  fontSize: 25,
                  height: 1.05,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (showFirstName) ...[
                const SizedBox(height: 5),
                Text(user.firstName!,
                    style: const TextStyle(
                        color: FlixieColors.light, fontSize: 16)),
              ],
              if (user.profileBadges.isNotEmpty) ...[
                const SizedBox(height: 8),
                ProfileBadgePills(
                  badges: user.profileBadges,
                  compact: true,
                  featuredOnly: true,
                ),
              ],
              const SizedBox(height: 9),
              Row(children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 14, color: FlixieColors.medium),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(_memberSinceLabel,
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 12)),
                ),
              ]),
              if (user.bio?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 9),
                Text(user.bio!.trim(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: FlixieColors.light, height: 1.35)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileActions() {
    if (_friendshipStatus != _FriendshipStatus.friends) {
      return SizedBox(width: double.infinity, child: _buildFriendshipButton());
    }
    return Row(children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: () => context.push('/chat/${widget.userId}'),
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('Message'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            side: const BorderSide(color: FlixieColors.primary),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton.icon(
          onPressed: _inviteToWatch,
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('Invite to watch'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
        ),
      ),
    ]);
  }

  Widget _modernStats(int watched, int watchlist, int favourites) {
    final values = [
      (watched, 'Watched'),
      (watchlist, 'Watchlist'),
      (favourites, 'Favourites'),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: .72),
        border: Border.all(color: FlixieColors.tabBarBorder),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        for (var i = 0; i < values.length; i++) ...[
          Expanded(
            child: Column(children: [
              Text('${values[i].$1}',
                  style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 25,
                      fontWeight: FontWeight.w800)),
              Text(values[i].$2,
                  style: const TextStyle(color: FlixieColors.light)),
            ]),
          ),
          if (i < values.length - 1)
            Container(width: 1, height: 50, color: FlixieColors.tabBarBorder),
        ],
      ]),
    );
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
                          : FlixieColors.light,
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

  List<Widget> _overviewContent(User user) => [
        if (!_compatibilityLoading) ...[
          TasteCompatibilityCard(
            score: _compatibilityScore,
            sharedMovies: _sharedMovieCount,
            sharedFavs: _sharedFavCount,
            friendName: user.username,
          ),
          const SizedBox(height: 20),
        ],
        ListsPreviewSection(
          userId: widget.userId,
          title: 'PUBLIC LISTS',
          emptyMessage: 'No public lists yet.',
          embedded: true,
          publicOnly: true,
        ),
        if (user.favoriteMovies?.isNotEmpty == true) ...[
          const SizedBox(height: 18),
          FavoriteMoviesSection(favoriteMovies: user.favoriteMovies!),
        ],
        if (_reviews.isNotEmpty) ...[
          const SizedBox(height: 18),
          _recentReview(_reviews.first),
        ],
      ];

  List<Widget> _activityContent(User user) => [
        if (user.watchedMovies?.isNotEmpty == true)
          FriendMiniStats(watchedMovies: user.watchedMovies!),
        if (user.watchedMovies?.isEmpty != false)
          const _EmptyProfileTab(
            icon: Icons.timeline_outlined,
            text: 'No public activity yet.',
          ),
      ];

  List<Widget> _reviewsContent() {
    if (_reviewsLoading) {
      return const [Center(child: CircularProgressIndicator())];
    }
    if (_reviews.isEmpty) {
      return const [
        _EmptyProfileTab(icon: Icons.reviews_outlined, text: 'No reviews yet.'),
      ];
    }
    return [
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _reviews.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => ReviewCard(
          review: _reviews[i],
          onTap: () {
            final id = _reviews[i].movieId;
            if (id != null) context.push('/movies/$id');
          },
        ),
      ),
    ];
  }

  Widget _recentReview(Review review) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RECENT ACTIVITY',
              style:
                  TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1.4)),
          const SizedBox(height: 10),
          ReviewCard(
            review: review,
            onTap: () {
              if (review.movieId != null) {
                context.push('/movies/${review.movieId}');
              }
            },
          ),
        ],
      );

  // Kept temporarily while the public-profile redesign settles, so its mature
  // loading/error variants remain available during follow-up visual QA.
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
              itemBuilder: (_) => const [
                PopupMenuItem(
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
                    leading: Icon(Icons.block, color: FlixieColors.danger),
                    title: Text(
                      'Block user',
                      style: TextStyle(color: FlixieColors.danger),
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
                      color: FlixieColors.surface,
                      border: Border.all(
                        color: FlixieColors.tabBarBorder.withValues(alpha: 0.9),
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
                                      color: FlixieColors.light,
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
                                        color: FlixieColors.light,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 7),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_month_outlined,
                                        size: 15,
                                        color: FlixieColors.medium,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _memberSinceLabel,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: FlixieColors.medium,
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
                              color: FlixieColors.light,
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
