import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/widgets/flixie_prompt_sheet.dart';
import 'package:flixie_app/features/settings/presentation/widgets/logout_sheet.dart';

void main() {
  for (final fails in [false, true]) {
    testWidgets('logout stays visible until completion (fails: $fails)',
        (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Builder(
        builder: (context) => TextButton(
            onPressed: () => showFlixiePromptSheet<void>(
                  context: context,
                  isDismissible: false,
                  builder: (_) => LogoutSheet(onSignOut: () {
                    calls++;
                    return pending.future;
                  }),
                ),
            child: const Text('Open')),
      ))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Log Out'));
      await tester.pump();
      expect(find.text('Logging you out…'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Logging you out…'), findsOneWidget);
      expect(calls, 1);
      if (fails) {
        pending.completeError(StateError('offline'));
      } else {
        pending.complete();
      }
      await tester.pumpAndSettle();
      expect(find.text('Logging you out…'), findsNothing);
      expect(find.text('Could not finish logging out. Please try again.'),
          fails ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
