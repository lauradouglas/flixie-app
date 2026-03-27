import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/movie_credits.dart';
import '../../theme/app_theme.dart';

class CastCard extends StatelessWidget {
  const CastCard({super.key, required this.member});

  final MovieCastMember member;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/people/${member.id}'),
      child: SizedBox(
        width: 100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF1B2E42),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: member.profileImage != null
                  ? CachedNetworkImage(
                      imageUrl:
                          'https://image.tmdb.org/t/p/w185${member.profileImage}',
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _avatarFallback(),
                    )
                  : _avatarFallback(),
            ),
            const SizedBox(height: 6),
            Text(
              member.name,
              style: const TextStyle(
                color: FlixieColors.light,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              member.character,
              style: const TextStyle(
                color: FlixieColors.medium,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      color: const Color(0xFF253A50),
      child: const Center(
        child: Icon(Icons.person, color: FlixieColors.medium, size: 40),
      ),
    );
  }
}
