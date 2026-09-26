import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/expandable_profile_bio.dart';

void main() {
  testWidgets('bio stays inline, collapses to three lines and expands fully', (tester) async {
    final bio = List.filled(15, 'Films, friends and another great movie night.').join(' ');
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 320, child: ExpandableProfileBio(text: bio))))));
    final collapsed = find.textContaining('… Read more');
    expect(collapsed, findsOneWidget);
    final text = tester.widget<Text>(collapsed);
    final painter = TextPainter(text: text.textSpan, textDirection: TextDirection.ltr)..layout(maxWidth:320);
    expect(painter.computeLineMetrics().length, lessThanOrEqualTo(3));
    painter.dispose();
    expect(find.byType(TextButton), findsNothing);
    await tester.tap(collapsed);
    await tester.pumpAndSettle();
    expect(find.textContaining(bio), findsOneWidget);
    await tester.tap(find.textContaining('Read less'));
    await tester.pumpAndSettle();
    expect(collapsed, findsOneWidget);
  });
}
