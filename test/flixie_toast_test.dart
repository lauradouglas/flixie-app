import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';

void main() {
  testWidgets('messages and actions expire without invoking the action',
      (tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    var actions = 0;
    await tester.pumpWidget(MaterialApp(
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox.expand())));
    for (final label in <String?>[null, 'Undo', 'Retry']) {
      key.currentState!.showFlixieToast(FlixieToast(
          type: FlixieToastType.success,
          content: const Text('Saved'),
          action: label == null
              ? null
              : SnackBarAction(label: label, onPressed: () => actions++)));
      await tester.pumpAndSettle();
      expect(tester.widget<SnackBar>(find.byType(SnackBar)).margin,
          const EdgeInsets.all(8));
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Saved'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsNothing);
      expect(actions, 0);
    }
  });
  setUpAll(() async {
    await (FontLoader('Manrope')
          ..addFont(
              rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf')))
        .load();
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  testWidgets(
      'variants share shape and surface and keep distinct icons and colours',
      (tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox.expand())));
    for (final type in FlixieToastType.values) {
      key.currentState!.removeCurrentSnackBar();
      key.currentState!.showSnackBar(
          FlixieToast(type: type, content: const Text('Your update')));
      await tester.pumpAndSettle();
      final toast = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(toast.backgroundColor, Colors.transparent);
      expect(toast.behavior, SnackBarBehavior.floating);
      final surface = tester
          .widgetList<Container>(find.descendant(
              of: find.byType(SnackBar), matching: find.byType(Container)))
          .firstWhere((widget) =>
              widget.decoration is BoxDecoration &&
              (widget.decoration! as BoxDecoration).color ==
                  const Color(0xFF261B40));
      expect(
          ((surface.decoration! as BoxDecoration).border! as Border).top.color,
          type.colour.withValues(alpha: .65));
      expect(find.byIcon(type.icon), findsOneWidget);
    }
  });
  testWidgets('retry and undo run once when tapped, never when dismissed',
      (tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox.expand())));
    for (final label in ['Retry', 'Undo']) {
      var count = 0;
      key.currentState!.showSnackBar(FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Couldn’t save your picks'),
          action: SnackBarAction(label: label, onPressed: () => count++)));
      await tester.pumpAndSettle();
      expect(count, 0);
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(count, 1);
    }
  });
  testWidgets('new feedback replaces a pending undo without running it',
      (tester) async {
    final key = GlobalKey<ScaffoldMessengerState>();
    var undos = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        scaffoldMessengerKey: key,
        home: const Scaffold(body: SizedBox.expand())));
    key.currentState!.showFlixieToast(FlixieToast(
        type: FlixieToastType.success,
        content: const Text('Added to watchlist'),
        action: SnackBarAction(label: 'Undo', onPressed: () => undos++)));
    await tester.pumpAndSettle();
    key.currentState!.showFlixieToast(FlixieToast(
        type: FlixieToastType.error,
        content: const Text('Couldn’t save your picks')));
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsNothing);
    expect(find.text('Couldn’t save your picks'), findsOneWidget);
    expect(undos, 0);
  });

  testWidgets('toast fits small phone and large text above bottom navigation',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        scaffoldMessengerKey: key,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: const Scaffold(
            body: SizedBox.expand(),
            bottomNavigationBar:
                SizedBox(key: Key('nav'), height: 72, child: Text('Home')))));
    key.currentState!.showSnackBar(FlixieToast(
        type: FlixieToastType.error,
        content: const Text(
            'Couldn’t save your picks. Your selections are still here.'),
        action: SnackBarAction(label: 'Retry', onPressed: () {})));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getBottomLeft(find.byType(SnackBar)).dy,
        lessThanOrEqualTo(tester.getTopLeft(find.byKey(const Key('nav'))).dy));
    expect(
        tester
            .getSize(find.text(
                'Couldn’t save your picks. Your selections are still here.'))
            .width,
        greaterThan(180));
    expect(
        tester.getTopLeft(find.text('Retry')).dy,
        greaterThan(tester
            .getBottomLeft(find.text(
                'Couldn’t save your picks. Your selections are still here.'))
            .dy));
  });
}
