class GroupMember {
  final String groupId;
  final String memberId;
  final String role;
  final String? inviteStatus;
  final String? username;
  final String? firstName;
  final String? lastName;
  final Map<String, dynamic>? iconColor;
  final String? initials;

  const GroupMember({
    required this.groupId,
    required this.memberId,
    required this.role,
    this.inviteStatus,
    this.username,
    this.firstName,
    this.lastName,
    this.iconColor,
    this.initials,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      groupId: json['groupId'] as String? ?? '',
      memberId: json['memberId'] as String? ?? '',
      role: json['role'] as String? ?? 'MEMBER',
      inviteStatus: json['inviteStatus'] as String?,
      username: json['username'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      iconColor: json['iconColor'] as Map<String, dynamic>?,
      initials: json['initials'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groupId': groupId,
      'memberId': memberId,
      'role': role,
      'inviteStatus': inviteStatus,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'iconColor': iconColor,
      'initials': initials,
    };
  }

  String get displayName => username ?? firstName ?? memberId;

  bool get isOwner => role == 'OWNER';
  bool get isAdmin => role == 'ADMIN';
  bool get isAccepted => inviteStatus == 'ACCEPTED';
  bool get isPending => inviteStatus == 'PENDING';
}
