import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';

class ActivityFeedCard extends StatefulWidget {
  const ActivityFeedCard(
      {super.key,
      required this.item,
      this.reactions = const ActivityReactionSummary(),
      this.onReact,
      this.onReactionSelected,
      required this.onOpen,
      required this.onProfile,
      this.onReply,
      this.onReview,
      this.onOpenList,
      this.busy = false,
      this.embedded = false});
  final ActivityListItem item;
  final ActivityReactionSummary reactions;
  final ValueChanged<BuildContext>? onReact;
  final ValueChanged<String?>? onReactionSelected;
  final VoidCallback onProfile;
  final VoidCallback? onOpen;
  final VoidCallback? onReply;
  final VoidCallback? onReview, onOpenList;
  final bool busy;
  final bool embedded;
  @override
  State<ActivityFeedCard> createState() => _ActivityFeedCardState();
}

class _ActivityFeedCardState extends State<ActivityFeedCard> {
  bool _showSpoiler = false;
  final _reactButtonKey = GlobalKey();

  void _openReactions() {
    final anchor = _reactButtonKey.currentContext;
    if (anchor != null) widget.onReact?.call(anchor);
  }

  String get _label => switch (widget.item.type) {
        ActivityListType.movieWatched || ActivityListType.showWatched => widget
                .item.isRewatch
            ? 'Watched again${(widget.item.watchCount ?? 0) > 1 ? ' · ${widget.item.watchCount} times' : ''}'
            : 'Watched a ${widget.item.showId != null ? 'show' : 'film'}',
        ActivityListType.movieRating ||
        ActivityListType.showRating =>
          'Rated a ${widget.item.showId != null ? 'show' : 'film'}',
        ActivityListType.movieReview ||
        ActivityListType.showReview =>
          'Wrote a review',
        ActivityListType.movieWatchlist ||
        ActivityListType.showWatchlist =>
          'Added to watchlist',
        ActivityListType.favoriteMovie ||
        ActivityListType.favoriteShow ||
        ActivityListType.favoritePerson =>
          'Added to favourites',
        ActivityListType.watchRequest ||
        ActivityListType.watchRequestSent =>
          'Shared a film',
        ActivityListType.watchRequestAccepted => 'Joined a watch plan',
        ActivityListType.movieListAdded => 'Added to a list',
        _ => 'Shared an update',
      };
  String get _age {
    final date = DateTime.tryParse(widget.item.timestamp);
    if (date == null) return '';
    final elapsed = DateTime.now().difference(date);
    if (elapsed.inMinutes < 1) return 'Just now';
    if (elapsed.inHours < 1) return '${elapsed.inMinutes}m ago';
    if (elapsed.inDays < 1) return '${elapsed.inHours}h ago';
    return '${elapsed.inDays}d ago';
  }

