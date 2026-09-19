import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/core/legal/terms_agreement_field.dart';
import 'package:flixie_app/core/legal/terms_of_use_screen.dart';

void main() {
  testWidgets('agreement is explicit and opening terms does not grant consent',
      (tester) async {
    final form = GlobalKey<FormState>();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Form(key: form, child: const TermsAgreementField())),
    ));
    expect(form.currentState!.validate(), isFalse);
    await tester.pump();
    await tester.tap(find.text('Read Terms of Use'));
    await tester.pumpAndSettle();
    expect(find.byType(TermsOfUseScreen), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(form.currentState!.validate(), isFalse);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(form.currentState!.validate(), isTrue);
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(form.currentState!.validate(), isFalse);
  });

  for (final size in [
    const Size(320, 568),
    const Size(440, 956),
    const Size(834, 1194),
    const Size(844, 390),
  ]) {
    testWidgets('terms remain readable at $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const TermsOfUseScreen(),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
          find.text('Privacy and your rights'), 300);
      expect(tester.takeException(), isNull);
      expect(
          find.text('Privacy and your rights').hitTestable(), findsOneWidget);
    });
  }
}
