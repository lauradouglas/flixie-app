import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Data stubs – in a real app these come from MovieService / the API.
// ---------------------------------------------------------------------------

class _CastMember {
  const _CastMember({
    required this.name,
    required this.character,
    this.profilePath,
  });

  final String name;
  final String character;
  final String? profilePath;
}

class _UserReview {
  const _UserReview({
    required this.author,
    required this.date,
    required this.rating,
    required this.body,
    this.avatarInitials = 'JD',
  });

  final String author;
  final String date;
  final int rating;
  final String body;
  final String avatarInitials;
}

class _SimilarMovie {
  const _SimilarMovie({
    required this.title,
    this.posterPath,
  });

  final String title;
  final String? posterPath;
}

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------

class MovieDetailScreen extends StatefulWidget {
  const MovieDetailScreen({super.key, required this.movieId});

  final String movieId;

  @override
  State<MovieDetailScreen> createState() => _MovieDetailScreenState();
}

class _MovieDetailScreenState extends State<MovieDetailScreen> {
  bool _inWatchlist = false;

  // --- placeholder data -------------------------------------------------------
  static const String _movieTitle = 'NEON ASCENSION';
  static const String _year = '2024';
  static const String _rating = 'PG-13';
  static const String _runtime = '2h 15m';
  static const double _cineScore = 8.9;
  static const int _criticsScore = 94;
  static const String _audienceScore = 'A+';
  static const String _synopsis =
      'In a decaying hyper-metropolis where memories are traded like currency, '
      'a low-level data courier discovers a fragment of code that could restart '
      'the sun. Pursued by celestial enforcers and underground syndicates, they '
      'must ascend to the legendary Spire before the final eclipse '
      'permanentizes the dark.';
  static const List<String> _genres = ['SCI-FI', 'ACTION', '4K ULTRA HD'];
  static const String _director = 'Denis Villeneuve';
  static const String _writers = 'Elena Vance, Jonathan Reed';
  static const String _studio = 'Warner Bros. / Legendary';

  static const List<_CastMember> _cast = [
    _CastMember(name: 'Liam Vance', character: 'Kaelen Flux'),
    _CastMember(name: 'Sarah Chen', character: 'Nova Seven'),
    _CastMember(name: 'Marcus Osei', character: 'The Curator'),
    _CastMember(name: 'Priya Nair', character: 'Echo'),
  ];

  static const List<_UserReview> _reviews = [
    _UserReview(
      author: 'John Doe',
      date: 'Feb 12, 2024',
      rating: 9,
      body:
          'Visually stunning and emotionally resonant. The world-building is '
          "top-notch. It's rare to see a sci-fi film today that takes this "
          'many risks.',
      avatarInitials: 'JD',
    ),
  ];

