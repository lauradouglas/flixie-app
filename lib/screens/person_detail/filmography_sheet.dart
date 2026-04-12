import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/person.dart';
import '../../theme/app_theme.dart';

class FilmographySheet extends StatefulWidget {
  const FilmographySheet({super.key, required this.filmography});

  final List<PersonCreditItem> filmography;

  @override
  State<FilmographySheet> createState() => _FilmographySheetState();
}

class _FilmographySheetState extends State<FilmographySheet> {
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
        child: const Icon(Icons.movie_outlined,
            color: Color(0xFF2E4057), size: 20),
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
                    style: const TextStyle(
                        color: FlixieColors.medium, fontSize: 13),
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
                  hintStyle:
                      const TextStyle(color: FlixieColors.medium, fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      color: FlixieColors.medium, size: 20),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              color: FlixieColors.medium, size: 18),
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
                    borderSide: BorderSide(
                        color: FlixieColors.primary.withValues(alpha: 0.6)),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
