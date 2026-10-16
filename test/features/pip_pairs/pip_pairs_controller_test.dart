import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/pip_pairs/presentation/controllers/pip_pairs_controller.dart';
import 'package:flixie_app/features/pip_pairs/models/pip_outfit.dart';

void main() {
  test('every board contains exactly two of each chosen outfit', () {
    final game = PipPairsController(random: Random(7));
    addTearDown(game.dispose);
    for (final count in [6, 8, 12]) {
      game.newGame(pairs: count);
      final ids = game.cards.map((card) => card.id).toSet();
      expect(ids.length, count);
      expect(game.cards.length, count * 2);
      for (final id in ids) {
        expect(game.cards.where((card) => card.id == id).length, 2);
      }
    }
    expect(pipOutfits.map((outfit) => outfit.id).toSet().length, 24);
  });
  test('mismatch blocks further flips until dismissed; restart clears state',
      () {
    final game = PipPairsController(random: Random(4));
    addTearDown(game.dispose);
    final different = game.cards.indexWhere((c) => c.id != game.cards[0].id);
    game.flip(0);
    game.flip(0);
    expect(game.moves, 0);
    game.flip(different);
    expect(game.moves, 1);
    expect(game.needsAnotherLook, isTrue);
    final third = List.generate(game.cards.length, (i) => i)
        .firstWhere((i) => i != 0 && i != different);
    game.flip(third);
    expect(game.isVisible(third), isFalse);
    game.hideMismatch();
    expect(game.isVisible(0), isFalse);
    game.flip(third);
    game.newGame();
    expect(game.moves, 0);
    expect(game.matches, 0);
    expect(game.isVisible(third), isFalse);
  });
  test('matching all outfits completes once and ignores already matched cards',
      () {
    final game = PipPairsController(random: Random(2));
    addTearDown(game.dispose);
    for (final id in game.cards.map((c) => c.id).toSet()) {
      final pair = List.generate(game.cards.length, (i) => i)
          .where((i) => game.cards[i].id == id)
          .toList();
      game.flip(pair[0]);
      game.flip(pair[1]);
      expect(game.isMatched(pair[0]), isTrue);
      game.flip(pair[0]);
    }
    expect(game.complete, isTrue);
    expect(game.moves, game.pairCount);
    game.newGame(pairs: 8);
    expect(game.complete, isFalse);
    expect(game.matches, 0);
  });
}
