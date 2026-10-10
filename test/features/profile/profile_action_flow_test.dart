import 'dart:async';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flutter/material.dart';
import 'package:flixie_app/models/movie_rating.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/features/profile/presentation/controllers/profile_controller.dart';
import 'package:flixie_app/features/profile/presentation/profile_action_flow.dart';
import 'profile_controller_test.dart' show ProfileAuth, ProfileData;

class DismissData extends ProfileData {
  bool fail = false;
  @override
  Future<void> dismissContinueWatching(String userId, int showId) async {
    await super.dismissContinueWatching(userId, showId);
    if (fail) throw StateError('offline');
  }
}

void main() {
  late ProfileAuth auth;
  late DismissData service;
  late ProfileController data;
  setUp(() {
    auth = ProfileAuth();
    service = DismissData();
    data = ProfileController(auth: auth, service: service);
  });
  tearDown(() {
    data.dispose();
    auth.dispose();
  });
  Future<void> mount(WidgetTester tester) async {
    await data.loadAll();
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(
            home: Scaffold(
                body: Builder(
                    builder: (context) => TextButton(
                        onPressed: () =>
                            ProfileActionFlow(context: context, data: data)
                                .removeContinueWatching(
                                    data.continueWatching.first),
                        child: const Text('Remove')))))));
    await tester.pumpAndSettle();
  }

  testWidgets('Undo restores the removed item without persisting dismissal',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(data.continueWatching, isEmpty);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(data.continueWatching.single.showId, 1);
    expect(service.dismissed, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('closing the notice persists dismissal', (tester) async {
    await mount(tester);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnackBar), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(service.dismissed, ['viewer/1']);
    expect(data.continueWatching, isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'account change prevents a deferred dismissal into the previous viewer',
      (tester) async {
    await mount(tester);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    auth.select('other');
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnackBar), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(service.dismissed, isEmpty);
    expect(data.continueWatching.single.showId, 2);
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed dismissal restores the item and reports failure',
      (tester) async {
    await mount(tester);
    service.fail = true;
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SnackBar), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(data.continueWatching.single.showId, 1);
    expect(find.text('Could not remove that show right now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'Ratings opens on demand and a repeat opening reuses this account’s result',
      (tester) async {
    await data.loadAll();
    expect(service.calls.where((c) => c.startsWith('ratings:')), isEmpty);
    final pending = Completer<List<MovieRating>>();
    service.ratingsGates['viewer'] = pending;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                      onPressed: () =>
                          ProfileActionFlow(context: context, data: data)
                              .openRatings(),
                      child: const Text('Open ratings'),
                    )))));
    await tester.tap(find.text('Open ratings'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.calls.where((c) => c == 'ratings:viewer'), hasLength(1));
    expect(
        find.byWidgetPredicate((widget) =>
            widget is ContentPlaceholder && widget.label == 'Loading ratings'),
        findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No ratings yet.'), findsOneWidget);
    Navigator.of(tester.element(find.text('No ratings yet.'))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open ratings'));
    await tester.pumpAndSettle();
    expect(service.calls.where((c) => c == 'ratings:viewer'), hasLength(1));
    expect(find.text('No ratings yet.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
