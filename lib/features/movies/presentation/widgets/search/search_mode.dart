import 'package:flutter/material.dart';

enum SearchMode { all, movies, shows, people, companies, collections }

extension SearchModeView on SearchMode {
  String get label => switch (this) {
        SearchMode.all => 'All',
        SearchMode.movies => 'Movies',
        SearchMode.shows => 'Shows',
        SearchMode.people => 'People',
        SearchMode.companies => 'Studios',
        SearchMode.collections => 'Collections',
      };

  String get hintText => switch (this) {
        SearchMode.all => 'Search movies, shows or people...',
        SearchMode.movies => 'Search movies...',
        SearchMode.shows => 'Search shows...',
        SearchMode.people => 'Search people...',
        SearchMode.companies => 'Search production companies...',
        SearchMode.collections => 'Search collections...',
      };

  IconData get icon => switch (this) {
        SearchMode.all => Icons.search_rounded,
        SearchMode.movies => Icons.movie_filter_rounded,
        SearchMode.shows => Icons.live_tv_rounded,
        SearchMode.people => Icons.person_outline_rounded,
        SearchMode.companies => Icons.business_outlined,
        SearchMode.collections => Icons.folder_special_outlined,
      };
}
