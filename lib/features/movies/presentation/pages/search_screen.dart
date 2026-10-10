import 'package:flixie_app/features/guest/presentation/guest_access.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'package:flixie_app/features/collections/collection_screen.dart';
import 'package:flixie_app/models/search_result.dart';
import '../controllers/search_controller.dart';
import '../widgets/search/search_controls.dart';
import '../widgets/search/search_default_view.dart';
import '../widgets/search/search_results_view.dart';
import '../widgets/search/search_mode.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.focusSearch = false,
    this.onFocusHandled,
  });
  final bool focusSearch;
  final VoidCallback? onFocusHandled;
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  late final SearchScreenController _search;
  @override
  void initState() {
    super.initState();
    _search = SearchScreenController(
      cachedTrending: context.read<AuthProvider>().cachedTrending,
    );
    if (widget.focusSearch) _focusSearch();
  }

  @override
  void didUpdateWidget(covariant SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusSearch && !oldWidget.focusSearch) _focusSearch();
  }

  void _focusSearch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
      _focus.requestFocus();
      widget.onFocusHandled?.call();
    });
  }

  void _openResult(SearchResultItem item) {
    _search.saveHistory(_search.query);
    if (item.person != null) {
      context.push(
        personDetailPath(item.person!.id, source: DetailSource.search),
      );
    } else if (item.show != null) {
      context.push(
        showDetailPath(item.show!.id, source: DetailSource.search),
        extra: {'title': item.show!.name, 'poster': item.show!.posterPath},
      );
    } else if (item.movie != null) {
      context.push(
        movieDetailPath(item.movie!.id, source: DetailSource.search),
        extra: {'title': item.movie!.name, 'poster': item.movie!.poster},
      );
    }
  }

  void _openEntity(SearchEntityResult item) async {
    if (item.type == SearchEntityType.collection) {
      if (!await GuestAccess.require(context, title: 'Explore your collections', path: '/search')) return;
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CollectionScreen(collectionId: item.id),
        ),
      );
    } else {
      _text.text = item.name;
      _search.changeQuery(item.name);
      _search.setMode(SearchMode.movies);
    }
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          title: Text(
            'Search',
            style: TextStyle(
              color: context.colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: const [_SearchNotificationsButton()],
        ),
        body: ListenableBuilder(
          listenable: _search,
          builder: (_, __) => Column(
            children: [
              SearchQueryField(
                controller: _text,
                focusNode: _focus,
                query: _search.query,
                mode: _search.mode,
                onChanged: _search.changeQuery,
                onSubmitted: _search.submit,
                onClear: () {
                  _text.clear();
                  _search.changeQuery('');
                },
              ),
              SearchModeSelector(
                  value: _search.mode, onChanged: _search.setMode),
              Expanded(
                child: _search.query.trim().isEmpty
                    ? SearchDefaultView(
                        state: _search,
                        onHistory: (query) {
                          _text.text = query;
                          _search.submit(query);
                        },
                      )
                    : SearchResultsView(
                        state: _search,
                        onResult: _openResult,
                        onEntity: _openEntity,
                      ),
              ),
            ],
          ),
        ),
      );
}

class _SearchNotificationsButton extends StatelessWidget {
  const _SearchNotificationsButton();
  @override
  Widget build(BuildContext context) {
    final count = context.select<AuthProvider, int>(
      (auth) => auth.unreadNotificationCount,
    );
    return IconButton(
      onPressed: () => context.push('/notifications'),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count < 100 ? '$count' : '99+'),
        backgroundColor: FlixieColors.notificationBadge,
        textColor: FlixieColors.onNotificationBadge,
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        child: Icon(Icons.notifications_outlined, color: context.colors.white),
      ),
    );
  }
}
