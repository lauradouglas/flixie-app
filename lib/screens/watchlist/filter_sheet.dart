import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WatchlistFilterSheet extends StatefulWidget {
  const WatchlistFilterSheet({
    super.key,
    required this.genres,
    required this.years,
    required this.currentGenre,
    required this.currentMinRating,
    required this.currentYear,
    required this.currentMaxRuntime,
    required this.currentSort,
    required this.onApply,
  });

  final List<String> genres;
  final List<int> years;
  final String? currentGenre;
  final double? currentMinRating;
  final int? currentYear;
  final int? currentMaxRuntime;
  final String currentSort;
  final void Function(String? genre, double? minRating, int? year,
      int? maxRuntime, String sort) onApply;

  @override
  State<WatchlistFilterSheet> createState() => _WatchlistFilterSheetState();
}

class _WatchlistFilterSheetState extends State<WatchlistFilterSheet> {
  late String _sort;
  String? _genre;
  double? _minRating;
  int? _year;
  int? _maxRuntime;

  static const _runtimeOptions = [
    (null, 'Any'),
    (90, '< 1h 30m'),
    (120, '< 2h'),
    (150, '< 2h 30m'),
  ];

  static const _sortOptions = [
    ('recent', 'Recently Added'),
    ('titleAsc', 'Title A\u2013Z'),
    ('titleDesc', 'Title Z\u2013A'),
    ('ratingDesc', 'Highest Rated'),
    ('yearDesc', 'Newest First'),
    ('yearAsc', 'Oldest First'),
  ];

  static const _ratingOptions = [
    (null, 'Any'),
    (5.0, '5+'),
    (6.0, '6+'),
    (7.0, '7+'),
    (8.0, '8+'),
  ];

  @override
  void initState() {
    super.initState();
    _sort = widget.currentSort;
    _genre = widget.currentGenre;
    _minRating = widget.currentMinRating;
    _year = widget.currentYear;
    _maxRuntime = widget.currentMaxRuntime;
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      decoration: const BoxDecoration(
        color: Color(0xFF1B3258),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: FlixieColors.medium,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Sort & Filter',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => setState(() {
                      _sort = 'recent';
                      _genre = null;
                      _minRating = null;
                      _year = null;
                      _maxRuntime = null;
                    }),
                    child: const Text('Reset',
                        style: TextStyle(color: FlixieColors.primary)),
                  ),
                ],
              ),

              // Sort
              _sectionLabel('Sort By'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _sortOptions.map((opt) {
                  final selected = _sort == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _sort = opt.$1),
                    selectedColor: FlixieColors.primary,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey,
                        fontSize: 13),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              // Runtime
              _sectionLabel('Max Runtime'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _runtimeOptions.map((opt) {
                  final selected = _maxRuntime == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _maxRuntime = opt.$1),
                    selectedColor: FlixieColors.primary,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey,
                        fontSize: 13),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              // Min Rating
              _sectionLabel('Minimum Rating'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _ratingOptions.map((opt) {
                  final selected = _minRating == opt.$1;
                  return ChoiceChip(
                    label: Text(opt.$2),
                    selected: selected,
                    onSelected: (_) => setState(() => _minRating = opt.$1),
                    selectedColor: FlixieColors.primary,
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.grey,
                        fontSize: 13),
                    side: BorderSide.none,
                  );
                }).toList(),
              ),

              // Genre
              if (widget.genres.isNotEmpty) ...[
                _sectionLabel('Genre'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _genre == null,
                      onSelected: (_) => setState(() => _genre = null),
                      selectedColor: FlixieColors.primary,
                      backgroundColor: FlixieColors.tabBarBackgroundFocused,
                      labelStyle: TextStyle(
                          color: _genre == null ? Colors.white : Colors.grey,
                          fontSize: 13),
                      side: BorderSide.none,
                    ),
                    ...widget.genres.map((g) {
                      final selected = _genre == g;
                      return ChoiceChip(
                        label: Text(g),
                        selected: selected,
                        onSelected: (_) => setState(() => _genre = g),
                        selectedColor: FlixieColors.primary,
                        backgroundColor: FlixieColors.tabBarBackgroundFocused,
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.grey,
                            fontSize: 13),
                        side: BorderSide.none,
                      );
                    }),
                  ],
                ),
              ],

              // Release Year
              if (widget.years.isNotEmpty) ...[
                _sectionLabel('Release Year'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _year == null,
                      onSelected: (_) => setState(() => _year = null),
                      selectedColor: FlixieColors.primary,
                      backgroundColor: FlixieColors.tabBarBackgroundFocused,
                      labelStyle: TextStyle(
                          color: _year == null ? Colors.white : Colors.grey,
                          fontSize: 13),
                      side: BorderSide.none,
                    ),
                    ...widget.years.map((y) {
                      final selected = _year == y;
                      return ChoiceChip(
                        label: Text('$y'),
                        selected: selected,
                        onSelected: (_) => setState(() => _year = y),
                        selectedColor: FlixieColors.primary,
                        backgroundColor: FlixieColors.tabBarBackgroundFocused,
                        labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.grey,
                            fontSize: 13),
                        side: BorderSide.none,
                      );
                    }),
                  ],
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onApply(
                        _genre, _minRating, _year, _maxRuntime, _sort);
                  },
                  style: FilledButton.styleFrom(
                      backgroundColor: FlixieColors.primary),
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
