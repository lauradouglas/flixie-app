import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flixie_app/features/social/presentation/widgets/insights_tab.dart';

http.Response response(String name, [int status = 200]) => http.Response(
    jsonEncode({
      'mostActiveMembers': [
        {'userId': name, 'username': name, 'activityCount': 2, 'rank': 1}
      ]
    }),
    status,
    headers: {'content-type': 'application/json'});
Widget screen(String id) =>
    MaterialApp(home: Scaffold(body: GroupInsightsTab(groupId: id)));
void main() {
  testWidgets(
      'period changes and explicit refresh request fresh insights; failures retry',
      (tester) async {
    final urls = <Uri>[];
    var fail = false;
    await http.runWithClient(() async {
      await tester.pumpWidget(screen('insights-period'));
      await tester.pumpAndSettle();
      expect(urls.single.queryParameters['timeWindow'], 'month');
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      expect(urls.last.queryParameters['timeWindow'], 'all');
      expect(urls.length, 2);
      await tester.tap(find.text('All time'));
      await tester.pumpAndSettle();
      expect(urls.length, 2);
      fail = true;
      final refresh = tester
          .widget<RefreshIndicator>(find.byType(RefreshIndicator))
          .onRefresh();
      await tester.pumpAndSettle();
      await refresh;
      expect(find.text('Retry'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(urls.length, 4);
      expect(find.text('Retry'), findsNothing);
    },
        () => MockClient((request) async {
              urls.add(request.url);
              return response('Member', fail ? 500 : 200);
            }));
  });
  testWidgets('old group response cannot replace current group insights',
      (tester) async {
    final old = Completer<http.Response>();
    await http.runWithClient(() async {
      await tester.pumpWidget(screen('old-insights'));
      await tester.pump();
      await tester.pumpWidget(screen('new-insights'));
      await tester.pumpAndSettle();
      expect(find.text('@New member'), findsWidgets);
      old.complete(response('Old member'));
      await tester.pumpAndSettle();
      expect(find.text('@Old member'), findsNothing);
      expect(find.text('@New member'), findsWidgets);
    },
        () => MockClient((request) async =>
            request.url.path.contains('old-insights')
                ? await old.future
                : response('New member')));
  });
}
