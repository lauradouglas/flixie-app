import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';

class GroupWatchRequestsOverview extends StatefulWidget {
  const GroupWatchRequestsOverview({
    super.key,
    required this.groups,
  });

  final List<Group> groups;

  @override
  State<GroupWatchRequestsOverview> createState() =>
      _GroupWatchRequestsOverviewState();
}

class _GroupWatchRequestsOverviewState
    extends State<GroupWatchRequestsOverview> {
  List<({Group group, GroupWatchRequest request})> _items = [];
  bool _loading = true;
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(GroupWatchRequestsOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups) _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final results = await Future.wait(
      widget.groups.map((group) async {
        final id = group.id;
        if (id == null) {
          return <({Group group, GroupWatchRequest request})>[];
        }
        try {
          final requests = await GroupService.getGroupWatchRequests(id);
          return requests.map((request) => (group: group, request: request));
        } catch (_) {
          return <({Group group, GroupWatchRequest request})>[];
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _items = results.expand((items) => items).toList()
        ..sort((a, b) => _date(b.request).compareTo(_date(a.request)));
      _loading = false;
    });
  }

  DateTime _date(GroupWatchRequest request) =>
      DateTime.tryParse(request.lastActivityAt ??
          request.updatedAt ??
          request.createdAt ??
          '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  String _dateTime(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    if (date == null) return '';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${date.day}/${date.month}/${date.year} · ${date.hour}:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final visible =
        _items.where((item) => _showArchived || item.request.isActive).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _showArchived
                          ? 'All group requests'
                          : 'Active group requests',
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        setState(() => _showArchived = !_showArchived),
                    child: Text(_showArchived ? 'Show active' : 'Show all'),
                  ),
                ],
              ),
            ),
          ),
          if (visible.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'No group watch requests here yet',
                  style: TextStyle(color: FlixieColors.medium),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              sliver: SliverList.separated(
                itemCount: visible.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, index) => _GroupRequestTile(
                  group: visible[index].group,
                  request: visible[index].request,
                  scheduledLabel: _dateTime(
                    visible[index].request.scheduledFor ??
                        visible[index].request.proposedDate,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupRequestTile extends StatelessWidget {
  const _GroupRequestTile({
    required this.group,
    required this.request,
    required this.scheduledLabel,
  });

  final Group group;
  final GroupWatchRequest request;
  final String scheduledLabel;

  @override
  Widget build(BuildContext context) {
    final path = request.moviePosterPath;
    final posterUrl = path == null
        ? null
        : path.startsWith('http')
            ? path
            : 'https://image.tmdb.org/t/p/w185$path';
    final groupId = group.id ?? request.groupId;
    void open() => context.push(
          '/groups/$groupId?tab=requests&requestId=${request.id}',
        );

    return Material(
      color: FlixieColors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 150,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: FlixieColors.primary.withValues(alpha: 0.28),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(11),
                ),
                child: SizedBox(
                  width: 100,
                  height: 150,
                  child: posterUrl == null
                      ? const ColoredBox(
                          color: FlixieColors.surface,
                          child: Icon(Icons.movie_outlined),
                        )
                      : CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const ColoredBox(
                            color: FlixieColors.surface,
                            child: Icon(Icons.movie_outlined),
                          ),
                        ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.movieTitle ?? 'Watch request',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${group.name} · by @${request.requesterUsername ?? 'member'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: FlixieColors.medium),
                      ),
                      if (scheduledLabel.isNotEmpty) ...[
                        const SizedBox(height: 9),
                        _detail(Icons.schedule_outlined, scheduledLabel),
                      ],
                      if (request.location?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 6),
                        _detail(
                          Icons.location_on_outlined,
                          request.location!.trim(),
                        ),
                      ],
                      const Spacer(),
                      Align(
                        alignment: Alignment.centerRight,
                        child: OutlinedButton.icon(
                          onPressed: open,
                          icon: const Icon(Icons.visibility_outlined, size: 15),
                          label: const Text('View request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detail(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 15, color: FlixieColors.secondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
}
