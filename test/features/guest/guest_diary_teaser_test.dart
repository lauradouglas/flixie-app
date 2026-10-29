import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_diary_teaser.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

void main() {
  for (final (width, scale) in [
    (320.0, 2.0),
    (430.0, 1.0),
    (844.0, 2.0),
    (834.0, 1.0)
  ]) {
    testWidgets(
        'diary example preserves artwork, spaced days and companion border at $width/$scale',
        (t) async {
      t.view.physicalSize = Size(width, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: Padding(
                          padding: EdgeInsets.all(20),
                          child: GuestDiaryTeaser()))))));
      await t.pumpAndSettle();
      expect(find.text('Example'), findsOneWidget);
      expect(find.text('Watched with'), findsOneWidget);
      expect(find.text('Maya'), findsOneWidget);
      final avatar =
          t.widget<ProfileAvatarView>(find.byType(ProfileAvatarView));
      expect(avatar.profileBadges, ['EARLY_ADOPTER']);
      expect(
          t.widget<SpecialAvatarFrame>(find.byType(SpecialAvatarFrame)).badges,
          ['EARLY_ADOPTER']);
      final poster = t.widget<Image>(find.byWidgetPredicate(
          (w) => w is Image && w.semanticLabel == 'Alien poster'));
      expect(poster.width! / poster.height!, 2 / 3);
      expect(poster.fit, BoxFit.contain);
      final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map((day) => t.getCenter(find.text(day)).dx)
          .toList();
      for (var i = 2; i < days.length; i++) {
        expect(days[i] - days[i - 1], closeTo(days[1] - days[0], .1));
      }
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('primary finds films and secondary opens saved diary drafts',
      (t) async {
    final router = GoRouter(routes: [
      GoRoute(
          path: '/',
          builder: (_, __) => const Scaffold(
              body: SingleChildScrollView(child: GuestDiaryTeaser()))),
      GoRoute(
          path: '/search',
          builder: (_, state) => Scaffold(
              body:
                  Text('Search focus ${state.uri.queryParameters['focus']}'))),
      GoRoute(
          path: '/guest-diary',
          builder: (_, __) => const Scaffold(body: Text('Saved drafts'))),
    ]);
    addTearDown(router.dispose);
    await t.pumpWidget(MaterialApp.router(routerConfig: router));
    await t.pumpAndSettle();
    expect(find.text('See what makes Flixie different'), findsNothing);
    await t.ensureVisible(find.text('Find a film to log'));
    await t.tap(find.text('Find a film to log'));
    await t.pumpAndSettle();
    expect(find.text('Search focus 1'), findsOneWidget);
    router.go('/');
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('View my diary drafts'));
    await t.tap(find.text('View my diary drafts'));
    await t.pumpAndSettle();
    expect(find.text('Saved drafts'), findsOneWidget);
  });
}
