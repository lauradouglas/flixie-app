import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';

class _LoginAuth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isLoading => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(402, 874),
    const Size(844, 390),
    const Size(834, 1194)
  ]) {
    testWidgets('login links fit $size with large text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>(
        create: (_) => _LoginAuth(),
        child: MaterialApp(
            builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(1.5)),
                  child: child!,
                ),
            home: const LoginScreen()),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Create Account'), findsOneWidget);
      final fields = find.byType(TextFormField);
      await tester.showKeyboard(fields.first);
      for (final value in ['l', 'la', 'laura@example.com']) {
        tester.testTextInput.updateEditingValue(TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        ));
        await tester.pump();
        final editable =
            tester.widget<EditableText>(find.byType(EditableText).first);
        expect(editable.controller.text, value);
        expect(editable.focusNode.hasFocus, isTrue);
      }
      await tester.showKeyboard(fields.last);
      for (final value in ['a', 'ab', 'abc12345']) {
        tester.testTextInput.updateEditingValue(TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        ));
        await tester.pump();
        final editable =
            tester.widget<EditableText>(find.byType(EditableText).last);
        expect(editable.controller.text, value);
        expect(editable.focusNode.hasFocus, isTrue);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
