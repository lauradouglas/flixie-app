import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/flixie_time_picker_sheet.dart';
import 'package:flixie_app/features/watch_plans/presentation/sheets/watch_plan_schedule_sheet.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('time picker follows ${dark ? 'dark' : 'light'} appearance',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        home: const Scaffold(
            body: FlixieTimePickerSheet(
                initialTime: TimeOfDay(hour: 19, minute: 30))),
      ));
      final context = tester.element(find.byType(CupertinoDatePicker));
      final theme = CupertinoTheme.of(context);
      expect(theme.brightness, dark ? Brightness.dark : Brightness.light);
      final color = CupertinoDynamicColor.resolve(
          theme.textTheme.dateTimePickerTextStyle.color!, context);
      expect(color.computeLuminance(), dark ? greaterThan(.5) : lessThan(.2));
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('selected schedule mode uses white on purple in light mode',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
          body: WatchPlanScheduleSheet(initial: DateTime(2030, 1, 1, 19))),
    ));
    final labels = tester.widgetList<Text>(find.text('Date & time'));
    expect(labels.any((label) => label.style?.color == Colors.white), isTrue);
    expect(tester.takeException(), isNull);
  });
}
