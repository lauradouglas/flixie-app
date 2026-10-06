import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_tile.dart';

void main() {
  testWidgets('preference explanation wraps on small screens with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var toggled = false;
    const description =
        'Hide other people’s movie scores until you’ve rated the movie. TV ratings stay visible.';
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home: Scaffold(
            body: SettingsTile(
                icon: Icons.visibility_off_outlined,
                label: 'Rate movies first',
                description: description,
                onTap: () => toggled = true,
                trailing: Switch.adaptive(
                    value: false, onChanged: (_) => toggled = true)))));
    expect(find.text(description), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(description));
    expect(toggled, isTrue);
  });
}
