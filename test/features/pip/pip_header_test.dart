import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/widgets/flixie_wordmark.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_watchlist_action.dart';
import 'package:flixie_app/features/pip/presentation/controllers/pip_collection_controller.dart';
import 'package:flixie_app/features/pip/presentation/widgets/pip_companion.dart';
import 'pip_collection_test.dart' show FakePips;

void main() {
  testWidgets(
      'compact Home Pip fits small phone large text and opens collection',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = PipCollectionController(service: FakePips());
    c.syncUser('fixture', 0);
    await tester.pumpAndSettle();
    await tester.pumpWidget(ChangeNotifierProvider.value(
        value: c,
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!),
            home: Scaffold(
                appBar: AppBar(
              title: const Row(mainAxisSize: MainAxisSize.min, children: [
                Flexible(child: FlixieWordmark()),
                PipHeaderCompanion(),
              ]),
              actions: [
                HomeWatchlistAction(onPressed: () {}),
                IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_outlined))
              ],
            )))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byTooltip('My Pip')).height,
        greaterThanOrEqualTo(48));
    await tester.tap(find.byTooltip('My Pip'));
    await tester.pumpAndSettle();
    expect(find.text('Make Flixie yours.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    c.dispose();
  });
}
