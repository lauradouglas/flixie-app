import 'package:flutter/material.dart';

/// Lazily builds poster rows with natural heights, so metadata, friend borders
/// and availability can wrap without clipping inside fixed-height grid tiles.
class WatchlistTabletGallery extends StatelessWidget {
  const WatchlistTabletGallery(
      {super.key,
      required this.header,
      required this.itemCount,
      required this.itemBuilder});
  final List<Widget> header;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final columns =
            ((constraints.maxWidth - 32 + 24) / 224).floor().clamp(2, 5);
        return CustomScrollView(
          key: const ValueKey('watchlist-cards'),
          slivers: [
            SliverList.list(children: header),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              sliver: SliverList.builder(
                itemCount: (itemCount / columns).ceil(),
                itemBuilder: (context, row) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var column = 0; column < columns; column++) ...[
                          if (column > 0) const SizedBox(width: 24),
                          Expanded(
                              child: row * columns + column < itemCount
                                  ? itemBuilder(context, row * columns + column)
                                  : const SizedBox.shrink()),
                        ],
                      ]),
                ),
              ),
            ),
          ],
        );
      });
}
