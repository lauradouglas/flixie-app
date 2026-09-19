import 'dart:math' as math;

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return (math.max(first, second) + .05) / (math.min(first, second) + .05);
}

void main() {
  for (final theme in [AppTheme.darkTheme, AppTheme.lightTheme]) {
    final mode = theme.brightness.name;
    test('$mode semantic fills keep normal labels readable', () {
      final c = theme.colorScheme;
      for (final pair in [
        (c.onPrimary, c.primary),
        (c.onPrimaryContainer, c.primaryContainer),
        (c.onSecondary, c.secondary),
        (c.onSecondaryContainer, c.secondaryContainer),
        (c.onTertiary, c.tertiary),
        (c.onTertiaryContainer, c.tertiaryContainer),
        (c.onError, c.error),
        (c.onErrorContainer, c.errorContainer),
        (c.onSurface, c.surface),
        (c.onSurfaceVariant, c.surfaceContainerHighest),
      ]) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5),
            reason: '$mode foreground ${pair.$1} on ${pair.$2}');
      }
      expect(contrast(c.outline, c.surfaceContainerHighest),
          greaterThanOrEqualTo(3));
    });

    test('$mode action labels and selected chips keep contrast', () {
      for (final style in [
        theme.filledButtonTheme.style!,
        theme.elevatedButtonTheme.style!,
      ]) {
        for (final states in [
          <WidgetState>{},
          {WidgetState.pressed},
          {WidgetState.focused},
        ]) {
          expect(
              contrast(style.foregroundColor!.resolve(states)!,
                  style.backgroundColor!.resolve(states)!),
              greaterThanOrEqualTo(4.5));
        }
      }
      final label = WidgetStateProperty.resolveAs<TextStyle>(
          theme.chipTheme.labelStyle!, {WidgetState.selected});
      expect(
          contrast(
              WidgetStateProperty.resolveAs<Color>(
                  label.color!, {WidgetState.selected}),
              theme.chipTheme.selectedColor!),
          greaterThanOrEqualTo(4.5));
    });

    for (final size in [
      const Size(320, 568),
      const Size(430, 932),
      const Size(844, 390),
      const Size(834, 1194),
    ]) {
      testWidgets('$mode controls reflow at 200% text on $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var pressed = false;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              backgroundColor: theme.colorScheme.surface,
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Find something to watch together',
                        style: theme.textTheme.headlineLarge),
                    const Text(
                        'Choose a film or show and make a plan with your friends.'),
                    const TextField(
                        decoration: InputDecoration(labelText: 'Search films')),
                    FilledButton(
                      onPressed: () => pressed = true,
                      child: const Text('Pick our next watch',
                          textAlign: TextAlign.center),
                    ),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                          label: const Text('Watching together'),
                          selected: true,
                          onSelected: (_) {}),
                      ChoiceChip(
                          label: const Text('Watch later'),
                          selected: false,
                          onSelected: (_) {}),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Pick our next watch'));
        await tester.tap(find.text('Pick our next watch'));
        expect(pressed, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
