import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/person.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/data/person_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonPhotoGridScreen extends StatelessWidget {
  const _PersonPhotoGridScreen({required this.person, required this.images});

  final Person person;
  final List<PersonImage> images;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
      appBar: AppBar(
        backgroundColor: FlixieColors.background,
        foregroundColor: FlixieColors.white,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${person.name} photos',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${images.length} images',
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => GridView.builder(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: constraints.maxWidth >= 700 ? 4 : 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: .78,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) => Semantics(
            button: true,
            label: 'Open photo ${index + 1} of ${images.length}',
            child: InkWell(
              onTap: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  pageBuilder: (_, animation, __) => FadeTransition(
                    opacity: animation,
                    child: _PersonPhotoViewer(
                      personName: person.name,
                      images: images,
                      initialIndex: index,
                    ),
                  ),
                ),
              ),
              borderRadius: BorderRadius.circular(12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: images[index].thumbnailUrl,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const ColoredBox(
                    color: FlixieColors.surface,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: FlixieColors.primary,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const ColoredBox(
                    color: FlixieColors.surface,
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: FlixieColors.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PersonPhotoViewer extends StatefulWidget {
  const _PersonPhotoViewer({
    required this.personName,
    required this.images,
    required this.initialIndex,
  });

  final String personName;
  final List<PersonImage> images;
  final int initialIndex;

  @override
  State<_PersonPhotoViewer> createState() => _PersonPhotoViewerState();
}

class _PersonPhotoViewerState extends State<_PersonPhotoViewer> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (_, index) => InteractiveViewer(
                key: ValueKey(widget.images[index].imageUrl),
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index].originalUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(
                        color: FlixieColors.primary,
                      ),
                    ),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: FlixieColors.medium,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 12,
              child: IconButton.filledTonal(
                onPressed: () => Navigator.of(context).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: .65),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            Positioned(
              top: 14,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .65),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '${_index + 1} / ${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Text(
                widget.personName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  Person? _person;
  PersonCredits? _credits;
  List<PersonImage> _images = const [];
  bool _imagesLoading = false;
  bool _isLoading = true;
  String? _error;
  bool _bioExpanded = false;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  _CreditFilter _creditFilter = _CreditFilter.all;
  _MediaCreditFilter _mediaCreditFilter = _MediaCreditFilter.all;
  _PersonalCreditFilter _personalCreditFilter = _PersonalCreditFilter.all;
  _CreditSort _creditSort = _CreditSort.popular;
  bool _showAdvancedCreditFilters = false;
  final TextEditingController _filmographySearchController =
      TextEditingController();
  String _filmographyQuery = '';
  String? _filmographyYear;

  static const _imgBase = 'https://image.tmdb.org/t/p/w500';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filmographySearchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.personId);
    if (id == null || id <= 0) {
      if (mounted) {
        setState(() {
          _error = 'Invalid person ID.';
          _isLoading = false;
        });
      }
      return;
    }
    try {
      final results = await Future.wait([
        PersonService.getPersonById(id),
        PersonService.getPersonCredits(id),
      ]);
      if (mounted) {
        setState(() {
          _person = results[0] as Person;
          _credits = results[1] as PersonCredits;
          _images = (results[0] as Person).images;
          _isLoading = false;
        });
        _loadImages(id);
        // Set initial favorite state from cached user
        final user = context.read<AuthProvider>().dbUser;
        final favoritePersonId = int.tryParse(widget.personId);
        if (user != null && favoritePersonId != null) {
          setState(
            () => _isFavorite = user.isPersonFavorite(favoritePersonId),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadImages(int personId) async {
    if (!mounted) return;
    setState(() => _imagesLoading = true);
    try {
      final images = await PersonService.getPersonImages(personId);
      if (!mounted) return;
      setState(() {
        _images = images;
        _imagesLoading = false;
      });
    } catch (_) {
      // Keep the compatible images bundled with the person response when the
      // independently deployable images endpoint is unavailable.
      if (mounted) setState(() => _imagesLoading = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final authProvider = context.read<AuthProvider>();
    final user = authProvider.dbUser;
    final personId = int.tryParse(widget.personId);
    if (user == null || personId == null) return;

    setState(() => _isFavoriteLoading = true);
    try {
      if (_isFavorite) {
        await PersonService.unfavoritePerson(personId, user.id);
      } else {
        await PersonService.favoritePerson(personId, user.id);
      }
      if (mounted) {
        HapticFeedback.lightImpact();
        final currentList = List<dynamic>.from(user.favoritePeople ?? []);
        if (_isFavorite) {
          currentList.removeWhere((item) {
            if (item is int) return item == personId;
            if (item is Map) {
              return item['personId'] == personId || item['id'] == personId;
            }
            return false;
          });
        } else {
          currentList.add(personId);
        }
        authProvider.updateUserList(favoritePeople: currentList);
        setState(() {
          _isFavorite = !_isFavorite;
          _isFavoriteLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFavorite
                  ? 'Added to favourite people'
                  : 'Removed from favourite people',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isFavoriteLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update favourite person.'),
            backgroundColor: FlixieColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split('-');
    if (parts.length < 3) return raw;
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
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return raw;
    return '${months[month - 1]} ${parts[2]}, ${parts[0]}';
  }

  String? _year(String? raw) {
    if (raw == null || raw.length < 4) return null;
    return raw.substring(0, 4);
  }

  String? _ageLabel(Person person) {
    final born = DateTime.tryParse(person.dateOfBirth ?? '');
    if (born == null) return null;
    final end = DateTime.tryParse(person.dateOfDeath ?? '') ?? DateTime.now();
    var age = end.year - born.year;
    if (end.month < born.month ||
        (end.month == born.month && end.day < born.day)) {
      age--;
    }
    if (age < 0) return null;
    return person.dateOfDeath == null ? 'Age $age' : 'Lived to $age';
  }

  List<_PersonFilmCredit> _allCredits(PersonCredits credits) {
    final byId = <String, _PersonFilmCredit>{};

    for (final item in credits.allCredits) {
      final key = '${item.type}:${item.id}';
      byId[key] = _PersonFilmCredit(
        id: item.id,
        title: item.title,
        type: item.type,
        posterPath: item.posterPath,
        releaseDate: item.releaseDate,
        voteAverage: item.voteAverage,
        voteCount: item.voteCount,
        popularity: item.popularity,
        roles: item.characters,
        isCast: true,
        jobs: const [],
      );
    }

    for (final item in credits.crewCredits) {
      final key = '${item.type}:${item.id}';
      final existing = byId[key];
      if (existing == null) {
        byId[key] = _PersonFilmCredit(
          id: item.id,
          title: item.title,
          type: item.type,
          posterPath: item.posterPath,
          releaseDate: item.releaseDate,
          voteAverage: item.voteAverage,
          voteCount: item.voteCount,
          popularity: item.popularity,
          roles: const [],
          isCast: false,
          jobs: [item.job],
        );
      } else {
        byId[key] = _PersonFilmCredit(
          id: existing.id,
          title: existing.title,
          type: existing.type,
          posterPath: existing.posterPath,
          releaseDate: existing.releaseDate,
          voteAverage: existing.voteAverage,
          voteCount: existing.voteCount,
          popularity: existing.popularity,
          roles: existing.roles,
          isCast: existing.isCast,
          jobs: {...existing.jobs, item.job}.toList(),
        );
      }
    }

    return byId.values.toList();
  }

  List<_PersonFilmCredit> _filteredCredits(PersonCredits credits) {
    final filtered = _allCredits(credits).where((credit) {
      final matchesRole = switch (_creditFilter) {
        _CreditFilter.all => true,
        _CreditFilter.actor => credit.isCast,
        _CreditFilter.director => credit.isDirector,
        _CreditFilter.writer => credit.isWriter,
        _CreditFilter.producer => credit.isProducer,
      };
      final matchesMedia = switch (_mediaCreditFilter) {
        _MediaCreditFilter.all => true,
        _MediaCreditFilter.movies => credit.isMovie,
        _MediaCreditFilter.tv => !credit.isMovie,
      };
      final query = _filmographyQuery.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          credit.title.toLowerCase().contains(query) ||
          credit.roleLabel.toLowerCase().contains(query);
      final matchesYear =
          _filmographyYear == null || credit.year == _filmographyYear;
      final matchesPersonal = switch (_personalCreditFilter) {
        _PersonalCreditFilter.all => true,
        _PersonalCreditFilter.watched =>
          credit.isMovie && _movieInWatched(credit.id),
        _PersonalCreditFilter.watchlist =>
          credit.isMovie && _movieInWatchlist(credit.id),
        _PersonalCreditFilter.favourites =>
          credit.isMovie && _movieInFavorites(credit.id),
      };
      return matchesRole &&
          matchesMedia &&
          matchesQuery &&
          matchesYear &&
          matchesPersonal;
    }).toList();

    filtered.sort((a, b) {
      return switch (_creditSort) {
        _CreditSort.popular => b.popularity.compareTo(a.popularity),
        _CreditSort.newest =>
          (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''),
        _CreditSort.oldest =>
          (a.releaseDate ?? '9999').compareTo(b.releaseDate ?? '9999'),
        _CreditSort.rating => b.voteAverage.compareTo(a.voteAverage),
      };
    });
    return filtered;
  }

  bool _movieInWatched(int movieId) {
    return context
            .read<AuthProvider>()
            .dbUser
            ?.watchedMovies
            ?.any((movie) => movie.movieId == movieId) ??
        false;
  }

  bool _movieInWatchlist(int movieId) {
    return context
            .read<AuthProvider>()
            .dbUser
            ?.movieWatchlist
            ?.any((movie) => movie.movieId == movieId) ??
        false;
  }

  bool _movieInFavorites(int movieId) {
    return context
            .read<AuthProvider>()
            .dbUser
            ?.favoriteMovies
            ?.any((movie) => movie.movieId == movieId) ??
        false;
  }

  List<Widget> _posterStatusBadges(PersonCreditItem item) {
    if (item.type != 'movie') return const [];
    final movieId = item.id;
    return [
      if (_movieInFavorites(movieId))
        _posterStatusBadge(
          icon: Icons.favorite_rounded,
          label: 'Favourite',
          color: FlixieColors.danger,
        ),
      if (_movieInWatchlist(movieId))
        _posterStatusBadge(
          icon: Icons.bookmark_rounded,
          label: 'On watchlist',
          color: FlixieColors.warning,
        ),
      if (_movieInWatched(movieId))
        _posterStatusBadge(
          icon: Icons.check_rounded,
          label: 'Watched',
          color: FlixieColors.success,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild personal movie status badges when the user's lists change.
    context.watch<AuthProvider>();
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: FlixieColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _person == null) {
      return Scaffold(
        backgroundColor: FlixieColors.background,
        appBar: AppBar(
          backgroundColor: FlixieColors.background,
          leading: const BackButton(color: FlixieColors.light),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline,
                    color: FlixieColors.danger, size: 56),
                const SizedBox(height: 16),
                Text('Failed to load person',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_error ?? 'Unknown error',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _load();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final person = _person!;
    final profileUrl = person.profileImgUrl != null
        ? '$_imgBase${person.profileImgUrl}'
        : null;

    return Scaffold(
      backgroundColor: FlixieColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                _buildCompactHero(person, profileUrl),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  left: 12,
                  child: _heroNavigationButton(
                    icon: Icons.arrow_back_rounded,
                    label: 'Back',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 8,
                  right: 12,
                  child: _isFavoriteLoading
                      ? Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .5),
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: FlixieColors.danger,
                            ),
                          ),
                        )
                      : _heroNavigationButton(
                          icon: _isFavorite
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          label: _isFavorite
                              ? 'Remove favourite'
                              : 'Add favourite',
                          color: _isFavorite
                              ? FlixieColors.danger
                              : FlixieColors.light,
                          onPressed: _toggleFavorite,
                        ),
                ),
              ],
            ),
          ),

          // ---- Content -----------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  if (_credits != null) _buildStatsStrip(person, _credits!),

                  const SizedBox(height: 24),

                  // Put recognisable work first; this is usually why someone
                  // opens a person profile.
                  if (_credits != null) _buildKnownForSection(_credits!),

                  if (_credits != null) const SizedBox(height: 24),

                  _buildPhotosSection(person),

                  if (_imagesLoading || _images.isNotEmpty)
                    const SizedBox(height: 28),

                  // Biography
                  if (person.biography != null && person.biography!.isNotEmpty)
                    _buildBiographyCard(person.biography!)
                  else
                    _emptySection(
                      'No biography yet',
                      'Biography details will appear here when available.',
                      Icons.person_outline,
                    ),

                  // Filmography
                  if (_credits != null) ...[
                    const SizedBox(height: 32),
                    _buildFilmographySection(_credits!),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactHero(Person person, String? profileUrl) {
    final width = MediaQuery.sizeOf(context).width;
    final portraitWidth = (width * .42).clamp(140.0, 190.0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 12, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
            ),
            child: GestureDetector(
              onTap: _images.isEmpty ? null : () => _openPhotoViewer(person, 0),
              child: ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(right: Radius.circular(12)),
                child: SizedBox(
                  width: portraitWidth,
                  height: portraitWidth * 1.48,
                  child: profileUrl != null
                      ? CachedNetworkImage(
                          imageUrl: profileUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorWidget: (_, __, ___) =>
                              _portraitFallback(person.name),
                        )
                      : _portraitFallback(person.name),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.paddingOf(context).top + 12,
              ),
              child: _buildHeroSummary(person),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroNavigationButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color color = FlixieColors.light,
  }) {
    return Semantics(
      button: true,
      label: label,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(44),
          backgroundColor: Colors.black.withValues(alpha: .5),
          foregroundColor: color,
          side: BorderSide(color: Colors.white.withValues(alpha: .1)),
        ),
        icon: Icon(icon),
      ),
    );
  }

  Widget _buildHeroSummary(Person person) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (person.department != null && person.department!.isNotEmpty) ...[
          _miniBadge(person.department!.toUpperCase(), FlixieColors.primary),
          const SizedBox(height: 10),
        ],
        Text(
          person.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FlixieColors.white,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (person.dateOfBirth != null && person.dateOfBirth!.isNotEmpty)
              _heroMeta(Icons.calendar_today_outlined,
                  _formatDate(person.dateOfBirth)),
            if (person.dateOfDeath != null && person.dateOfDeath!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _heroMeta(
                    Icons.event_busy_outlined, _formatDate(person.dateOfDeath)),
              ),
            if (person.placeOfBirth != null && person.placeOfBirth!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _heroMeta(Icons.place_outlined, person.placeOfBirth!),
              ),
            if (_ageLabel(person) != null)
              Padding(
                padding: const EdgeInsets.only(top: 7),
                child: _heroMeta(Icons.cake_outlined, _ageLabel(person)!),
              ),
          ],
        ),
        if ((person.imdbId?.isNotEmpty ?? false) ||
            (person.instagramId?.isNotEmpty ?? false)) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              if (person.imdbId?.isNotEmpty ?? false)
                _compactExternalLink(
                  icon: Icons.movie_filter_outlined,
                  label: 'IMDb',
                  onTap: () =>
                      _launch('https://www.imdb.com/name/${person.imdbId}'),
                ),
              if (person.instagramId?.isNotEmpty ?? false)
                _compactExternalLink(
                  icon: Icons.camera_alt_outlined,
                  label: 'Instagram',
                  onTap: () => _launch(
                    'https://www.instagram.com/${person.instagramId}',
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _compactExternalLink({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 15, color: FlixieColors.primaryTint),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      labelStyle: const TextStyle(
        color: FlixieColors.light,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }

  Widget _heroMeta(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: FlixieColors.light, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotosSection(Person person) {
    if (_imagesLoading && _images.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos',
            style: TextStyle(
              color: FlixieColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            height: 150,
            child: Row(
              children: [
                Expanded(child: SkeletonBox(height: 150, borderRadius: 12)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 150, borderRadius: 12)),
                SizedBox(width: 10),
                Expanded(child: SkeletonBox(height: 150, borderRadius: 12)),
              ],
            ),
          ),
        ],
      );
    }
    if (_images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Photos',
                style: TextStyle(
                  color: FlixieColors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _openPhotoGrid(person),
              child: Text(
                'See all (${_images.length})',
                style: const TextStyle(
                  color: FlixieColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, index) {
              final image = _images[index];
              final width =
                  (150 * (image.aspectRatio ?? .67)).clamp(100.0, 240.0);
              return InkWell(
                onTap: () => _openPhotoViewer(person, index),
                borderRadius: BorderRadius.circular(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: image.thumbnailUrl,
                    width: width,
                    height: 150,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => SkeletonBox(
                      width: width,
                      height: 150,
                      borderRadius: 12,
                    ),
                    errorWidget: (_, __, ___) => Container(
                      width: width,
                      color: FlixieColors.surface,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: FlixieColors.medium,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openPhotoGrid(Person person) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PersonPhotoGridScreen(
          person: person,
          images: _images,
        ),
      ),
    );
  }

  void _openPhotoViewer(Person person, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: _PersonPhotoViewer(
            personName: person.name,
            images: _images,
            initialIndex: initialIndex,
          ),
        ),
      ),
    );
  }

  Widget _buildStatsStrip(Person person, PersonCredits credits) {
    final allCredits = _allCredits(credits);
    final topRated = allCredits.where((c) => c.voteCount >= 25).toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    final knownForCount = credits.knownForCredits.length;

    return Container(
      decoration: BoxDecoration(
        color: FlixieColors.surface.withValues(alpha: .55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statTile(
              'Credits',
              allCredits.isEmpty ? '-' : '${allCredits.length}',
              Icons.local_movies_outlined,
            ),
          ),
          const _PersonStatDivider(),
          Expanded(
            child: _statTile(
              'Known for',
              knownForCount == 0 ? '-' : '$knownForCount',
              Icons.auto_awesome_outlined,
            ),
          ),
          const _PersonStatDivider(),
          Expanded(
            child: _statTile(
              'Top title',
              topRated.isEmpty
                  ? '-'
                  : topRated.first.voteAverage.toStringAsFixed(1),
              Icons.star_border_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: const BoxDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: FlixieColors.primary, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: FlixieColors.medium, fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _miniBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _posterStatusBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: FlixieColors.background.withValues(alpha: 0.92),
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 1.5),
              boxShadow: const [
                BoxShadow(color: Colors.black54, blurRadius: 5),
              ],
            ),
            child: Icon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }

  Widget _buildBiographyCard(String bio) {
    const previewLines = 4;
    final shouldCollapse = bio.length > 380;
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biography',
            style: TextStyle(
              color: FlixieColors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: _bioExpanded || !shouldCollapse
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              bio,
              maxLines: previewLines,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            secondChild: Text(
              bio,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 14,
                height: 1.6,
              ),
            ),
          ),
          if (shouldCollapse) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => setState(() => _bioExpanded = !_bioExpanded),
              child: Row(
                children: [
                  Text(
                    _bioExpanded ? 'Show less' : 'Read more',
                    style: const TextStyle(
                      color: FlixieColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _bioExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: FlixieColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _emptySection(String title, String message, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: FlixieColors.medium, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style:
                      const TextStyle(color: FlixieColors.medium, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKnownForSection(PersonCredits credits) {
    final knownFor = credits.knownForCredits;
    if (knownFor.isEmpty) {
      return _emptySection(
        'No known titles yet',
        'Recognisable titles will appear here once they are available.',
        Icons.local_movies_outlined,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Known For',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: FlixieColors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            Text(
              '${knownFor.length} titles',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 286,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: knownFor.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) => _knownForCard(knownFor[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildFilmographySection(PersonCredits credits) {
    final filmography = _filteredCredits(credits);
    final allCredits = _allCredits(credits);

    if (allCredits.isEmpty) {
      return _emptySection(
        'No credits yet',
        'Credits will appear here once they are available.',
        Icons.local_movies_outlined,
      );
    }

    Widget sectionTitle(String text) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            text,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: FlixieColors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Filmography ---------------------------------------------
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Expanded(child: sectionTitle('Filmography')),
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                '${allCredits.length} credits',
                style: const TextStyle(
                  color: FlixieColors.medium,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        _buildCreditControls(),
        const SizedBox(height: 12),
        if (filmography.isEmpty)
          _emptySection(
            'No matches',
            'Try another role filter or sorting option.',
            Icons.filter_alt_off_outlined,
          )
        else ...[
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: filmography.length > 12 ? 12 : filmography.length,
            separatorBuilder: (_, __) => const Divider(
              color: FlixieColors.tabBarBorder,
              height: 1,
            ),
            itemBuilder: (context, i) => _creditListRow(filmography[i]),
          ),
          if (filmography.length > 12) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showAllCredits(context, filmography),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: FlixieColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All ${filmography.length} Credits',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down,
                        color: FlixieColors.primary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _knownForCard(PersonCreditItem item) {
    const posterBase = 'https://image.tmdb.org/t/p/w342';
    final statusBadges = _posterStatusBadges(item);
    final role = _knownForRole(item);
    return GestureDetector(
      onTap: () => context.push(
        item.type == 'tv' ? '/shows/${item.id}' : '/movies/${item.id}',
      ),
      child: SizedBox(
        width: 126,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: AspectRatio(
                    aspectRatio: 2 / 3,
                    child: item.posterPath != null
                        ? CachedNetworkImage(
                            imageUrl: '$posterBase${item.posterPath}',
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _posterFallback(),
                          )
                        : _posterFallback(),
                  ),
                ),
                if (statusBadges.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: statusBadges,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.25,
              ),
            ),
            if (_year(item.releaseDate) != null) ...[
              const SizedBox(height: 3),
              Text(
                '${_year(item.releaseDate)!} · ${item.type == 'tv' ? 'TV' : 'Movie'}',
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 11),
              ),
            ],
            if (role != null) ...[
              const SizedBox(height: 3),
              Text(
                role,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: FlixieColors.primaryTint,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _knownForRole(PersonCreditItem item) {
    if (item.characters.isNotEmpty) return item.characters.first;
    final jobs = _credits?.crewCredits
        .where((credit) => credit.id == item.id)
        .map((credit) => credit.job)
        .where((job) => job.trim().isNotEmpty)
        .toSet()
        .toList();
    if (jobs == null || jobs.isEmpty) return null;
    return jobs.take(2).join(' • ');
  }

  Widget _buildCreditControls() {
    final allCredits =
        _credits == null ? <_PersonFilmCredit>[] : _allCredits(_credits!);
    final years = allCredits
        .map((credit) => credit.year)
        .whereType<String>()
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));
    final roleFilters = <_CreditFilter>[
      _CreditFilter.all,
      if (allCredits.any((credit) => credit.isCast)) _CreditFilter.actor,
      if (allCredits.any((credit) => credit.isDirector)) _CreditFilter.director,
      if (allCredits.any((credit) => credit.isWriter)) _CreditFilter.writer,
      if (allCredits.any((credit) => credit.isProducer)) _CreditFilter.producer,
    ];
    final personalFilters = <_PersonalCreditFilter>[
      _PersonalCreditFilter.all,
      if (allCredits.any(
        (credit) => credit.isMovie && _movieInWatched(credit.id),
      ))
        _PersonalCreditFilter.watched,
      if (allCredits.any(
        (credit) => credit.isMovie && _movieInWatchlist(credit.id),
      ))
        _PersonalCreditFilter.watchlist,
      if (allCredits.any(
        (credit) => credit.isMovie && _movieInFavorites(credit.id),
      ))
        _PersonalCreditFilter.favourites,
    ];
    final advancedFilterCount = [
      _creditFilter != _CreditFilter.all,
      _personalCreditFilter != _PersonalCreditFilter.all,
      _filmographyYear != null,
      _creditSort != _CreditSort.popular,
    ].where((active) => active).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _filmographySearchController,
          onChanged: (value) => setState(() => _filmographyQuery = value),
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          style: const TextStyle(color: FlixieColors.white),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search titles or roles',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _filmographyQuery.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _filmographySearchController.clear();
                      setState(() => _filmographyQuery = '');
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 42,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: FlixieColors.surface.withValues(alpha: .55),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                ),
                child: Row(
                  children: _MediaCreditFilter.values.map((filter) {
                    final selected = _mediaCreditFilter == filter;
                    return Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _mediaCreditFilter = filter),
                        borderRadius: BorderRadius.circular(19),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? FlixieColors.primary
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(19),
                          ),
                          child: Text(
                            filter.label,
                            style: TextStyle(
                              color: selected
                                  ? FlixieColors.white
                                  : FlixieColors.medium,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(growable: false),
                ),
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: () => setState(
                () => _showAdvancedCreditFilters = !_showAdvancedCreditFilters,
              ),
              borderRadius: BorderRadius.circular(22),
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: FlixieColors.tabBarBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.tune_rounded,
                      color: FlixieColors.medium,
                      size: 17,
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Filters',
                      style: TextStyle(
                        color: FlixieColors.light,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (advancedFilterCount > 0) ...[
                      const SizedBox(width: 5),
                      CircleAvatar(
                        radius: 9,
                        backgroundColor: FlixieColors.primary,
                        child: Text(
                          '$advancedFilterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        if (_showAdvancedCreditFilters) ...[
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: roleFilters.map((filter) {
                final selected = _creditFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(filter.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _creditFilter = filter),
                    selectedColor: FlixieColors.primary.withValues(alpha: 0.22),
                    backgroundColor: FlixieColors.surface,
                    labelStyle: TextStyle(
                      color:
                          selected ? FlixieColors.primary : FlixieColors.medium,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: selected
                          ? FlixieColors.primary.withValues(alpha: 0.55)
                          : FlixieColors.tabBarBorder,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: personalFilters.map((filter) {
                final selected = _personalCreditFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: Icon(
                      filter.icon,
                      size: 16,
                      color: selected ? filter.color : FlixieColors.medium,
                    ),
                    label: Text(filter.label),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) =>
                        setState(() => _personalCreditFilter = filter),
                    selectedColor: filter.color.withValues(alpha: .16),
                    backgroundColor: FlixieColors.surface,
                    labelStyle: TextStyle(
                      color: selected ? filter.color : FlixieColors.medium,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                    side: BorderSide(
                      color: selected
                          ? filter.color.withValues(alpha: .65)
                          : FlixieColors.tabBarBorder,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _creditSortMenu(),
              PopupMenuButton<String?>(
                initialValue: _filmographyYear,
                onSelected: (year) => setState(() => _filmographyYear = year),
                color: FlixieColors.surface,
                itemBuilder: (context) => [
                  const PopupMenuItem<String?>(
                    value: null,
                    child: Text('All years'),
                  ),
                  ...years.map(
                    (year) => PopupMenuItem<String?>(
                      value: year,
                      child: Text(year),
                    ),
                  ),
                ],
                child: _controlChip(
                  Icons.calendar_month_outlined,
                  _filmographyYear ?? 'All years',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _creditSortMenu() {
    return PopupMenuButton<_CreditSort>(
      initialValue: _creditSort,
      onSelected: (sort) => setState(() => _creditSort = sort),
      color: FlixieColors.surface,
      itemBuilder: (context) => _CreditSort.values
          .map(
            (sort) => PopupMenuItem(
              value: sort,
              child: Text(sort.label),
            ),
          )
          .toList(),
      child: _controlChip(Icons.sort_rounded, _creditSort.label),
    );
  }

  Widget _controlChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FlixieColors.medium, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: FlixieColors.light,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: FlixieColors.medium,
            size: 16,
          ),
        ],
      ),
    );
  }

  Widget _creditListRow(_PersonFilmCredit item) {
    const thumbBase = 'https://image.tmdb.org/t/p/w185';
    final statusIcons = <Widget>[
      if (item.isMovie && _movieInWatched(item.id))
        const Tooltip(
          message: 'Watched',
          child: Icon(
            Icons.check_circle_rounded,
            color: FlixieColors.success,
            size: 15,
          ),
        ),
      if (item.isMovie && _movieInWatchlist(item.id))
        const Tooltip(
          message: 'Watchlist',
          child: Icon(
            Icons.bookmark_rounded,
            color: FlixieColors.warning,
            size: 15,
          ),
        ),
      if (item.isMovie && _movieInFavorites(item.id))
        const Tooltip(
          message: 'Favourite',
          child: Icon(
            Icons.favorite_rounded,
            color: FlixieColors.danger,
            size: 15,
          ),
        ),
    ];

    return GestureDetector(
      onTap: () => context.push(
        item.type == 'tv' ? '/shows/${item.id}' : '/movies/${item.id}',
      ),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 40,
                height: 60,
                child: item.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: '$thumbBase${item.posterPath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _posterFallback(),
                      )
                    : _posterFallback(),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (item.year != null)
                        Flexible(
                          child: Text(
                            '${item.year!} · ${item.isMovie ? 'Movie' : 'TV'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FlixieColors.medium,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      if (statusIcons.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        ...statusIcons.expand(
                          (icon) => [icon, const SizedBox(width: 4)],
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.roleLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.primaryTint,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (item.voteAverage > 0) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.star_rounded,
                color: FlixieColors.warning,
                size: 16,
              ),
              const SizedBox(width: 3),
              Text(
                item.voteAverage.toStringAsFixed(1),
                style: const TextStyle(
                  color: FlixieColors.warning,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: FlixieColors.medium, size: 20),
          ],
        ),
      ),
    );
  }

  void _showAllCredits(BuildContext context, List<_PersonFilmCredit> credits) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: FlixieColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.82,
        minChildSize: 0.45,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: FlixieColors.medium.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_creditFilter.label} Credits',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: FlixieColors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: FlixieColors.medium),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: credits.length,
                separatorBuilder: (_, __) => const Divider(
                  color: FlixieColors.tabBarBorder,
                  height: 1,
                ),
                itemBuilder: (context, index) => _creditListRow(credits[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: FlixieColors.surfaceElevated,
      child: Icon(Icons.movie_outlined,
          color: FlixieColors.medium.withValues(alpha: 0.55), size: 24),
    );
  }

  Widget _portraitFallback(String name) {
    return Container(
      color: FlixieColors.surfaceElevated,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: FlixieColors.medium,
            fontSize: 80,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}

enum _CreditFilter { all, actor, director, writer, producer }

enum _MediaCreditFilter { all, movies, tv }

extension _MediaCreditFilterView on _MediaCreditFilter {
  String get label => switch (this) {
        _MediaCreditFilter.all => 'All',
        _MediaCreditFilter.movies => 'Movies',
        _MediaCreditFilter.tv => 'TV',
      };
}

class _PersonStatDivider extends StatelessWidget {
  const _PersonStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 42,
      color: FlixieColors.tabBarBorder,
    );
  }
}

enum _CreditSort { popular, newest, oldest, rating }

enum _PersonalCreditFilter { all, watched, watchlist, favourites }

extension _PersonalCreditFilterView on _PersonalCreditFilter {
  String get label => switch (this) {
        _PersonalCreditFilter.all => 'All titles',
        _PersonalCreditFilter.watched => 'Watched',
        _PersonalCreditFilter.watchlist => 'Watchlist',
        _PersonalCreditFilter.favourites => 'Favourites',
      };

  IconData get icon => switch (this) {
        _PersonalCreditFilter.all => Icons.movie_filter_outlined,
        _PersonalCreditFilter.watched => Icons.check_circle_outline_rounded,
        _PersonalCreditFilter.watchlist => Icons.bookmark_outline_rounded,
        _PersonalCreditFilter.favourites => Icons.favorite_outline_rounded,
      };

  Color get color => switch (this) {
        _PersonalCreditFilter.all => FlixieColors.primary,
        _PersonalCreditFilter.watched => FlixieColors.success,
        _PersonalCreditFilter.watchlist => FlixieColors.warning,
        _PersonalCreditFilter.favourites => FlixieColors.danger,
      };
}

extension _CreditFilterView on _CreditFilter {
  String get label => switch (this) {
        _CreditFilter.all => 'All',
        _CreditFilter.actor => 'Actor',
        _CreditFilter.director => 'Director',
        _CreditFilter.writer => 'Writer',
        _CreditFilter.producer => 'Producer',
      };
}

extension _CreditSortView on _CreditSort {
  String get label => switch (this) {
        _CreditSort.popular => 'Popular',
        _CreditSort.newest => 'Newest',
        _CreditSort.oldest => 'Oldest',
        _CreditSort.rating => 'Rating',
      };
}

class _PersonFilmCredit {
  const _PersonFilmCredit({
    required this.id,
    required this.title,
    required this.type,
    required this.posterPath,
    required this.releaseDate,
    required this.voteAverage,
    required this.voteCount,
    required this.popularity,
    required this.roles,
    required this.isCast,
    required this.jobs,
  });

  final int id;
  final String title;
  final String type;
  final String? posterPath;
  final String? releaseDate;
  final double voteAverage;
  final int voteCount;
  final double popularity;
  final List<String> roles;
  final bool isCast;
  final List<String> jobs;

  bool get isMovie => type == 'movie';

  String? get year => releaseDate != null && releaseDate!.length >= 4
      ? releaseDate!.substring(0, 4)
      : null;

  String get roleLabel {
    final allRoles = [
      ...roles.where((role) => role.trim().isNotEmpty),
      ...jobs.where((job) => job.trim().isNotEmpty),
    ];
    return allRoles.isEmpty ? 'Credit' : allRoles.toSet().take(2).join(', ');
  }

  bool get isDirector =>
      jobs.any((job) => job.toLowerCase().contains('director'));

  bool get isWriter {
    return jobs.any((job) {
      final lower = job.toLowerCase();
      return lower.contains('writer') ||
          lower.contains('screenplay') ||
          lower.contains('story');
    });
  }

  bool get isProducer =>
      jobs.any((job) => job.toLowerCase().contains('producer'));
}
