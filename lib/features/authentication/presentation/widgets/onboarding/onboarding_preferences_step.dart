import 'package:flutter/material.dart';
import '../../controllers/onboarding_controller.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import 'package:flixie_app/features/settings/presentation/widgets/around_flixie_sharing_setting.dart';
import 'package:flixie_app/features/settings/presentation/widgets/movie_rating_privacy_setting.dart';

class OnboardingPreferencesStep extends StatelessWidget {
  const OnboardingPreferencesStep({super.key, required this.controller});
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _sharingPreferences(context));
  List<Widget> _preferences(BuildContext context) => [
        ListenableBuilder(
            listenable: EpisodeSpoilerPreference.instance,
            builder: (context, _) => SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hide episode spoilers'),
                subtitle: const Text('Keep unwatched episode details hidden.'),
                value: EpisodeSpoilerPreference.instance.hide,
                onChanged: controller.busy
                    ? null
                    : (value) => controller.run(() =>
                        EpisodeSpoilerPreference.instance.setHidden(value)))),
        const MovieRatingPrivacySetting(
            showIcon: false, contentPadding: EdgeInsets.zero),
        const SizedBox(height: 16),
        Text('You can change both in Settings anytime.',
            style: Theme.of(context).textTheme.bodySmall),
      ];
  List<Widget> _sharingPreferences(BuildContext context) => [
        const SizedBox(height: 16),
        AroundFlixieSharingSetting(
          key: ValueKey('signup-sharing-$controller.userId'),
          enabled: !controller.busy,
          contentPadding: EdgeInsets.zero,
          load: controller.service.sharing,
          save: controller.service.setSharing,
          onBusyChanged: (busy) {
            controller.setBusy(busy);
          },
        ),
        const SizedBox(height: 28),
        Text('Your viewing preferences',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        ..._preferences(context),
      ];
}
