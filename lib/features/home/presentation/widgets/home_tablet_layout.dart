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
      required this.games,
      this.curatedLists = const SizedBox.shrink()});
  final Widget greeting,
      discovery,
      cinemas,
      plans,
      picker,
      community,
      games,
      curatedLists;

  static bool trendingActive(BuildContext context) =>
      active(context) ||
      (MediaQuery.sizeOf(context).shortestSide >= 600 &&
          MediaQuery.sizeOf(context).height >
              MediaQuery.sizeOf(context).width &&
          MediaQuery.sizeOf(context).width >= 700 &&
          MediaQuery.textScalerOf(context).scale(1) <= 1.4);

  static bool portrait(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabletScope>()?.portrait ??
      false;

  static bool active(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeTabletScope>() != null;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final portrait = box.maxWidth >= 700 &&
            MediaQuery.sizeOf(context).shortestSide >= 600 &&
            MediaQuery.sizeOf(context).height >
                MediaQuery.sizeOf(context).width &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.4;
        final tablet = MediaQuery.sizeOf(context).shortestSide >= 600 &&
            box.maxWidth >= 900 &&
            MediaQuery.textScalerOf(context).scale(1) <= 1.4;
        if (portrait) {
          return HomeTabletScope(
              portrait: true,
              child: Column(
                  key: const ValueKey('home-tablet-portrait-layout'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    greeting,
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              discovery,
                              curatedLists,
                              cinemas,
                              const SizedBox(height: 16),
                              IntrinsicHeight(
                                  child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                    Expanded(
                                        flex: 3,
                                        child: Padding(
                                            padding: const EdgeInsets.only(
                                                bottom: 12),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  Expanded(child: plans),
                                                  games,
                                                ]))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        flex: 2,
                                        child: _panel(context, picker)),
                                  ])),
                              community,
                            ])),
                  ]));
        }
        if (!tablet) {
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                greeting,
                discovery,
                curatedLists,
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
                                children: [discovery, curatedLists, cinemas])),
                        const SizedBox(width: 16),
                        Expanded(
                            flex: 7,
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  plans,
                                  const SizedBox(height: 12),
                                  _panel(context, picker),
                                  community,
                                  const SizedBox(height: 12),
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
  const HomeTabletScope(
      {super.key, required super.child, this.portrait = false});
  final bool portrait;
  @override
  bool updateShouldNotify(HomeTabletScope oldWidget) =>
      portrait != oldWidget.portrait;
}
