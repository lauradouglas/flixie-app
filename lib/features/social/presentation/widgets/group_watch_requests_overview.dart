import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';

enum _GroupRequestFilter { active, needsReply, scheduled, completed }

class GroupWatchRequestsOverview extends StatefulWidget {
  const GroupWatchRequestsOverview({super.key, required this.groups});

  final List<Group> groups;

  @override
  State<GroupWatchRequestsOverview> createState() =>
      _GroupWatchRequestsOverviewState();
}

class _GroupWatchRequestsOverviewState
    extends State<GroupWatchRequestsOverview> {
  List<({Group group, GroupWatchRequest request})> _items = [];
  bool _loading = true;
  _GroupRequestFilter _filter = _GroupRequestFilter.active;

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
    final results = await Future.wait(widget.groups.map((group) async {
      if (group.id == null) {
        return <({Group group, GroupWatchRequest request})>[];
      }
      try {
        final requests = await GroupService.getGroupWatchRequests(group.id!);
        return requests.map((request) => (group: group, request: request));
      } catch (_) {
        return <({Group group, GroupWatchRequest request})>[];
      }
    }));
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

  bool _matches(GroupWatchRequest request, _GroupRequestFilter filter) {
    return switch (filter) {
      _GroupRequestFilter.active => request.isActive,
      _GroupRequestFilter.needsReply =>
        request.isActive && request.currentUserResponse == null,
      _GroupRequestFilter.scheduled =>
        request.status == WatchRequestStatus.scheduled ||
            request.scheduledFor != null,
      _GroupRequestFilter.completed =>
        request.status == WatchRequestStatus.completed,
    };
  }

  int _count(_GroupRequestFilter filter) =>
      _items.where((item) => _matches(item.request, filter)).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const WatchRequestsSkeleton();
    final active = _items.where((item) => item.request.isActive).toList();
    final completed = _items
        .where((item) => item.request.status == WatchRequestStatus.completed)
        .toList();
    final visible = _filter == _GroupRequestFilter.active
        ? [...active, ...completed]
        : _items.where((item) => _matches(item.request, _filter)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _GroupRequestFilter.values
                  .map((filter) => Padding(
                        padding:
                            const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                        child: ChoiceChip(
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                          label: Text('${_label(filter)} ${_count(filter)}'),
                          selectedColor: FlixieColors.primary,
                          backgroundColor: FlixieColors.tabBarBackgroundFocused,
                          side: BorderSide(
                            color: FlixieColors.primary.withValues(
                              alpha: _filter == filter ? 1 : .3,
                            ),
                          ),
                          labelStyle: TextStyle(
                            color: _filter == filter
                                ? Colors.white
                                : FlixieColors.medium,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(
                child: Text('No group watch requests here yet',
                    style: TextStyle(color: FlixieColors.medium)),
              ),
            )
          else ...[
            if (_filter == _GroupRequestFilter.active && active.isNotEmpty) ...[
              const _SectionLabel('ACTIVE REQUESTS'),
              const SizedBox(height: 10),
              ...active.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupRequestTile(
                        group: item.group, request: item.request),
                  )),
            ],
            if (_filter == _GroupRequestFilter.active &&
                completed.isNotEmpty) ...[
              const SizedBox(height: 18),
              const _SectionLabel('COMPLETED REQUESTS', muted: true),
              const SizedBox(height: 10),
              ...completed.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupRequestTile(
                      group: item.group,
                      request: item.request,
                      compact: true,
                    ),
                  )),
            ],
            if (_filter != _GroupRequestFilter.active)
              ...visible.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _GroupRequestTile(
                      group: item.group,
                      request: item.request,
                      compact: _filter == _GroupRequestFilter.completed,
                    ),
                  )),
          ],
          const SizedBox(height: 54),
          const Icon(Icons.movie_filter_outlined,
              color: FlixieColors.primary, size: 32),
          const SizedBox(height: 10),
          const Text(
            'Group movie magic happens here.\nRequest a movie, rally the crew, and enjoy together.',
            textAlign: TextAlign.center,
            style: TextStyle(color: FlixieColors.medium, height: 1.5),
          ),
        ],
      ),
    );
  }

  String _label(_GroupRequestFilter filter) => switch (filter) {
        _GroupRequestFilter.active => 'Active',
        _GroupRequestFilter.needsReply => 'Needs reply',
        _GroupRequestFilter.scheduled => 'Scheduled',
        _GroupRequestFilter.completed => 'Completed',
      };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label, {this.muted = false});
  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: muted ? FlixieColors.medium : FlixieColors.primary,
          fontWeight: FontWeight.w900,
          fontSize: 13,
          letterSpacing: 1.1,
        ),
      );
}

