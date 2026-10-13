import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_identity.dart';
import 'package:flixie_app/features/social/presentation/widgets/community_pip.dart';

void main() {
  test('every public community has bundled artwork; private IDs have none', () {
    expect(
        CommunityPip.variants.keys.toSet(), CommunityIdentity.all.keys.toSet());
    for (final id in CommunityIdentity.all.keys) {
      expect(File(CommunityPip.assetFor(id)!).existsSync(), isTrue,
          reason: '$id');
    }
    expect(CommunityPip.assetFor(-1001), isNull);
    expect(CommunityPip.assetFor(99999), isNull);
    expect(CommunityPip.assetFor(27), contains('horror-slasher-v2'));
  });
  for (final config in [
    (320.0, 1.0),
    (390.0, 1.0),
    (390.0, 2.0),
    (834.0, 1.0),
    (844.0, 1.0)
  ]) {
    testWidgets(
        'header preserves copy at width ${config.$1}, scale ${config.$2}',
        (tester) async {
      tester.view.physicalSize = Size(config.$1, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(config.$2)),
              child: const Scaffold(
                  body: SingleChildScrollView(
                      child: CommunityIdentityHeader(
                          id: -2, name: 'Superheroes / Marvel & DC'))))));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityPip), findsOneWidget);
      expect(find.text(CommunityIdentity.all[-2]!.blurb), findsOneWidget);
      expect(find.text('Films & series · Opinions from people who joined'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
