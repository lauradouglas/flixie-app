import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/models/movie_short.dart';
import '../../data/diary_entry_service.dart';

class DiaryFilmSearchSheet extends StatefulWidget {
  const DiaryFilmSearchSheet({super.key, required this.service});
  final DiaryEntryService service;
  @override
  State<DiaryFilmSearchSheet> createState() => _DiaryFilmSearchSheetState();
}

class _DiaryFilmSearchSheetState extends State<DiaryFilmSearchSheet> {
  final input = TextEditingController();
  Timer? debounce;
  int generation = 0;
  bool loading = false, failed = false;
  List<MovieShort> results = [];
  void changed(String value) {
    debounce?.cancel();
    final request = ++generation;
    setState(() {
      results = [];
      failed = false;
      loading = value.trim().length >= 2;
    });
    if (loading) {
      debounce = Timer(const Duration(milliseconds: 300),
          () => search(value.trim(), request));
    }
  }

  Future<void> search(String query, int request) async {
    try {
      final found = await widget.service.search(query);
      if (mounted && request == generation) {
        setState(() {
          results = found;
          loading = false;
        });
      }
    } catch (_) {
      if (mounted && request == generation) {
        setState(() {
          failed = true;
          loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    debounce?.cancel();
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: MediaQuery.sizeOf(context).height * .95,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, MediaQuery.viewInsetsOf(context).bottom),
          child: Column(children: [
            Row(children: [
              Expanded(
                  child: Text('Log a film',
                      style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                  tooltip: 'Close film search',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: input,
                autofocus: true,
                onChanged: changed,
                decoration: const InputDecoration(
                    labelText: 'Search films', prefixIcon: Icon(Icons.search))),
            const SizedBox(height: 12),
            Expanded(
                child: loading
                    ? const Center(child: CircularProgressIndicator())
                    : failed
                        ? Center(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                const Text('Couldn’t search films.'),
                                TextButton(
                                    onPressed: () => changed(input.text),
                                    child: const Text('Try again'))
                              ]))
                        : results.isEmpty
                            ? Center(
                                child: Text(input.text.trim().length < 2
                                    ? 'Find a film to add to your diary.'
                                    : 'No films found. Try another title.'))
                            : ListView.builder(
                                itemCount: results.length,
                                itemBuilder: (_, i) {
                                  final movie = results[i],
                                      path = results[i].poster;
                                  return ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                              vertical: 6),
                                      leading: path == null
                                          ? const SizedBox(
                                              width: 40,
                                              child: Icon(Icons.movie_outlined))
                                          : CachedNetworkImage(
                                              imageUrl: path
                                                      .startsWith('https://')
                                                  ? path
                                                  : 'https://image.tmdb.org/t/p/w185$path',
                                              width: 40,
                                              height: 60,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  const Icon(
                                                      Icons.movie_outlined)),
                                      title: Text(movie.name),
                                      subtitle: movie.releaseDate == null
                                          ? null
                                          : Text(movie.releaseDate!
                                              .split('-')
                                              .first),
                                      trailing: const Icon(Icons.chevron_right),
                                      onTap: () =>
                                          Navigator.pop(context, movie));
                                })),
          ]),
        ),
      );
}
