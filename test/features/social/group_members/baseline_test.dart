import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/group_member.dart';
import 'package:flixie_app/features/social/presentation/controllers/group_members_controller.dart';
import 'controller_test.dart' show fixture;

class Before {
  final _members = fixture();
  final String _searchQuery = '';
  String? _filterRole;
  int sorts = 0;
  int _roleOrder(GroupMember m) {
    if (m.isOwner) return 0;
    if (m.isAdmin) return 1;
    if (m.isPending) return 3;
    return 2;
  }

  List<GroupMember> get _filtered {
    sorts++;
    final sorted = [..._members]
      ..sort((a, b) => _roleOrder(a).compareTo(_roleOrder(b)));
    return sorted.where((m) {
      if (_filterRole == 'PENDING' && !m.isPending) return false;
      if (_searchQuery.isEmpty) return true;
      return m.displayName.toLowerCase().contains(_searchQuery) ||
          (m.username?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }
}

void main() {
  test('100 repeated lookups: archived getter versus cached selection',
      () async {
    final old = Before();
    final c = GroupMembersController(
        groupId: 'g', accountId: 'a', fetch: (_) async => fixture());
    addTearDown(c.dispose);
    await c.load();
    final selected = c.filter('');
    var reused = 0;
    for (var i = 0; i < 100; i++) {
      expect(old._filtered.length, 100);
      if (identical(c.filter(''), selected)) reused++;
    }
    expect(old.sorts, 100);
    expect(reused, 100);
    // ignore: avoid_print
    print(
        'GROUP_MEMBERS_BASELINE repeatedLookups=100 beforeSorts=${old.sorts} afterSelectionReuse=$reused afterLoadSorts=1');
  });
}
