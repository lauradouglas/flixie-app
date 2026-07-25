import 'package:flixie_app/models/profile_avatar.dart';

class MovieListMembership {
  const MovieListMembership({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.scope,
    this.groupId,
    this.groupName,
    this.isOwner = false,
    this.canEdit = false,
    this.canManageMembers = false,
    this.canLeave = false,
    this.members = const [],
  });

  final String id;
  final String name;
  final String ownerId;
  final String scope;
  final String? groupId;
  final String? groupName;
  final bool isOwner;
  final bool canEdit;
  final bool canManageMembers;
  final bool canLeave;
  final List<MovieListMember> members;

  factory MovieListMembership.fromJson(Map<String, dynamic> json) =>
      MovieListMembership(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        ownerId: json['ownerId']?.toString() ?? '',
        scope: json['scope']?.toString() ?? 'PERSONAL',
        groupId: json['groupId']?.toString(),
        groupName: json['groupName']?.toString(),
        isOwner: json['isOwner'] as bool? ?? false,
        canEdit: json['canEdit'] as bool? ?? false,
        canManageMembers: json['canManageMembers'] as bool? ?? false,
        canLeave: json['canLeave'] as bool? ?? false,
        members: (json['members'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(MovieListMember.fromJson)
            .toList(growable: false),
      );
}

class MovieListMember {
  const MovieListMember({
    required this.id,
    required this.username,
    this.firstName,
    this.avatar,
    this.profileBadges = const [],
  });

  final String id;
  final String username;
  final String? firstName;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  factory MovieListMember.fromJson(Map<String, dynamic> json) =>
      MovieListMember(
        id: json['id']?.toString() ?? '',
        username: json['username']?.toString() ?? '',
        firstName: json['firstName']?.toString(),
        avatar: json['avatar'] is Map<String, dynamic>
            ? ProfileAvatar.fromJson(json['avatar'] as Map<String, dynamic>)
            : null,
        profileBadges: (json['profileBadges'] as List<dynamic>? ?? const [])
            .map((badge) => badge is Map ? badge['badge'] : badge)
            .whereType<String>()
            .toList(growable: false),
      );
}
