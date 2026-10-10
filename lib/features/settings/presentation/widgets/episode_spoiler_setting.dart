import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import '../../data/episode_spoiler_preference.dart';
import 'settings_tile.dart';

class EpisodeSpoilerSetting extends StatefulWidget {
  const EpisodeSpoilerSetting({super.key});

  @override
  State<EpisodeSpoilerSetting> createState() => EpisodeSpoilerSettingState();
}

class EpisodeSpoilerSettingState extends State<EpisodeSpoilerSetting> {
  final preference = EpisodeSpoilerPreference.instance;

  @override
  void initState() {
    super.initState();
    preference.load().catchError((Object _) {});
  }

  Future<void> _change(bool value) async {
    try {
      await preference.setHidden(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
            type: FlixieToastType.error,
            content: const Text(
                'Couldn’t save your spoiler preference. Please try again.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: preference,
        builder: (context, _) => SettingsTile(
          icon: Icons.visibility_off_outlined,
          label: 'Hide episode spoilers',
          description:
              'Hide titles, images and descriptions for episodes you haven’t watched.',
          onTap: () {
            if (!preference.saving) _change(!preference.hide);
          },
          trailing: Switch.adaptive(
            value: preference.hide,
            onChanged: preference.saving ? null : _change,
          ),
        ),
      );
}
