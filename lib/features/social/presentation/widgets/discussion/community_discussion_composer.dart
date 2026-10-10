import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import '../../../data/community_space_service.dart';
import '../community_mention_suggestions.dart';

class CommunityDiscussionComposer extends StatefulWidget {
  const CommunityDiscussionComposer(
      {super.key, required this.communityId, required this.service});
  final int communityId;
  final CommunitySpaceService service;
  @override
  State<CommunityDiscussionComposer> createState() =>
      _CommunityDiscussionComposerState();
}

class _CommunityDiscussionComposerState
    extends State<CommunityDiscussionComposer> {
  final _form = GlobalKey<FormState>();
  final Map<String, String> _mentions = {};
  final _title = TextEditingController(),
      _body = TextEditingController(),
      _query = TextEditingController(),
      _season = TextEditingController(),
      _episode = TextEditingController();
  List<Map<String, dynamic>> _titles = [];
  Map<String, dynamic>? _selected;
  String _spoiler = 'none';
  String? _error, _searchError;
  bool _sending = false, _searching = false;
  int _searchRevision = 0;
  @override
  void dispose() {
    for (final c in [_title, _body, _query, _season, _episode]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _search() async {
    final q = _query.text.trim();
    if (q.length < 2) {
      setState(() => _searchError = 'Type at least two characters.');
      return;
    }
    final revision = ++_searchRevision;
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final page =
          await widget.service.get(widget.communityId, '/titles', {'q': q});
      if (mounted && revision == _searchRevision) {
        setState(() => _titles = (page['items'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
    } catch (_) {
      if (mounted && revision == _searchRevision) {
        setState(() => _searchError = 'Couldn’t search titles. Try again.');
      }
    } finally {
      if (mounted && revision == _searchRevision) {
        setState(() => _searching = false);
      }
    }
  }

  Future<void> _publish() async {
    if (_sending || !_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.service.post(widget.communityId, '/discussions', {
        'title': _title.text.trim(),
        'body': _body.text.trim(),
        'spoiler': _spoiler,
        'mentionIds':
            activeCommunityMentions(_mentions, '${_title.text} ${_body.text}'),
        if (_selected != null)
          (_selected!['kind'] == 'show' ? 'showId' : 'movieId'):
              _selected!['id'],
        if (_spoiler == 'episode') 'season': int.parse(_season.text),
        if (_spoiler == 'episode') 'episode': int.parse(_episode.text)
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t publish. Your draft is kept. Check the selected title, episode and membership, then try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _required(String? value, int min) =>
      value == null || value.trim().length < min
          ? 'Enter at least $min characters.'
          : null;
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_sending,
      child: Scaffold(
          backgroundColor: context.colors.background,
          appBar: AppBar(
              leading: const FlixieBackButton(),
              title: const Text('Start a discussion')),
          body: SafeArea(
              child: Form(
                  key: _form,
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    const Text(
                        'Published discussions are visible to people browsing this community. Keep the title spoiler-free; label any spoilers in the post.'),
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _title,
                        enabled: !_sending,
                        maxLength: 180,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            labelText: 'What would you like to talk about?'),
                        validator: (v) => _required(v, 3)),
                    CommunityMentionSuggestions(
                        controller: _title,
                        additionalController: _body,
                        communityId: widget.communityId,
                        service: widget.service,
                        selected: _mentions),
                    const SizedBox(height: 12),
                    Text('About a title (optional)',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (_selected == null) ...[
                      TextField(
                          controller: _query,
                          enabled: !_sending,
                          decoration: const InputDecoration(
                              labelText: 'Search films or series'),
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search()),
                      TextButton(
                          onPressed: _searching || _sending ? null : _search,
                          child: Text(
                              _searching ? 'Searching…' : 'Search titles')),
                      if (_searchError != null) Text(_searchError!),
                      if (_titles.isEmpty &&
                          _query.text.length >= 2 &&
                          !_searching &&
                          _searchError == null)
                        const Text(
                            'No matching titles loaded. Try another search or start a general question.'),
                      for (final t in _titles)
                        ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(t['title']),
                            subtitle:
                                Text(t['kind'] == 'show' ? 'Series' : 'Film'),
                            onTap: _sending
                                ? null
                                : () => setState(() {
                                      _selected = t;
                                      _titles = [];
                                    })),
                    ] else
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_selected!['title']),
                          subtitle: const Text('Selected title'),
                          trailing: IconButton(
                              tooltip: 'Remove title',
                              onPressed: _sending
                                  ? null
                                  : () => setState(() {
                                        _selected = null;
                                        _spoiler = 'none';
                                      }),
                              icon: const Icon(Icons.close))),
                    if (_selected != null)
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        itemHeight: null,
                        initialValue: _spoiler,
                        decoration: const InputDecoration(
                            labelText: 'Spoiler boundary'),
                        items: [
                          const DropdownMenuItem(
                              value: 'none', child: Text('Spoiler-free')),
                          const DropdownMenuItem(
                              value: 'full',
                              child: Text('Full-title spoilers')),
                          if (_selected!['kind'] == 'show')
                            const DropdownMenuItem(
                                value: 'episode',
                                child: Text('Through an episode'))
                        ],
                        onChanged: _sending
                            ? null
                            : (v) => setState(() => _spoiler = v!),
                      ),
                    if (_spoiler == 'episode') ...[
                      TextFormField(
                          controller: _season,
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Season number'),
                          validator: (v) =>
                              int.tryParse(v ?? '') == null || int.parse(v!) < 0
                                  ? 'Enter a valid season.'
                                  : null),
                      TextFormField(
                          controller: _episode,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Episode number'),
                          validator: (v) =>
                              int.tryParse(v ?? '') == null || int.parse(v!) < 1
                                  ? 'Enter a valid episode.'
                                  : null),
                    ],
                    const SizedBox(height: 20),
                    TextFormField(
                        controller: _body,
                        enabled: !_sending,
                        minLines: 5,
                        maxLines: 12,
                        maxLength: 5000,
                        decoration:
                            const InputDecoration(labelText: 'Your post'),
                        validator: (v) => _required(v, 1)),
                    CommunityMentionSuggestions(
                        controller: _body,
                        additionalController: _title,
                        communityId: widget.communityId,
                        service: widget.service,
                        selected: _mentions),
                    const Text(
                        'Type @ to mention a friend who joined this community.',
                        style: TextStyle(fontSize: 12)),
                    if (_error != null)
                      Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(_error!)),
                    FilledButton(
                        onPressed: _sending ? null : _publish,
                        child: Text(
                            _sending ? 'Publishing…' : 'Publish discussion')),
                  ])))));
}
