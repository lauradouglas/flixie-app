import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/features/social/presentation/widgets/group_detail/group_detail_title.dart';

void main() {
  for (final width in [320.0, 844.0, 1024.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('long group name fits width $width text scale $scale',
          (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 400));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const name = 'Alien and The Odyssey friends watching films together';
        await tester.pumpWidget(MaterialApp(
            home: MediaQuery(
                data: MediaQueryData(
                    size: Size(width, 400),
                    textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                    appBar: AppBar(
                        toolbarHeight: 56 * scale,
                        title: const GroupDetailTitle(
                            group: Group(name: name, ownerId: 'fictional'),
                            loading: false,
                            memberCount: 100))))));
        expect(find.text(name), findsOneWidget);
        expect(find.text('100 members'), findsOneWidget);
        expect(tester.widget<Text>(find.text(name)).overflow,
            isNot(TextOverflow.ellipsis));
        expect(tester.takeException(), isNull);
      });
    }
  }
}
