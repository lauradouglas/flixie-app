import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import '../../features/pip/pip_collection_test.dart' show FakePips;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/router/flixie_tablet_navigation.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import '../../support/navigation_structure_fixture.dart';
import '../../support/watchlist_auth.dart';

void main() {
  testWidgets('tablet tabs retain search and scroll through compact resize',
      (t) async {
    t.view.physicalSize = const Size(1194, 834);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final refreshed = <String>[];
    final router = navigationStructureFixture(
        onRefresh: (path) async => refreshed.add(path));
    final auth = TestAuth();
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: MaterialApp.router(routerConfig: router)));
    await t.pumpAndSettle();
    expect(find.byType(FlixieTabletNavigation), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('tablet-nav-discover')));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'Alien');
    t.testTextInput.hide();
    await t.drag(find.byType(ListView).last, const Offset(0, -500));
    await t.pumpAndSettle();
    final position =
        t.state<ScrollableState>(find.byType(Scrollable).last).position;
    final offset = position.pixels;
    expect(offset, greaterThan(0));
    await t.tap(find.byKey(const ValueKey('tablet-nav-plans')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tablet-nav-discover')));
    await t.pumpAndSettle();
    expect(find.text('Alien'), findsOneWidget);
    expect(position.pixels, offset);
    t.view.physicalSize = const Size(820, 1180);
    await t.pumpAndSettle();
    expect(find.byType(FlixieTabletNavigation), findsNothing);
    expect(find.text('Alien'), findsOneWidget);
    expect(position.pixels, offset);
    t.view.physicalSize = const Size(1194, 834);
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('tablet-nav-discover')));
    await t.pumpAndSettle();
    expect(refreshed, ['/search']);
    expect(
        t.state<ScrollableState>(find.byType(Scrollable).last).position.pixels,
        0);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sidebar library shortcut works and large text wraps', (t) async {
    var watchlist = false;
    await t.pumpWidget(MaterialApp(
        home: Scaffold(
            body: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(2)),
                child: FlixieTabletNavigation(
                    selectedIndex: 0,
                    onSelected: (_) {},
                    onWatchlist: () => watchlist = true)))));
    await t.scrollUntilVisible(find.text('Watchlist'), 200,
        scrollable: find.byType(Scrollable));
    await t.tap(find.text('Watchlist'));
    expect(watchlist, true);
    expect(t.takeException(), isNull);
  });
  testWidgets(
      'narrow sidebar keeps Pip beside the wordmark and opens collection',
      (t) async {
    SharedPreferences.setMockInitialValues({});
    final pip = PipCollectionController(service: FakePips());
    pip.syncUser('fixture', 0);
    await t.pumpAndSettle();
    await t.pumpWidget(ChangeNotifierProvider.value(
        value: pip,
        child: MaterialApp(
            home: Scaffold(
                body: FlixieTabletNavigation(
                    selectedIndex: 0,
                    onSelected: (_) {},
                    onWatchlist: () {})))));
    await t.pumpAndSettle();
    expect(t.getSize(find.byType(FlixieTabletNavigation)).width, 156);
    expect(t.getTopLeft(find.byTooltip('My Pip')).dx,
        greaterThan(t.getTopLeft(find.byType(FlixieWordmark)).dx));
    expect(
        (t.getCenter(find.byTooltip('My Pip')).dy -
                t.getCenter(find.byType(FlixieWordmark)).dy)
            .abs(),
        lessThan(12));
    expect(
        t.getSize(find.byTooltip('My Pip')).height, greaterThanOrEqualTo(48));
    await t.tap(find.byTooltip('My Pip'));
    await t.pumpAndSettle();
    expect(find.text('Make Flixie yours.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    pip.dispose();
  });
}
