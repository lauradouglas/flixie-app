import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_scroll_view.dart';
void main() {
  testWidgets('switching profile content retains the scrolled position', (tester) async {
    var activity = false;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, update) => Scaffold(
      body: ProfileScrollView(slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 600, child: Text('Profile header'))),
        SliverToBoxAdapter(child: TextButton(onPressed: () => update(() => activity = !activity), child: const Text('Activity'))),
        SliverToBoxAdapter(child: SizedBox(height: 1200, child: Text(activity ? 'Your activity' : 'Library'))),
      ]),
    ))));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -550));
    await tester.pumpAndSettle();
    final before = tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;
    await tester.tap(find.text('Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Your activity'), findsOneWidget);
    expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels, before);
    expect(before, greaterThan(0));
  });
}
