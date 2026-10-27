import 'package:flixie_app/core/widgets/preference_switch.dart';
import 'package:flutter/material.dart';
import '../../controllers/onboarding_controller.dart';
import 'package:flixie_app/features/settings/data/episode_spoiler_preference.dart';
import 'package:flixie_app/features/settings/presentation/widgets/movie_rating_privacy_setting.dart';

class OnboardingPreferencesStep extends StatelessWidget {
  const OnboardingPreferencesStep({super.key, required this.controller});
  final OnboardingController controller;

  @override
  Widget build(BuildContext context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _preferences(context));
  List<Widget> _preferences(BuildContext context) => [
        ListenableBuilder(
            listenable: EpisodeSpoilerPreference.instance,
            builder: (context, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hide episode spoilers'),
                subtitle: const Text('Keep unwatched episode details hidden.'),
                trailing: PreferenceSwitch(
                    loading: !EpisodeSpoilerPreference.instance.loadFailed,
                    value: EpisodeSpoilerPreference.instance.loaded
                        ? EpisodeSpoilerPreference.instance.hide
                        : null,
                    onChanged: controller.busy
                        ? null
                        : (value) => controller.run(() =>
                            EpisodeSpoilerPreference.instance
                                .setHidden(value))))),
        const MovieRatingPrivacySetting(
            showIcon: false, contentPadding: EdgeInsets.zero),
        const SizedBox(height: 16),
        Text('You can change both in Settings anytime.',
            style: Theme.of(context).textTheme.bodySmall),
      ];
}
