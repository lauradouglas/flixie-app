import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flixie_app/models/movie_video.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video});

  final MovieVideo video;

  static TextStyle _titleStyle(BuildContext context) =>
      DefaultTextStyle.of(context).style.merge(TextStyle(
        color: context.colors.light,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ));

  static double carouselHeight(BuildContext context, List<MovieVideo> videos) {
    var titleHeight = 0.0;
    for (final video in videos) {
      final painter = TextPainter(
        text: TextSpan(text: video.name, style: _titleStyle(context)),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: 270);
      if (painter.height > titleHeight) titleHeight = painter.height;
      painter.dispose();
    }
    return 146 + 8 + titleHeight.ceilToDouble();
  }

  Future<void> _launchVideo(BuildContext context) async {
    final url = video.youtubeUrl;
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Could not open video'),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        }
        logger.w('Could not launch YouTube URL: $url');
      }
    } catch (e) {
      logger.e('Error launching video', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
            type: FlixieToastType.error,
            content: const Text('Error opening video'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _launchVideo(context),
      child: SizedBox(
        width: 270,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 146,
                  width: 270,
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _thumbnailFallback(context),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video.name,
              style: _titleStyle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback(BuildContext context) {
    return Container(
      color: context.colors.surfaceElevated,
      child: Center(
        child: Icon(
          Icons.play_circle_outline,
          color: context.colors.medium,
          size: 48,
        ),
      ),
    );
  }
}
