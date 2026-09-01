import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/navigation/tab_refresh_controller.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_watch_request.dart';

enum _GroupRequestFilter { active, completed }

class GroupWatchRequestsOverview extends StatefulWidget {
  const GroupWatchRequestsOverview({
    super.key,
    required this.groups,
    required this.currentUserId,
  });

  final List<Group> groups;
  final String currentUserId;

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
    TabRefreshController.social.addListener(_onWatchPlansChanged);
    _load();
  }

  @override
  void dispose() {
    TabRefreshController.social.removeListener(_onWatchPlansChanged);
    super.dispose();
  }

  void _onWatchPlansChanged() {
    if (mounted) _load();
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
      _GroupRequestFilter.completed =>
        request.status == WatchRequestStatus.completed,
    };
  }

  int _count(_GroupRequestFilter filter) =>
      _items.where((item) => _matches(item.request, filter)).length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const GroupWatchRequestsSkeleton();
    final active = _items.where((item) => item.request.isActive).toList();
    final visible =
        _items.where((item) => _matches(item.request, _filter)).toList();
    final needsReply = active
        .where((item) => _needsReply(item.request, widget.currentUserId))
        .toList();
    final upcoming = active.where((item) {
      final scheduledFor = DateTime.tryParse(item.request.scheduledFor ?? '');
      return scheduledFor != null && scheduledFor.isAfter(DateTime.now());
    }).toList();
    final readyToWrapUp = active.where((item) {
      final scheduledFor = DateTime.tryParse(item.request.scheduledFor ?? '');
      return scheduledFor != null && !scheduledFor.isAfter(DateTime.now());
    }).toList();
    final planning = active
        .where((item) =>
            !needsReply.contains(item) &&
            !upcoming.contains(item) &&
            !readyToWrapUp.contains(item))
        .toList();

    final content = <Widget>[];
    void addSection(
      String title,
      String subtitle,
      List<({Group group, GroupWatchRequest request})> items,
    ) {
      if (items.isEmpty) return;
      if (content.isNotEmpty) content.add(const SizedBox(height: 22));
      content.add(_GroupSectionHeader(
        title: title,
        subtitle: subtitle,
        count: items.length,
      ));
      content.add(const SizedBox(height: 10));
      for (final item in items) {
        content.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GroupRequestTile(
            group: item.group,
            request: item.request,
            currentUserId: widget.currentUserId,
          ),
        ));
      }
    }

    if (_filter == _GroupRequestFilter.active) {
      addSection('Needs reply', 'Plans waiting for your response', needsReply);
      addSection('Upcoming', 'Your agreed Watch Plans', upcoming);
      addSection(
        'Ready to wrap up',
        'The planned time has passed',
        readyToWrapUp,
      );
      addSection(
        'Scheduling in progress',
        'Invites waiting or being arranged',
        planning,
      );
    } else {
      for (final item in visible) {
        content.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _GroupRequestTile(
            group: item.group,
            request: item.request,
            currentUserId: widget.currentUserId,
          ),
        ));
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: FlixieColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          SizedBox(
            height: 58,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _GroupRequestFilter.values.length,
              itemBuilder: (_, index) {
                final filter = _GroupRequestFilter.values[index];
                final selected = _filter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
                  child: ChoiceChip(
                    label: Text(
                      filter == _GroupRequestFilter.active
                          ? 'Active · ${_count(_GroupRequestFilter.active)}'
                          : 'Past · ${_count(_GroupRequestFilter.completed)}',
                    ),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = filter),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                    padding: EdgeInsets.zero,
                    selectedColor: FlixieColors.primary.withValues(alpha: .22),
                    backgroundColor: FlixieColors.tabBarBackgroundFocused,
                    side: BorderSide(
                      color: FlixieColors.primary
                          .withValues(alpha: selected ? 1 : .3),
                    ),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : FlixieColors.medium,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
          if (content.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 100),
              child: Center(
                child: Text('No group Watch Plans here yet',
                    style: TextStyle(color: FlixieColors.medium)),
              ),
            )
          else
            ...content,
        ],
      ),
    );
  }
}

class _GroupSectionHeader extends StatelessWidget {
  const _GroupSectionHeader({
    required this.title,
    required this.subtitle,
    required this.count,
  });

  final String title;
  final String subtitle;
  final int count;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: FlixieColors.primary.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: FlixieColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      );
}

