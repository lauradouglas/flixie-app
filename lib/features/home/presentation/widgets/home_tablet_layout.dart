import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';

/// Home's tablet reading columns share one scroll surface. Narrow windows and
/// large text retain the phone reading order and full-width controls.
class HomeTabletLayout extends StatelessWidget {
  const HomeTabletLayout(
      {super.key,
      required this.greeting,
      required this.discovery,
      required this.cinemas,
      required this.plans,
      required this.picker,
      required this.community,
      required this.games});
  final Widget greeting, discovery, cinemas, plans, picker, community, games;

  static bool trendingActive(BuildContext context) =>
      active(context) ||
      (MediaQuery.sizeOf(context).shortestSide >= 600 &&
          MediaQuery.sizeOf(context).height >
              MediaQuery.sizeOf(context).width &&
          MediaQuery.sizeOf(context).width >= 700 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4);

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabletScope>() != null;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final tablet = MediaQuery.sizeOf(context).shortestSide >= 600 &&
            box.maxWidth >= 900 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.4;
        if (!tablet) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                greeting,
                discovery,
                cinemas,
                picker,
                community,
                games
              ]);
        }
        return HomeTabletScope(
            child: Column(
                key: const ValueKey('home-tablet-layout'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              greeting,
              const SizedBox(height: 4),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            flex: 13,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [discovery, cinemas])),
                        const SizedBox(width: 16),
                        Expanded(
                            flex: 7,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _panel(context, plans),
                                  _panel(context, picker),
                                  _panel(context, community),
                                  games
                                ]))
                      ]))
            ]));
      });
  Widget _panel(BuildContext context, Widget child) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(16),
          child: child));
}

class HomeTabletScope extends InheritedWidget {
  const HomeTabletScope({super.key, required super.child});
  @override
  bool updateShouldNotify(HomeTabletScope oldWidget) => false;
}
