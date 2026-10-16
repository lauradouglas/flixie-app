import 'package:flutter/widgets.dart';

/// Page geometry uses the available Home section width, including tablet sidebars.
class HomeWatchPlanLayout {
  HomeWatchPlanLayout(
      {required Size screen, required double width, required int count}) {
    final tablet = screen.shortestSide >= 600;
    stacked = tablet && (screen.width > screen.height || width < 650);
    cardsPerPage = tablet && !stacked && count > 1 ? 2 : 1;
    cardWidth = count == 1
        ? width - (tablet ? 32 : 12)
        : cardsPerPage == 2
            ? (width - 44) / 2
            : width >= 600
                ? 460
                : width * .90;
    // Match the six-point leading inset of the phone TrendingCarousel cards.
    padding = !tablet
        ? 6
        : cardsPerPage == 2
            ? 16
            : (width - cardWidth) / 2;
    pageCount = (count / cardsPerPage).ceil();
    itemExtent = (cardWidth + 12) * cardsPerPage;
    trailingSpace = cardsPerPage == 2 && count.isOdd ? cardWidth + 12 : 0;
  }
  late final bool stacked;
  late final int cardsPerPage, pageCount;
  late final double cardWidth, padding, itemExtent, trailingSpace;
}
