import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/authentication/presentation/pages/signup_avatar_step.dart';
import 'package:flixie_app/models/profile_avatar.dart';

void main() {
  const avatars = [
    ProfileAvatar(
        id: 1,
        key: 'cat',
        displayName: 'Black cat',
        storagePath: 'cat',
        imageUrl: 'https://example.com/cat.png'),
    ProfileAvatar(
        id: 2,
        key: 'boba',
        displayName: 'Bubble tea',
        storagePath: 'boba',
        imageUrl: 'https://example.com/boba.png'),
  ];
  testWidgets(
      'selection updates footer, survives filtering, and Continue uses choice',
      (tester) async {
    int? selected, submitted;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: StatefulBuilder(
            builder: (context, update) => SignupAvatarStep(
                  avatars: avatars,
                  selectedId: selected,
                  onSelected: (a) => update(() => selected = a.id),
                  onContinue: () => submitted = selected,
                  onBack: () {},
                  onRetry: () {},
                ))));
    await tester.tap(find.text('Continue'));
    expect(submitted, isNull);
    await tester.tap(find.text('Black cat'));
    await tester.pump();
    expect(find.text('Your avatar · change it anytime'), findsOneWidget);
    await tester.tap(find.text('Playful'));
    await tester.pump();
    expect(find.text('Black cat'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    expect(submitted, 1);
    expect(tester.takeException(), isNull);
  });
  for (final size in [
    const Size(320, 568),
    const Size(844, 390),
    const Size(1024, 768)
  ]) {
    testWidgets('footer remains reachable at $size with larger text',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.5)),
              child: child!),
          home: SignupAvatarStep(
              avatars: avatars,
              selectedId: 1,
              onSelected: (_) {},
              onContinue: () {},
              onBack: () {},
              onRetry: () {})));
      expect(tester.getBottomRight(find.text('Continue')).dy,
          lessThan(size.height));
      expect(tester.takeException(), isNull);
    });
  }
}
