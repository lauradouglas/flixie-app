import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flixie_app/main.dart';
import 'package:flixie_app/theme/app_theme.dart';

void main() {
  group('FlixieColors', () {
    test('primary color has correct value', () {
      expect(FlixieColors.primary, const Color(0xFF947AF1));
    });

    test('secondary color has correct value', () {
      expect(FlixieColors.secondary, const Color(0xFF08A391));
    });

    test('background color has correct value', () {
      expect(FlixieColors.background, const Color(0xFF172B4D));
    });

    test('danger color has correct value', () {
      expect(FlixieColors.danger, const Color(0xFFE57373));
    });

    test('warning color has correct value', () {
      expect(FlixieColors.warning, const Color(0xFFFFD166));
    });
  });

  group('AppTheme', () {
    test('darkTheme is not null', () {
      expect(AppTheme.darkTheme, isNotNull);
    });

    test('darkTheme uses dark brightness', () {
      expect(AppTheme.darkTheme.brightness, Brightness.dark);
    });

    test('darkTheme primary color matches FlixieColors.primary', () {
      expect(
        AppTheme.darkTheme.colorScheme.primary,
        FlixieColors.primary,
      );
    });

    test('darkTheme scaffold background matches FlixieColors.background', () {
      expect(
        AppTheme.darkTheme.scaffoldBackgroundColor,
        FlixieColors.background,
      );
    });
  });

  group('FlixieApp widget', () {
    testWidgets('renders without errors', (WidgetTester tester) async {
      await tester.pumpWidget(const FlixieApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows bottom navigation bar', (WidgetTester tester) async {
      await tester.pumpWidget(const FlixieApp());
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('has three navigation destinations', (WidgetTester tester) async {
      await tester.pumpWidget(const FlixieApp());
      expect(find.byType(NavigationDestination), findsNWidgets(3));
    });

    testWidgets('navigation labels are correct', (WidgetTester tester) async {
      await tester.pumpWidget(const FlixieApp());
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });
  });
}
