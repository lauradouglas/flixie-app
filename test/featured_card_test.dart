import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/features/home/presentation/widgets/featured_card.dart';
import 'package:flixie_app/models/movie_short.dart';

void main() {
  testWidgets('For You card displays the recommendation reason',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FeaturedCard(
            movie: MovieShort(id: 1, name: 'Arrival'),
            recommendationReason: 'Matches your interest in first contact',
          ),
        ),
      ),
    );

    expect(find.text('Arrival'), findsOneWidget);
    expect(find.text('Matches your interest in first contact'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
  });
}
