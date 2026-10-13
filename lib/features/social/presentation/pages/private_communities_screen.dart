import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import '../../data/private_community_service.dart';

class PrivateCommunitiesScreen extends StatefulWidget {
  const PrivateCommunitiesScreen(
      {super.key,
      this.service = const PrivateCommunityService(),
      this.inviteKey});
  final PrivateCommunityService service;
  final String? inviteKey;
  @override
  State<PrivateCommunitiesScreen> createState() =>
      _PrivateCommunitiesScreenState();
}

class _PrivateCommunitiesScreenState extends State<PrivateCommunitiesScreen> {
  final _items = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _invitations = [];
  int? _after;
  bool _loading = true;
  bool _canCreate = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
    if (widget.inviteKey != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _invite(widget.inviteKey));
    }
  }

  Future<void> _load({bool more = false}) async {
    setState(() => _loading = true);
    try {
      final data = await widget.service
          .get('/private', {if (more && _after != null) 'after': '$_after'});
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        _items.addAll(
            (data['items'] as List).map((e) => Map<String, dynamic>.from(e)));
        _invitations = (data['invitations'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _after = data['nextAfter'] as int?;
        _canCreate = data['canCreateCommunity'] == true;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Couldn’t load private communities. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (!_canCreate) return;
    final created = await showFlixiePromptSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) => _PrivateCreateForm(service: widget.service));
    if (created != null && mounted) {
      await context.push('/genre-communities/${created['id']}');
      if (mounted) await _load();
    }
  }

  Future<void> _invite([String? key]) async {
    final joined = await showFlixiePromptSheet<Map<String, dynamic>>(
        context: context,
        builder: (ctx) =>
            PrivateInviteForm(service: widget.service, initialKey: key));
    if (joined != null && mounted) {
      await context.push('/genre-communities/${joined['id']}');
      if (mounted) await _load();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            leading: const FlixieBackButton(),
            title: const Text('Private communities')),
        body: SafeArea(
            child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  Text('Your people, by invitation.',
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 8),
                  const Text(
                      'A home for your stream community, a big group of friends or the next movie night. Only members can see inside.'),
                  const SizedBox(height: 20),
                  Wrap(spacing: 12, runSpacing: 8, children: [
                    if (_canCreate)
                      FilledButton.icon(
                          onPressed: _create,
                          icon: const Icon(Icons.add),
                          label: const Text('Create a community')),
                    OutlinedButton.icon(
                        onPressed: () => _invite(),
                        icon: const Icon(Icons.link),
                        label: const Text('Use an invite')),
                  ]),
                  if (_error != null)
                    TextButton(onPressed: _load, child: Text(_error!)),
                  if (_loading) const LinearProgressIndicator(),
                  if (_invitations.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    Text('You’re invited',
                        style: Theme.of(context).textTheme.titleLarge),
                    for (final invitation in _invitations)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(invitation['name']),
                          subtitle: const Text('Private community invitation'),
                          trailing: const Icon(Icons.arrow_forward),
                          onTap: () => _invite(invitation['id'])),
                  ],
                  const SizedBox(height: 28),
                  Text('Your communities',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (!_loading && _items.isEmpty)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(_canCreate
                            ? 'Create a community or accept an invitation to find your people here.'
                            : 'Accept an invitation to find your people here.')),
                  for (final community in _items) ...[
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.lock_outline),
                        title: Text(community['name']),
                        subtitle: Text(community['role'] == 'OWNER'
                            ? 'Private · You own this community'
                            : 'Private · ${community['role'] == 'ADMIN' ? 'Admin' : 'Member'}'),
                        onTap: () async {
                          await context
                              .push('/genre-communities/${community['id']}');
                          if (mounted) await _load();
                        }),
                    const Divider(),
                  ],
                  if (_after != null)
                    TextButton(
                        onPressed: _loading ? null : () => _load(more: true),
                        child: const Text('Load more communities')),
                ]))),
      );
}

class _PrivateCreateForm extends StatefulWidget {
  const _PrivateCreateForm({required this.service});
  final PrivateCommunityService service;
  @override
  State<_PrivateCreateForm> createState() => _PrivateCreateFormState();
}

class _PrivateCreateFormState extends State<_PrivateCreateForm> {
  final _name = TextEditingController(), _description = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final row = await widget.service.post('/private',
          {'name': _name.text.trim(), 'description': _description.text.trim()});
      if (mounted) Navigator.pop(context, row);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t create the community. Your draft is saved here. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Form(
      key: _form,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Create a private community',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            const Text(
                'You’ll be the owner. Invite people and appoint admins to help look after your community.'),
            const SizedBox(height: 20),
            TextFormField(
                controller: _name,
                enabled: !_saving,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Community name'),
                validator: (v) => (v?.trim().length ?? 0) < 3
                    ? 'Use at least 3 characters.'
                    : null),
            TextFormField(
                controller: _description,
                enabled: !_saving,
                maxLength: 500,
                minLines: 2,
                maxLines: 4,
                decoration:
                    const InputDecoration(labelText: 'About your community')),
            const SizedBox(height: 12),
            const Text(
                'Your public reviews and shared ratings can appear here. Joining doesn’t change your sharing settings.'),
            if (_error != null) Text(_error!),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Creating…' : 'Create community')),
          ]));
}

class PrivateInviteForm extends StatefulWidget {
  const PrivateInviteForm({super.key, required this.service, this.initialKey});
  final PrivateCommunityService service;
  final String? initialKey;
  @override
  State<PrivateInviteForm> createState() => _PrivateInviteFormState();
}

class _PrivateInviteFormState extends State<PrivateInviteForm> {
  final _input = TextEditingController();
  Map<String, dynamic>? _preview;
  String? _key, _error;
  bool _busy = false;
  @override
  void initState() {
    super.initState();
    if (widget.initialKey != null) {
      _key = widget.initialKey;
      _previewInvite();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _previewInvite() async {
    if (_busy) return;
    _key ??= privateInviteKey(_input.text);
    if (_key == null) {
      setState(() => _error = 'Paste a Flixie invite link or invite code.');
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await widget.service.get('/invitations/$_key');
      if (mounted) {
        setState(() {
          _preview = result;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _key = null;
          _error =
              'This invitation is unavailable or expired. Ask an admin for a new one.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final result = await widget.service.post('/invitations/$_key/accept', {});
      if (mounted) Navigator.pop(context, result);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Couldn’t join. Ask an admin for a new personal invitation or try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_preview?['name'] ?? 'Use an invitation',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (_preview == null)
              TextField(
                  controller: _input,
                  enabled: !_busy,
                  decoration:
                      const InputDecoration(labelText: 'Invite link or code'),
                  onChanged: (_) => _key = null)
            else ...[
              Text(_preview!['description'] ?? ''),
              const SizedBox(height: 12),
              const Text(
                  'Only invited members can see discussions, polls and people. Your public reviews and shared ratings can appear here; your sharing settings stay the same.')
            ],
            if (_error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: _busy
                    ? null
                    : (_preview == null ? _previewInvite : _accept),
                child: Text(_busy
                    ? 'Loading…'
                    : _preview == null
                        ? 'Preview invitation'
                        : 'Join community')),
          ]);
}
