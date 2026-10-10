import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/authentication/data/setup_service.dart';
import 'package:flixie_app/features/authentication/presentation/pages/onboarding_screen.dart';
import 'package:flixie_app/models/user.dart';
import '../../setup_flow_test.dart' show SetupFixture;
import '../../support/watchlist_auth.dart';

class _Auth extends TestAuth {
  String account = 'first';
  Completer<void>? refreshGate;
  final completions = <String>[];
  @override
  User get dbUser => super.dbUser.copyWith(id: account);
  void switchAccount() {
    account = 'second';
    notifyListeners();
  }

  @override
  Future<void> refreshDbUser() async {
    await refreshGate?.future;
  }

  @override
  Future<bool> completeOnboarding() async {
    completions.add(account);
    return false;
  }
}

class _Setup extends SetupFixture {
  final firstTaste = Completer<List<SetupTitle>>();
  @override
  Future<List<SetupTitle>> loadTaste(String id) async => id == 'first'
      ? await firstTaste.future
      : [const SetupTitle(2, 'Second account taste', null)];
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  Future<void> mount(WidgetTester t, _Auth auth, SetupFixture service) async {
    final router = GoRouter(initialLocation: '/setup', routes: [
      GoRoute(
          path: '/setup',
          builder: (_, __) =>
              OnboardingScreen(service: service, returnTo: '/invitation')),
      GoRoute(
          path: '/invitation',
          builder: (_, __) => const Scaffold(body: Text('Invitation opened'))),
    ]);
    addTearDown(router.dispose);
    addTearDown(auth.dispose);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp.router(
            theme: AppTheme.lightTheme, routerConfig: router)));
  }

  testWidgets(
      'account switch replaces selections and ignores late old-account taste',
      (t) async {
    final auth = _Auth();
    final service = _Setup();
    await mount(t, auth, service);
    await t.pump();
    auth.switchAccount();
    await t.pumpAndSettle();
    expect(find.text('1 of 3 selected'), findsOneWidget);
    service.firstTaste.complete([
      const SetupTitle(10, 'Old one', null),
      const SetupTitle(11, 'Old two', null)
    ]);
    await t.pumpAndSettle();
    expect(find.text('1 of 3 selected'), findsOneWidget);
    await t.tap(find.text('Edit'));
    await t.pumpAndSettle();
    expect(find.text('Second account taste'), findsOneWidget);
    expect(find.text('Old one'), findsNothing);
  });
  testWidgets(
      'account switch during finish cannot complete or navigate the new account',
      (t) async {
    final auth = _Auth()..refreshGate = Completer();
    await mount(t, auth, SetupFixture());
    await t.pumpAndSettle();
    await t.tap(find.text('Go straight to your invitation'));
    await t.pump();
    auth.switchAccount();
    await t.pumpAndSettle();
    auth.refreshGate!.complete();
    await t.pumpAndSettle();
    expect(auth.completions, isEmpty);
    expect(find.text('Invitation opened'), findsNothing);
    expect(find.text('What stays with you?'), findsOneWidget);
  });
}
