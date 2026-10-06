import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_refresh.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../data/genre_community_service.dart';
import '../widgets/community_identity.dart';

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
  final Set<int> _retained = {};
  final Map<int, bool> _undo = {}, _failed = {};
  final _searchController = TextEditingController();
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filter(bool joined) => setState(() {
        _joinedOnly = joined;
        _retained.clear();
        _undo.clear();
      });
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

  Future<void> _confirm(GenreCommunity community) async {
    final confirmed = await showFlixiePromptSheet<bool>(
        context: context,
        builder: (context) => FlixiePromptSheetContent(
              title: Text(
                  '${community.joined ? 'Leave' : 'Join'} ${community.name}?'),
              content: Text(community.joined
                  ? 'Your contributions disappear from this community. Your original reviews stay intact.'
                  : 'Your public reviews can appear here. Private reviews stay private, and joining does not follow anyone or turn on public sharing.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(community.joined
                        ? 'Leave community'
                        : 'Join community'))
              ],
            ));
    if (confirmed == true && mounted) await _join(community, !community.joined);
  }

  Future<void> _join(GenreCommunity community, bool target) async {
    if (_busy.contains(community.id)) return;
    _generation++;
    setState(() {
      _busy.add(community.id);
      _failed.remove(community.id);
    });
    try {
      await widget.service.setJoined(community.id, target);
      if (mounted) {
        setState(() {
          _items = _items
              .map((g) => g.id == community.id ? g.withJoined(target) : g)
              .toList();
          _undo[community.id] = !target;
          if (!target && _joinedOnly) _retained.add(community.id);
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed[community.id] = target);
    } finally {
      if (mounted) setState(() => _busy.remove(community.id));
    }
  }

  Widget _row(GenreCommunity g) {
    final busy = _busy.contains(g.id);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 220);
    final button = AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
            color: g.joined ? const Color(0xFF203E38) : Colors.transparent,
            borderRadius: BorderRadius.circular(11)),
        child: OutlinedButton(
            onPressed: busy ? null : () => _confirm(g),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size(94, 44),
                foregroundColor:
                    g.joined ? const Color(0xFFA3ECDF) : context.colors.white,
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                elevation: 0,
                side: BorderSide(
                    color: g.joined
                        ? const Color(0xFF37645A)
                        : const Color(0xFF8266AC),
                    width: 1),
                textStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11))),
            child: AnimatedSwitcher(
                duration: duration,
                child: Text(
                    busy
                        ? 'Saving…'
                        : g.joined
                            ? '✓ Joined'
                            : 'Join',
                    key: ValueKey('$busy:${g.joined}')))));
    final title = InkWell(
        onTap: () async {
          await context.push('/genre-communities/${g.id}');
          if (mounted) await _load();
        },
        child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              CommunityIcon(id: g.id, size: 34),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(g.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
            ])));
    return Padding(
        key: ValueKey('community:${g.id}'),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 20),
          LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(15) > 22
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                          title,
                          Align(alignment: Alignment.centerRight, child: button)
                        ])
                  : Row(children: [
                      Expanded(child: title),
                      const SizedBox(width: 12),
                      button
                    ])),
          Padding(
              padding: const EdgeInsets.only(left: 46, top: 8),
              child: Text(CommunityIdentity.forId(g.id).blurb,
                  style: TextStyle(
                      fontSize: 13, height: 1.5, color: context.colors.light))),
          if (_failed.containsKey(g.id) || _undo.containsKey(g.id))
            Semantics(
                liveRegion: true,
                child: Padding(
                    padding: const EdgeInsets.only(left: 46),
                    child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          Text(
                              _failed.containsKey(g.id)
                                  ? 'Couldn’t save. Membership unchanged.'
                                  : g.joined
                                      ? 'You’re in. Welcome!'
                                      : 'You left ${g.name}.',
                              style: TextStyle(
                                  fontSize: 12, color: context.colors.light)),
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      _join(g, _failed[g.id] ?? _undo[g.id]!),
                              child: Text(_failed.containsKey(g.id)
                                  ? 'Retry'
                                  : 'Undo')),
                        ]))),
          const SizedBox(height: 20),
          Divider(
              height: 1,
              thickness: .5,
              color: context.colors.medium.withValues(alpha: .3)),
        ]));
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where((g) =>
            (!_joinedOnly || g.joined || _retained.contains(g.id)) &&
            g.name.toLowerCase().contains(_search.toLowerCase()))
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return FlixieRefresh(
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
                      Text('Find your film people.',
                          style: TextStyle(
                              color: context.colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                          'Big opinions. Shared obsessions. A little corner for every kind of fan.',
                          style: TextStyle(color: context.colors.medium)),
                      const SizedBox(height: 12),
                      TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _search = value),
                          decoration: const InputDecoration(
                              hintText: 'Search communities',
                              prefixIcon: Icon(Icons.search))),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        FlixiePill.choice(
                            label: const Text('Explore all'),
                            showCheckmark: false,
                            selected: !_joinedOnly,
                            onSelected: (_) => _filter(false)),
                        FlixiePill.choice(
                            label: Text(
                                'Your communities · ${_items.where((g) => g.joined).length}'),
                            showCheckmark: false,
                            selected: _joinedOnly,
                            onSelected: (_) => _filter(true))
                      ]),
                      const SizedBox(height: 18),
                      Text(
                          _joinedOnly
                              ? 'Your kind of people'
                              : 'Find your next conversation',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text('${visible.length} communities',
                          style: TextStyle(
                              fontSize: 12, color: context.colors.light)),
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
                      child: Column(children: [
                        Text(_search.isNotEmpty
                            ? 'No communities match your search.'
                            : 'Your people are out there. Explore all communities to find yours.'),
                        TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _search = '';
                              _filter(false);
                            },
                            child: Text(_search.isNotEmpty
                                ? 'Clear search'
                                : 'Explore communities'))
                      ])))
            else
              SliverList.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) => _row(visible[index])),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ));
  }
}
