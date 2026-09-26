import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../data/genre_community_service.dart';

class GenreCommunitiesView extends StatefulWidget {
  const GenreCommunitiesView(
      {super.key, this.service = const GenreCommunityService()});
  final GenreCommunityService service;
  @override
  State<GenreCommunitiesView> createState() => _GenreCommunitiesViewState();
}

class _GenreCommunitiesViewState extends State<GenreCommunitiesView> {
  List<GenreCommunity> _items = [];
  final Set<int> _busy = {};
  String _search = '';
  bool _loading = true, _joinedOnly = false;
  String? _error;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (_busy.isNotEmpty) return;
    final generation = ++_generation;
    try {
      final items = await widget.service.list();
      if (mounted && generation == _generation) {
        setState(() {
          _items = items;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Couldn’t load communities. Pull to retry.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _join(GenreCommunity community) async {
    if (_busy.contains(community.id)) return;
    _generation++; // A pending directory read cannot undo this mutation.
    setState(() {
      _busy.add(community.id);
      _error = null;
    });
    try {
      await widget.service.setJoined(community.id, !community.joined);
      if (mounted) {
        setState(() => _items = _items
            .map((g) =>
                g.id == community.id ? g.withJoined(!community.joined) : g)
            .toList());
      }
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Couldn’t change membership. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy.remove(community.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where((g) =>
            (!_joinedOnly || g.joined) &&
            g.name.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.joined != b.joined
          ? (a.joined ? -1 : 1)
          : a.name.compareTo(b.name));
    return RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          key: const PageStorageKey('genre-communities'),
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                sliver: SliverToBoxAdapter(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Find your film people',
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          'Join a community to include your public reviews and discover other members’ opinions.',
                          style: TextStyle(color: context.colors.medium)),
                      const SizedBox(height: 12),
                      TextField(
                          onChanged: (value) => setState(() => _search = value),
                          decoration: const InputDecoration(
                              hintText: 'Search communities',
                              prefixIcon: Icon(Icons.search))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        ChoiceChip(
                            label: const Text('All communities'),
                            selected: !_joinedOnly,
                            onSelected: (_) =>
                                setState(() => _joinedOnly = false)),
                        ChoiceChip(
                            label: const Text('Joined'),
                            selected: _joinedOnly,
                            onSelected: (_) =>
                                setState(() => _joinedOnly = true))
                      ]),
                      if (_error != null)
                        TextButton(onPressed: _load, child: Text(_error!)),
                    ]))),
            if (_loading)
              const SliverToBoxAdapter(
                  child: Center(child: CircularProgressIndicator()))
            else if (visible.isEmpty)
              SliverToBoxAdapter(
                  child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_joinedOnly
                          ? 'No joined communities yet. Browse All communities to find yours.'
                          : 'No communities match your search.')))
            else
              SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final g = visible[index];
                    return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 4),
                          title: Text(g.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(g.joined
                              ? (g.id == -1
                                  ? 'Joined · Films & series'
                                  : 'Joined · Explore reviews')
                              : (g.id == -1
                                  ? 'Films & series · Member reviews'
                                  : 'Explore members’ reviews')),
                          onTap: () async {
                            await context.push('/genre-communities/${g.id}');
                            if (mounted) await _load();
                          },
                          trailing: TextButton(
                              onPressed:
                                  _busy.contains(g.id) ? null : () => _join(g),
                              child: Text(_busy.contains(g.id)
                                  ? 'Saving…'
                                  : g.joined
                                      ? 'Leave'
                                      : 'Join')),
                        ));
                  }),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ));
  }
}
