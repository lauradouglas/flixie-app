import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/models/search_result.dart';
import '../../controllers/search_controller.dart';
import 'search_entity_tile.dart';
import 'search_media_tile.dart';
import 'search_person_tile.dart';
import 'search_content.dart';

class SearchResultsView extends StatelessWidget {
  const SearchResultsView({
    super.key,
    required this.state,
    required this.onResult,
    required this.onEntity,
  });
  final SearchScreenController state;
  final ValueChanged<SearchResultItem> onResult;
  final ValueChanged<SearchEntityResult> onEntity;
  @override
  Widget build(BuildContext context) =>
      FlixieRefresh(onRefresh: state.refresh, child: _content(context));

  Widget _content(BuildContext context) {
    if (state.isSearching) {
      return const ContentListSkeleton(label: 'Loading search results');
    }

    if (state.searchFailed &&
        state.results == null &&
        state.entityResults == null) {
      return searchRetryMessage('Couldn’t load search results.', state.retry);
    }
    final results = state.results?.results ?? [];
    final entityResults = state.entityResults?.results ?? [];
    final hasSearchResponse =
        state.results != null || state.entityResults != null;

    if (hasSearchResponse && results.isEmpty && entityResults.isEmpty) {
      return CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: context.colors.medium),
                const SizedBox(height: 16),
                Text('No results for "${state.query}"',
                    style: Theme.of(context).textTheme.bodyLarge),
              ],
            ),
          ),
        ),
      ]);
    }

    if (results.isEmpty && entityResults.isEmpty) {
      return const SizedBox.shrink();
    }

    if (entityResults.isNotEmpty) {
      return ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entityResults.length + (state.searchFailed ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == entityResults.length) {
            return searchRetryMessage('Couldn’t refresh results.', state.retry);
          }
          final item = entityResults[index];
          return SearchEntityTile(result: item, onTap: () => onEntity(item));
        },
      );
    }

    final total = state.results?.totalResults ?? results.length;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      itemCount: results.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: SearchSummary(query: state.query.trim(), total: total),
          );
        }
        if (index == results.length + 1) {
          if (state.searchFailed) {
            return searchRetryMessage(
              state.failedRefresh
                  ? 'Couldn’t refresh results.'
                  : 'Couldn’t load more results.',
              state.retry,
            );
          }
          if ((state.results?.page ?? 0) >= (state.results?.totalPages ?? 0)) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: state.loadingMore
                ? const Center(child: CircularProgressIndicator())
                : TextButton(
                    onPressed: state.loadMore,
                    child: const Text('Load more'),
                  ),
          );
        }
        final item = results[index - 1];
        if (item.isPerson && item.person != null) {
          return SearchPersonTile(
            person: item.person!,
            query: state.query.trim(),
            onTap: () => onResult(item),
          );
        }
        if (item.isShow && item.show != null) {
          return SearchMediaTile.show(
            show: item.show!,
            query: state.query.trim(),
            onTap: () => onResult(item),
          );
        }
        if (item.movie != null) {
          return SearchMediaTile.movie(
            movie: item.movie!,
            query: state.query.trim(),
            onTap: () => onResult(item),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
