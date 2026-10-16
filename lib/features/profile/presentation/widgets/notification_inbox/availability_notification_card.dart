import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/notification.dart';

/// Availability is an observation at the notification's date, not a playback guarantee.
class AvailabilityNotificationCard extends StatelessWidget {
  const AvailabilityNotificationCard(
      {super.key,
      required this.notification,
      required this.date,
      required this.onOptions,
      this.onOpen});
  final FlixieNotification notification;
  final String date;
  final VoidCallback onOptions;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final seasonRelease = n.event == 'NEW_SEASON_RELEASE';
    final title = n.watchMediaTitle ?? 'A title on your watchlist';
    final providers = n.data?['providerNames']?.toString() ?? 'your services';
    final country = n.data?['country']?.toString();
    final poster = n.watchMediaPosterPath;
    final type = n.data?['mediaType'] == 'tv' ? 'TV show' : 'Film';
    return Semantics(
        label: n.isRead ? null : 'Unread release alert',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
              onTap: onOpen,
              onLongPress: onOptions,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 18),
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                              width: 58,
                              height: 87,
                              child: poster != null && poster.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl:
                                          'https://image.tmdb.org/t/p/w185$poster',
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _fallback(context),
                                      placeholder: (_, __) =>
                                          _fallback(context))
                                  : _fallback(context))),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(
                                seasonRelease
                                    ? 'New season today'
                                    : 'Now on your services',
                                style: TextStyle(
                                    color: context.colors.primaryText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 5),
                            Text(title,
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    height: 1.3)),
                            const SizedBox(height: 6),
                            Text(
                                seasonRelease
                                    ? n.message
                                    : 'Added to $providers${country == null ? '' : ' · $country'}',
                                style: TextStyle(
                                    color: context.colors.white,
                                    fontSize: 14,
                                    height: 1.4)),
                            const SizedBox(height: 5),
                            Text(
                                '$type · ${seasonRelease ? 'Watched shows' : 'Your watchlist'} · $date',
                                style: TextStyle(
                                    color: context.colors.light,
                                    fontSize: 12,
                                    height: 1.4)),
                            const SizedBox(height: 5),
                            if (!seasonRelease)
                              Text('Availability via JustWatch',
                                  style: TextStyle(
                                      color: context.colors.light,
                                      fontSize: 11)),
                            if (onOpen != null)
                              TextButton(
                                  onPressed: onOpen,
                                  style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      alignment: Alignment.centerLeft,
                                      minimumSize: const Size(48, 48)),
                                  child: const Text('View title →')),
                          ])),
                      SizedBox(
                          width: 48,
                          height: 48,
                          child: IconButton(
                              onPressed: onOptions,
                              tooltip: 'Notification options',
                              icon: Icon(Icons.more_horiz,
                                  color: context.colors.light))),
                    ]),
              )),
        ));
  }

  Widget _fallback(BuildContext context) => ColoredBox(
      color: context.colors.surfaceElevated,
      child: Icon(
          notification.data?['mediaType'] == 'tv'
              ? Icons.tv_outlined
              : Icons.movie_outlined,
          color: context.colors.light));
}
