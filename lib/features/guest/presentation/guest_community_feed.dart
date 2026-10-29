import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';
import 'guest_access.dart';

/// Public browsing uses a separate endpoint with no account-specific data.
class GuestCommunityFeed extends StatefulWidget {
  const GuestCommunityFeed({super.key, this.preview = false});
  final bool preview;
  @override
  State<GuestCommunityFeed> createState() => GuestCommunityFeedState();
}

class GuestCommunityFeedState extends State<GuestCommunityFeed> {
  final _items = <ActivityListItem>[];
  String? _cursor, _error;
  bool _loading = true, _more = false;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() => _load();
  Future<void> _load({bool more = false}) async {
    if (more && (_loading || _more || _cursor == null)) return;
    final generation = more ? _generation : ++_generation;
    setState(() {
      _error = null;
      if (more) {
        _more = true;
      } else {
        _loading = true;
        _more = false;
      }
    });
    try {
      final data = await ApiClient.get('/guest/community/activity',
          queryParams: {if (more) 'cursor': _cursor!}) as Map;
      if (!mounted || generation != _generation) return;
      final rows = (data['items'] as List)
          .map((r) => ActivityListItem.fromJson(Map<String, dynamic>.from(r)));
      setState(() {
        if (!more) _items.clear();
        final keys = _items.map((r) => '${r.type.value}:${r.id}').toSet();
        _items.addAll(rows.where((r) => keys.add('${r.type.value}:${r.id}')));
        _cursor = data['nextCursor'] as String?;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() => _error = 'Couldn’t load Around Flixie.');
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() {
          _loading = false;
          _more = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content =
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (widget.preview)
        Row(children: [
          Expanded(
              child: Text('Around Flixie',
                  style: Theme.of(context).textTheme.titleLarge)),
          TextButton(
              onPressed: () => context.push('/around-flixie'),
              child: const Text('See all')),
        ]),
      if (_loading && _items.isEmpty)
        const Padding(
            padding: EdgeInsets.all(24), child: LinearProgressIndicator()),
      if (_error != null) ...[
        Text(_error!),
        TextButton(
            onPressed: () => _load(more: _items.isNotEmpty),
            child: const Text('Try again'))
      ],
      if (!_loading && _error == null && _items.isEmpty)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('Public ratings, reviews and lists will appear here.')),
    ]);
    if (widget.preview) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ...content.children,
        for (final item in _items.take(3)) _activity(item)
      ]);
    }
    final headers = content.children;

    return Scaffold(
        appBar: AppBar(title: const Text('Around Flixie')),
        body: RefreshIndicator(
            onRefresh: refresh,
            child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                itemCount:
                    headers.length + _items.length + (_cursor == null ? 0 : 1),
                itemBuilder: (context, index) {
                  if (index < headers.length) return headers[index];
                  final itemIndex = index - headers.length;
                  if (itemIndex < _items.length) {
                    return _activity(_items[itemIndex]);
                  }
                  return TextButton(
                      onPressed: _more ? null : () => _load(more: true),
                      child: Text(_more ? 'Loading…' : 'Load more'));
                })));
  }

  Widget _activity(ActivityListItem item) => ActivityTile(
      key: ValueKey('guest:${item.type.value}:${item.id}'),
      item: item,
      feedStyle: true,
      community: true,
      detailSource: DetailSource.communityActivity,
      onDiscussion: () => GuestAccess.require(context,
          title: 'Join the conversation',
          message:
              'Create an account to read and write comments, and connect with film people.',
          path:
              '/community/posts/${item.userId}/${item.type.value}/${item.id}'));
}
