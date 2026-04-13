import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../models/group_watch_request.dart' show GroupWatchRequest;
import '../../theme/app_theme.dart';

class PendingRequestPreviewTile extends StatelessWidget {
  const PendingRequestPreviewTile({
    super.key,
    required this.request,
    required this.canRespond,
    required this.onRespond,
  });

  final GroupWatchRequest request;
  final bool canRespond;
  final void Function(String status) onRespond;

  @override
  Widget build(BuildContext context) {
    final abbr = (request.requesterUsername?.isNotEmpty == true)
        ? request.requesterUsername![0].toUpperCase()
        : 'R';
    final posterUrl = request.moviePosterPath != null
        ? 'https://image.tmdb.org/t/p/w185${request.moviePosterPath}'
        : null;
    return Container(
      clipBehavior: Clip.hardEdge,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: FlixieColors.primary, width: 3),
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Text content
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          FlixieColors.primary.withValues(alpha: 0.2),
                      child: Text(
                        abbr,
                        style: const TextStyle(
                          color: FlixieColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            request.requesterUsername ?? 'Unknown',
                            style: const TextStyle(
                              color: FlixieColors.light,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (request.movieTitle != null)
                            Text(
                              request.movieTitle!,
                              style: const TextStyle(
                                  color: FlixieColors.medium, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (request.message != null &&
                              request.message!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: FlixieColors.primary
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: FlixieColors.primary
                                        .withValues(alpha: 0.25)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_outline,
                                      size: 11, color: FlixieColors.primary),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      request.message!,
                                      style: const TextStyle(
                                        color: FlixieColors.light,
                                        fontSize: 11,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (canRespond) ...[
                      IconButton(
                        onPressed: () => onRespond('DECLINED'),
                        icon: const Icon(Icons.close,
                            color: FlixieColors.danger, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => onRespond('ACCEPTED'),
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: FlixieColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.check,
                              color: FlixieColors.primary, size: 18),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Poster flush to right
            SizedBox(
              width: 80,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  posterUrl != null
                      ? CachedNetworkImage(
                          imageUrl: posterUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: FlixieColors.tabBarBorder,
                            child: const Icon(Icons.movie_outlined,
                                color: FlixieColors.medium),
                          ),
                        )
                      : Container(
                          color: FlixieColors.tabBarBorder,
                          child: const Icon(Icons.movie_outlined,
                              color: FlixieColors.medium),
                        ),
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          FlixieColors.tabBarBackgroundFocused,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.25],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
