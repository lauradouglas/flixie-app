import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/home/presentation/widgets/greeting_header.dart';

void main() {
  for (final width in [320.0, 390.0, 430.0, 768.0]) {
    for (final scale in [1.0, 1.25, 2.0]) {
      testWidgets('shortcuts stay equal at $width with text scale $scale',
          (t) async {
        await t.binding.setSurfaceSize(Size(width, 1000));
        addTearDown(() => t.binding.setSurfaceSize(null));
        var invited = false;
        await t.pumpWidget(MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
                body: MediaQuery(
                    data: MediaQueryData(
                        size: Size(width, 1000),
                        textScaler: TextScaler.linear(scale)),
                    child: GreetingHeader(
                        name: 'Laura',
                        requestCount: 4,
                        onSearch: () {},
                        onWatchlist: () {},
                        onRequests: () {},
                        onInvite: () => invited = true)))));
        final buttons = find.descendant(
            of: find.byType(GreetingHeader), matching: find.byType(InkWell));
        expect(buttons, findsNWidgets(4));
        final first = t.getSize(buttons.at(0));
        for (var i = 1; i < 4; i++) {
          expect(t.getSize(buttons.at(i)), first);
        }
        await t.tap(find.text('Invite friends'));
        expect(invited, isTrue);
        expect(t.takeException(), isNull);
      });
    }
  }
}
