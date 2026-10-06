import 'dart:io';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/referral_attribution_store.dart';
import 'package:flixie_app/core/auth/social_auth_provider.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_screen.dart';
import 'package:flixie_app/features/authentication/presentation/pages/social_auth_buttons.dart';

class _Auth extends ChangeNotifier implements AuthProvider {
  _Auth({this.needsSocialProfile = false});
  @override
  final bool needsSocialProfile;
  @override
  bool get isLoading => false;
  @override
  fb.User? get firebaseUser => null;
  @override
  bool isProviderConnected(SocialAuthProvider provider) => false;
  SocialAuthProvider? submitted;
  @override
  Future<bool> signInWithSocialProvider(SocialAuthProvider provider) async {
    submitted = provider;
    return true;
  }

  @override
  Future<bool> connectSocialProvider(SocialAuthProvider provider) async {
    submitted = provider;
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Store extends Fake implements ReferralAttributionStore {}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Manrope')
      ..addFont(rootBundle.load('assets/fonts/Manrope-VariableFont_wght.ttf'));
    await loader.load();
  });
  for (final size in [
    const Size(320, 568),
    const Size(402, 874),
    const Size(844, 390),
    const Size(834, 1194)
  ]) {
    for (final screen in ['login', 'signup', 'social-profile']) {
      testWidgets('$screen is scrollable and fits $size at larger text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final auth = _Auth(needsSocialProfile: screen == 'social-profile');
        addTearDown(auth.dispose);
        final capture = GlobalKey();
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!),
            home: RepaintBoundary(
                key: capture,
                child: screen == 'login'
                    ? const LoginScreen()
                    : SignupScreen(referralStore: _Store())),
          ),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (screen == 'social-profile') {
          expect(find.text('Password'), findsNothing);
          expect(find.text('Finish your Flixie profile'), findsOneWidget);
        } else {
          expect(find.text('Continue with Apple'), findsNothing);
          expect(find.text('Continue with Google'), findsOneWidget);
        }
        final preview = Platform.environment['FLIXIE_AUTH_PREVIEW_DIR'];
        if (preview != null &&
            size.width == 402 &&
            screen != 'social-profile') {
          final boundary = capture.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final bytes =
                await image.toByteData(format: ui.ImageByteFormat.png);
            await Directory(preview).create(recursive: true);
            await File('$preview/$screen.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        final bottom =
            find.text(screen == 'login' ? 'Create Account' : 'Continue');
        await tester.ensureVisible(bottom);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final connect in [false, true]) {
      testWidgets('$platform offers supported providers for connect=$connect', (tester) async {
        final auth = _Auth();
        addTearDown(auth.dispose);
        await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(home: Scaffold(body: SocialAuthButtons(
            connect: connect, onSignedIn: () {},
          ))),
        ));
        final prefix = connect ? 'Connect' : 'Continue';
        expect(find.text('$prefix with Apple'), platform == TargetPlatform.iOS ? findsOneWidget : findsNothing);
        expect(find.text('$prefix with Google'), findsOneWidget);
        await tester.tap(find.text('$prefix with Google'));
        await tester.pumpAndSettle();
        expect(auth.submitted, SocialAuthProvider.google);
      }, variant: TargetPlatformVariant.only(platform));
    }
  }
  testWidgets(
      'provider buttons invoke authentication without email form validation',
      (tester) async {
    final auth = _Auth();
    addTearDown(auth.dispose);
    var continued = false;
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: SocialAuthButtons(onSignedIn: () => continued = true)))));
    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(auth.submitted, SocialAuthProvider.google);
    expect(continued, isTrue);
  });
}
