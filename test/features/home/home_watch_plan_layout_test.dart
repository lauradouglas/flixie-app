import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/models/home_watch_plan_layout.dart';

void main() {
  test('portrait iPad fits two cards and pages extra plans in pairs', () {
    for (final count in [2, 3, 4, 5]) {
      final layout = HomeWatchPlanLayout(
          screen: const Size(1024, 1366), width: 800, count: count);
      expect(layout.stacked, isFalse);
      expect(layout.cardsPerPage, 2);
      expect(layout.cardWidth * 2 + 12 + layout.padding * 2, 800);
      expect(layout.pageCount, (count / 2).ceil());
      expect(layout.trailingSpace > 0, count.isOdd);
      final content = count * layout.cardWidth +
          (count - 1) * 12 +
          layout.trailingSpace +
          layout.padding * 2;
      expect(content - 800,
          closeTo((layout.pageCount - 1) * layout.itemExtent, .001));
    }
  });
  test('landscape sidebar and narrow tablet windows remain stacked', () {
    expect(
        HomeWatchPlanLayout(
                screen: const Size(1366, 1024), width: 480, count: 3)
            .stacked,
        isTrue);
    expect(
        HomeWatchPlanLayout(screen: const Size(768, 1024), width: 520, count: 3)
            .stacked,
        isTrue);
  });
  test('single plan uses the full width; phone retains one card carousel', () {
    final single = HomeWatchPlanLayout(
        screen: const Size(1024, 1366), width: 800, count: 1);
    expect(single.cardWidth, 768);
    expect(single.pageCount, 1);
    final phone =
        HomeWatchPlanLayout(screen: const Size(390, 844), width: 390, count: 3);
    expect(phone.cardsPerPage, 1);
    expect(phone.stacked, isFalse);
    expect(phone.cardWidth, 351);
  });
}
