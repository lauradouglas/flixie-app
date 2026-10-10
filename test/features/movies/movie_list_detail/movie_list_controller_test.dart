import 'dart:async';
import 'package:flixie_app/core/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_list_membership.dart';
import 'package:flixie_app/models/user.dart';
import 'package:flixie_app/features/movies/data/movie_list_detail_service.dart';
import 'package:flixie_app/features/movies/presentation/controllers/movie_list_detail_controller.dart';
import '../../../../patrol_test/support/movie_list_detail_fixture.dart';

class MetadataReads extends MovieListDetailService {
  final reads = <Completer<MovieListMembership>>[];
  final owners = <String>[];
  final ownerReads = <Completer<User>>[];
  @override
  Future<MovieListMembership> members(String ownerId, String listId) {
    final gate = Completer<MovieListMembership>();
    reads.add(gate);
    return gate.future;
  }

  @override
  Future<User> owner(String id) {
    owners.add(id);
    final gate = Completer<User>();
    ownerReads.add(gate);
    return gate.future;
  }
}

MovieListMembership member(String name, {String owner = 'list-owner'}) =>
    MovieListMembership(
        id: 'list', name: name, ownerId: owner, scope: 'FRIENDS');
void main() {
  test('revoked access clears private metadata and a successful retry recovers',
      () async {
    final service = MetadataReads();
    final controller = MovieListDetailController(
        listId: 'list',
        ownerId: 'list-owner',
        viewer: User.fromJson(listPerson('list-owner')),
        currentViewer: () => 'list-owner',
        service: service);
    addTearDown(controller.dispose);
    final first = controller.refresh();
    service.reads[0].complete(member('Private'));
    await first;
    final denied = controller.refresh();
    service.reads[1].completeError(
        const ApiException(statusCode: 404, message: 'List not found'));
    await denied;
    expect(controller.membership, isNull);
    expect(controller.owner, isNull);
    expect(controller.accessDenied, isTrue);
    final retry = controller.refresh();
    service.reads[2].complete(member('Restored'));
    await Future<void>.delayed(Duration.zero);
    service.ownerReads.single.complete(User.fromJson(listPerson('list-owner')));
    await retry;
    expect(controller.accessDenied, isFalse);
    expect(controller.membership!.name, 'Restored');
  });

  test('newest metadata refresh wins; current owner needs no profile read',
      () async {
    final service = MetadataReads();
    final controller = MovieListDetailController(
        listId: 'list',
        ownerId: 'list-owner',
        viewer: User.fromJson(listPerson('list-owner')),
        currentViewer: () => 'list-owner',
        service: service);
    addTearDown(controller.dispose);
    final first = controller.refresh();
    final second = controller.refresh();
    service.reads[1].complete(member('Fresh'));
    await second;
    service.reads[0].complete(member('Old'));
    await first;
    expect(controller.membership!.name, 'Fresh');
    expect(service.owners, isEmpty);
  });
  for (final disposed in [false, true]) {
    test(
        '${disposed ? 'disposal' : 'account change'} rejects late metadata and skips owner follow-up',
        () async {
      var viewer = 'viewer';
      final service = MetadataReads();
      final controller = MovieListDetailController(
          listId: 'list',
          ownerId: 'list-owner',
          viewer: User.fromJson(listPerson(viewer)),
          currentViewer: () => viewer,
          service: service);
      final pending = controller.refresh();
      if (disposed) {
        controller.dispose();
      } else {
        viewer = 'other';
        addTearDown(controller.dispose);
      }
      service.reads.single.complete(member('Private old'));
      await pending;
      expect(controller.membership, isNull);
      expect(service.owners, isEmpty);
      await controller.refresh();
      expect(service.reads, hasLength(1));
    });
  }
  test('late owner enrichment cannot replace the newer membership owner',
      () async {
    final service = MetadataReads();
    final controller = MovieListDetailController(
        listId: 'list',
        ownerId: 'list-owner',
        viewer: User.fromJson(listPerson('viewer')),
        currentViewer: () => 'viewer',
        service: service);
    addTearDown(controller.dispose);
    final first = controller.refresh();
    service.reads[0].complete(member('Old'));
    await Future<void>.delayed(Duration.zero);
    final second = controller.refresh();
    service.reads[1].complete(member('New', owner: 'new-owner'));
    await Future<void>.delayed(Duration.zero);
    service.ownerReads[1].complete(User.fromJson(listPerson('new-owner')));
    await second;
    service.ownerReads[0].complete(User.fromJson(listPerson('list-owner')));
    await first;
    expect(controller.owner!.id, 'new-owner');
  });
  test('ordinary failed refresh preserves useful membership', () async {
    final service = MetadataReads();
    final controller = MovieListDetailController(
        listId: 'list',
        ownerId: 'list-owner',
        viewer: User.fromJson(listPerson('list-owner')),
        currentViewer: () => 'list-owner',
        service: service);
    addTearDown(controller.dispose);
    final first = controller.refresh();
    service.reads[0].complete(member('Loaded'));
    await first;
    final second = controller.refresh();
    service.reads[1].completeError(StateError('offline'));
    await second;
    expect(controller.membership!.name, 'Loaded');
  });
}
