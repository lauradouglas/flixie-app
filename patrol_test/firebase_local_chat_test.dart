import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/auth/firebase_environment.dart';
import 'package:flixie_app/features/authentication/presentation/pages/login_screen.dart';
import 'package:flixie_app/features/profile/presentation/widgets/avatar_picker.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_input.dart';
import 'package:flixie_app/features/social/presentation/pages/direct_chat_screen.dart';
import 'package:flixie_app/main.dart' as app;

class _RealLocalHttp extends HttpOverrides {}

void main() {
  patrolTest('local Dougasaur signs in, chats and loads Storage avatars',
      ($) async {
    const password = String.fromEnvironment('LOCAL_FIREBASE_PASSWORD');
    expect(password, isNotEmpty,
        reason: 'Supply the local fixture password at run time.');
    expect(FirebaseEnvironment.useEmulators, isTrue);
    HttpOverrides.global = _RealLocalHttp();
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues(
        {'analytics_consent_v2': 'declined', 'guest_welcome_seen_v1': true});
    await $.tester.runAsync(() => app.main());
    Future<void> until(bool Function() ready, String reason) async {
      final watch = Stopwatch()..start();
      while (!ready() && watch.elapsed < const Duration(seconds: 60)) {
        await $.pump(const Duration(milliseconds: 200));
      }
      expect(ready(), isTrue, reason: reason);
    }

    await until(() => find.text('Sign in').evaluate().isNotEmpty,
        'guest sign-in action');
    await $('Sign in').tap();
    await until(
        () => find.byType(LoginScreen).evaluate().isNotEmpty, 'login screen');
    final fields = find.descendant(
        of: find.byType(LoginScreen), matching: find.byType(TextFormField));
    expect(fields, findsNWidgets(2));
    await $.tester.enterText(fields.at(0), 'dougasaur');
    await $.tester.enterText(fields.at(1), password);
    await $.tester.testTextInput.receiveAction(TextInputAction.done);
    await $.pump();
    await until(() => find.byType(LoginScreen).evaluate().isEmpty,
        'username/password login completes');
    await until(
        () => find.text('Home').evaluate().isNotEmpty, 'signed-in app shell');
    final shell = $.tester.element(find.text('Home').first);
    final auth = shell.read<AuthProvider>();
    expect(auth.dbUser?.username.toLowerCase(), 'dougasaur');
    expect(FirebaseEnvironment.auth.app.options.projectId, 'demo-flixie-local');
    expect(FirebaseEnvironment.firestore.app.options.projectId,
        'demo-flixie-local');
    final originalAvatar = auth.dbUser!.avatar?.id;
    GoRouter.of(shell).push('/messages');
    await until(() => find.text('dev_firebase_robin').evaluate().isNotEmpty,
        'local Robin inbox row');
    await $('dev_firebase_robin').tap();
    await until(
        () =>
            find.byType(DirectChatScreen).evaluate().isNotEmpty &&
            find
                .text('Want to watch Alien or The Odyssey?')
                .evaluate()
                .isNotEmpty,
        'seeded local chat loads');
    final message =
        'Local simulator check ${DateTime.now().millisecondsSinceEpoch}: Alien';
    final input = find.descendant(
        of: find.byType(ChatInput), matching: find.byType(TextField));
    await $.tester.enterText(input, message);
    await $.tester.testTextInput.receiveAction(TextInputAction.send);
    await until(() => find.text(message).evaluate().isNotEmpty,
        'sent message arrives through the real Firestore stream');
    final chat = $.tester.element(find.byType(DirectChatScreen));
    GoRouter.of(chat).go('/settings');
    await until(() => find.text('Change Avatar').evaluate().isNotEmpty,
        'settings avatar action');
    await $('Change Avatar').tap();
    await until(
        () =>
            find.byType(AvatarPicker).evaluate().isNotEmpty &&
            $.tester
                .widget<AvatarPicker>(find.byType(AvatarPicker))
                .avatars
                .isNotEmpty,
        'local avatar catalogue');
    final picker = $.tester.widget<AvatarPicker>(find.byType(AvatarPicker));
    expect(picker.error, isNull);
    final images = find.descendant(
        of: find.byType(AvatarPicker),
        matching: find.byType(CachedNetworkImage));
    await until(() => images.evaluate().isNotEmpty, 'avatar image widgets');
    final image = $.tester.widget<CachedNetworkImage>(images.first);
    expect(Uri.parse(image.imageUrl).host, '127.0.0.1');
    expect(Uri.parse(image.imageUrl).port, 9199);
    final decoded = Completer<ImageInfo>();
    final stream = CachedNetworkImageProvider(image.imageUrl)
        .resolve(ImageConfiguration.empty);
    final listener = ImageStreamListener((info, _) {
      if (!decoded.isCompleted) decoded.complete(info);
    }, onError: (Object error, StackTrace? trace) {
      if (!decoded.isCompleted) decoded.completeError(error, trace);
    });
    stream.addListener(listener);
    await until(
        () => decoded.isCompleted, 'local avatar bytes decode successfully');
    final pixels = await decoded.future;
    expect(pixels.image.width, greaterThan(0));
    stream.removeListener(listener);
    if (originalAvatar != null) {
      expect(picker.selectedId, originalAvatar);
      await $('Save avatar').tap();
      await until(() => find.byType(AvatarPicker).evaluate().isEmpty,
          'local avatar save succeeds');
      expect(auth.dbUser?.avatar?.id, originalAvatar);
    }
    expect($.tester.takeException(), isNull);
    debugPrint(
        'LOCAL FIREBASE UI PASS: Dougasaur login, canonical Robin chat, sent message, avatar decoded from port 9199 and existing avatar preserved.');
  });
}