  static const List<_SimilarMovie> _similar = [
    _SimilarMovie(title: 'Digital Mirage'),
    _SimilarMovie(title: 'The Void Project'),
    _SimilarMovie(title: 'Orbit Zero'),
  ];
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  _buildGenreChips(),
                  const SizedBox(height: 12),
                  _buildTitleBlock(context),
                  const SizedBox(height: 16),
                  _buildScores(context),
                  const Divider(height: 32, color: Color(0xFF1E2D40)),
                  _buildSynopsis(context),
                  const SizedBox(height: 24),
                  _buildWatchNowButton(),
                  const SizedBox(height: 12),
                  _buildAddToListButton(),
                  const SizedBox(height: 20),
                  _buildCreditsCard(context),
                  const SizedBox(height: 28),
                  _buildTopCastSection(context),
                  const SizedBox(height: 28),
                  _buildUserReviewsSection(context),
                  const SizedBox(height: 28),
                  _buildMoreLikeThisSection(context),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Sliver app bar with hero image --------------------------------------

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: const Color(0xFF0D1B2A),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
        onPressed: () => context.pop(),
      ),
      title: const Text(
        'CINEHUB',
        style: TextStyle(
          color: FlixieColors.primary,
          fontWeight: FontWeight.bold,
          fontSize: 18,
          letterSpacing: 2,
        ),
      ),
      centerTitle: true,
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: FlixieColors.light),
          onPressed: () => context.go('/search'),
        ),
        IconButton(
          icon: const Icon(Icons.share_outlined, color: FlixieColors.light),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _HeroBackdrop(posterPath: null),
      ),
    );
  }

  // ---- Genre chips ---------------------------------------------------------

  Widget _buildGenreChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: _genres.map((g) => _GenreChip(label: g)).toList(),
    );
  }

  // ---- Title + meta --------------------------------------------------------

  Widget _buildTitleBlock(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _movieTitle,
          style: const TextStyle(
            color: FlixieColors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$_year  •  $_rating  •  $_runtime',
          style: const TextStyle(
            color: FlixieColors.medium,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ---- Score row -----------------------------------------------------------

  Widget _buildScores(BuildContext context) {
    return Row(
      children: [
        _ScoreTile(
          leading: const Icon(Icons.star, color: FlixieColors.warning, size: 18),
          value: _cineScore.toString(),
          label: 'CINESCORE',
        ),
        const SizedBox(width: 28),
        _ScoreTile(
          value: '$_criticsScore%',
          valueColor: FlixieColors.success,
          label: 'CRITICS',
        ),
        const SizedBox(width: 28),
        _ScoreTile(
          value: _audienceScore,
          label: 'AUDIENCE',
        ),
      ],
    );
  }

  // ---- Synopsis ------------------------------------------------------------

  Widget _buildSynopsis(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Synopsis',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          _synopsis,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  // ---- CTA buttons ---------------------------------------------------------

  Widget _buildWatchNowButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: FlixieColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.play_arrow),
        label: const Text(
          'Watch Now',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: () {},
      ),
    );
  }

  Widget _buildAddToListButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: FlixieColors.primary,
          side: const BorderSide(color: FlixieColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(_inWatchlist ? Icons.check : Icons.add),
        label: Text(
          _inWatchlist ? 'Remove from List' : 'Add to List',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        onPressed: () => setState(() => _inWatchlist = !_inWatchlist),
      ),
    );
  }

  // ---- Credits card --------------------------------------------------------

  Widget _buildCreditsCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CreditsRow(label: 'DIRECTOR', value: _director),
          const SizedBox(height: 12),
          _CreditsRow(label: 'WRITERS', value: _writers),
          const SizedBox(height: 12),
          _CreditsRow(label: 'STUDIO', value: _studio),
        ],
      ),
    );
  }

  // ---- Top cast ------------------------------------------------------------

  Widget _buildTopCastSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Top Cast',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlixieColors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            TextButton(
              onPressed: () {},
              child: const Row(
                children: [
                  Text(
                    'See All',
                    style: TextStyle(
                      color: FlixieColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: FlixieColors.primary,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _cast.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _CastCard(member: _cast[i]),
          ),
        ),
      ],
    );
  }

  // ---- User reviews --------------------------------------------------------

  Widget _buildUserReviewsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'User Reviews',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: FlixieColors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: FlixieColors.primary,
                side: const BorderSide(color: FlixieColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {},
              child: const Text(
                'Write Review',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._reviews.map((r) => _ReviewCard(review: r)),
      ],
    );
  }

  // ---- More like this ------------------------------------------------------

  Widget _buildMoreLikeThisSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'More Like This',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 190,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _similar.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) => _SimilarCard(movie: _similar[i]),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({this.posterPath});

  final String? posterPath;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        posterPath != null
            ? CachedNetworkImage(
                imageUrl: posterPath!,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => _placeholder(),
              )
            : _placeholder(),
        // Dark gradient overlay
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x44000000),
                Color(0xBB000000),
              ],
            ),
          ),
        ),
        // Play button
        Center(
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFF1B2E42),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 64,
        ),
      ),
    );
  }
}

class _GenreChip extends StatelessWidget {
  const _GenreChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: FlixieColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({
    required this.value,
    required this.label,
    this.leading,
    this.valueColor = FlixieColors.white,
  });

  final Widget? leading;
  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 4)],
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: FlixieColors.medium,
            fontSize: 10,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CreditsRow extends StatelessWidget {
  const _CreditsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: FlixieColors.medium,
            fontSize: 11,
            letterSpacing: 1,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: FlixieColors.light,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CastCard extends StatelessWidget {
  const _CastCard({required this.member});

  final _CastMember member;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile image
          Container(
            height: 100,
            width: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2E42),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: member.profilePath != null
                ? CachedNetworkImage(
                    imageUrl: member.profilePath!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _avatarFallback(),
                  )
                : _avatarFallback(),
          ),
          const SizedBox(height: 6),
          Text(
            member.name,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            member.character,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(Icons.person, color: FlixieColors.medium, size: 40),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final _UserReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B2E42),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 20,
                backgroundColor: FlixieColors.primary.withValues(alpha: 0.3),
                child: Text(
                  review.avatarInitials,
                  style: const TextStyle(
                    color: FlixieColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.author,
                      style: const TextStyle(
                        color: FlixieColors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      review.date,
                      style: const TextStyle(
                        color: FlixieColors.medium,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.star, color: FlixieColors.warning, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '${review.rating}/10',
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.body,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarCard extends StatelessWidget {
  const _SimilarCard({required this.movie});

  final _SimilarMovie movie;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 160,
            width: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF1B2E42),
              borderRadius: BorderRadius.circular(10),
            ),
            clipBehavior: Clip.antiAlias,
            child: movie.posterPath != null
                ? CachedNetworkImage(
                    imageUrl: movie.posterPath!,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _posterFallback(),
                  )
                : _posterFallback(),
          ),
          const SizedBox(height: 6),
          Text(
            movie.title,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(
          Icons.movie_creation_outlined,
          color: FlixieColors.medium,
          size: 36,
        ),
      ),
    );
  }
}
