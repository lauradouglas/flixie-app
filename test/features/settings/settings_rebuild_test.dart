import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../../support/api_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/app/theme/appearance_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/settings/presentation/pages/settings_screen.dart';
import 'package:flixie_app/features/settings/presentation/widgets/settings_tile.dart';
import '../../settings_country_test.dart' show CountryAuth, SettingsAnalytics;

void main() {
  testWidgets('unrelated cached profile update preserves Settings tiles',
      (tester) async {
    useApiFixture(MockClient((_) async => http.Response('[]', 200)));
    SharedPreferences.setMockInitialValues({});
    final appearance =
        AppearanceController(await SharedPreferences.getInstance());
    addTearDown(appearance.dispose);
    final auth = CountryAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider<AppearanceController>.value(value: appearance),
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<AnalyticsController>(
              create: (_) => SettingsAnalytics()),
        ],
        child: MaterialApp(
            theme: AppTheme.darkTheme, home: const SettingsScreen())));
    await tester.pumpAndSettle();
    final target = find.byWidgetPredicate(
        (widget) => widget is SettingsTile && widget.label == 'Edit details');
    final original = tester.widget(target);
    auth.updateCachedUser(auth.dbUser.copyWith(bio: 'Updated elsewhere'));
    await tester.pumpAndSettle();
    expect(identical(tester.widget(target), original),
        !const bool.fromEnvironment('SETTINGS_BEFORE'));
  });
}
