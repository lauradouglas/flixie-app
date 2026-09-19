import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/profile/presentation/widgets/change_avatar_sheet.dart';
import 'package:flixie_app/models/profile_avatar.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_badges.dart';

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    super.key,
    required this.displayName,
    required this.username,
    this.memberSince,
    this.onPreview,
    this.bio,
    this.iconColor,
    this.avatar,
    this.profileBadges = const [],
  });

  final String displayName;
  final String username;
  final String? memberSince;
  final VoidCallback? onPreview;
  final String? bio;
  final Map<String, dynamic>? iconColor;
  final ProfileAvatar? avatar;
  final List<String> profileBadges;

  Color get _avatarColor {
    final hex = ((iconColor?['hexCode'] ?? iconColor?['hex']) as String? ?? '')
        .replaceAll('#', '');
    if (hex.isEmpty) return FlixieColors.primary;
    return Color(int.tryParse('0xFF$hex') ?? FlixieColors.primary.toARGB32());
  }

  void _openEditSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditProfileSheet(
        currentUsername: username,
        currentBio: bio,
      ),
    );
  }

  void _openAvatarSheet(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: context.colors.background,
        builder: (_) => const FractionallySizedBox(
          heightFactor: .9,
          child: ChangeAvatarSheet(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Semantics(
              button: true,
              label: 'Change profile avatar',
              child: InkWell(
                  onTap: () => _openAvatarSheet(context),
                  child: ProfileAvatarView(
                      avatar: avatar,
                      fallbackText: displayName.isEmpty
                          ? '?'
                          : displayName[0].toUpperCase(),
                      fallbackColor: _avatarColor,
                      size: 76,
                      profileBadges: profileBadges))),
          const SizedBox(width: 16),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(displayName,
                    style: TextStyle(
                        color: context.colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('@$username',
                    style:
                        TextStyle(color: context.colors.light, fontSize: 14)),
              ])),
        ]),
        if (profileBadges.isNotEmpty) ...[
          const SizedBox(height: 12),
          ProfileBadgePills(badges: profileBadges, compact: true),
        ],
        if (bio?.isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _ExpandableProfileBio(text: bio!),
        ],
        const SizedBox(height: 4),
        Wrap(spacing: 12, children: [
          TextButton.icon(
              onPressed: () => _openEditSheet(context),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile')),
          if (onPreview != null)
            TextButton.icon(
                onPressed: onPreview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Preview profile')),
        ]),
      ]),
    );
  }
}

class _ExpandableProfileBio extends StatefulWidget {
  const _ExpandableProfileBio({required this.text});
  final String text;
  @override
  State<_ExpandableProfileBio> createState() => _ExpandableProfileBioState();
}

class _ExpandableProfileBioState extends State<_ExpandableProfileBio> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final style =
            TextStyle(color: context.colors.light, fontSize: 14, height: 1.4);
        final painter = TextPainter(
            text: TextSpan(text: widget.text, style: style),
            maxLines: 2,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context))
          ..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;
        painter.dispose();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.text,
              style: style,
              maxLines: expanded ? null : 2,
              overflow:
                  expanded ? TextOverflow.visible : TextOverflow.ellipsis),
          if (overflows)
            TextButton(
                onPressed: () => setState(() => expanded = !expanded),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.light,
                  textStyle: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                  padding: EdgeInsets.zero,
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(48, 40),
                ),
                child: Text(expanded ? 'Read less' : 'Read more')),
        ]);
      });
}
