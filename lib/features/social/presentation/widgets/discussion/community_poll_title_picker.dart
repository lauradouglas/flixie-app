import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import '../../../data/community_space_service.dart';

Future<Map<String, dynamic>?> pickCommunityPollTitle(BuildContext context,
        {required int communityId,
        required CommunitySpaceService service,
        Set<String> excluded = const {}}) =>
    showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        useRootNavigator: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (_) => FractionallySizedBox(
            heightFactor: .85,
            child: CommunityPollTitlePicker(
                communityId: communityId,
                service: service,
                excluded: excluded)));

String pollMediaKey(Map<String, dynamic> title) =>
    '${title['kind']}:${title['mediaId'] ?? title['id']}';
Map<String, dynamic> pollMediaInput(Map<String, dynamic> title) => {
      title['kind'] == 'show' ? 'showId' : 'movieId':
          title['mediaId'] ?? title['id']
    };

class CommunityPollTitlePicker extends StatefulWidget {
  const CommunityPollTitlePicker(
      {super.key,
      required this.communityId,
      required this.service,
      this.excluded = const {}});
  final int communityId;
  final CommunitySpaceService service;
  final Set<String> excluded;
  @override
  State<CommunityPollTitlePicker> createState() =>
      _CommunityPollTitlePickerState();
}

class _CommunityPollTitlePickerState extends State<CommunityPollTitlePicker> {
  final _query = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _busy = false, _searched = false;
  String? _error;
  int _revision = 0;
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    final revision = ++_revision;
    if (q.length < 2) {
      setState(() {
        _error = 'Type at least two characters.';
        _busy = false;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _items = [];
    });
    try {
      final result =
          await widget.service.get(widget.communityId, '/titles', {'q': q});
      if (mounted && revision == _revision) {
        setState(() {
          _searched = true;
          _items = (result['items'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        });
      }
    } catch (_) {
      if (mounted && revision == _revision) {
        setState(() => _error = 'Couldn’t search. Try again.');
      }
    } finally {
      if (mounted && revision == _revision) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: ListView(children: [
        Row(children: [
          Expanded(
              child: Text('Add a title',
                  style: Theme.of(context).textTheme.headlineSmall)),
          IconButton(
              tooltip: 'Close title search',
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close))
        ]),
        const Text(
            'Choose a film or series from this community. Every option links to a real title.'),
        const SizedBox(height: 16),
        TextField(
            controller: _query,
            autofocus: true,
            decoration:
                const InputDecoration(labelText: 'Search films or series'),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search()),
        TextButton(
            onPressed: _busy ? null : _search,
            child: Text(_busy ? 'Searching…' : 'Search titles')),
        if (_error != null)
          Text(_error!, style: TextStyle(color: context.colors.danger)),
        if (_searched && _items.isEmpty && !_busy && _error == null)
          const Text(
              'No matching titles in this community yet. Try another search.'),
        for (final title in _items)
          ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title['title']),
              subtitle: Text(title['kind'] == 'show' ? 'Series' : 'Film'),
              trailing: widget.excluded.contains(pollMediaKey(title))
                  ? const Text('Already added')
                  : const Icon(Icons.add),
              onTap: widget.excluded.contains(pollMediaKey(title))
                  ? null
                  : () => Navigator.pop(context, title))
      ]));
}
