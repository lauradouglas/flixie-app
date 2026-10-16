import 'package:flixie_app/features/space_premiere/presentation/pages/space_premiere_screen.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/features/pip_games/audio/game_audio.dart';
import 'package:flixie_app/features/pip_games/presentation/widgets/game_audio_controls.dart';
import 'package:flixie_app/features/pip_pairs/presentation/controllers/pip_pairs_controller.dart';
import 'package:flixie_app/features/space_premiere/domain/space_engine.dart';
import 'package:flixie_app/features/space_premiere/presentation/controllers/space_controller.dart';
import 'package:flixie_app/features/popcorn_catch/domain/popcorn_engine.dart';
import 'package:flixie_app/features/popcorn_catch/presentation/controllers/popcorn_controller.dart';
import '../../support/fake_game_audio.dart';

class UnavailableAudioBackend extends FakeGameAudioBackend {
  @override
  Future<void> music(String asset, double volume) async =>
      throw StateError('Audio device unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
      'quiet music loops only while playing; background/mute invalidates pending effects',
      () async {
    final settings = GameAudioSettings();
    await settings.load();
    final native = FakeGameAudioBackend();
    final audio =
        GameAudioSession('space', settings: settings, backend: native);
    audio.setPlaying(true);
    await audio.settled;
    expect(native.calls, contains('music:space-music:0.14'));
    audio.play('space-laser');
    await audio.settled;
    expect(native.calls, contains('effect:space-laser'));
    native.calls.clear();
    audio.play('space-laser');
    audio.setForeground(false);
    await audio.settled;
    expect(native.calls, isNot(contains('effect:space-laser')));
    expect(native.calls, containsAll(['pause', 'stopEffects']));
    audio.setForeground(true);
    await audio.settled;
    expect(native.calls, contains('music:space-music:0.14'));
    await settings.update(music: false, effects: false);
    await audio.settled;
    native.calls.clear();
    audio.play('space-laser');
    await audio.settled;
    expect(native.calls, isEmpty);
    await audio.close();
    audio.play('space-laser');
    await audio.settled;
    expect(native.calls, ['dispose']);
    settings.dispose();
  });

  test('native playback failure cannot break effects, settings or disposal',
      () async {
    final settings = GameAudioSettings();
    await settings.load();
    final native = UnavailableAudioBackend();
    final audio =
        GameAudioSession('pairs', settings: settings, backend: native);
    audio.setPlaying(true);
    await audio.settled;
    audio.play('pairs-flip');
    await audio.settled;
    expect(native.calls, contains('effect:pairs-flip'));
    await settings.update(music: false);
    await audio.settled;
    expect(native.calls, contains('pause'));
    await audio.close();
    expect(native.calls.last, 'dispose');
    settings.dispose();
  });

  test('music and effects settings persist independently across sessions',
      () async {
    final settings = GameAudioSettings();
    await settings.update(music: false, effects: true, volume: .09);
    final restored = GameAudioSettings();
    await restored.load();
    expect(restored.music, isFalse);
    expect(restored.effects, isTrue);
    expect(restored.musicVolume, .09);
    settings.dispose();
    restored.dispose();
  });

  test(
      'pairs plays flips, match, mismatch and completion only for accepted actions',
      () {
    final game = PipPairsController(random: Random(3));
    final sounds = <String>[];
    game.onSound = sounds.add;
    final firstId = game.cards.first.id;
    final match = game.cards.indexWhere((c) => c.id == firstId, 1);
    game.flip(0);
    game.flip(0);
    game.flip(match);
    expect(sounds, ['pairs-flip', 'pairs-match']);
    final unseen = List.generate(game.cards.length, (i) => i)
        .where((i) => !game.isMatched(i))
        .toList();
    final other = unseen
        .firstWhere((i) => game.cards[i].id != game.cards[unseen.first].id);
    game.flip(unseen.first);
    game.flip(other);
    expect(sounds.last, 'pairs-mismatch');
    game.hideMismatch();
    expect(sounds.last, 'pairs-flip');
    for (var i = 0; i < game.cards.length; i++) {
      if (game.isMatched(i)) continue;
      game.flip(i);
      game.flip(game.cards.indexWhere((c) => c.id == game.cards[i].id, i + 1));
    }
    expect(game.complete, isTrue);
    expect(sounds.last, 'pairs-complete');
    game.dispose();
  });

