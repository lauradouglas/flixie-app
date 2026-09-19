import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/models/profile_avatar.dart';

/// A compact attribution marker for a Watch Plan movie option.
class WatchPlanCandidateAvatar extends StatelessWidget {
  const WatchPlanCandidateAvatar({
    super.key,
    required this.avatar,
    required this.username,
  });

  final ProfileAvatar? avatar;
  final String? username;

  @override
  Widget build(BuildContext context) {
    final name = username?.trim() ?? '';
    final label = name.isEmpty ? 'Added this movie' : 'Added by @$name';
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: InkResponse(
          onTap: () => ScaffoldMessenger.of(context).showFlixieToast(
            FlixieToast(type: FlixieToastType.info, content: Text(label)),
          ),
          radius: 18,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: context.colors.surface, width: 1.5),
            ),
            child: ProfileAvatarView(
              avatar: avatar,
              fallbackText: name.isEmpty ? '?' : name[0].toUpperCase(),
              fallbackColor: FlixieColors.primary,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