class _GroupRequestTile extends StatelessWidget {
  const _GroupRequestTile({
    required this.group,
    required this.request,
    this.compact = false,
  });

  final Group group;
  final GroupWatchRequest request;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final path = request.moviePosterPath;
    final posterUrl = path == null
        ? null
        : path.startsWith('http')
            ? path
            : 'https://image.tmdb.org/t/p/w342$path';
    final groupId = group.id ?? request.groupId;
    void open() => context.push(
          '/groups/$groupId?tab=requests&requestId=${request.id}',
        );
    final accepted = request.memberStatuses
        .where((member) => member.status.toUpperCase() == 'ACCEPTED')
        .toList();
    final acceptedCount = request.acceptedCount > accepted.length
        ? request.acceptedCount
        : accepted.length;
    final waiting =
        (group.memberCount ?? request.responseCount) - acceptedCount;

    return Material(
      color: FlixieColors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: compact ? 142 : 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: FlixieColors.primary.withValues(alpha: .3),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.horizontal(left: Radius.circular(15)),
                child: SizedBox(
                  width: compact ? 98 : 132,
                  height: double.infinity,
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
                  padding: const EdgeInsets.all(14),
                  child: compact
                      ? _compactContent(open)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(request.movieTitle ?? 'Watch request',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: FlixieColors.light,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                )),
                            const SizedBox(height: 8),
                            Row(children: [
                              ProfileAvatarView(
                                avatar: request.requesterAvatar,
                                fallbackText:
                                    _initial(request.requesterUsername),
                                fallbackColor: FlixieColors.primary,
                                size: 30,
                              ),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  '@${request.requesterUsername ?? 'member'} created this',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: FlixieColors.medium, fontSize: 12),
                                ),
                              ),
                            ]),
                            if (request.scheduledFor != null) ...[
                              const SizedBox(height: 9),
                              _StatusLine(request: request),
                            ],
                            const Spacer(),
                            const Divider(color: FlixieColors.tabBarBorder),
                            Row(children: [
                              SizedBox(
                                width: 76,
                                height: 30,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: accepted
                                      .take(3)
                                      .toList()
                                      .asMap()
                                      .entries
                                      .map((entry) {
                                    final member = entry.value;
                                    return Positioned(
                                      left: entry.key * 22,
                                      child: ExcludeSemantics(
                                        child: ProfileAvatarView(
                                          avatar: member.avatar,
                                          fallbackText:
                                              _initial(member.username),
                                          fallbackColor: FlixieColors.primary,
                                          size: 30,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '$acceptedCount accepted · ${waiting.clamp(0, 999)} waiting',
                                  style: const TextStyle(
                                      color: FlixieColors.success,
                                      fontSize: 11),
                                ),
                              ),
                            ]),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              height: 40,
                              child: OutlinedButton.icon(
                                onPressed: open,
                                icon: const Icon(Icons.visibility_outlined,
                                    size: 16),
                                label: Text(request.status ==
                                        WatchRequestStatus.scheduled
                                    ? 'View plan'
                                    : 'View request'),
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

  Widget _compactContent(VoidCallback open) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(request.movieTitle ?? 'Watch request',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 16,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 9),
          const Row(children: [
            Icon(Icons.event_available_outlined,
                color: FlixieColors.medium, size: 16),
            SizedBox(width: 6),
            Text('Watched', style: TextStyle(color: FlixieColors.medium)),
          ]),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton(onPressed: open, child: const Text('View')),
          ),
        ],
      );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.request});
  final GroupWatchRequest request;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(request.scheduledFor ?? '')?.toLocal();
    final text = date == null
        ? 'Scheduled'
        : '${date.day}/${date.month} · ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    return Row(children: [
      const Icon(Icons.event_available_outlined,
          color: FlixieColors.success, size: 17),
      const SizedBox(width: 6),
      Expanded(
        child: Text(text,
            style: const TextStyle(
                color: FlixieColors.success, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

String _initial(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '?' : text[0].toUpperCase();
}