  Widget _surface({required EdgeInsets padding, required Widget child}) =>
      widget.embedded
          ? Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: child)
          : WatchPlanSurface(padding: padding, child: child);

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final name = item.username.isNotEmpty ? item.username : item.firstName;
    final review = item.reviewData;
    final text = review?.body ?? item.notes;
    return GestureDetector(
        onLongPress:
            widget.busy || widget.onReact == null ? null : _openReactions,
        child: _surface(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                InkWell(
                    onTap: widget.onProfile,
                    child: ProfileAvatarView(
                        avatar: item.avatar,
                        profileBadges: item.profileBadges,
                        fallbackColor: FlixieColors.primary,
                        size: 40,
                        fallbackText: name.isEmpty ? '?' : name[0])),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(name,
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text('$_label${_age.isEmpty ? '' : ' · $_age'}',
                          style: TextStyle(
                              color: context.colors.light, fontSize: 13)),
                    ])),
                PopupMenuButton<String>(
                    tooltip: 'Activity options',
                    icon: Icon(Icons.more_horiz, color: context.colors.light),
                    onSelected: (value) => value == 'profile'
                        ? widget.onProfile()
                        : widget.onOpen?.call(),
                    itemBuilder: (_) => [
                          const PopupMenuItem(
                              value: 'profile', child: Text('View profile')),
                          if (widget.onOpen != null)
                            const PopupMenuItem(
                                value: 'media', child: Text('View title'))
                        ]),
              ]),
              const SizedBox(height: 12),
              Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                InkWell(
                    onTap: widget.onOpen,
                    child: WatchPlanPoster(
                        path: item.mediaPosterPath,
                        title: item.mediaTitle,
                        width: widget.embedded ? 68 : 84)),
                const SizedBox(width: 16),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.mediaTitle ?? 'Shared activity',
                          style: TextStyle(
                              color: context.colors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      if (item.mediaRating != null) ...[
                        const SizedBox(height: 4),
                        Text(
                            '★ ${item.mediaRating! == item.mediaRating!.roundToDouble() ? item.mediaRating!.toStringAsFixed(0) : item.mediaRating!.toStringAsFixed(1)} / 10',
                            style: TextStyle(
                                color: context.colors.warning,
                                fontWeight: FontWeight.w700)),
                      ],
                      if (item.recommended != null) ...[
                        const SizedBox(height: 4),
                        Text(
                            item.recommended!
                                ? 'Recommends'
                                : 'Doesn’t recommend',
                            style: TextStyle(
                                color: item.recommended!
                                    ? context.colors.success
                                    : context.colors.light,
                                fontWeight: FontWeight.w700)),
                      ],
                      if (item.type == ActivityListType.watchRequest ||
                          item.type == ActivityListType.watchRequestSent) ...[
                        const SizedBox(height: 4),
                        const FlixiePill.label(
                            avatar: Icon(Icons.confirmation_number_outlined,
                                size: 16),
                            label: Text('Request')),
                      ],
                      if (item.listName?.isNotEmpty == true)
                        TextButton(
                            onPressed: widget.onOpenList,
                            child: Text(item.listName!,
                                style: TextStyle(
                                    color: context.colors.primaryText))),
                      const SizedBox(height: 4),
                      if (widget.onOpen != null)
                        TextButton(
                            onPressed: widget.onOpen,
                            style: TextButton.styleFrom(
                                foregroundColor: context.colors.primaryText,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(44, 44),
                                tapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap),
                            child: Text(item.showId != null
                                ? 'View show  ›'
                                : item.personId != null
                                    ? 'View person  ›'
                                    : 'View film  ›')),
                    ])),
              ]),
              if (text?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 12),
                if (review?.containsSpoilers == true && !_showSpoiler)
                  TextButton(
                      onPressed: () => setState(() => _showSpoiler = true),
                      child: const Text('Show review · contains spoilers'))
                else
                  Text(text!,
                      style:
                          TextStyle(color: context.colors.light, height: 1.4)),
              ],
              if (widget.onReview != null)
                TextButton(
                    onPressed: widget.onReview,
                    child: const Text('View review')),
              if (widget.onReact != null ||
                  widget.onReply != null ||
                  widget.reactions.counts.values.any((count) => count > 0)) ...[
                const SizedBox(height: 0),
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                        for (final reaction in ActivityReaction.values)
                          if ((widget.reactions.counts[reaction.emoji] ?? 0) >
                              0)
                            FlixiePill.action(
                                onPressed: widget.busy ||
                                        (widget.onReact == null &&
                                            widget.onReactionSelected == null)
                                    ? null
                                    : () {
                                        if (widget.onReactionSelected != null) {
                                          widget.onReactionSelected!(
                                              widget.reactions.mine ==
                                                      reaction.emoji
                                                  ? null
                                                  : reaction.emoji);
                                        } else {
                                          _openReactions();
                                        }
                                      },
                                tooltip:
                                    '${reaction.label}${widget.reactions.mine == reaction.emoji ? ' · Tap to remove' : ''}',
                                label: Text(
                                    '${reaction.emoji} ${widget.reactions.counts[reaction.emoji]}')),
                        if (widget.onReact != null)
                          IconButton.outlined(
                              key: _reactButtonKey,
                              tooltip: 'Add reaction',
                              onPressed: widget.busy ? null : _openReactions,
                              icon: const Icon(Icons.add_reaction_outlined),
                              style: IconButton.styleFrom(
                                  foregroundColor: context.colors.light,
                                  side: BorderSide(
                                      color: context.colors.tabBarBorder))),
                      ])),
                  if (widget.onReply != null) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                        onPressed: widget.onReply,
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text('Reply'),
                        style: TextButton.styleFrom(
                            foregroundColor: context.colors.light)),
                  ],
                ]),
              ],
            ])));
  }
}
