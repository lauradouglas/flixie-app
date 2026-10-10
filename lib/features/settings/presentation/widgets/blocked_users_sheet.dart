import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/safety/safety_service.dart';

class BlockedUsersSheet extends StatefulWidget {
  const BlockedUsersSheet({super.key});

  @override
  State<BlockedUsersSheet> createState() => BlockedUsersSheetState();
}

class BlockedUsersSheetState extends State<BlockedUsersSheet> {
  late Future<List<BlockedUser>> _users = SafetyService.blockedUsers();
  final Set<String> _unblocking = {};
  String? _error;

  Future<void> _unblock(BlockedUser user) async {
    if (!_unblocking.add(user.id)) return;
    setState(() {
      _error = null;
    });
    try {
      await SafetyService.unblock(user.id);
      if (!mounted) return;
      final users = SafetyService.blockedUsers(refresh: true);
      setState(() {
        _users = users;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not unblock this user. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _unblocking.remove(user.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Text(
            'Blocked Users',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Text(
            'Blocked users cannot contact or interact with you.',
            style: TextStyle(color: context.colors.medium),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<BlockedUser>>(
            future: _users,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: TextButton(
                  onPressed: () {
                    setState(() {
                      _users = SafetyService.blockedUsers(refresh: true);
                    });
                  },
                  child: const Text('Could not load blocked users. Retry'),
                ));
              }
              final users = snapshot.data ?? const [];
              if (users.isEmpty) {
                return Center(
                  child: Text(
                    'You have not blocked anyone.',
                    style: TextStyle(color: context.colors.medium),
                  ),
                );
              }
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(user.username[0].toUpperCase()),
                    ),
                    title: Text('@${user.username}'),
                    subtitle: user.firstName?.isNotEmpty == true
                        ? Text(user.firstName!)
                        : null,
                    trailing: TextButton(
                      onPressed: _unblocking.contains(user.id)
                          ? null
                          : () => _unblock(user),
                      child: Text(_unblocking.contains(user.id)
                          ? 'Unblocking…'
                          : 'Unblock'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text(_error!, style: TextStyle(color: context.colors.danger)),
          ),
      ],
    );
  }
}
