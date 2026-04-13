import 'package:flutter/material.dart';

import '../../models/group.dart';
import '../../theme/app_theme.dart';
import 'group_avatar.dart';

class GroupInvitationCard extends StatelessWidget {
  const GroupInvitationCard({
    super.key,
    required this.group,
    required this.onAccept,
    required this.onDecline,
    this.invitedByUsername,
  });

  final Group group;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final String? invitedByUsername;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: FlixieColors.tabBarBackgroundFocused,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FlixieColors.tabBarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GroupAvatar(group: group, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        color: FlixieColors.light,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        text: 'Invited by ',
                        style: const TextStyle(
                            color: FlixieColors.medium, fontSize: 12),
                        children: [
                          TextSpan(
                            text: invitedByUsername != null
                                ? '@$invitedByUsername'
                                : 'group owner',
                            style: const TextStyle(
                              color: FlixieColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FlixieColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: const Text('Accept',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: FlixieColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(
                        color: FlixieColors.danger.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Decline',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
