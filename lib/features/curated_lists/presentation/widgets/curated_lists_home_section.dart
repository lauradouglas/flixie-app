import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../../data/curated_lists_service.dart';
import '../../models/curated_list.dart';
import 'curated_list_views.dart';

class CuratedListsHomeSection extends StatefulWidget {
  const CuratedListsHomeSection(
      {super.key,
      this.service = const CuratedListsService(),
      this.horizontalPadding = 16,
      this.leadingSpacing = 0,
      this.includeOuterSpacing = true});
  final double leadingSpacing;
  final CuratedListsService service;
  final double horizontalPadding;

  /// Disable when the parent owns the gaps between Home sections.
  final bool includeOuterSpacing;
  @override
  State<CuratedListsHomeSection> createState() =>
      CuratedListsHomeSectionState();
}

class CuratedListsHomeSectionState extends State<CuratedListsHomeSection> {
  List<CuratedList> _lists = [];
  Map<String, CuratedProgress> _progress = {};
  bool _started = false, _loading = true;
  String? _error, _owner;
  AuthProvider? _auth;
  int _activity = -1, _generation = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider?>();
    _auth = auth;
    final owner = auth?.dbUser?.id, activity = auth?.activityVersion ?? 0;
    if (!_started || _owner != owner || _activity != activity) {
      _started = true;
      _owner = owner;
      _activity = activity;
      _progress = {};
      scheduleMicrotask(refresh);
    }
  }

  Future<void> refresh() async {
    if (!mounted) return;
    final generation = ++_generation, owner = _owner;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final lists = (await widget.service.lists(homepage: true))
          .where((list) => list.endsAt == null || now.isBefore(list.endsAt!))
          .take(2).toList();
      // Archive cards support an active promotion; they never create a Home
      // section on their own or accompany an upcoming challenge.
      if (lists.any((list) => list.openAt(now)) && lists.length < 2) {
        for (var page = 1; page <= 1000 && lists.length < 2; page++) {
          List<CuratedList> archive;
          try {
            archive = await widget.service.lists(page: page);
          } catch (_) {
            // Optional history must not hide the promoted challenge.
            break;
          }
          for (final list in archive) {
            if (list.endsAt != null &&
                !now.isBefore(list.endsAt!) &&
                !lists.any((shown) => shown.id == list.id)) {
              lists.add(list);
              if (lists.length == 2) break;
            }
          }
          if (archive.length < 25) break;
        }
      }
      final progress = <String, CuratedProgress>{};
      if (owner != null) {
        await Future.wait(lists.map((list) async {
          try {
            progress[list.id] = await widget.service.progress(list.id);
          } catch (_) {
            /* Public list remains available if private progress cannot load. */
          }
        }));
      }
      if (!mounted || generation != _generation || owner != _auth?.dbUser?.id) {
        return;
      }
      setState(() {
        _lists = lists;
        _progress = progress;
        _error = null;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Couldn’t load Watch challenges.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _open(String path) async {
    await context.push(path);
    if (mounted) await refresh();
  }

  @override
  Widget build(BuildContext context) {
    if (_lists.isEmpty) return const SizedBox.shrink();
    return Padding(
        padding: EdgeInsets.fromLTRB(
            widget.horizontalPadding,
            widget.leadingSpacing + (widget.includeOuterSpacing ? 4 : 0),
            widget.horizontalPadding,
            widget.includeOuterSpacing ? 16 : 0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
                child: Text('Watch challenges',
                    style: Theme.of(context).textTheme.titleLarge)),
            TextButton(
                onPressed: () => _open('/flixie-lists'),
                child: const Text('See all'))
          ]),
          if (_loading && _lists.isEmpty) const LinearProgressIndicator(),
          if (_error != null)
            Row(children: [
              Expanded(child: Text(_error!)),
              TextButton(onPressed: refresh, child: const Text('Retry'))
            ]),
          const SizedBox(height: 4),
          for (final list in _lists)
            Padding(
                padding: EdgeInsets.only(
                    bottom: !widget.includeOuterSpacing && list == _lists.last
                        ? 0
                        : 12),
                child: CuratedListCard(
                    list: list,
                    progress: _progress[list.id],
                    onTap: () => _open('/flixie-lists/${list.id}'))),
          if (!_loading && _error == null && _lists.isEmpty)
            TextButton(
                onPressed: () => _open('/flixie-lists'),
                child: const Text('Explore collections picked by Flixie')),
        ]));
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }
}
