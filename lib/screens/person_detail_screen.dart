import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/person.dart';
import '../providers/auth_provider.dart';
import '../services/person_service.dart';
import '../theme/app_theme.dart';

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

  static const _imgBase = 'https://image.tmdb.org/t/p/w500';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = int.tryParse(widget.personId);
    if (id == null || id <= 0) {
      if (mounted) setState(() { _error = 'Invalid person ID.'; _isLoading = false; });
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
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
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
            if (item is Map) return item['personId'] == personId || item['id'] == personId;
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
      if (mounted) setState(() => _isFavoriteLoading = false);
    }
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    final parts = raw.split('-');
    if (parts.length < 3) return raw;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return raw;
    return '${months[month - 1]} ${parts[2]}, ${parts[0]}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null || _person == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF0D1B2A),
          leading: const BackButton(color: FlixieColors.light),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: FlixieColors.danger, size: 56),
                const SizedBox(height: 16),
                Text('Failed to load person', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(_error ?? 'Unknown error',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () { setState(() { _isLoading = true; _error = null; }); _load(); },
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
      backgroundColor: const Color(0xFF0D1B2A),
      body: CustomScrollView(
        slivers: [
          // ---- App bar with hero portrait ----------------------------------
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: const Color(0xFF0D1B2A),
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
              background: profileUrl != null
                  ? CachedNetworkImage(
                      imageUrl: profileUrl,
                      fit: BoxFit.cover,
                      color: Colors.black.withValues(alpha: 0.25),
                      colorBlendMode: BlendMode.darken,
                      errorWidget: (_, __, ___) => _portraitFallback(person.name),
                    )
                  : _portraitFallback(person.name),
            ),
          ),

          // ---- Content -----------------------------------------------------
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Department badge
                  if (person.department != null && person.department!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: FlixieColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: FlixieColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        person.department!.toUpperCase(),
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Name
                  Text(
                    person.name.toUpperCase(),
                    style: const TextStyle(
                      color: FlixieColors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Date of birth
                  if (person.dateOfBirth != null && person.dateOfBirth!.isNotEmpty)
                    _metaRow(Icons.calendar_today_outlined, _formatDate(person.dateOfBirth)),

                  // Place of birth
                  if (person.placeOfBirth != null && person.placeOfBirth!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _metaRow(Icons.place_outlined, person.placeOfBirth!.toUpperCase()),
                  ],

                  const SizedBox(height: 24),

                  // Biography
                  if (person.biography != null && person.biography!.isNotEmpty)
                    _buildBiographyCard(person.biography!),

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

  Widget _metaRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: FlixieColors.medium, size: 14),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: FlixieColors.medium,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBiographyCard(String bio) {
    const previewLines = 6;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2033),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E2D40)),
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
            crossFadeState: _bioExpanded
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
                  _bioExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: FlixieColors.primary,
                  size: 16,
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
    final hasInstagram = person.instagramId != null && person.instagramId!.isNotEmpty;

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
            color: const Color(0xFF0F2033),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF1E2D40)),
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
                const Icon(Icons.open_in_new, color: FlixieColors.medium, size: 18),
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
            leading: const Icon(Icons.language, color: FlixieColors.medium, size: 20),
            label: 'INSTAGRAM',
            onTap: () => _launch('https://www.instagram.com/${person.instagramId}'),
          ),
      ],
    );
  }

  Widget _buildCreditsSection(PersonCredits credits) {
    const posterBase = 'https://image.tmdb.org/t/p/w342';
    const thumbBase = 'https://image.tmdb.org/t/p/w185';

    final knownFor = credits.knownForCredits
        .where((c) => c.type == 'movie')
        .toList();

    final filmography = credits.allCredits
        .where((c) => c.type == 'movie')
        .toList()
      ..sort((a, b) {
        if (a.releaseDate == null && b.releaseDate == null) return 0;
        if (a.releaseDate == null) return 1;
        if (b.releaseDate == null) return -1;
        return b.releaseDate!.compareTo(a.releaseDate!);
      });

    if (knownFor.isEmpty && filmography.isEmpty) return const SizedBox.shrink();

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

    Widget filmEntry(PersonCreditItem item) {
      final year = item.releaseDate != null && item.releaseDate!.length >= 4
          ? item.releaseDate!.substring(0, 4)
          : null;
      final character = item.characters.isNotEmpty && item.characters.first.isNotEmpty
          ? item.characters.first
          : null;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 46,
              height: 68,
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
                  style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (year != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    year,
                    style: const TextStyle(color: FlixieColors.medium, fontSize: 12),
                  ),
                ],
                if (character != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    character,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlixieColors.medium,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ---- Known For -----------------------------------------------
        if (knownFor.isNotEmpty) ...[
          sectionTitle('Known For'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < knownFor.length; i++) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: () => context.push('/movies/${knownFor[i].id}'),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: AspectRatio(
                          aspectRatio: 2 / 3,
                          child: knownFor[i].posterPath != null
                              ? CachedNetworkImage(
                                  imageUrl: '$posterBase${knownFor[i].posterPath}',
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _posterFallback(),
                                )
                              : _posterFallback(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        knownFor[i].title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.light,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                  ),
                ),
                if (i < knownFor.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 32),
        ],

        // ---- Filmography ---------------------------------------------
        if (filmography.isNotEmpty) ...[
          sectionTitle('Filmography'),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: filmography.length > 10 ? 10 : filmography.length,
            separatorBuilder: (_, __) => const Divider(
              color: Color(0xFF1E2D40),
              height: 1,
            ),
            itemBuilder: (context, i) => GestureDetector(
              onTap: () => context.push('/movies/${filmography[i].id}'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: filmEntry(filmography[i]),
              ),
            ),
          ),
          if (filmography.length > 10) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => _showAllFilmography(context, filmography),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2033),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF1E2D40)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'View All ${filmography.length} Films',
                      style: const TextStyle(
                        color: FlixieColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.keyboard_arrow_down, color: FlixieColors.primary, size: 18),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  void _showAllFilmography(BuildContext context, List<PersonCreditItem> filmography) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0D1B2A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _FilmographySheet(filmography: filmography),
    );
  }

  Widget _posterFallback() {
    return Container(
      color: const Color(0xFF1B2E42),
      child: const Icon(Icons.movie_outlined, color: Color(0xFF2E4057), size: 24),
    );
  }

  Widget _portraitFallback(String name) {
    return Container(
      color: const Color(0xFF1B2E42),
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

// ---------------------------------------------------------------------------
// Filmography bottom sheet with search
// ---------------------------------------------------------------------------
class _FilmographySheet extends StatefulWidget {
  const _FilmographySheet({required this.filmography});

  final List<PersonCreditItem> filmography;

  @override
  State<_FilmographySheet> createState() => _FilmographySheetState();
}

class _FilmographySheetState extends State<_FilmographySheet> {
  static const _thumbBase = 'https://image.tmdb.org/t/p/w185';

  late List<PersonCreditItem> _filtered;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filtered = widget.filmography;
    _controller.addListener(_onSearch);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSearch() {
    final q = _controller.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.filmography
          : widget.filmography
              .where((f) => f.title.toLowerCase().contains(q))
              .toList();
    });
  }

  Widget _posterFallback() => Container(
        color: const Color(0xFF1B2E42),
        child: const Icon(Icons.movie_outlined, color: Color(0xFF2E4057), size: 20),
      );

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF1E2D40),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title + count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filmography',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: FlixieColors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    '${_filtered.length} films',
                    style: const TextStyle(color: FlixieColors.medium, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _controller,
                style: const TextStyle(color: FlixieColors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search films...',
                  hintStyle: const TextStyle(color: FlixieColors.medium, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: FlixieColors.medium, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, color: FlixieColors.medium, size: 18),
                          onPressed: () => _controller.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF0F2033),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1E2D40)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1E2D40)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: FlixieColors.primary.withValues(alpha: 0.6)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            const Divider(color: Color(0xFF1E2D40), height: 1),

            // List
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No films found',
                        style: TextStyle(color: FlixieColors.medium),
                      ),
                    )
                  : ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        color: Color(0xFF1E2D40),
                        height: 1,
                      ),
                      itemBuilder: (context, i) {
                        final item = _filtered[i];
                        final year = item.releaseDate != null &&
                                item.releaseDate!.length >= 4
                            ? item.releaseDate!.substring(0, 4)
                            : null;
                        final character = item.characters.isNotEmpty &&
                                item.characters.first.isNotEmpty
                            ? item.characters.first
                            : null;
                        return GestureDetector(
                          onTap: () => context.push('/movies/${item.id}'),
                          child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: SizedBox(
                                  width: 46,
                                  height: 68,
                                  child: item.posterPath != null
                                      ? CachedNetworkImage(
                                          imageUrl:
                                              '$_thumbBase${item.posterPath}',
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) =>
                                              _posterFallback(),
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
                                      style: const TextStyle(
                                        color: FlixieColors.white,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (year != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        year,
                                        style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                    if (character != null) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        character,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: FlixieColors.medium,
                                          fontSize: 12,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
