import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/movie_list_movie.dart';
import '../providers/auth_provider.dart';
import '../providers/movie_lists_provider.dart';
import '../repositories/movie_features_repository.dart';
import '../theme/app_theme.dart';

class MovieListDetailScreen extends StatelessWidget {
  const MovieListDetailScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to view list')),
      );
    }
    return ChangeNotifierProvider(
      create: (_) => MovieListsProvider(
        repository: const MovieFeaturesRepository(),
        userId: userId,
      )..loadListMovies(listId),
      child: _MovieListDetailView(listId: listId, listName: listName),
    );
  }
}

class _MovieListDetailView extends StatelessWidget {
  const _MovieListDetailView({
    required this.listId,
    required this.listName,
  });

  final String listId;
  final String listName;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final movies = provider.listMovies[listId] ?? const <MovieListMovie>[];
    return Scaffold(
      appBar: AppBar(title: Text(listName)),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : movies.isEmpty
              ? const Center(
                  child: Text(
                    'No movies in this list yet.',
                    style: TextStyle(color: FlixieColors.medium),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: movies.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.56,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (_, index) {
                    final entry = movies[index];
                    final posterPath = entry.movie?.posterPath;
                    final posterUrl =
                        posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null;
                    return GestureDetector(
                      onTap: () => context.push('/movies/${entry.movieId}'),
                      child: Container(
                        decoration: BoxDecoration(
                          color: FlixieColors.tabBarBackgroundFocused,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    const BorderRadius.vertical(top: Radius.circular(12)),
                                child: posterUrl == null
                                    ? Container(
                                        color: const Color(0xFF1E2D40),
                                        child: const Center(
                                          child: Icon(Icons.movie_outlined,
                                              color: FlixieColors.medium),
                                        ),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: posterUrl,
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                              child: Text(
                                entry.movie?.title ?? 'Unknown',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconButton(
                                icon: const Icon(Icons.remove_circle_outline,
                                    color: FlixieColors.danger),
                                onPressed: () async {
                                  final ok = await provider.removeMovieFromList(listId, entry.movieId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(ok
                                            ? 'Removed from list'
                                            : (provider.error ?? 'Unable to remove movie')),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
