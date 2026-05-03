import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/friendship.dart';
import '../../models/group.dart';
import '../../providers/auth_provider.dart';
import '../../services/friend_service.dart';
import '../../services/group_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/app_logger.dart';
import 'visibility_chip.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({this.onCreated});

  final void Function(Group)? onCreated;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _abbrController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = true;

  // Step 1 — add members (before creation)
  int _step = 0;
  List<FriendshipUser> _friends = [];
  final List<String> _selectedFriendIds = [];
  bool _loadingFriends = false;
  bool _inviting = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _abbrController.dispose();
    _descController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    _loadFriendsForInvite(userId);
    setState(() => _step = 1);
  }

  Future<void> _createGroupWithMembers() async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (userId == null) return;
    setState(() => _inviting = true);
    try {
      final members = [
        {'memberId': userId, 'role': 'OWNER', 'inviteStatus': 'ACCEPTED'},
        ..._selectedFriendIds.map((id) => {
              'memberId': id,
              'role': 'MEMBER',
              'inviteStatus': 'PENDING',
            }),
      ];
      final group = await GroupService.createGroup({
        'name': _nameController.text.trim(),
        if (_abbrController.text.trim().isNotEmpty)
          'abbreviation': _abbrController.text.trim(),
        if (_descController.text.trim().isNotEmpty)
          'description': _descController.text.trim(),
        'visibility': _isPublic ? 'PUBLIC' : 'PRIVATE',
        'ownerId': userId,
        'members': members,
      });
      widget.onCreated?.call(group);
    } catch (e) {
      logger.e('Create group error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to create group')),
        );
        setState(() => _inviting = false);
        return;
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loadFriendsForInvite(String userId) async {
    if (mounted) setState(() => _loadingFriends = true);
    try {
      final data = await FriendService.getFriends(userId);
      if (mounted) {
        setState(() {
          _friends = data.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .toList();
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFriends = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) => _step == 0
          ? _buildFormStep(scrollController, textTheme)
          : _buildInviteStep(scrollController),
    );
  }

  Widget _buildFormStep(
      ScrollController scrollController, TextTheme textTheme) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: FlixieColors.medium.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Create Group',
              style:
                  textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _inputField(
              controller: _nameController,
              label: 'Group Name *',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _abbrController,
              label: 'Abbreviation (optional, max 4 chars)',
              maxLength: 4,
            ),
            const SizedBox(height: 14),
            _inputField(
              controller: _descController,
              label: 'Description (optional)',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Text(
              'Visibility',
              style: textTheme.bodyMedium
                  ?.copyWith(color: FlixieColors.light, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                VisibilityChip(
                  label: 'Public',
                  selected: _isPublic,
                  onTap: () => setState(() => _isPublic = true),
                ),
                const SizedBox(width: 10),
                VisibilityChip(
                  label: 'Private',
                  selected: !_isPublic,
                  onTap: () => setState(() => _isPublic = false),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: FlixieColors.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Next',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInviteStep(ScrollController scrollController) {
    final query = _searchController.text.toLowerCase();
    final filtered = _friends.where((f) {
      return f.username.toLowerCase().contains(query) ||
          (f.firstName?.toLowerCase().contains(query) ?? false);
    }).toList();

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: FlixieColors.medium.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Members',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'to "${_nameController.text}"',
                      style: const TextStyle(
                          color: FlixieColors.medium, fontSize: 13),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _inviting ? null : _createGroupWithMembers,
                child: const Text('Skip',
                    style: TextStyle(color: FlixieColors.medium)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(color: FlixieColors.light),
            decoration: InputDecoration(
              hintText: 'Search friends…',
              hintStyle: const TextStyle(color: FlixieColors.medium),
              prefixIcon: const Icon(Icons.search, color: FlixieColors.medium),
              filled: true,
              fillColor: FlixieColors.tabBarBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _loadingFriends
              ? const Center(child: CircularProgressIndicator())
              : filtered.isEmpty
                  ? Center(
                      child: Text(
                        _friends.isEmpty
                            ? 'No friends to invite yet'
                            : 'No matches',
                        style: const TextStyle(color: FlixieColors.medium),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final friend = filtered[i];
                        final selected = _selectedFriendIds.contains(friend.id);
                        return CheckboxListTile(
                          value: selected,
                          onChanged: (val) => setState(() {
                            if (val == true) {
                              _selectedFriendIds.add(friend.id);
                            } else {
                              _selectedFriendIds.remove(friend.id);
                            }
                          }),
                          title: Text(friend.username,
                              style:
                                  const TextStyle(color: FlixieColors.light)),
                          subtitle: friend.firstName != null
                              ? Text(friend.firstName!,
                                  style: const TextStyle(
                                      color: FlixieColors.medium, fontSize: 12))
                              : null,
                          activeColor: FlixieColors.primary,
                          checkColor: Colors.black,
                          secondary: CircleAvatar(
                            backgroundColor:
                                FlixieColors.primary.withValues(alpha: 0.2),
                            child: Text(
                              friend.username[0].toUpperCase(),
                              style: const TextStyle(
                                color: FlixieColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
              20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _inviting ? null : _createGroupWithMembers,
              style: ElevatedButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _inviting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : Text(
                      _selectedFriendIds.isEmpty
                          ? 'Create Group'
                          : 'Create & Invite ${_selectedFriendIds.length}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _inputField({
    required TextEditingController controller,
    required String label,
    int? maxLength,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLength: maxLength,
      maxLines: maxLines,
      validator: validator,
      style: const TextStyle(color: FlixieColors.light),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: FlixieColors.medium, fontSize: 13),
        counterStyle: const TextStyle(color: FlixieColors.medium),
        filled: true,
        fillColor: FlixieColors.tabBarBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.tabBarBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: FlixieColors.primary),
        ),
      ),
    );
  }
}
