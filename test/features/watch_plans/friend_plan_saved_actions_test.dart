import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/watch_plans/presentation/widgets/friend_plan/friend_plan_saved_actions.dart';

void main() {
  for (final spec in [
    (320.0, 2.0),
    (390.0, 1.0),
    (844.0, 1.3),
    (1024.0, 1.0)
  ]) {
    testWidgets('saved actions remain usable at $spec', (tester) async {
      tester.view.physicalSize = Size(spec.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      Future<void> show({bool busy = false}) => tester.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(spec.$2)),
              child: Scaffold(
                  body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: FriendPlanSavedActions(
                  friend: 'dev_watch_casey_with_a_long_username',
                  busy: busy,
                  onAddDate: () => calls.add('date'),
                  onWatched: () => calls.add('watch'),
                  onChangeMovie: () => calls.add('movie'),
                  onMessage: () => calls.add('message'),
                ),
              )),
            ),
          ));
      await show();
      for (final label in [
        'Add a date',
        'We watched it',
        'Change movie',
        'Message dev_watch_casey_with_a_long_username'
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }
      expect(calls, ['date', 'watch', 'movie', 'message']);
      expect(tester.takeException(), isNull);
      await show(busy: true);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull);
      expect(
          tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
          isNull);
      for (final row in tester.widgetList<InkWell>(find.byType(InkWell))) {
        expect(row.onTap, isNull);
      }
    });
  }
}
