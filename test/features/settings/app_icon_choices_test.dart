import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/settings/presentation/widgets/app_icon_choices.dart';

class FixtureAuth extends ChangeNotifier implements AuthProvider {
  FixtureAuth(List<String> badges)
      : dbUser = User(
            id: 'fictional-member',
            username: 'fixture',
            email: 'fixture@example.invalid',
            iconColorId: 1,
            completedSetup: true,
            darkMode: false,
            profileBadges: badges);
  @override
  final User dbUser;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('eligible members select Pip; other members have no picker',
      (tester) async {
    const channel = MethodChannel('flixie/app_icon');
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'status') {
        return {'supported': true, 'selected': 'default'};
      }
      calls.add(call.arguments as String);
      return null;
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null));
    for (final badges in [
      ['EARLY_ADOPTER'],
      ['FOUNDER'],
      <String>[],
    ]) {
      final auth = FixtureAuth(badges);
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: const AppIconChoices(),
          ),
        ))),
      ));
      await tester.pumpAndSettle();
      if (badges.isEmpty) {
        expect(find.text('Pip in 3D'), findsNothing);
      } else {
        await tester.tap(find.text('Pip in 3D'));
        await tester.pumpAndSettle();
        expect(calls.last, 'pipGlasses');
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
    }
  });
}
