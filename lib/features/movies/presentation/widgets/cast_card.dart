import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/analytics/detail_source.dart';

class CastCard extends StatelessWidget {
  const CastCard({
    super.key,
    required this.member,
    required this.parentContentId,
    required this.parentContentType,
  });

  final MovieCastMember member;
  final int parentContentId;
  final String parentContentType;

  static double widthFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 700 ? 220 : 132;

  static double heightFor(BuildContext context) {
    final width = widthFor(context);
    return (width * 1.5) + 72;
  }

  @override
  Widget build(BuildContext context) {
    final cardWidth = widthFor(context);
    final imageHeight = cardWidth * 1.5;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push(personDetailPath(
          member.id,
          source: DetailSource.personCredits,
          parentContentId: parentContentId,
          parentContentType: parentContentType,
        )),
        child: SizedBox(
          width: cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: member.profileImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: member.profileImageUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _avatarFallback(),
                        )
                      : _avatarFallback(),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 36,
                child: Text(
                  member.name,
                  style: const TextStyle(
                    color: FlixieColors.light,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    height: 1.16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (member.character.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  member.character,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: FlixieColors.surfaceElevated,
      child: const Center(
        child: Icon(Icons.person, color: FlixieColors.medium, size: 40),
      ),
    );
  }
}
