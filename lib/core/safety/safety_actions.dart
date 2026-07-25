import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/safety/safety_service.dart';

class SafetyActions {
  const SafetyActions._();

  static const _reasons = <String, String>{
    'HARASSMENT': 'Harassment or bullying',
    'HATE_SPEECH': 'Hate speech',
    'SEXUAL_CONTENT': 'Sexual content',
    'VIOLENCE': 'Violence or threats',
    'SPAM': 'Spam or scam',
    'IMPERSONATION': 'Impersonation',
    'OTHER': 'Something else',
  };

  static Future<bool> report(
    BuildContext context, {
    required String targetType,
    String? targetId,
    String? reportedUserId,
    String? contentPreview,
  }) async {
    final reason = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: FlixieColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: Text(
                  'Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              ..._reasons.entries.map(
                (entry) => ListTile(
                  title: Text(entry.value),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, entry.key),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason == null || !context.mounted) return false;

    try {
      await SafetyService.report(
        targetType: targetType,
        reason: reason,
        targetId: targetId,
        reportedUserId: reportedUserId,
        contentPreview: contentPreview,
      );
      if (!context.mounted) return true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Thanks. Your report has been sent for review.'),
        ),
      );
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not send the report. Try again.')),
        );
      }
      return false;
    }
  }

  static Future<void> contentMenu(
    BuildContext context, {
    required String targetType,
    required String targetId,
    required String reportedUserId,
    required String username,
    required String contentPreview,
  }) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      backgroundColor: FlixieColors.surface,
      showDragHandle: true,
      builder: (context) => Wrap(
        children: [
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report content'),
            onTap: () => Navigator.pop(context, 'report'),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: FlixieColors.danger),
            title: const Text(
              'Block user',
              style: TextStyle(color: FlixieColors.danger),
            ),
            onTap: () => Navigator.pop(context, 'block'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
    if (!context.mounted) return;
    if (action == 'report') {
      await report(
        context,
        targetType: targetType,
        targetId: targetId,
        reportedUserId: reportedUserId,
        contentPreview: contentPreview,
      );
    } else if (action == 'block') {
      await block(context, userId: reportedUserId, username: username);
    }
  }

  static Future<bool> block(
    BuildContext context, {
    required String userId,
    required String username,
  }) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Block @$username?'),
            content: const Text(
              'You will be unfriended. They will no longer be able to interact '
              'with you, and their content will be hidden from you.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Block'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return false;

    try {
      await SafetyService.block(userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('@$username has been blocked.')),
        );
      }
      return true;
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not block this user. Try again.')),
        );
      }
      return false;
    }
  }
}
