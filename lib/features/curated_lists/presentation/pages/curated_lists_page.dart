import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../data/curated_lists_service.dart';
import '../../models/curated_list.dart';
import '../widgets/curated_list_views.dart';

class CuratedListsPage extends StatefulWidget {
  const CuratedListsPage(
      {super.key, this.service = const CuratedListsService()});
  final CuratedListsService service;
  @override
  State<CuratedListsPage> createState() => _CuratedListsPageState();
}

class _CuratedListsPageState extends State<CuratedListsPage> {
  final List<CuratedList> _items = [];
  int _page = 1;
  bool _loading = false, _more = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = reset ? 1 : _page;
      final items = await widget.service.lists(page: page);
      if (!mounted) return;
      setState(() {
        if (reset) _items.clear();
        _items.addAll(items);
        _page = page + 1;
        _more = items.length == 25;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t load lists. Please retry.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(title: const Text('Watch challenges')),
      body: RefreshIndicator(
          onRefresh: () => _load(reset: true),
          child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                    child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                  'Collections picked by Flixie. Find a few films and make them part of your diary.'),
                              const SizedBox(height: 20),
                              for (final list in _items)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: CuratedListCard(
                                        list: list,
                                        onTap: () => context
                                            .push('/flixie-lists/${list.id}'))),
                              if (_loading)
                                const Center(
                                    child: CircularProgressIndicator()),
                              if (_error != null) ...[
                                Text(_error!),
                                TextButton(
                                    onPressed: () =>
                                        _load(reset: _items.isEmpty),
                                    child: const Text('Retry'))
                              ],
                              if (!_loading && _error == null && _items.isEmpty)
                                const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Text(
                                        'No collections just yet. Seasonal picks will appear here.')),
                              if (!_loading && _more && _items.isNotEmpty)
                                TextButton(
                                    onPressed: _load,
                                    child: const Text('Load more')),
                            ])))
              ])));
}
