import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/activity_list_item.dart';
import 'package:flixie_app/models/activity_reaction.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'profile_avatar_view.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';

/// The flat, scan-friendly presentation for the full Activity feed.
/// Detail sheets and profile previews keep their existing presentation.
class CompactActivityPost extends StatefulWidget {
  const CompactActivityPost(
      {super.key,
      required this.item,
      required this.label,
      required this.age,
      required this.reactions,
      this.onProfile,
      this.onOpen,
      this.onOpenList,
      this.onReview,
      this.onComment,
      this.onReply,
      this.onReact,
      this.busy = false,
      this.headerAction,
      this.saveAction,
      this.onOptions,
      this.publicPost = false});
  final ActivityListItem item;
  final String label, age;
  final ActivityReactionSummary reactions;
  final VoidCallback? onProfile,
      onOpen,
      onOpenList,
      onReview,
      onComment,
      onReply,
      onOptions;
  final ValueChanged<BuildContext>? onReact;
  final Widget? headerAction, saveAction;
  final bool busy;
  final bool publicPost;
  @override
  State<CompactActivityPost> createState() => _CompactActivityPostState();
}

class _CompactActivityPostState extends State<CompactActivityPost> {
  bool revealed = false, expanded = false;
  @override
  void didUpdateWidget(covariant CompactActivityPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id ||
        oldWidget.item.type != widget.item.type) {
      revealed = false;
      expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isList = item.type == ActivityListType.movieListAdded;
    final isPerson = item.type == ActivityListType.favoritePerson;
    final hasMedia =
        item.movieId != null || item.showId != null || item.personId != null;
    final name = item.username.isNotEmpty ? item.username : item.firstName;
    final body = item.reviewData?.body ?? item.notes;
    final spoiler = item.reviewData?.containsSpoilers == true && !revealed;
    final open = isList ? widget.onOpenList : widget.onOpen;
    final rating = item.mediaRating;
    final secondary = context.colors.light;
    final title = isList
        ? item.listName ?? 'Shared list'
        : item.mediaTitle ?? 'Activity update';
    final inlineAction = MediaQuery.sizeOf(context).width >= 390 &&
        MediaQuery.textScalerOf(context).scale(14) <= 18;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 48,
              height: 48,
              child: InkWell(
                  onTap: widget.onProfile,
                  child: Center(
                      child: ProfileAvatarView(
                          avatar: item.avatar,
                          profileBadges: item.profileBadges,
                          fallbackColor: FlixieColors.primary,
                          size: 36,
                          fallbackText: name.isEmpty ? '?' : name[0])))),
          const SizedBox(width: 10),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                InkWell(
                    onTap: widget.onProfile,
                    child: Padding(
                        padding: const EdgeInsets.only(top: 3, bottom: 3),
                        child: Text(name,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w800)))),
                Text(
                    '${widget.label}${widget.age.isEmpty ? '' : ' · ${widget.age}'}',
                    style:
                        TextStyle(fontSize: 12, color: secondary, height: 1.4)),
              ])),
          if (inlineAction && widget.headerAction != null) widget.headerAction!,
          if (widget.onOptions != null)
            IconButton(
                tooltip: 'Activity options',
                onPressed: widget.onOptions,
                icon: const Icon(Icons.more_horiz)),
          if (widget.onOptions == null)
            PopupMenuButton<String>(
                tooltip: 'Activity options',
                icon: const Icon(Icons.more_horiz),
                onSelected: (value) {
                  switch (value) {
                    case 'profile':
                      widget.onProfile?.call();
                    case 'title':
                      open?.call();
                    case 'review':
                      widget.onReview?.call();
                    case 'message':
                      widget.onReply?.call();
                  }
                },
                itemBuilder: (_) => [
                      if (widget.onProfile != null)
                        const PopupMenuItem(
                            value: 'profile', child: Text('View profile')),
                      if (open != null)
                        PopupMenuItem(
                            value: 'title',
                            child: Text(isList
                                ? 'Open list'
                                : isPerson
                                    ? 'View person'
                                    : 'View title')),
                      if (widget.onReview != null)
                        const PopupMenuItem(
                            value: 'review', child: Text('View review')),
                      if (widget.onReply != null)
                        const PopupMenuItem(
                            value: 'message', child: Text('Message')),
                    ]),
        ]),
        if (!inlineAction && widget.headerAction != null)
          Padding(
              padding: const EdgeInsets.only(left: 58),
              child: widget.headerAction!),
        const SizedBox(height: 12),
        InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(8),
            child:
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              if (isList && item.listPreviewPosterPaths.isNotEmpty)
                SizedBox(
                  width: 96,
                  height: 86,
                  child: Stack(children: [
                    for (final entry in item.listPreviewPosterPaths
                        .take(3)
                        .toList()
                        .asMap()
                        .entries)
                      Positioned(
                        left: entry.key * 20.0,
                        top: entry.key.isOdd ? 4 : 0,
                        child: WatchPlanPoster(
                          path: entry.value,
                          width: 54,
                        ),
                      ),
                  ]),
                )
              else if (hasMedia && !isList)
                WatchPlanPoster(
                    path: item.mediaPosterPath,
                    title: item.mediaTitle,
                    width: isPerson ? 64 : 76)
              else
                Container(
                    width: 64,
                    height: 80,
                    decoration: BoxDecoration(
                        color: context.colors.surface,
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(
                        isList
                            ? Icons.playlist_play
                            : Icons.local_activity_outlined,
                        size: 30,
                        color: context.colors.primaryText)),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: context.colors.textPrimary,
                            height: 1.2)),
                    const SizedBox(height: 5),
                    Text(
                        isList
                            ? item.listAdditionCount == null
                                ? 'List'
                                : '${item.listAdditionCount} ${item.listAdditionCount == 1 ? 'title' : 'titles'}${hasMedia ? ' added' : ''}'
                            : isPerson
                                ? 'Person'
                                : item.showId != null
                                    ? 'TV show'
                                    : hasMedia
                                        ? 'Film'
                                        : 'Update',
                        style: TextStyle(color: secondary, fontSize: 13)),
                    if (rating != null &&
                        !isList &&
                        !isPerson &&
                        !hideMovieRatings(context, item.movieId,
                            isShow: item.showId != null, ownerId: item.userId))
                      Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Row(children: [
                            Icon(Icons.star_rounded,
                                color: context.colors.warning, size: 20),
                            const SizedBox(width: 4),
                            Flexible(
                                child: Text(
                                    '${rating.toStringAsFixed(rating % 1 == 0 ? 0 : 1)}/10',
                                    style: TextStyle(
                                        color: context.colors.warning,
                                        fontWeight: FontWeight.w700)))
                          ])),
                    if (item.recommended != null && !isList && !isPerson)
                      Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                    item.recommended!
                                        ? Icons.thumb_up_alt_outlined
                                        : Icons.thumb_down_alt_outlined,
                                    size: 16,
                                    color: item.recommended!
                                        ? context.colors.success
                                        : secondary),
                                const SizedBox(width: 6),
                                Expanded(
                                    child: Text(
                                        item.recommended!
                                            ? 'Recommends'
                                            : 'Doesn’t recommend',
                                        style: TextStyle(
                                            color: item.recommended!
                                                ? context.colors.success
                                                : secondary,
                                            fontSize: 13)))
                              ])),
                  ])),
            ])),
        if (body?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          if (spoiler)
            TextButton.icon(
                onPressed: () => setState(() => revealed = true),
                icon: const Icon(Icons.visibility_off_outlined, size: 18),
                label: const Text('Show review · contains spoilers'))
          else
            LayoutBuilder(builder: (context, constraints) {
              final style = TextStyle(
                  fontSize: 15,
                  color: context.colors.textPrimary,
                  height: 1.45);
              final painter = TextPainter(
                  text: TextSpan(text: body, style: style),
                  textDirection: Directionality.of(context),
                  textScaler: MediaQuery.textScalerOf(context),
                  maxLines: 3)
                ..layout(maxWidth: constraints.maxWidth);
              final long = painter.didExceedMaxLines;
              painter.dispose();
              return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(body!,
                        style: style,
                        maxLines: expanded ? null : 3,
                        overflow: expanded
                            ? TextOverflow.visible
                            : TextOverflow.ellipsis),
                    if (long)
                      TextButton(
                          onPressed: () => setState(() => expanded = !expanded),
                          child: Text(expanded ? 'Show less' : 'Read more'))
                  ]);
            }),
        ],
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
              child: Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                Builder(
                    builder: (anchor) => TextButton.icon(
                        onPressed: widget.busy || widget.onReact == null
                            ? null
                            : () => widget.onReact!(anchor),
                        icon: Icon(Icons.add_reaction_outlined,
                            color: widget.reactions.mine != null
                                ? context.colors.primaryText
                                : secondary,
                            size: 22),
                        label: const Text('React'),
                        style:
                            TextButton.styleFrom(foregroundColor: secondary))),
                for (final entry in widget.reactions.counts.entries)
                  if (entry.value > 0)
                    Semantics(
                        label: '${entry.key}: ${entry.value} reactions',
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: entry.key == widget.reactions.mine
                                    ? context.colors.primaryText
                                    : Colors.transparent),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(entry.key,
                                style:
                                    const TextStyle(fontSize: 16, height: 1)),
                            const SizedBox(width: 6),
                            Text('${entry.value}',
                                style:
                                    const TextStyle(fontSize: 13, height: 1)),
                          ]),
                        )),
                if (widget.onComment != null)
                  widget.publicPost
                      ? TextButton.icon(
                          onPressed: widget.onComment,
                          icon:
                              const Icon(Icons.arrow_forward_rounded, size: 16),
                          label: const Text('View post'),
                          style: TextButton.styleFrom(
                              foregroundColor: context.colors.primaryText,
                              minimumSize: const Size(44, 44),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              textStyle: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500)))
                      : IconButton(
                          tooltip: 'Comments',
                          onPressed: widget.onComment,
                          icon: Icon(Icons.chat_bubble_outline,
                              color: secondary, size: 22)),
              ])),
          if (widget.saveAction != null) widget.saveAction!,
        ]),
        const SizedBox(height: 10),
        Divider(height: 1, color: context.colors.medium.withValues(alpha: .35)),
      ]),
    );
  }
}
