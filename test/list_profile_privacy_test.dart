import 'package:flutter_test/flutter_test.dart';
import 'package:flixie_app/models/movie_list.dart';

void main() {
  const privateList =
      MovieList(id: 'list', userId: 'owner', name: 'Private', removed: false);
  test('private lists are hidden from friends and unauthenticated viewers', () {
    expect(
        privateList.visibleInProfile(viewerId: 'friend', publicPreview: false),
        isFalse);
    expect(privateList.visibleInProfile(viewerId: null, publicPreview: false),
        isFalse);
  });
  test('owner sees private lists except in public preview', () {
    expect(
        privateList.visibleInProfile(viewerId: 'owner', publicPreview: false),
        isTrue);
    expect(privateList.visibleInProfile(viewerId: 'owner', publicPreview: true),
        isFalse);
  });
  test('server-provided owner flags cannot grant private access', () {
    final list = MovieList.fromJson({
      'id': 'list',
      'userId': 'owner',
      'visibility': 'PRIVATE',
      'isOwner': true,
      'canEdit': true
    });
    expect(list.visibleInProfile(viewerId: 'friend', publicPreview: false),
        isFalse);
  });
  test('public preview contains public lists only', () {
    const publicList = MovieList(
        id: 'public',
        userId: 'owner',
        name: 'Public',
        removed: false,
        visibility: ListVisibility.public);
    const friendsList = MovieList(
        id: 'friends',
        userId: 'owner',
        name: 'Friends',
        removed: false,
        visibility: ListVisibility.friends);
    expect(publicList.visibleInProfile(viewerId: 'friend', publicPreview: true),
        isTrue);
    expect(
        friendsList.visibleInProfile(viewerId: 'friend', publicPreview: true),
        isFalse);
  });
}
