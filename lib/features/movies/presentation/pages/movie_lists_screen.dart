import '../widgets/movie_lists/movie_list_grid_card.dart';
import '../widgets/movie_lists/movie_list_editor.dart';
import 'package:flixie_app/core/widgets/load_failure_notice.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_lists_controller.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/core/utils/skeleton.dart';

class MovieListsScreen extends StatelessWidget {
  const MovieListsScreen({super.key, this.createOnOpen = false});
  final bool createOnOpen;

  @override
  Widget build(BuildContext context) {
    final userId =
        context.select<AuthProvider, String?>((auth) => auth.dbUser?.id);
    if (userId == null) {
      return const Scaffold(
        body: Center(child: Text('Sign in to manage lists')),
      );
    }
    return ChangeNotifierProvider(
      key: ValueKey(userId),
      create: (_) => MovieListsProvider(
        userId: userId,
      )..loadLists(),
      child: _MovieListsView(createOnOpen: createOnOpen),
    );
  }
}

class _MovieListsView extends StatefulWidget {
  const _MovieListsView({this.createOnOpen = false});
  final bool createOnOpen;

  @override
  State<_MovieListsView> createState() => _MovieListsViewState();
}

enum _ListFilter { all, private, shared }

enum _ListSort { updated, name }

class _MovieListsViewState extends State<_MovieListsView> {
  @override
  void initState() {
    super.initState();
    if (widget.createOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showMovieListEditor(context);
      });
    }
  }

  _ListFilter _filter = _ListFilter.all;
  _ListSort _sort = _ListSort.updated;
  bool _showSearch = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MovieListsProvider>();
    final visibleLists = provider.lists.where((list) {
      final matchesFilter = switch (_filter) {
        _ListFilter.all => true,
        _ListFilter.private => list.visibility == ListVisibility.private &&
            list.scope == ListScope.personal,
        _ListFilter.shared => list.visibility != ListVisibility.private ||
            list.scope != ListScope.personal,
      };
      final query = _query.trim().toLowerCase();
      return matchesFilter &&
          (query.isEmpty || list.name.toLowerCase().contains(query));
    }).toList();
    if (_sort == _ListSort.name) {
      visibleLists
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      visibleLists.sort((a, b) => (b.updatedAt ?? b.createdAt ?? '')
          .compareTo(a.updatedAt ?? a.createdAt ?? ''));
    }

    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(title: Text('Your lists')),
      body: provider.isLoading
          ? const MovieListsScreenSkeleton()
          : provider.error != null && provider.lists.isEmpty
              ? Center(
                  child: SingleChildScrollView(
                      child: LoadFailureNotice(
                          message: 'Couldn’t load your lists.',
                          onRetry: provider.loadLists)))
              : provider.lists.isEmpty
                  ? const _EmptyState(
                      message: 'No lists yet. Create your first one.',
                    )
                  : Column(
                      children: [
                        if (provider.error != null)
                          LoadFailureNotice(
                              message:
                                  'Couldn’t refresh your lists. Your saved lists are still here.',
                              onRetry: provider.loadLists),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  TextButton.icon(
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size(0, 44),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600),
                                    ),
                                    onPressed: () =>
                                        showMovieListEditor(context),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('New list'),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => setState(
                                        () => _showSearch = !_showSearch),
                                    icon: const Icon(Icons.search_rounded),
                                  ),
                                ],
                              ),
                              if (_showSearch) ...[
                                const SizedBox(height: 8),
                                TextField(
                                  autofocus: true,
                                  onChanged: (value) =>
                                      setState(() => _query = value),
                                  decoration: const InputDecoration(
                                    hintText: 'Search lists',
                                    prefixIcon: Icon(Icons.search_rounded),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildFilterControl()),
                                  const SizedBox(width: 10),
                                  PopupMenuButton<_ListSort>(
                                    initialValue: _sort,
                                    onSelected: (value) =>
                                        setState(() => _sort = value),
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(
                                        value: _ListSort.updated,
                                        child: Text('Recently updated'),
                                      ),
                                      PopupMenuItem(
                                        value: _ListSort.name,
                                        child: Text('List name'),
                                      ),
                                    ],
                                    tooltip: 'Sort lists',
                                    icon: const Icon(Icons.sort_rounded,
                                        size: 21),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: visibleLists.isEmpty
                              ? const _EmptyState(
                                  message: 'No lists match these filters.')
                              : ListView.builder(
                                  padding:
                                      const EdgeInsets.fromLTRB(16, 0, 16, 28),
                                  itemCount: visibleLists.length,
                                  itemBuilder: (_, index) => MovieListGridCard(
                                    list: visibleLists[index],
                                    onOpen: () =>
                                        _openList(context, visibleLists[index]),
                                    onMenu: (value) => _handleListMenu(context,
                                        provider, visibleLists[index], value),
                                  ),
                                ),
                        ),
                      ],
                    ),
    );
  }

  Widget _buildFilterControl() => Row(children: [
        for (final filter in _ListFilter.values)
          Expanded(
              child: Semantics(
            selected: _filter == filter,
            child: InkWell(
              onTap: () => setState(() => _filter = filter),
              child: Container(
                constraints: const BoxConstraints(minHeight: 44),
                alignment: Alignment.center,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: _filter == filter
                                ? context.colors.primaryText
                                : context.colors.tabBarBorder,
                            width: _filter == filter ? 2 : 1))),
                child: Text(
                    switch (filter) {
                      _ListFilter.all => 'All',
                      _ListFilter.private => 'Private',
                      _ListFilter.shared => 'Shared'
                    },
                    style: TextStyle(
                        fontSize: 14,
                        color: _filter == filter
                            ? context.colors.textPrimary
                            : context.colors.medium,
                        fontWeight: _filter == filter
                            ? FontWeight.w700
                            : FontWeight.w500)),
              ),
            ),
          )),
      ]);

  void _openList(BuildContext context, MovieList list) => context.push(
        '/movie-lists/${list.id}?name=${Uri.encodeComponent(list.name)}&isOwner=${list.isOwner}&canEdit=${list.canEdit}',
      );

  Future<void> _handleListMenu(BuildContext context,
      MovieListsProvider provider, MovieList list, String value) async {
    if (value == 'edit') {
      await showMovieListEditor(context,
          listId: list.id,
          initialName: list.name,
          initialDescription: list.description,
          initialVisibility: list.visibility,
          initialWhoCanAddMovies: list.whoCanAddMovies,
          initialScope: list.scope,
          initialGroupId: list.groupId,
          initialCollaborators: list.collaborators);
      return;
    }
    final ok = await provider.deleteList(list.id);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: Text(ok
              ? 'List deleted'
              : (provider.error ?? 'Failed to delete list'))));
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.colors.medium),
        ),
      ),
    );
  }
}
