import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/features/social/data/request_service.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/models/group_member.dart';

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
  List<GroupMember> _members = const [];
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
      final values = await Future.wait([
        GroupService.getGroup(widget.groupId),
        GroupService.getGroupMembers(widget.groupId),
      ]);
      if (!mounted) {
        return;
      }
      setState(() {
        _group = values[0] as Group;
        _members = values[1] as List<GroupMember>;
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update this group invitation.'),
          backgroundColor: FlixieColors.danger,
        ));
      }
    } finally {
      if (mounted) setState(() => _responding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FlixieColors.background,
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
                      const Icon(Icons.group_off_outlined,
                          color: FlixieColors.medium, size: 40),
                      const SizedBox(height: 12),
                      const Text('This invitation is no longer available.',
                          style: TextStyle(color: FlixieColors.light)),
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
    final owner = _members.where((member) => member.isOwner).firstOrNull;
    final otherMembers = _members.where((member) => !member.isPending).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: FlixieColors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: FlixieColors.tertiary.withValues(alpha: .55)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.group_add_outlined,
                color: FlixieColors.tertiary, size: 30),
            const SizedBox(height: 14),
            Text(_group!.name,
                style: const TextStyle(
                    color: FlixieColors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800)),
            if (_group!.description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(_group!.description!.trim(),
                  style:
                      const TextStyle(color: FlixieColors.light, height: 1.35)),
            ],
            const SizedBox(height: 12),
            Text(
                '${otherMembers.length} ${otherMembers.length == 1 ? 'member' : 'members'}',
                style: const TextStyle(
                    color: FlixieColors.medium, fontWeight: FontWeight.w700)),
          ]),
        ),
        const SizedBox(height: 24),
        const Text('Created by',
            style: TextStyle(
                color: FlixieColors.medium,
                fontSize: 13,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (owner != null) _memberRow(owner, owner: true),
        const SizedBox(height: 22),
        const Text('Members',
            style: TextStyle(
                color: FlixieColors.white,
                fontSize: 19,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ...otherMembers
            .where((member) => !member.isOwner)
            .map((member) => _memberRow(member)),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _responding ? null : () => _respond('ACCEPTED'),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Accept invitation'),
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: FlixieColors.success,
              foregroundColor: Colors.black),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _responding ? null : () => _respond('DECLINED'),
          icon: const Icon(Icons.close_rounded),
          label: const Text('Decline invitation'),
          style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: FlixieColors.danger,
              side: const BorderSide(color: FlixieColors.danger)),
        ),
      ],
    );
  }

  Widget _memberRow(GroupMember member, {bool owner = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          ProfileAvatarView(
            avatar: member.avatar,
            fallbackText: member.initials ??
                (member.displayName.isEmpty
                    ? '?'
                    : member.displayName.substring(0, 1).toUpperCase()),
            fallbackColor: FlixieColors.primary,
            size: 38,
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(member.displayName,
                  style: const TextStyle(
                      color: FlixieColors.light, fontWeight: FontWeight.w700))),
          if (owner)
            const Text('Owner',
                style: TextStyle(
                    color: FlixieColors.tertiary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800)),
        ]),
      );
}
