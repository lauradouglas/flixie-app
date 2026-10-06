import 'package:flixie_app/core/widgets/flixie_back_button.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import '../../data/community_service.dart';

class CommunityPeopleScreen extends StatefulWidget {
  const CommunityPeopleScreen(
      {super.key, this.service = const CommunityService()});
  final CommunityService service;
  @override
  State<CommunityPeopleScreen> createState() => _CommunityPeopleScreenState();
}

class _CommunityPeopleScreenState extends State<CommunityPeopleScreen> {
  List<Map<String, dynamic>> _people = [], _invites = [];
  bool _loading = true;
  String? _error;
  final _busy = <String>{};
  @override
  void initState() {
    super.initState();
    _load();
    SafetyService.changes.addListener(_blocked);
  }

  @override
  void dispose() {
    SafetyService.changes.removeListener(_blocked);
    super.dispose();
  }

  void _blocked() {
    if (!mounted) return;
    setState(() {
      _people.removeWhere(
          (p) => SafetyService.isBlocked(p['user']['id'] as String));
      _invites.removeWhere(
          (i) => SafetyService.isBlocked(i['owner']['id'] as String));
    });
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait(
          [widget.service.people(), widget.service.invitations()]);
      if (mounted) {
        setState(() {
          _people = results[0]
              .where((p) => !SafetyService.isBlocked(p['user']['id'] as String))
              .toList();
          _invites = results[1]
              .where(
                  (i) => !SafetyService.isBlocked(i['owner']['id'] as String))
              .toList();
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Couldn’t load Community connections.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _respond(Map<String, dynamic> invite, String action) async {
    final id = invite['listId'] as String;
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      await widget.service.invitation(id, invite['userId'] as String, action);
      if (mounted) {
        setState(() => _invites.remove(invite));
        if (action == 'accept') {
          context.push(
              '/movie-lists/$id?owner=${invite['owner']['id']}&canEdit=true');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t update this invitation. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Widget _avatar(FriendshipUser user) => SizedBox(
      width: 52,
      height: 52,
      child: Center(
          child: ProfileAvatarView(
              avatar: user.avatar,
              profileBadges: user.profileBadges,
              size: 40,
              fallbackText: user.username.isEmpty ? '?' : user.username[0],
              fallbackColor: Theme.of(context).colorScheme.primary)));
  @override
  Widget build(BuildContext context) => FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(
          leading: FlixieBackButton(), title: Text('Find your people')),
      body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
              padding: const EdgeInsets.all(20),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  TextButton(onPressed: _load, child: Text('$_error Retry')),
                if (_invites.isNotEmpty) ...[
                  Text('List invitations',
                      style: Theme.of(context).textTheme.titleLarge),
                  for (final invite in _invites)
                    Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite['name'] as String,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              Text(
                                  '${invite['owner']['username']} invited you to edit this public list.'),
                              const Text(
                                  'Editors can add and remove titles. The owner controls sharing and membership.'),
                              Wrap(spacing: 12, children: [
                                TextButton(
                                    onPressed: _busy.contains(invite['listId'])
                                        ? null
                                        : () => _respond(invite, 'accept'),
                                    child: const Text('Accept invitation')),
                                TextButton(
                                    onPressed: _busy.contains(invite['listId'])
                                        ? null
                                        : () => _respond(invite, 'decline'),
                                    child: const Text('Decline'))
                              ])
                            ])),
                  const SizedBox(height: 24)
                ],
                Text('Similar taste',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'People who share your favourite films. Only their public favourites appear here.'),
                if (!_loading && _error == null && _people.isEmpty)
                  const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                          'No matches yet. Add favourite films to your profile to help find people with similar taste.')),
                for (final person in _people)
                  Builder(builder: (context) {
                    final user = FriendshipUser.fromJson(
                        Map<String, dynamic>.from(person['user']));
                    final shared = person['sharedFavourites'] as List;
                    return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                        leading: _avatar(user),
                        title: Text(user.username),
                        subtitle: Text(
                            'You both love ${shared.map((m) => m['title']).join(', ')}'),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/community/profiles/${user.id}'));
                  })
              ])));
}
