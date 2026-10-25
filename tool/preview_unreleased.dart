// Isolated, fictional release-state fixtures. No account or backend access.
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/movies/presentation/widgets/movie_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/show_detail_hero.dart';
import 'package:flixie_app/features/movies/presentation/widgets/unreleased_movie_prompt.dart';
import 'package:flixie_app/models/movie.dart';
import 'package:flixie_app/models/show.dart';

void main() => runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.darkTheme,
    home: const ReleasePreview()));

class ReleasePreview extends StatefulWidget {
  const ReleasePreview({super.key});
  @override
  State<ReleasePreview> createState() => _ReleasePreviewState();
}

class _ReleasePreviewState extends State<ReleasePreview> {
  bool? _showOverride;
  bool get show =>
      _showOverride ??
      (const bool.fromEnvironment('PREVIEW_SHOW') ||
          MediaQuery.sizeOf(context).width >= 600);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!show) {
        confirmUnreleasedMovie(context,
            title: 'The Odyssey', releaseDate: '2999-07-15');
      }
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: CustomScrollView(slivers: [
        const SliverToBoxAdapter(
            child: SafeArea(
                bottom: false,
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Fictional release-state preview',
                        textAlign: TextAlign.center)))),
        SliverToBoxAdapter(
            child: Wrap(alignment: WrapAlignment.center, children: [
          TextButton(
              onPressed: () => setState(() => _showOverride = false),
              child: const Text('Movie fixture')),
          TextButton(
              onPressed: () => setState(() => _showOverride = true),
              child: const Text('Show fixture')),
        ])),
        if (show)
          const ShowDetailHero(
              show: TvShow(
                  id: 999,
                  name: 'Spider-Man: fixture series',
                  firstAirDate: '2999-07-15',
                  status: 'Planned'))
        else
          SliverToBoxAdapter(
              child: MovieDetailHero(
                  movie: const Movie(
                      id: 1368337,
                      title: 'The Odyssey',
                      releaseDate: '2999-07-15',
                      posterPath: '/5rhTDKUhPYvpdQIijFIs5VoWsON.jpg',
                      backdropPath: '/sSIzzVhhLfgLKVBcAUv0X6cLYz9.jpg',
                      runtime: 173),
                  onShowScoreInfo: () {})),
        SliverToBoxAdapter(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: FilledButton(
                    onPressed: () => confirmUnreleasedMovie(context,
                        title: 'The Odyssey', releaseDate: '2999-07-15'),
                    child: const Text('Log watch')))),
      ]));
}
