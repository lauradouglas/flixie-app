import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/group_member.dart';
import 'group_plan_components.dart';

Widget groupPlanAvatar(
  BuildContext context,
  String userId,
  GroupMember member,
  double size,
) {
  const framed = {
    'FOUNDER',
    'OG_USER',
    'VERIFIED',
    'EARLY_ADOPTER',
    'FOUNDING_FILM_FRIEND',
  };
  final hasFrame = member.profileBadges.any(framed.contains);
  final name = member.displayName.trim();
  final avatar = ProfileAvatarView(
    avatar: member.avatar,
    fallbackText: name.isEmpty ? '?' : name[0].toUpperCase(),
    fallbackColor: FlixieColors.primary,
    size: size - (hasFrame ? 8 : 10),
    profileBadges: member.profileBadges,
  );
  return Semantics(
    image: true,
    label: member.memberId == userId ? 'You' : member.displayName,
    child: SizedBox.square(
      dimension: size,
      child: hasFrame
          ? Center(child: avatar)
          : DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: member.isOwner
                      ? context.colors.warning
                      : FlixieColors.primary,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Center(child: avatar),
              ),
            ),
    ),
  );
}

Widget groupPlanAvatars(
  BuildContext context,
  String userId,
  List<GroupMember> members,
  double size,
) {
  if (members.isEmpty) {
    return Text(
      'Member details unavailable',
      style: groupPlanBody.copyWith(color: context.colors.light),
    );
  }
  return Wrap(
    spacing: 6,
    runSpacing: 6,
    children: members
        .map((member) => groupPlanAvatar(context, userId, member, size))
        .toList(),
  );
}
