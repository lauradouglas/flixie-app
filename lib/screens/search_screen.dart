import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              autofocus: false,
              decoration: const InputDecoration(
                hintText: 'Search movies, shows…',
                prefixIcon: Icon(Icons.search),
                suffixIcon: null,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          if (_query.isEmpty)
            Expanded(
              child: _GenreGrid(),
            )
          else
            Expanded(
              child: _SearchResults(query: _query),
            ),
        ],
      ),
    );
  }
}

class _GenreGrid extends StatelessWidget {
  final List<Map<String, dynamic>> _genres = const [
    {'label': 'Action', 'color': FlixieColors.primary},
    {'label': 'Comedy', 'color': FlixieColors.secondary},
    {'label': 'Drama', 'color': FlixieColors.tertiary},
    {'label': 'Horror', 'color': FlixieColors.danger},
    {'label': 'Sci-Fi', 'color': FlixieColors.dark},
    {'label': 'Romance', 'color': FlixieColors.warning},
    {'label': 'Thriller', 'color': FlixieColors.primaryShade},
    {'label': 'Animation', 'color': FlixieColors.success},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Browse by Genre',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.5,
              ),
              itemCount: _genres.length,
              itemBuilder: (context, index) {
                final genre = _genres[index];
                return Card(
                  color: (genre['color'] as Color).withValues(alpha: 0.3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {},
                    child: Center(
                      child: Text(
                        genre['label'] as String,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: genre['color'] as Color,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 8,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return Card(
          child: ListTile(
            leading: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: FlixieColors.secondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.movie, color: FlixieColors.secondary),
            ),
            title: Text('Result for "$query" #${index + 1}'),
            subtitle: const Text('Genre • Year'),
            onTap: () {},
          ),
        );
      },
    );
  }
}
