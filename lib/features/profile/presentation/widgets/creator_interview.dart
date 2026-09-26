import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/models/creator_profile.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/shared/watch_plan_components.dart';

class CreatorInterview extends StatelessWidget {
  const CreatorInterview({super.key, required this.profile});
  final CreatorProfile profile;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in [...profile.credits, ...profile.answers]) ...[
            Text(entry.question,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (entry.movieId != null && entry.title != null)
              InkWell(
                onTap: () => context.push('/movies/${entry.movieId}'),
                child: Row(children: [
                  WatchPlanPoster(
                      path: entry.posterPath, title: entry.title, width: 64),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Text(entry.title!,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_right),
                ]),
              ),
            const SizedBox(height: 10),
            Text(entry.answer,
                style: TextStyle(color: context.colors.light, height: 1.5)),
            const SizedBox(height: 28),
          ],
        ],
      );
}
