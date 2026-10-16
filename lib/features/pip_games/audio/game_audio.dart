import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared device preferences for the three offline/online arcade games.
class GameAudioSettings extends ChangeNotifier {
  static final instance = GameAudioSettings();
  bool music = true, effects = true;
  double musicVolume = .14;
  Future<void>? _loaded;
  Future<void> _writes = Future.value();
  Future<void> load() => _loaded ??= _load();
  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      music = prefs.getBool('pip.audio.music') ?? true;
      effects = prefs.getBool('pip.audio.effects') ?? true;
      musicVolume = (prefs.getDouble('pip.audio.volume') ?? .14).clamp(0, .35);
    } catch (error) {
      debugPrint('Game audio preferences unavailable: $error');
    }
    notifyListeners();
  }

  Future<void> update({bool? music, bool? effects, double? volume}) async {
    await load();
    this.music = music ?? this.music;
    this.effects = effects ?? this.effects;
    musicVolume = (volume ?? musicVolume).clamp(0, .35);
    notifyListeners();
    final m = this.music, e = this.effects, v = musicVolume;
    _writes = _writes.then((_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pip.audio.music', m);
        await prefs.setBool('pip.audio.effects', e);
        await prefs.setDouble('pip.audio.volume', v);
      } catch (error) {
        debugPrint('Could not save game audio preferences: $error');
      }
    });
    await _writes;
  }
}

abstract class GameAudioBackend {
  Future<void> music(String asset, double volume);
  Future<void> pauseMusic();
  Future<void> effect(String asset, double volume);
  Future<void> stopEffects();
  Future<void> dispose();
}

/// Native players are created lazily, never during a game controller's tick.
class NativeGameAudioBackend implements GameAudioBackend {
  AudioPlayer? _music;
  String? _track;
  final _effects = <AudioPlayer>[];
  int _slot = 0;
  final _context = AudioContext(
    iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    android: const AudioContextAndroid(
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none,
    ),
  );
  Future<AudioPlayer> _player() async {
    final player = AudioPlayer();
    await player.setAudioContext(_context);
    return player;
  }

  @override
  Future<void> music(String asset, double volume) async {
    final player = _music ??= await _player();
    await player.setVolume(volume);
    if (_track != asset) {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('audio/pip_games/$asset.wav'));
      _track = asset;
    } else if (player.state != PlayerState.playing) {
      await player.resume();
    }
  }

  @override
  Future<void> pauseMusic() async => _music?.pause();

  @override
  Future<void> effect(String asset, double volume) async {
    if (_effects.length < 4) _effects.add(await _player());
    final player = _effects[_slot++ % _effects.length];
    await player.stop();
    await player.play(AssetSource('audio/pip_games/$asset.wav'),
        volume: volume);
  }

  @override
  Future<void> stopEffects() async {
    for (final player in _effects) {
      await player.stop();
    }
  }

  @override
  Future<void> dispose() async {
    if (_music != null) await _music!.dispose();
    for (final player in _effects) {
      await player.dispose();
    }
  }
}

/// Serializes native operations; invalidates pending effects on pause/mute/exit.
class GameAudioSession {
  GameAudioSession(this.track,
      {GameAudioSettings? settings, GameAudioBackend? backend})
      : settings = settings ?? GameAudioSettings.instance,
        _backend = backend ?? backendFactory() {
    this.settings.addListener(_changed);
    unawaited(this.settings.load());
  }
  @visibleForTesting
  static GameAudioBackend Function() backendFactory =
      NativeGameAudioBackend.new;
  final String track;
  final GameAudioSettings settings;
  final GameAudioBackend _backend;
  Future<void> _queue = Future.value();
  bool _playing = false, _foreground = true, _closed = false;
  int _generation = 0;
  bool get _audible => !_closed && _foreground;
  Future<void> get settled => _queue;

  void _run(Future<void> Function() action) {
    _queue = _queue.then((_) async {
      try {
        await action();
      } catch (error) {
        debugPrint('Game audio unavailable: $error');
      }
    });
  }

  void setPlaying(bool value) {
    if (_playing == value) return;
    _playing = value;
    _changed();
  }

  void setForeground(bool value) {
    if (_foreground == value) return;
    _foreground = value;
    _changed();
  }

  void _changed() {
    _generation++;
    _run(() async {
      await settings.load();
      if (_audible && _playing && settings.music) {
        await _backend.music('$track-music', settings.musicVolume);
      } else {
        await _backend.pauseMusic();
      }
      if (!_audible || !settings.effects) await _backend.stopEffects();
    });
  }

  void play(String effect) {
    if (!_audible) return;
    final generation = _generation;
    _run(() async {
      await settings.load();
      if (!_audible || !settings.effects || generation != _generation) return;
      await _backend.effect(effect, effect == 'space-laser' ? .30 : .60);
    });
  }

  Future<void> close() {
    if (_closed) return _queue;
    _closed = true;
    _generation++;
    settings.removeListener(_changed);
    _run(_backend.dispose);
    return _queue;
  }
}
