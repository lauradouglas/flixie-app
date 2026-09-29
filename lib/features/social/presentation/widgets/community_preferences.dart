import 'package:flutter/material.dart';
import '../../data/community_service.dart';

class CommunityPreferences extends StatefulWidget {
  const CommunityPreferences({super.key, required this.service});
  final CommunityService service;
  @override
  State<CommunityPreferences> createState() => _CommunityPreferencesState();
}

class _CommunityPreferencesState extends State<CommunityPreferences> {
  Map<String, dynamic>? _settings;
  bool _failed = false, _busy = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final result = await widget.service.settings();
      if (mounted) setState(() => _settings = result);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _change(String key, bool value) async {
    setState(() => _busy = true);
    try {
      await widget.service.updateSettings({key: value});
      if (mounted) setState(() => _settings![key] = value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Couldn’t save this preference. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return TextButton(
          onPressed: _load,
          child: const Text('Retry profile and notification settings'));
    }
    if (_settings == null) {
      return const Padding(
          padding: EdgeInsets.all(12), child: LinearProgressIndicator());
    }
    return Column(children: [
      TextButton(
          onPressed: () async {
            try {
              await widget.service.resetFeedPreferences();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text(
                        'Hidden posts and muted authors restored. Refresh the feed to see them.')));
              }
            } catch (_) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Couldn’t reset feed preferences.')));
              }
            }
          },
          child: const Text('Restore hidden posts and authors')),
      for (final entry in const {
        'communityProfileDetails': (
          'Show bio and favourites',
          'Include my bio and favourite films. Public favourites can help people find me through similar taste.'
        ),
        'communityProfileGenres': (
          'Show favourite genres',
          'Include my favourite genres in my public profile.'
        ),
        'communityReplyNotifications': (
          'Replies and mentions',
          'Notify me about replies to my public posts or comments, and when someone mentions me in a community.'
        ),
        'communityReactionNotifications': (
          'Reaction notifications',
          'Notify me once when someone first reacts to a post.'
        ),
      }.entries)
        SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(entry.value.$1),
            subtitle: Text(entry.value.$2),
            value: _settings![entry.key] == true,
            onChanged: _busy ? null : (value) => _change(entry.key, value)),
    ]);
  }
}
