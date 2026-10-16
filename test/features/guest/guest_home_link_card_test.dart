import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/guest/presentation/widgets/guest_home_link_card.dart';

void main() {
  testWidgets('compact public entries open their destinations', (tester) async {
    String? destination;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
            body: Column(children: [
          GuestHomeLinkCard(
              icon: Icons.article_outlined,
              title: 'Around Flixie',
              subtitle: 'Explore public ratings, reviews and lists',
              actionLabel: 'Take a look',
              onTap: () => destination = '/around-flixie'),
          GuestHomeLinkCard(
              icon: Icons.sports_esports,
              title: 'Take a break with Pip’s games',
              onTap: () => destination = '/play'),
        ]))));
    await tester.tap(find.text('Take a look'));
    expect(destination, '/around-flixie');
    await tester.tap(find.text('Take a break with Pip’s games'));
    expect(destination, '/play');
    expect(tester.takeException(), isNull);
  });
}
