import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/models/movie_credits.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

class CastCard extends StatelessWidget {
  const CastCard({super.key, required this.member});

  final MovieCastMember member;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/people/${member.id}'),
        child: Container(
          width: 112,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: FlixieColors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: 100,
                decoration: BoxDecoration(
                  color: FlixieColors.surface,
                  borderRadius: BorderRadius.circular(10),
                ),
                clipBehavior: Clip.antiAlias,
                child: member.profileImageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: member.profileImageUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _avatarFallback(),
                      )
                    : _avatarFallback(),
              ),
              const SizedBox(height: 7),
              Text(
                member.name,
                style: const TextStyle(
                  color: FlixieColors.light,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (member.character.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  member.character,
                  style: const TextStyle(
                    color: FlixieColors.medium,
                    fontSize: 10.5,
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
