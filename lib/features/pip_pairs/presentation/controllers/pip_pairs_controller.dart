import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../../models/pip_outfit.dart';

enum PipPairsDifficulty {
  easy('Easy', 'Turn mismatches back yourself.', null),
  medium('Medium', 'Mismatches flip back after 1.5 seconds.',
      Duration(milliseconds: 1500)),
  hard('Hard', 'Just half a second to remember a mismatch.',
      Duration(milliseconds: 500));

  const PipPairsDifficulty(this.label, this.description, this.revealTime);
  final String label;
  final String description;
  final Duration? revealTime;
}

class PipPairsController extends ChangeNotifier {
  PipPairsController({Random? random}) : _random = random ?? Random() {
    newGame();
  }
  void Function(String)? onSound;
  final Random _random;
  List<PipOutfit> _cards = [];
  final Set<int> _matched = {};
  final List<int> _revealed = [];
  int _pairCount = 6;
  int _moves = 0;
  Timer? _hideTimer;
  PipPairsDifficulty _difficulty = PipPairsDifficulty.easy;
  PipPairsDifficulty get difficulty => _difficulty;
  List<PipOutfit> get cards => List.unmodifiable(_cards);
  int get pairCount => _pairCount;
  int get moves => _moves;
  int get matches => _matched.length ~/ 2;
  bool get complete => matches == pairCount;
  bool get needsAnotherLook => _revealed.length == 2;
  bool isMatched(int index) => _matched.contains(index);
  bool isVisible(int index) => isMatched(index) || _revealed.contains(index);

  void newGame({int? pairs, PipPairsDifficulty? difficulty}) {
    final count = pairs ?? _pairCount;
    if (![6, 8, 12].contains(count)) {
      throw ArgumentError.value(count, 'pairs', 'Choose 6, 8 or 12 pairs');
    }
    _hideTimer?.cancel();
    _difficulty = difficulty ?? _difficulty;
    _pairCount = count;
    final outfits = [...pipOutfits]..shuffle(_random);
    final chosen = outfits.take(count).toList();
    _cards = [...chosen, ...chosen]..shuffle(_random);
    _matched.clear();
    _revealed.clear();
    _moves = 0;
    notifyListeners();
    onSound?.call('arcade-select');
  }

  void flip(int index) {
    if (index < 0 ||
        index >= _cards.length ||
        complete ||
        needsAnotherLook ||
        isVisible(index)) {
      return;
    }
    var sound = 'pairs-flip';
    _revealed.add(index);
    if (_revealed.length == 2) {
      _moves++;
      if (_cards[_revealed[0]].id == _cards[_revealed[1]].id) {
        sound = matches + 1 == pairCount ? 'pairs-complete' : 'pairs-match';
        _matched.addAll(_revealed);
        _revealed.clear();
      } else {
        sound = 'pairs-mismatch';
        if (_difficulty.revealTime case final delay?) {
          _hideTimer = Timer(delay, hideMismatch);
        }
      }
    }
    notifyListeners();
    onSound?.call(sound);
  }

  void hideMismatch() {
    if (!needsAnotherLook) return;
    _hideTimer?.cancel();
    _revealed.clear();
    notifyListeners();
    onSound?.call('pairs-flip');
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }
}
