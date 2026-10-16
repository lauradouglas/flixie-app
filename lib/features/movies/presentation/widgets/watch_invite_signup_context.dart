import 'package:flutter/material.dart';
import 'package:flixie_app/core/auth/pending_watch_invite_store.dart';
import 'package:flixie_app/features/movies/data/external_watch_invite_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Retains the reason for joining without replacing the established auth form.
class WatchInviteSignupContext extends StatefulWidget {
  const WatchInviteSignupContext({super.key});
  @override
  State<WatchInviteSignupContext> createState() =>
      _WatchInviteSignupContextState();
}

class _WatchInviteSignupContextState extends State<WatchInviteSignupContext> {
  late final Future<Map<String, dynamic>?> _context = _load();
  Future<Map<String, dynamic>?> _load() async {
    final token = await PendingWatchInviteStore.read();
    return token == null
        ? null
        : ExternalWatchInviteService.publicPreview(token);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>?>(
      future: _context,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) return const SizedBox.shrink();
        final movie = data['movie'] as Map, owner = data['owner'] as Map;
        return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${movie['title']} with ${owner['username']}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text(
                  'Your watch is waiting. Create your account, then add your rating. You can finish setting up Flixie afterwards.'),
            ]));
      });
}
