import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/watchlist/presentation/pages/watchlist_screen.dart';
import 'package:flixie_app/features/watchlist/presentation/widgets/watchlist_tablet_gallery.dart';
import '../../support/watchlist_auth.dart';

void main() {
  testWidgets('tablet gallery pages enrichment while searching and clearing',
      (t) async {
    t.view.physicalSize = const Size(1194, 834);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final auth = TestAuth()..ids = List.generate(400, (i) => i + 1);
    addTearDown(auth.dispose);
    final requested = <int>{};
    final client = MockClient((request) async {
      Object body = {'watchProviders': []};
      if (request.url.path.endsWith('friend-recommendations')) {
        final ids = (jsonDecode(request.body)['movieIds'] as List).cast<int>();
        requested.addAll(ids);
        body = {
          'items': [
            for (final id in ids)
              {
                'movieId': '$id',
                'recommendPercent': 0,
                'friendCount': 0,
                'recommendedCount': 0,
                'friends': []
              }
          ]
        };
      }
      return http.Response(jsonEncode(body), 200);
    });
    ApiClient.useClientForTesting(client);
    addTearDown(() => ApiClient.useClientForTesting(null));
    addTearDown(client.close);
    await t.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth, child: const MaterialApp(home: WatchlistScreen())));
    await t.pumpAndSettle();
    expect(find.byType(WatchlistTabletGallery), findsOneWidget);
    expect(find.text('Film 1').hitTestable(), findsOneWidget);
    expect(requested.length, lessThanOrEqualTo(40));
    await t.scrollUntilVisible(find.text('Film 21'), 500,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('watchlist-cards')),
                matching: find.byType(Scrollable))
            .first,
        maxScrolls: 60);
    await t.pumpAndSettle();
    expect(requested, contains(21));
    expect(requested.length, lessThan(100));
    expect(auth.providerRequests.every((batch) => batch.length <= 20), isTrue);
    await t.drag(find.byType(CustomScrollView), const Offset(0, 10000));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'Film 399');
    await t.pumpAndSettle();
    expect(find.text('Film 399', skipOffstage: true).last, findsOneWidget);
    expect(find.text('Film 21'), findsNothing);
    await t.enterText(find.byType(TextField).first, '');
    await t.pumpAndSettle();
    expect(find.text('Film 1'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
  });
}
