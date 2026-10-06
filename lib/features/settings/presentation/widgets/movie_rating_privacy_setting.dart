import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/features/settings/data/movie_rating_privacy.dart';
import 'settings_tile.dart';

class MovieRatingPrivacySetting extends StatelessWidget {
  const MovieRatingPrivacySetting(
      {super.key, this.showIcon = true, this.contentPadding});
  final bool showIcon;
  final EdgeInsetsGeometry? contentPadding;
  @override
  Widget build(BuildContext context) {
    final privacy = context.watch<MovieRatingPrivacy?>();
    if (privacy == null) return const SizedBox.shrink();
    Future<void> change(bool value) async {
      try {
        await privacy.setEnabled(value);
      } catch (_) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content:
                const Text('Couldn’t save your rating preference. Try again.'),
          ));
        }
      }
    }

    final canChange = privacy.loaded && !privacy.saving;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showIcon)
        SettingsTile(
          icon: Icons.visibility_off_outlined,
          label: 'Rate movies first',
          description:
              'Hide other people’s movie scores until you’ve rated the movie. TV ratings stay visible.',
          onTap: () {
            if (canChange) change(!privacy.enabled);
          },
          trailing: Switch.adaptive(
            value: privacy.enabled,
            onChanged: canChange ? change : null,
          ),
        )
      else
        SwitchListTile.adaptive(
          contentPadding: contentPadding,
          title: const Text('Rate movies first'),
          subtitle: const Text(
              'Hide other people’s movie scores until you’ve rated the movie. TV ratings stay visible.'),
          value: privacy.enabled,
          onChanged: canChange ? change : null,
        ),
      if (privacy.enabled && privacy.ratingsFailed)
        Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
                onPressed: privacy.refreshRatings,
                child: const Text(
                    'Scores stay hidden while your ratings are unavailable. Retry'))),
    ]);
  }
}
