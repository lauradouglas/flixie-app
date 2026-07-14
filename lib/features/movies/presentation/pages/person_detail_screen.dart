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

class PersonDetailScreen extends StatefulWidget {
  const PersonDetailScreen({super.key, required this.personId});

  final String personId;

  @override
  State<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends State<PersonDetailScreen> {
  Person? _person;
  PersonCredits? _credits;
  bool _isLoading = true;
  String? _error;
  bool _bioExpanded = false;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  _CreditFilter _creditFilter = _CreditFilter.all;
  _CreditSort _creditSort = _CreditSort.popular;

  static const _imgBase = 'https://image.tmdb.org/t/p/w500';

  @override
  void initState() {
    super.initState();
    _load();
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
          _isLoading = false;
        });
        // Set initial favorite state from cached user
        final user = context.read<AuthProvider>().dbUser;
        final id = int.tryParse(widget.personId);
        if (user != null && id != null) {
          setState(() => _isFavorite = user.isPersonFavorite(id));
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

  List<_PersonFilmCredit> _allMovieCredits(PersonCredits credits) {
    final byId = <int, _PersonFilmCredit>{};

    for (final item in credits.allCredits.where((c) => c.type == 'movie')) {
      byId[item.id] = _PersonFilmCredit(
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

    for (final item in credits.crewCredits.where((c) => c.type == 'movie')) {
      final existing = byId[item.id];
      if (existing == null) {
        byId[item.id] = _PersonFilmCredit(
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
        byId[item.id] = _PersonFilmCredit(
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
    final filtered = _allMovieCredits(credits).where((credit) {
      return switch (_creditFilter) {
        _CreditFilter.all => true,
        _CreditFilter.actor => credit.isCast,
        _CreditFilter.director => credit.isDirector,
        _CreditFilter.writer => credit.isWriter,
        _CreditFilter.producer => credit.isProducer,
      };
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

  List<Widget> _personalBadges(int movieId) {
    final badges = <Widget>[];
    if (_movieInWatched(movieId)) {
      badges.add(_miniBadge('Watched', FlixieColors.success));
    }
    if (_movieInWatchlist(movieId)) {
      badges.add(_miniBadge('Watchlist', FlixieColors.warning));
    }
    if (_movieInFavorites(movieId)) {
      badges.add(_miniBadge('Favourite', FlixieColors.danger));
    }
    return badges;
  }

  @override
  Widget build(BuildContext context) {
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
          // ---- App bar with hero portrait ----------------------------------
          SliverAppBar(
            expandedHeight: 430,
            pinned: true,
            backgroundColor: FlixieColors.background,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: FlixieColors.light),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: const Text(
              'CAST MEMBER',
              style: TextStyle(
                color: FlixieColors.light,
                fontWeight: FontWeight.w600,
                fontSize: 14,
                letterSpacing: 1.5,
              ),
            ),
            centerTitle: true,
            actions: [
              _isFavoriteLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.red,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        _isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: _isFavorite ? Colors.red : FlixieColors.light,
                      ),
                      onPressed: _toggleFavorite,
                    ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  profileUrl != null
                      ? CachedNetworkImage(
                          imageUrl: profileUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _portraitFallback(person.name),
                        )
                      : _portraitFallback(person.name),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x66000000),
                          Color(0x22000000),
                          Color(0xF2120A24),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 24,
                    child: _buildHeroSummary(person),
                  ),
                ],
              ),
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

                  // Biography
                  if (person.biography != null && person.biography!.isNotEmpty)
                    _buildBiographyCard(person.biography!)
                  else
                    _emptySection(
                      'No biography yet',
                      'Biography details will appear here when available.',
                      Icons.person_outline,
                    ),

                  // External links
                  const SizedBox(height: 16),
                  _buildExternalLinks(person),

                  // Credits
                  if (_credits != null) ...[
                    const SizedBox(height: 32),
                    _buildCreditsSection(_credits!),
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: FlixieColors.white,
            fontSize: 34,
            fontWeight: FontWeight.w900,
            height: 1.04,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            if (person.dateOfBirth != null && person.dateOfBirth!.isNotEmpty)
              _heroMeta(Icons.calendar_today_outlined,
                  _formatDate(person.dateOfBirth)),
            if (person.dateOfDeath != null && person.dateOfDeath!.isNotEmpty)
              _heroMeta(
                  Icons.event_busy_outlined, _formatDate(person.dateOfDeath)),
            if (person.placeOfBirth != null && person.placeOfBirth!.isNotEmpty)
              _heroMeta(Icons.place_outlined, person.placeOfBirth!),
          ],
        ),
      ],
    );
  }

  Widget _heroMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: FlixieColors.light, size: 14),
        const SizedBox(width: 6),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 64,
          ),
          child: Text(
            text,
            maxLines: 1,
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

  Widget _buildStatsStrip(Person person, PersonCredits credits) {
    final allCredits = _allMovieCredits(credits);
    final topRated = allCredits.where((c) => c.voteCount >= 25).toList()
      ..sort((a, b) => b.voteAverage.compareTo(a.voteAverage));
    final newest = allCredits.where((c) => c.releaseDate != null).toList()
      ..sort((a, b) => b.releaseDate!.compareTo(a.releaseDate!));
    final knownForCount =
        credits.knownForCredits.where((c) => c.type == 'movie').length;

    return Row(
      children: [
        Expanded(
          child: _statTile(
            'Known For',
            knownForCount == 0 ? '-' : '$knownForCount',
            Icons.auto_awesome_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Credits',
            allCredits.isEmpty ? '-' : '${allCredits.length}',
            Icons.local_movies_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Top Film',
            topRated.isEmpty
                ? '-'
                : topRated.first.voteAverage.toStringAsFixed(1),
            Icons.star_border_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statTile(
            'Recent',
            newest.isEmpty ? '-' : newest.first.year ?? '-',
            Icons.update_rounded,
          ),
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: FlixieColors.primary, size: 16),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: FlixieColors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
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

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildBiographyCard(String bio) {
    const previewLines = 6;
    final shouldCollapse = bio.length > 620;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FlixieColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.person_outline, color: FlixieColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'THE BIOGRAPHY',
                style: TextStyle(
                  color: FlixieColors.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                    _bioExpanded ? 'SHOW LESS' : 'READ MORE',
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

  Widget _buildExternalLinks(Person person) {
    final hasImdb = person.imdbId != null && person.imdbId!.isNotEmpty;
    final hasInstagram =
        person.instagramId != null && person.instagramId!.isNotEmpty;

    if (!hasImdb && !hasInstagram) return const SizedBox.shrink();

    Widget linkCard({
      required Widget leading,
      required String label,
      required VoidCallback onTap,
      bool fullWidth = false,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: FlixieColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: Row(
            mainAxisAlignment: fullWidth
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  leading,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (fullWidth)
                const Icon(Icons.open_in_new,
                    color: FlixieColors.medium, size: 18),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Connect & Resources',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FlixieColors.white,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        if (hasImdb)
          linkCard(
            fullWidth: true,
            leading: Container(
              width: 36,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFFF5C518),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: const Text(
                'IMDb',
                style: TextStyle(
                  color: Color(0xFF000000),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            label: 'Official Profile',
            onTap: () => _launch('https://www.imdb.com/name/${person.imdbId}'),
          ),
        if (hasImdb && hasInstagram) const SizedBox(height: 10),
        if (hasInstagram)
          linkCard(
            leading: const Icon(Icons.language,
                color: FlixieColors.medium, size: 20),
            label: 'INSTAGRAM',
            onTap: () =>
                _launch('https://www.instagram.com/${person.instagramId}'),
          ),
      ],
    );
  }

  Widget _buildCreditsSection(PersonCredits credits) {
    final knownFor =
        credits.knownForCredits.where((c) => c.type == 'movie').toList();
    final filmography = _filteredCredits(credits);
    final allCredits = _allMovieCredits(credits);

    if (knownFor.isEmpty && allCredits.isEmpty) {
      return _emptySection(
        'No movie credits yet',
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
        // ---- Known For -----------------------------------------------
        if (knownFor.isNotEmpty) ...[
          sectionTitle('Known For'),
          SizedBox(
            height: 236,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: knownFor.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = knownFor[index];
                return _knownForCard(item);
              },
            ),
          ),
          const SizedBox(height: 32),
        ],

        // ---- Filmography ---------------------------------------------
        sectionTitle('Filmography'),
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
    final badges = _personalBadges(item.id);
    return GestureDetector(
      onTap: () => context.push('/movies/${item.id}'),
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
                if (badges.isNotEmpty)
                  Positioned(
                    left: 6,
                    right: 6,
                    bottom: 6,
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: badges.take(2).toList(),
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
                _year(item.releaseDate)!,
                style:
                    const TextStyle(color: FlixieColors.medium, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCreditControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _CreditFilter.values.map((filter) {
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
        PopupMenuButton<_CreditSort>(
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
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: FlixieColors.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: FlixieColors.tabBarBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded,
                    color: FlixieColors.medium, size: 16),
                const SizedBox(width: 8),
                Text(
                  _creditSort.label,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down_rounded,
                    color: FlixieColors.medium, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _creditListRow(_PersonFilmCredit item) {
    const thumbBase = 'https://image.tmdb.org/t/p/w185';
    final badges = _personalBadges(item.id);

    return GestureDetector(
      onTap: () => context.push('/movies/${item.id}'),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 48,
                height: 72,
                child: item.posterPath != null
                    ? CachedNetworkImage(
                        imageUrl: '$thumbBase${item.posterPath}',
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _posterFallback(),
                      )
                    : _posterFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.year != null)
                        Text(
                          item.year!,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                          ),
                        ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          item.roleLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: FlixieColors.medium,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      if (item.voteAverage > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                color: FlixieColors.warning, size: 13),
                            const SizedBox(width: 2),
                            Text(
                              item.voteAverage.toStringAsFixed(1),
                              style: const TextStyle(
                                color: FlixieColors.warning,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 5,
                      runSpacing: 5,
                      children: badges,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
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

enum _CreditSort { popular, newest, oldest, rating }

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