  test('space laser, collision, shield, heart and wave events follow gameplay',
      () {
    final c = SpaceController();
    final sounds = <String>[];
    c.onSound = sounds.add;
    c.start();
    c.advance(const Duration(milliseconds: 20));
    expect(sounds, contains('space-laser'));
    sounds.clear();
    final enemy = c.engine.invaders.first;
    c.engine.shots.add(SpaceShot(enemy.x, enemy.y + 6));
    c.advance(const Duration(milliseconds: 20));
    expect(sounds, contains('space-enemy'));
    c.engine.enemyShots.add(SpaceShot(c.engine.shields.first.x, 400));
    c.advance(const Duration(milliseconds: 20));
    expect(sounds, contains('space-shield'));
    c.engine.enemyShots.add(SpaceShot(c.engine.x, 478));
    c.advance(const Duration(milliseconds: 20));
    expect(sounds, contains('space-heart'));
    c.engine.invaders.clear();
    c.advance(const Duration(milliseconds: 20));
    expect(sounds, contains('space-wave'));
    c.dispose();
  });

  test(
      'popcorn catch, gold, burnt and streak effects follow authoritative tick events',
      () {
    final c = PopcornController(userId: null);
    final sounds = <String>[];
    c.onSound = sounds.add;
    c.startPractice();
    for (var i = 0; i < 60; i++) {
      c.advance(const Duration(milliseconds: 50));
    }
    void catchKind(int kind) {
      c.engine.kernels.clear();
      c.engine.kernels
          .add(PopcornKernel(c.engine.x, c.engine.tick - 1, 1, kind));
      c.advance(const Duration(milliseconds: 50));
    }

    catchKind(4);
    expect(sounds.last, 'popcorn-catch');
    catchKind(9);
    expect(sounds.last, 'popcorn-gold');
    c.engine.combo = 4;
    catchKind(4);
    expect(sounds.last, 'popcorn-streak');
    catchKind(0);
    expect(sounds.last, 'popcorn-burnt');
    c.dispose();
  });

  testWidgets('audio sheet saves toggles, fits small phone and large text',
      (tester) async {
    await GameAudioSettings.instance.update(music: true, effects: true);
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 568), textScaler: TextScaler.linear(2)),
            child:
                Scaffold(appBar: AppBar(actions: const [GameAudioButton()])))));
    await tester.tap(find.byTooltip('Game audio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Background music'));
    await tester.pumpAndSettle();
    expect(GameAudioSettings.instance.music, isFalse);
    expect(GameAudioSettings.instance.effects, isTrue);
    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();
    expect(GameAudioSettings.instance.effects, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('covering or leaving a game and backgrounding stops its audio',
      (tester) async {
    final native = FakeGameAudioBackend();
    final settings = GameAudioSettings();
    await settings.load();
    final audio = GameAudioSession('pairs', backend: native, settings: settings)
      ..setPlaying(true);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        home: GameAudioBoundary(
            audio: audio, child: const Scaffold(body: Text('Game')))));
    await tester.pumpAndSettle();
    await audio.settled;
    native.calls.clear();
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other page'))));
    await tester.pumpAndSettle();
    await audio.settled;
    expect(native.calls, contains('pause'));
    native.calls.clear();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    await audio.settled;
    expect(native.calls.any((v) => v.startsWith('music:')), isTrue);
    native.calls.clear();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    await audio.settled;
    expect(native.calls, contains('stopEffects'));
    await audio.close();
    settings.dispose();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('opening audio controls pauses the running space game',
      (tester) async {
    GameAudioSession.backendFactory = FakeGameAudioBackend.new;
    addTearDown(() {
      GameAudioSession.backendFactory = NativeGameAudioBackend.new;
    });
    final c = SpaceController()..start(practice: true);
    await tester
        .pumpWidget(MaterialApp(home: SpacePremiereScreen(controller: c)));
    await tester.pump();
    await tester.tap(find.byTooltip('Game audio'));
    await tester.pumpAndSettle();
    expect(c.engine.phase, SpacePhase.paused);
    expect(find.text('Background music'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  });

  test(
      'all approved effects and music are bundled and no Pip voice is included',
      () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final assets = manifest
        .listAssets()
        .where((a) =>
            a.startsWith('assets/audio/pip_games/') && a.endsWith('.wav'))
        .toList();
    expect(assets.length, 20);
    expect(assets.any((a) => a.split('/').last.startsWith('pip-')), isFalse);
    for (final asset in assets) {
      expect((await rootBundle.load(asset)).lengthInBytes, greaterThan(100));
    }
  });
}
