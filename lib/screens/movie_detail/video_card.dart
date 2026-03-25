import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/movie_video.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({super.key, required this.video});

  final MovieVideo video;

  Future<void> _launchVideo(BuildContext context) async {
    final url = video.youtubeUrl;
    final uri = Uri.parse(url);

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open video'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
        logger.w('Could not launch YouTube URL: $url');
      }
    } catch (e) {
      logger.e('Error launching video', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening video'),
            backgroundColor: Color(0xFFEF4444),
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
        width: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 170,
                  width: 300,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2E42),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: CachedNetworkImage(
                    imageUrl: video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => _thumbnailFallback(),
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
                        Icons.play_circle_filled,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              video.name,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _thumbnailFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          color: FlixieColors.medium,
          size: 48,
        ),
      ),
    );
  }
}
