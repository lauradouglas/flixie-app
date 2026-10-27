import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/core/utils/color_utils.dart';
import 'package:flixie_app/models/movie_watch_entry.dart';
import '../widgets/profile_avatar_view.dart';
import 'diary_calendar_sheet.dart';
import 'diary_selection.dart';

class DiaryWatchEntry extends StatelessWidget {
  const DiaryWatchEntry(
      {super.key, required this.entry, this.rewatch = false, this.onEdit});
  final MovieWatchEntry entry;
  final bool rewatch;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final date = diaryWatchDay(entry), path = entry.movie?.posterPath;
    final title = entry.movie?.title ?? 'View film';
    final people = {
      for (final p in [...entry.allCompanions, ...entry.groupCompanions])
        p.id: p
    }.values.toList();
    final local = MaterialLocalizations.of(context);
    Widget text(String s, double size,
            {FontWeight weight = FontWeight.w500, Color color = diaryInk}) =>
        Text(s,
            style: TextStyle(
                color: color, fontSize: size, fontWeight: weight, height: 1.4));
    final details =
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: InkWell(
                onTap: () => context.push('/movies/${entry.movieId}'),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: text(title, 19, weight: FontWeight.w800)))),
        if (onEdit != null)
          IconButton(
              tooltip: 'Edit memory',
              onPressed: onEdit,
              icon: const Icon(Icons.more_horiz, color: diaryMuted)),
      ]),
      Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (entry.rating != null)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded,
                    color: Color(0xff8b5b13), size: 18),
                const SizedBox(width: 4),
                text(
                    '${entry.rating!.toStringAsFixed(entry.rating! % 1 == 0 ? 0 : 1)}/10',
                    13,
                    weight: FontWeight.w700)
              ]),
            if (rewatch) text('Rewatch', 12, color: diaryMuted),
            if (entry.watchedAtCinema)
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.theaters_outlined,
                    size: 16, color: diaryMuted),
                const SizedBox(width: 4),
                text('Cinema', 12, color: diaryMuted)
              ]),
          ]),
      if (entry.notes?.trim().isNotEmpty == true) ...[
        const SizedBox(height: 7),
        text(entry.notes!, 13, color: diaryMuted)
      ],
      // Reviews are deliberately opened on the existing title screen; no spoiler text leaks here.
      if (people.isNotEmpty) ...[
        const SizedBox(height: 10),
        text('Watched with', 11, color: diaryMuted),
        const SizedBox(height: 7),
        LayoutBuilder(
            builder: (context, box) =>
                Wrap(spacing: 12, runSpacing: 10, children: [
                  for (final person in people)
                    ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: box.maxWidth),
                        child: InkWell(
                          onTap: () => context.push('/friends/${person.id}'),
                          child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ProfileAvatarView(
                                        avatar: person.avatar,
                                        fallbackText: person.username.isEmpty
                                            ? '?'
                                            : person.username[0],
                                        fallbackColor: avatarColorFromIconColor(
                                            person.iconColor),
                                        profileBadges: person.profileBadges,
                                        size: 28),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: text(person.username, 12,
                                            weight: FontWeight.w700)),
                                  ])),
                        )),
                ]))
      ],
      if (entry.externalInvite?.displayName.isNotEmpty == true) ...[
        const SizedBox(height: 8),
        text('With ${entry.externalInvite!.displayName}', 12, color: diaryMuted)
      ],
    ]);
    final poster = ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: SizedBox(
            width: 58,
            height: 87,
            child: path == null || path.isEmpty
                ? const ColoredBox(
                    color: Color(0xffe2d5ef),
                    child: Icon(Icons.movie_outlined, color: diaryMuted))
                : CachedNetworkImage(
                    imageUrl: path.startsWith('https://')
                        ? path
                        : 'https://image.tmdb.org/t/p/w185$path',
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xffe2d5ef),
                        child:
                            Icon(Icons.movie_outlined, color: diaryMuted)))));
    return LayoutBuilder(builder: (context, box) {
      final large =
          MediaQuery.textScalerOf(context).scale(1) > 1.4 || box.maxWidth < 300;
      return Padding(
          // Companion links already reserve 10px below the visible avatar for
          // their touch target. Count that space in the 16px row gutter.
          padding: EdgeInsets.only(
              top: 16,
              bottom: people.isNotEmpty &&
                      entry.externalInvite?.displayName.isNotEmpty != true
                  ? 6
                  : 16),
          child: large
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (date != null)
                    text(local.formatShortDate(date), 13, color: diaryMuted),
                  const SizedBox(height: 8),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    poster,
                    const SizedBox(width: 16),
                    Expanded(child: details)
                  ])
                ])
              : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (date != null) ...[
                    SizedBox(
                        width: 38,
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              text('${date.day}', 25, weight: FontWeight.w800),
                              text(local.narrowWeekdays[date.weekday % 7], 10,
                                  color: diaryMuted)
                            ])),
                    const SizedBox(width: 8)
                  ],
                  poster,
                  const SizedBox(width: 14),
                  Expanded(child: details)
                ]));
    });
  }
}
