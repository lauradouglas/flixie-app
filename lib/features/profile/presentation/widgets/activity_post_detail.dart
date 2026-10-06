import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';
import 'profile_avatar_view.dart';

/// Full post content: no nested review link, clipped body, or surrounding card.
class ActivityPostDetail extends StatefulWidget {
  const ActivityPostDetail(
      {super.key,
      required this.item,
      required this.label,
      required this.age,
      required this.reactions,
      this.onProfile,
      this.onOpen,
      this.onOpenList,
      this.onReply,
      this.onOptions,
      this.onReact,
      this.onReactionSelected,
      this.saveAction,
      this.headerAction,
      this.secondaryAction,
      this.busy = false,
      this.publicPost = false});
  final ActivityListItem item;
  final String label, age;
  final ActivityReactionSummary reactions;
  final VoidCallback? onProfile, onOpen, onOpenList, onReply, onOptions;
  final ValueChanged<BuildContext>? onReact;
  final ValueChanged<String?>? onReactionSelected;
  final Widget? saveAction, headerAction, secondaryAction;
  final bool busy, publicPost;
  @override
  State<ActivityPostDetail> createState() => _ActivityPostDetailState();
}

class _ActivityPostDetailState extends State<ActivityPostDetail> {
  bool _revealed = false;
  @override
  void didUpdateWidget(covariant ActivityPostDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.type != widget.item.type ||
        oldWidget.item.reviewData?.body != widget.item.reviewData?.body) {
      _revealed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final list = item.type == ActivityListType.movieListAdded;
    final person = item.type == ActivityListType.favoritePerson;
    final body = list
        ? item.listDescription ?? item.notes
        : item.reviewData?.body ?? item.notes;
    final name = item.username.isNotEmpty ? item.username : item.firstName;
    final secondary = context.colors.light;
    final posters = item.listPreviewPosterPaths.take(3).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
            onTap: widget.onProfile,
            child: SizedBox(
                width: 48,
                height: 48,
                child: Center(
                    child: ProfileAvatarView(
                        avatar: item.avatar,
                        profileBadges: item.profileBadges,
                        fallbackColor: context.colors.primaryText,
                        size: 38,
                        fallbackText: name.isEmpty ? '?' : name[0])))),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                InkWell(
                    onTap: widget.onProfile,
                    child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16)))),
                if (widget.headerAction != null) widget.headerAction!,
              ]),
          Text(
              '${list && widget.publicPost ? 'Shared a public list' : widget.label}${widget.age.isEmpty ? '' : ' · ${widget.age}'}',
              style: TextStyle(color: secondary, fontSize: 13))
        ])),
        if (widget.onOptions != null)
          IconButton(
              tooltip: 'Post options',
              onPressed: widget.onOptions,
              icon: const Icon(Icons.more_horiz))
        else
          PopupMenuButton<String>(
              tooltip: 'Post options',
              icon: const Icon(Icons.more_horiz),
              onSelected: (value) {
                if (value == 'profile') widget.onProfile?.call();
                if (value == 'message') widget.onReply?.call();
              },
              itemBuilder: (_) => [
                    if (widget.onProfile != null)
                      const PopupMenuItem(
                          value: 'profile', child: Text('View profile')),
                    if (widget.onReply != null)
                      const PopupMenuItem(
                          value: 'message', child: Text('Message'))
                  ]),
      ]),
      const SizedBox(height: 20),
      if (list) ...[
        Text(item.listName ?? 'Shared list',
            style: const TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800, height: 1.15)),
        const SizedBox(height: 8),
        Text(
            '${widget.publicPost ? 'Public list' : 'List'}${item.listAdditionCount == null ? '' : ' · ${item.listAdditionCount} titles'}',
            style: TextStyle(color: secondary)),
        const SizedBox(height: 18),
        if (posters.isNotEmpty)
          LayoutBuilder(builder: (context, constraints) {
            final width = ((constraints.maxWidth - 24) / 3).clamp(48.0, 150.0);
            return Wrap(spacing: 12, runSpacing: 12, children: [
              for (var index = 0; index < posters.length; index++)
                InkWell(
                    onTap: widget.onOpenList,
                    child: Stack(children: [
                      WatchPlanPoster(path: posters[index], width: width),
                      if (index == posters.length - 1 &&
                          (item.listAdditionCount ?? 0) > posters.length)
                        Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                    color: Colors.black87,
                                    borderRadius: BorderRadius.circular(20)),
                                child: Text(
                                    '+${item.listAdditionCount! - posters.length}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700))))
                    ]))
            ]);
          }),
        if (posters.isEmpty)
          Icon(Icons.playlist_play, size: 48, color: secondary),
      ] else
        InkWell(
            onTap: widget.onOpen,
            borderRadius: BorderRadius.circular(10),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              WatchPlanPoster(
                  path: item.mediaPosterPath,
                  title: item.mediaTitle,
                  width: MediaQuery.sizeOf(context).width < 360 ? 72 : 88),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(item.mediaTitle ?? 'Activity update',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            height: 1.2)),
                    const SizedBox(height: 8),
                    Text(
                        person
                            ? 'Person'
                            : item.showId != null
                                ? 'TV show'
                                : 'Film',
                        style: TextStyle(color: secondary, fontSize: 13)),
                    if (widget.onOpen != null)
                      Text('View details ›',
                          style: TextStyle(
                              color: context.colors.primaryText,
                              fontSize: 12,
                              height: 1.6)),
                    if (item.mediaRating != null &&
                        !person &&
                        !hideMovieRatings(context, item.movieId,
                            isShow: item.showId != null, ownerId: item.userId))
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Wrap(
                              spacing: 5,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: context.colors.warning),
                                Text(
                                    '${item.mediaRating!.toStringAsFixed(item.mediaRating! % 1 == 0 ? 0 : 1)}/10',
                                    style: TextStyle(
                                        color: context.colors.warning,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700))
                              ])),
                    if (item.recommended != null && !person)
                      Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                    item.recommended!
                                        ? Icons.thumb_up_alt_outlined
                                        : Icons.thumb_down_alt_outlined,
                                    size: 18,
                                    color: item.recommended!
                                        ? context.colors.success
                                        : secondary),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text(
                                        item.recommended!
                                            ? 'Recommends'
                                            : 'Doesn’t recommend',
                                        style: TextStyle(
                                            color: item.recommended!
                                                ? context.colors.success
                                                : secondary,
                                            fontWeight: FontWeight.w600)))
                              ])),
                  ])),
            ])),
      if (body?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 24),
        if (item.reviewData?.containsSpoilers == true && !_revealed)
          TextButton.icon(
              onPressed: () => setState(() => _revealed = true),
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('Show review · contains spoilers'))
        else
          SelectableText(body!,
              style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: context.colors.textPrimary)),
      ],
      if (list && widget.onOpenList != null)
        Padding(
            padding: const EdgeInsets.only(top: 20),
            child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                    onPressed: widget.onOpenList,
                    label: const Text('Open list'),
                    icon: const Icon(Icons.arrow_forward)))),
      const SizedBox(height: 18),
      Row(children: [
        Expanded(
            child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
              if (widget.onReact != null)
                Builder(
                    builder: (anchor) => TextButton.icon(
                        onPressed:
                            widget.busy ? null : () => widget.onReact!(anchor),
                        icon: const Icon(Icons.add_reaction_outlined),
                        style: TextButton.styleFrom(
                            foregroundColor: secondary,
                            textStyle: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                        label: const Text('React'))),
              for (final reaction in ActivityReaction.values)
                if ((widget.reactions.counts[reaction.emoji] ?? 0) > 0)
                  FlixiePill.action(
                      label: Text(
                          '${reaction.emoji} ${widget.reactions.counts[reaction.emoji]}'),
                      tooltip: reaction.label,
                      onPressed:
                          widget.busy || widget.onReactionSelected == null
                              ? null
                              : () => widget.onReactionSelected!(
                                  widget.reactions.mine == reaction.emoji
                                      ? null
                                      : reaction.emoji)),
            ])),
        if (widget.saveAction != null) widget.saveAction!
      ]),
      const SizedBox(height: 16),
    ]);
  }
}
