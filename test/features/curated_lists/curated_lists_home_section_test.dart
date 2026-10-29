import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/curated_lists/data/curated_lists_service.dart';
import 'package:flixie_app/features/curated_lists/models/curated_list.dart';
import 'package:flixie_app/features/curated_lists/presentation/widgets/curated_lists_home_section.dart';

class HomeLists extends CuratedListsService {
  HomeLists(this.promoted, this.archive);
  final List<CuratedList> promoted, archive;
  int archiveReads = 0;
  @override
  Future<List<CuratedList>> lists({bool homepage = false, int page = 1}) async {
    if (homepage) return promoted;
    archiveReads++;
    return archive;
  }
}

void main() {
  final now = DateTime.now();
  CuratedList list(String id, int start, int end) => CuratedList(
      id: id,
      title: id,
      startsAt: now.add(Duration(days: start)),
      endsAt: now.add(Duration(days: end)));
  for (final mode in ['empty', 'upcoming', 'active']) {
    testWidgets('$mode promotion controls Home and archive visibility',
        (t) async {
      final service = HomeLists(
          mode == 'empty'
              ? []
              : [list('Featured', mode == 'active' ? -1 : 1, 5)],
          [list('Expired', -10, -5)]);
      await t.pumpWidget(MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: CuratedListsHomeSection(service: service)))));
      await t.pumpAndSettle();
      expect(find.text('Watch challenges'),
          mode == 'empty' ? findsNothing : findsOneWidget);
      expect(find.text('Expired'),
          mode == 'active' ? findsOneWidget : findsNothing);
      expect(service.archiveReads, mode == 'active' ? 1 : 0);
      expect(t.takeException(), isNull);
    });
  }
}
