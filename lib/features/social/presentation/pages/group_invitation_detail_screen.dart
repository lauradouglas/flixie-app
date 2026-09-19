import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/models/group.dart';

class GroupInvitationDetailScreen extends StatefulWidget {
  const GroupInvitationDetailScreen({
    super.key,
    required this.groupId,
    required this.requestId,
  });

  final String groupId;
  final String requestId;

  @override
  State<GroupInvitationDetailScreen> createState() =>
      _GroupInvitationDetailScreenState();
}

class _GroupInvitationDetailScreenState
    extends State<GroupInvitationDetailScreen> {
  Group? _group;
  Object? _error;
  bool _loading = true;
  bool _responding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // Pending invitees can preview the group, but cannot read its members.
      final group = await GroupService.getGroup(widget.groupId);
      if (!mounted) {
        return;
      }
      setState(() {
        _group = group;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  Future<void> _respond(String status) async {
    setState(() => _responding = true);
    try {
      await RequestService.updateRequest(widget.requestId, status);
      if (!mounted) return;
      if (status == 'ACCEPTED') {
        context.go('/groups/${widget.groupId}');
      } else {
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showFlixieToast(FlixieToast(
          type: FlixieToastType.error,
          content: const Text('Could not update this group invitation.'),
          backgroundColor: context.colors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Group invitation'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || _group == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.group_off_outlined,
                          color: context.colors.medium, size: 40),
                      const SizedBox(height: 12),
                      Text('This invitation is no longer available.',
                          style: TextStyle(color: context.colors.light)),
                      const SizedBox(height: 12),
                      TextButton(
                          onPressed: () => context.pop(),
                          child: const Text('Go back')),
                    ]),
                  ),
                )
              : _content(),
    );
  }

  Widget _content() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: context.colors.tertiary.withValues(alpha: .55)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.group_add_outlined,
                color: context.colors.tertiary, size: 30),
            const SizedBox(height: 14),
            Text(_group!.name,
                style: TextStyle(
                    color: context.colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            if (_group!.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(_group!.description!.trim(),
                  style: TextStyle(color: context.colors.light, height: 1.35)),
            ],
            const SizedBox(height: 12),
            Text('Accept the invitation to see members and group activity.',
                style: TextStyle(color: context.colors.medium)),
          ]),
        ),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _responding ? null : () => _respond('ACCEPTED'),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Accept invitation'),
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: context.colors.success,
              foregroundColor: Colors.black),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _responding ? null : () => _respond('DECLINED'),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Decline invitation'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: context.colors.danger,
              side: BorderSide(color: context.colors.danger)),
        ),
      ],
    );
  }
}
