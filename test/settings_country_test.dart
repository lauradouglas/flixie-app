import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'dart:convert';
import 'package:flixie_app/core/analytics/analytics_consent.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart';
import 'watchlist_recommendation_batch_test.dart' show TestAuth, response;

class SettingsAnalytics extends ChangeNotifier implements AnalyticsController {
  @override
  bool get isEnabled => false;
  @override
  AnalyticsConsent get consent => AnalyticsConsent.unknown;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class CountryAuth extends TestAuth {
  User current = const User(
      id: 'viewer',
      username: 'Viewer',
      email: '',
      countryId: 1,
      country: {'id': 1, 'name': 'United Kingdom', 'abbreviation': 'GB'},
      iconColorId: 0,
      completedSetup: true,
      darkMode: true);
  @override
  User get dbUser => current;
  @override
  void updateCachedUser(User user) {
    current = user;
    notifyListeners();
  }
}

void main() {
  testWidgets(
      'country retry stays visible and saved selection updates availability region',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final appearance =
        AppearanceController(await SharedPreferences.getInstance());
    addTearDown(appearance.dispose);
    final auth = CountryAuth();
    addTearDown(auth.dispose);
    var loads = 0;
    Map<String, dynamic>? saved;
    await http.runWithClient(() async {
      await tester.pumpWidget(MultiProvider(
          providers: [
            ChangeNotifierProvider<AppearanceController>.value(
                value: appearance),
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<AnalyticsController>(
                create: (_) => SettingsAnalytics())
          ],
          child: MaterialApp(
              theme: AppTheme.darkTheme, home: const SettingsScreen())));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit details'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(tester.getBottomRight(sheet).dy,
          tester.view.physicalSize.height / tester.view.devicePixelRatio);
      expect(
          tester.getSize(sheet).height,
          lessThanOrEqualTo(tester.view.physicalSize.height /
              tester.view.devicePixelRatio *
              .85));
      await tester.ensureVisible(find.text('Country'));
      await tester.tap(find.text('Couldn’t load countries. Tap to retry.'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('United Kingdom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('United States'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(saved, {'countryId': 2});
      expect(auth.dbUser.watchProviderRegion, 'US');
      expect(tester.takeException(), isNull);
    },
        () => MockClient((request) async {
              if (request.url.path.endsWith('/utils/countries')) {
                if (++loads == 1) return response({'message': 'offline'}, 503);
                return response({
                  'countries': [
                    {'id': 1, 'name': 'United Kingdom', 'abbreviation': 'GB'},
                    {'id': 2, 'name': 'United States', 'abbreviation': 'US'},
                  ]
                });
              }
              if (request.method != 'GET') {
                saved = jsonDecode(request.body) as Map<String, dynamic>;
                return response(auth.dbUser.copyWith(countryId: 2).toJson());
              }
              return response([]);
            }));
  });
}
