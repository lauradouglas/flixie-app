import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/safety/safety_service.dart';
import 'package:flixie_app/features/social/presentation/widgets/chat_tab.dart';
import '../../../support/api_fixture.dart';
import 'fixture.dart';
import 'journey.dart';

void main() {
  testWidgets(
      'auth notifications do not multiply loading calls',
      (tester) => loadingJourney(
          tester, (data) => GroupChatTab(groupId: 'club', service: data)));
  testWidgets('send failure, retry and stream reconnection', sendJourney);
  testWidgets(
      '50-message chat keeps its subscription through ten rebuilds',
      (tester) => rebuildJourney(
          tester,
          (data, active) =>
              GroupChatTab(groupId: 'club', service: data, active: active)));
  testWidgets('retry and account/group changes show only current messages',
      (tester) async {
    SafetyService.reset();
    useApiFixture(MockClient((_) async => http.Response('[]', 200)));
    final data = ChatFixture()..fail = true;
    final auth = ChatFixtureAuth();
    addTearDown(auth.dispose);
    addTearDown(data.close);
    Future<void> mount(String group) async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: GroupChatTab(groupId: group, service: data)))));
      await tester.pumpAndSettle();
    }

    await mount('club');
    expect(find.text('Retry chat'), findsOneWidget);
    data.fail = false;
    await tester.tap(find.text('Retry chat'));
    await tester.pumpAndSettle();
    expect(find.textContaining('club-viewer: Alien'), findsWidgets);
    auth.change('new');
    await tester.pumpAndSettle();
    expect(find.textContaining('club-viewer: Alien'), findsNothing);
    expect(find.textContaining('club-new: Alien'), findsWidgets);
    await mount('other');
    expect(find.textContaining('club-new: Alien'), findsNothing);
    expect(find.textContaining('other-new: Alien'), findsWidgets);
    auth.change(null);
    await tester.pump();
    expect(find.textContaining('other-new: Alien'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    expect(data.cancellations, data.subscriptions);
  });
}
