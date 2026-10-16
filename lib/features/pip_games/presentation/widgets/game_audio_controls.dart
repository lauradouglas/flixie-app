import 'dart:async';
import 'package:flutter/material.dart';
import '../../audio/game_audio.dart';

/// Keeps sound behind the current game route and out of the background.
class GameAudioBoundary extends StatefulWidget {
  const GameAudioBoundary(
      {super.key, required this.audio, required this.child});
  final GameAudioSession audio;
  final Widget child;
  @override
  State<GameAudioBoundary> createState() => _GameAudioBoundaryState();
}

class _GameAudioBoundaryState extends State<GameAudioBoundary>
    with WidgetsBindingObserver {
  bool _resumed = true;
  bool _current = true;
  @override
  void initState() {
    super.initState();
    _resumed = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _current = ModalRoute.isCurrentOf(context) ?? true;
    widget.audio.setForeground(_resumed && _current);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _resumed = state == AppLifecycleState.resumed;
    widget.audio.setForeground(_resumed && _current);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class GameAudioButton extends StatelessWidget {
  const GameAudioButton({super.key, this.onOpen});
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Game audio',
        icon: const Icon(Icons.volume_up_rounded),
        onPressed: () {
          onOpen?.call();
          showModalBottomSheet<void>(
            context: context,
            useRootNavigator: true,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: const Color(0xFF211332),
            builder: (context) => const _AudioSheet(),
          );
        },
      );
}

class _AudioSheet extends StatelessWidget {
  const _AudioSheet();
  @override
  Widget build(BuildContext context) {
    final settings = GameAudioSettings.instance;
    unawaited(settings.load());
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 24),
        child: ListenableBuilder(
            listenable: settings,
            builder: (context, _) => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Game audio',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800))),
                    SwitchListTile(
                        title: const Text('Background music',
                            style: TextStyle(color: Colors.white)),
                        value: settings.music,
                        onChanged: (value) => settings.update(music: value)),
                    SwitchListTile(
                        title: const Text('Sound effects',
                            style: TextStyle(color: Colors.white)),
                        value: settings.effects,
                        onChanged: (value) => settings.update(effects: value)),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Music volume',
                            style: TextStyle(color: Color(0xFFFFF0C8)))),
                    Slider(
                        value: settings.musicVolume,
                        min: 0,
                        max: .35,
                        label: '${(settings.musicVolume * 100).round()}%',
                        semanticFormatterCallback: (v) =>
                            '${(v * 100).round()} percent',
                        onChanged: settings.music
                            ? (value) => settings.update(volume: value)
                            : null),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Saved for all Pip games.',
                            style: TextStyle(color: Color(0xFFD2BCE9)))),
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done')),
                  ],
                )),
      ),
    );
  }
}
