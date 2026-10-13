// Fictional, in-memory design preview; no account or database writes.
import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/models/profile_milestone.dart';
import 'package:flixie_app/features/profile/presentation/widgets/recent_milestones.dart';

@Preview(name: 'Recent trophy shields · phone', size: Size(390, 360))
@Preview(name: 'Recent trophy shields · tablet', size: Size(1000, 240))
Widget recentMilestonesPreview() => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
          body: Padding(
        padding: const EdgeInsets.all(20),
        child: RecentMilestones(
            data: ProfileMilestones(owner: true, items: [
          for (final entry in [
            ('10 films watched', 'Watching', 'films', 12),
            ('Movie mates', 'Together', 'movie_mates', 11),
            ('5 countries explored', 'Exploring', 'countries', 10)
          ])
            ProfileMilestone(
                id: entry.$3,
                family: entry.$3,
                group: entry.$2,
                title: entry.$1,
                description: '',
                target: 10,
                progress: 10,
                earned: true,
                earnedAt: DateTime(2026, 10, entry.$4)),
        ])),
      )),
    );
