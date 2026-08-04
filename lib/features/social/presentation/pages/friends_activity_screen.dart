import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_page.dart';
import 'package:flixie_app/features/profile/presentation/widgets/activity_tile.dart';
import 'package:flixie_app/features/social/data/friend_service.dart';
import 'package:flixie_app/models/activity_list_item.dart';

class FriendsActivityScreen extends StatefulWidget {
  const FriendsActivityScreen({super.key});

  @override
  State<FriendsActivityScreen> createState() => _FriendsActivityScreenState();
}

class _FriendsActivityScreenState extends State<FriendsActivityScreen> {
  List<ActivityListItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final cached = context.read<AuthProvider>().cachedFriendsActivity;
    if (cached != null) {
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      _items = cached.where((item) {
        final timestamp = DateTime.tryParse(item.timestamp);
        return timestamp == null || timestamp.isAfter(cutoff);
      }).toList();
      _loading = false;
    }
    _load(showSpinner: cached == null);
  }

  Future<void> _load({bool showSpinner = false}) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.dbUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    if (showSpinner) setState(() => _loading = true);
    setState(() => _error = null);
    try {
      final items = await FriendService.getFriendsActivityLists(
        userId,
        days: 14,
        limit: 100,
      );
      if (mounted) {
        setState(() => _items = items);
      }
    } catch (_) {
      if (mounted && _items.isEmpty) {
        setState(() => _error = 'Couldn\'t load friend activity.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlixiePageScaffold(
      appBar: const FlixieTitleAppBar(
        title: Text(
          'Friend Activity',
          style: TextStyle(
            color: FlixieColors.light,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 180),
                      Center(child: Text(_error!)),
                      TextButton(
                          onPressed: _load, child: const Text('Try again')),
                    ],
                  )
                : _items.isEmpty
                    ? ListView(
                        padding: const EdgeInsets.all(24),
                        children: const [
                          SizedBox(height: 160),
                          Icon(Icons.people_outline_rounded,
                              size: 52, color: FlixieColors.medium),
                          SizedBox(height: 12),
                          Text(
                            'No friend activity in the last two weeks.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: FlixieColors.medium),
                          ),
                        ],
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                        itemCount: _items.length + 1,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, index) {
                          if (index == 0) {
                            return Row(
                              children: [
                                const Icon(Icons.calendar_today_outlined,
                                    size: 16, color: FlixieColors.primary),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Last 14 days · ratings and recommendations first',
                                    style: TextStyle(
                                      color: FlixieColors.medium,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${_items.length}',
                                  style: const TextStyle(
                                    color: FlixieColors.light,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            );
                          }
                          return ActivityTile(item: _items[index - 1]);
                        },
                      ),
      ),
    );
  }
}
