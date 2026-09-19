import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/legal/terms_acceptance_screen.dart';

class TermsAuth extends ChangeNotifier implements AuthProvider {
  TermsAuth(this.check);
  final Future<bool> Function() check;
  int agreements = 0;
  String? deletedWith;
  @override
  Future<bool> verifyTerms({bool accept = false}) {
    if (accept) agreements++;
    return check();
  }

  @override
  Future<String?> deleteAccount(String password) async {
    deletedWith = password;
    return null;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final state in ['missing', 'failed', 'loading']) {
    testWidgets('deletion is available when terms are $state without accepting',
        (tester) async {
      final pending = Completer<bool>();
      final auth = TermsAuth(() => state == 'loading'
          ? pending.future
          : state == 'failed'
              ? Future.error(Exception('offline'))
              : Future.value(false));
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: const MaterialApp(home: TermsAcceptanceScreen())));
      await tester.pump();
      await tester.ensureVisible(find.text('Delete account'));
      await tester.tap(find.text('Delete account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Delete your account?'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Delete account'))
              .onPressed,
          isNull);
      await tester.enterText(
          find.widgetWithText(TextField, 'Current password'), 'test-password');
      await tester.enterText(
          find.widgetWithText(TextField, 'Type DELETE to confirm'), 'DELETE');
      await tester.pump();
      await tester
          .ensureVisible(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete account'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(auth.deletedWith, 'test-password');
      expect(auth.agreements, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      if (!pending.isCompleted) pending.complete(false);
    });
  }
  for (final size in [
    const Size(320, 568),
    const Size(440, 956),
    const Size(834, 1194),
    const Size(844, 390)
  ]) {
    testWidgets('terms deletion remains accessible at $size with large text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = TermsAuth(() async => false);
      addTearDown(auth.dispose);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!),
              home: const TermsAcceptanceScreen())));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Delete account'));
      await tester.tap(find.text('Delete account'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(auth.deletedWith, isNull);
      expect(auth.agreements, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
