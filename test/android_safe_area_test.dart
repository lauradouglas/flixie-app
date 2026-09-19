import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/authentication/presentation/pages/auth_ui.dart';

void main() {
  for (final size in [const Size(360, 800), const Size(800, 360)]) {
    for (final bottomInset in [24.0, 48.0]) {
      testWidgets('auth controls clear system bars: $size / $bottomInset',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        tester.view.padding = FakeViewPadding(
            top: 32, left: 24, right: 24, bottom: bottomInset);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          home: AuthScaffold(
            topLabel: 'Flixie',
            title: const Text('Create account'),
            subtitle: 'Choose your next film',
            cardChild: FilledButton(
              key: const ValueKey('continue'),
              onPressed: () {},
              child: const Text('Continue'),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        final button = find.byKey(const ValueKey('continue'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        final bounds = tester.getRect(button);
        expect(bounds.top, greaterThanOrEqualTo(32));
        expect(bounds.bottom, lessThanOrEqualTo(size.height - bottomInset));
        expect(bounds.left, greaterThanOrEqualTo(24));
        expect(bounds.right, lessThanOrEqualTo(size.width - 24));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