class _GroupRequestTile extends StatelessWidget {
  const _GroupRequestTile({
    required this.group,
    required this.request,
    required this.currentUserId,
  });

  final Group group;
  final GroupWatchRequest request;
  final String currentUserId;

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
    final invitees = request.memberStatuses
        .where((member) => member.memberId != request.userId)
        .toList();
    final acceptedInvitees = invitees
        .where((member) => member.status.toUpperCase() == 'ACCEPTED')
        .length;
    final respondedInvitees = invitees.where((member) {
      return const {'ACCEPTED', 'DECLINED', 'MAYBE'}
          .contains(member.status.toUpperCase());
    }).length;
    // Creating a group Watch Plan is the creator's acceptance. Only the
    // remaining group members need to respond.
    final acceptedCount = 1 + acceptedInvitees;
    final participantCount = group.memberCount ?? (invitees.length + 1);
    final waiting = participantCount - 1 - respondedInvitees;

    final completed = request.status == WatchRequestStatus.completed;
    final scheduled = request.status == WatchRequestStatus.scheduled ||
        request.scheduledFor != null;
    final needsReply = request.isActive && _needsReply(request, currentUserId);
    final label = completed
        ? 'WATCHED TOGETHER'
        : needsReply
            ? 'NEEDS REPLY'
            : scheduled
                ? 'SCHEDULED'
                : 'PLANNING TOGETHER';
    final actionLabel = completed ? 'View recap' : 'View plan';
    final scheduleText = completed
        ? 'Watched'
        : request.scheduledFor == null
            ? 'Time to be agreed'
            : _scheduledLabel(request.scheduledFor!);
    final contextText = completed
        ? '$acceptedCount members watched'
        : '$acceptedCount accepted · ${waiting.clamp(0, 999)} waiting';

    return Material(
      color: FlixieColors.tabBarBackgroundFocused,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: FlixieColors.tabBarBorder),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stackedFooter = constraints.maxWidth < 350;
              final posterWidth = stackedFooter ? 82.0 : 72.0;
              final posterHeight = posterWidth * 1.5;
              final poster = ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: posterWidth,
                  height: posterHeight,
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
              );
              final details = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 2,
                    style: TextStyle(
                      color: completed
                          ? FlixieColors.success
                          : FlixieColors.secondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    request.movieTitle ?? 'Watch Plan',
                    style: const TextStyle(
                      color: FlixieColors.light,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.event_outlined,
                        color: FlixieColors.medium, size: 18),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        scheduleText,
                        maxLines: 2,
                        style: const TextStyle(
                            color: FlixieColors.light, fontSize: 14),
                      ),
                    ),
                  ]),
                ],
              );
              final participant = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProfileAvatarView(
                    avatar: request.requesterAvatar,
                    fallbackText: _initial(request.requesterUsername),
                    fallbackColor: FlixieColors.primary,
                    size: 32,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '${group.name} · $contextText',
                      maxLines: 2,
                      style: const TextStyle(
                          color: FlixieColors.light, fontSize: 14),
                    ),
                  ),
                ],
              );
              final action = FilledButton(
                onPressed: open,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: Text(actionLabel),
              );

              if (stackedFooter) {
                return Column(mainAxisSize: MainAxisSize.min, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    poster,
                    const SizedBox(width: 14),
                    Expanded(child: details),
                  ]),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Divider(color: FlixieColors.tabBarBorder),
                  ),
                  Row(children: [
                    Expanded(child: participant),
                    const SizedBox(width: 12),
                    action,
                  ]),
                ]);
              }

              return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    poster,
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          details,
                          const SizedBox(height: 12),
                          participant
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: posterHeight,
                      child: Align(
                          alignment: Alignment.bottomRight, child: action),
                    ),
                  ]);
            },
          ),
        ),
      ),
    );
  }
}

String _scheduledLabel(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return 'Scheduled';
  return '${date.day}/${date.month} · ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
}

bool _needsReply(GroupWatchRequest request, String currentUserId) {
  if (currentUserId.isEmpty || request.userId == currentUserId) return false;
  if (request.canRespond == false || request.currentUserResponse != null) {
    return false;
  }
  return !request.memberStatuses.any((member) =>
      member.memberId == currentUserId &&
      const {'ACCEPTED', 'DECLINED', 'MAYBE'}
          .contains(member.status.toUpperCase()));
}

String _initial(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? '?' : text[0].toUpperCase();
}
