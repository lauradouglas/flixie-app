import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/home/presentation/widgets/home_session_updates.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_notification_button.dart';
import 'profile_controller_test.dart' show ProfileAuth;

void main() {
  testWidgets(
      'mounted notification actions disappear on logout and return on login',
      (tester) async {
    final auth = ProfileAuth();
    addTearDown(auth.dispose);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: const MaterialApp(
            home: Scaffold(
                body: Row(children: [
          HomeNotificationAction(),
          ProfileNotificationButton(),
        ])))));
    expect(find.byIcon(Icons.notifications_outlined), findsNWidgets(2));
    auth.select(null);
    await tester.pump();
    expect(find.byIcon(Icons.notifications_outlined), findsNothing);
    auth.select('viewer');
    await tester.pump();
    expect(find.byIcon(Icons.notifications_outlined), findsNWidgets(2));
  });
}
