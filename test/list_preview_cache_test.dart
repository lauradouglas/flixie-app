import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/features/profile/presentation/widgets/lists_preview_section.dart';
import 'support/watchlist_auth.dart';

void main() {
  testWidgets('profile preview uses updated list cache after adding films',
      (tester) async {
    final auth = _ListAuth();
    addTearDown(auth.dispose);
    MovieList list(int count) => MovieList.fromJson({
          'id': 'list',
          'userId': auth.dbUser!.id,
          'name': 'Friday films',
          'visibility': 'PUBLIC',
          'itemCount': count
        });
    auth.updateCachedMovieLists([list(0)]);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: ListsPreviewSection(
                      userId: auth.dbUser!.id,
                      title: 'Your lists',
                      emptyMessage: 'Empty',
                      allowManage: true)))));
      await tester.pumpAndSettle();
      expect(
          find.textContaining('0 items', findRichText: true), findsOneWidget);
      auth.updateCachedMovieLists([list(2)]);
      await tester.pumpAndSettle();
      expect(
          find.textContaining('2 items', findRichText: true), findsOneWidget);
      expect(find.textContaining('0 items', findRichText: true), findsNothing);
    },
        () => MockClient(
            (_) async => http.Response(jsonEncode([list(0).toJson()]), 200)));
  });
  testWidgets('fresh lists replace stale profile cache and show newest first',
      (tester) async {
    final auth = _ListAuth();
    addTearDown(auth.dispose);
    Map<String, dynamic> fixture(String id, String date) => {
          'id': id,
          'userId': auth.dbUser!.id,
          'name': id,
          'visibility': 'PRIVATE',
          'createdAt': date,
          'itemCount': 1,
        };
    final old = fixture('Old collection', '2026-09-01');
    auth.updateCachedMovieLists([MovieList.fromJson(old)]);
    await http.runWithClient(() async {
      await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
          value: auth,
          child: MaterialApp(
              home: Scaffold(
                  body: ListsPreviewSection(
                      userId: auth.dbUser!.id,
                      title: 'Your lists',
                      emptyMessage: 'Empty',
                      allowManage: true)))));
      await tester.pumpAndSettle();
      expect(find.text('3 lists'), findsOneWidget);
      expect(find.text('New collection'), findsOneWidget);
      expect(find.text('Old collection'), findsNothing);
      expect(auth.cachedMovieLists, hasLength(3));
    },
        () => MockClient((_) async => http.Response(
            jsonEncode([
              old,
              fixture('Middle collection', '2026-09-20'),
              fixture('New collection', '2026-10-01')
            ]),
            200)));
  });
}

class _ListAuth extends TestAuth {
  List<MovieList>? _lists;
  @override
  List<MovieList>? get cachedMovieLists => _lists;
  @override
  void updateCachedMovieLists(List<MovieList> lists) {
    _lists = lists;
    notifyListeners();
  }
}
