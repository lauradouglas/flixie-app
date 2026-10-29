import 'package:flixie_app/features/social/presentation/widgets/friend_search_scope.dart';
import 'package:flixie_app/features/profile/presentation/widgets/profile_avatar_view.dart';
import 'package:flixie_app/core/utils/skeleton.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:flixie_app/models/friendship.dart';
import 'package:flixie_app/models/group.dart';
import 'package:flixie_app/features/social/presentation/controllers/friend_actions_controller.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/analytics/flixie_analytics.dart';
import 'package:flixie_app/features/social/data/group_service.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/utils/app_logger.dart';
import 'package:flixie_app/features/social/presentation/widgets/visibility_chip.dart';

class CreateGroupSheet extends StatefulWidget {
  const CreateGroupSheet({super.key, this.onCreated});

  final void Function(Group)? onCreated;

  @override
  State<CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<CreateGroupSheet>
    with StarredFriendsState<CreateGroupSheet> {
  final FriendActionsController _friendActions =
      FriendActionsController.instance;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _abbrController = TextEditingController();
  final _descController = TextEditingController();
  bool _isPublic = true;
  late final String? _viewer;
  bool get _owns =>
      mounted && context.read<AuthProvider>().dbUser?.id == _viewer;
  @override
  void initState() {
    super.initState();
    _viewer = context.read<AuthProvider>().dbUser?.id;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewer = context.watch<AuthProvider>().dbUser?.id;
    if (viewer == _viewer) return;
    final route = ModalRoute.of(context);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && route?.isCurrent == true) Navigator.of(context).pop();
    });
  }

  // Step 1 - add members (before creation)
  int _step = 0;
  List<FriendshipUser> _friends = [];
  final List<String> _selectedFriendIds = [];
  bool _loadingFriends = false, _friendsFailed = false;
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
    if (!_owns || userId == null) return;
    FocusScope.of(context).unfocus();
    _loadFriendsForInvite(userId);
    setState(() => _step = 1);
  }

  Future<void> _createGroupWithMembers({bool withoutInvites = false}) async {
    final userId = context.read<AuthProvider>().dbUser?.id;
    if (!_owns || userId == null) return;
    if (_inviting) return;
    setState(() => _inviting = true);
    try {
      final members = [
        {'memberId': userId, 'role': 'OWNER', 'inviteStatus': 'ACCEPTED'},
        ...(withoutInvites ? <String>[] : _selectedFriendIds).map((id) => {
              'memberId': id,
              'role': 'MEMBER',
              'inviteStatus': 'PENDING',
            }),
      ];
      final analytics = context.read<AnalyticsController>();
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
      if (!_owns) return;
      await analytics.groupCreated(
        groupType: _isPublic ? 'public' : 'private',
        source: 'group',
      );
      if (!_owns) return;
      widget.onCreated?.call(group);
    } catch (e) {
      logger.e('Create group error: $e');
      if (mounted && _owns) {
        ScaffoldMessenger.of(context).showFlixieToast(
          FlixieToast(
              type: FlixieToastType.error,
              content: const Text('Failed to create group')),
        );
        setState(() => _inviting = false);
        return;
      }
    }
    if (mounted && _owns) Navigator.of(context).pop();
  }

  Future<void> _loadFriendsForInvite(String userId) async {
    if (_owns) {
      setState(() {
        _loadingFriends = true;
        _friendsFailed = false;
      });
    }
    try {
      final data = await _friendActions.getFriends(userId);
      if (mounted && _owns) {
        setState(() {
          _friends = data.friendships
              .map((f) => f.friendUser)
              .whereType<FriendshipUser>()
              .toList();
          _loadingFriends = false;
        });
      }
    } catch (_) {
      if (_owns) {
        setState(() {
          _loadingFriends = false;
          _friendsFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_inviting,
      child: LayoutBuilder(
          builder: (context, constraints) => ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: constraints.maxHeight * .9),
                child: Padding(
                    padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const SizedBox(height: 12),
                      Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color:
                                  context.colors.medium.withValues(alpha: .4),
                              borderRadius: BorderRadius.circular(2))),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
                          child: Row(children: [
                            if (_step == 1)
                              IconButton(
                                  tooltip: 'Back to group details',
                                  onPressed: _inviting
                                      ? null
                                      : () => setState(() => _step = 0),
                                  icon: const Icon(Icons.arrow_back)),
                            Expanded(
                                child: Text(
                                    _step == 0
                                        ? 'Create a group'
                                        : 'Invite friends',
                                    style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700))),
                            IconButton(
                                tooltip: 'Close',
                                onPressed: _inviting
                                    ? null
                                    : () => Navigator.pop(context),
                                icon: const Icon(Icons.close)),
                          ])),
                      Flexible(
                          fit: _step == 0 ? FlexFit.loose : FlexFit.tight,
                          child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                              child: _step == 0
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                          _details(),
                                          const SizedBox(height: 12),
                                          _actions(inline: true),
                                        ])
                                  : _invitations())),
                      if (_step == 1) _actions(),
                    ])),
              )));

  Widget _actions({bool inline = false}) => Padding(
      padding: EdgeInsets.fromLTRB(inline ? 0 : 20, 8, inline ? 0 : 20, 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(
            onPressed: _inviting
                ? null
                : _step == 0
                    ? _submit
                    : _createGroupWithMembers,
            style: FilledButton.styleFrom(
                backgroundColor: FlixieColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: _inviting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(
                    _step == 0
                        ? 'Continue'
                        : _selectedFriendIds.isEmpty
                            ? 'Create group'
                            : 'Create & invite ${_selectedFriendIds.length}',
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700))),
        if (_step == 0) ...[
          const SizedBox(height: 8),
          Text('Invite friends next. You can create it on your own.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: context.colors.light)),
        ] else if (_selectedFriendIds.isNotEmpty)
          TextButton(
              onPressed: _inviting
                  ? null
                  : () {
                      _createGroupWithMembers(withoutInvites: true);
                    },
              child: const Text('Create without invites',
                  style: TextStyle(fontSize: 14))),
      ]));

  Widget _details() => Form(
      key: _formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Step 1 of 2',
            style: TextStyle(fontSize: 12, color: context.colors.light)),
        const SizedBox(height: 16),
        _inputField(
            controller: _nameController,
            label: 'Group name *',
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null),
        const SizedBox(height: 14),
        _inputField(
            controller: _abbrController,
            label: 'Short name · Optional',
            maxLength: 4),
        const SizedBox(height: 14),
        _inputField(
            controller: _descController,
            label: 'Description · Optional',
            maxLines: 2),
        const SizedBox(height: 16),
        Text('Visibility',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: context.colors.white)),
        const SizedBox(height: 6),
        Wrap(spacing: 10, children: [
          VisibilityChip(
              label: 'Public',
              selected: _isPublic,
              onTap: () => setState(() => _isPublic = true)),
          VisibilityChip(
              label: 'Private',
              selected: !_isPublic,
              onTap: () => setState(() => _isPublic = false)),
        ]),
      ]));

  Widget _invitations() {
    final filtered = orderedFriends(
        _friends, (f) => f, _searchController.text.toLowerCase());
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Step 2 of 2 · ${_nameController.text.trim()}',
          style: TextStyle(fontSize: 12, color: context.colors.light)),
      const SizedBox(height: 14),
      const Text('Choose who to invite. You can add more people later.',
          style: TextStyle(fontSize: 14, height: 1.5)),
      const SizedBox(height: 12),
      TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: _decoration().copyWith(
              hintText: 'Search friends',
              prefixIcon: const Icon(Icons.search, size: 20))),
      const SizedBox(height: 12),
      if (_loadingFriends)
        const ContentListSkeleton()
      else if (_friendsFailed) ...[
        const Text('Couldn’t load your friends.',
            style: TextStyle(fontSize: 14)),
        TextButton(
            onPressed: () => _loadFriendsForInvite(_viewer!),
            child: const Text('Retry')),
      ] else if (filtered.isEmpty)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(children: [
              Icon(Icons.people_outline,
                  size: 28, color: context.colors.primaryText),
              const SizedBox(height: 12),
              Text(_friends.isEmpty ? 'No friends to invite yet' : 'No matches',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
              if (_friends.isEmpty) ...[
                const SizedBox(height: 8),
                const Text(
                    'You can create your group now and invite people later.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, height: 1.5)),
              ],
            ]))
      else
        for (final friend in filtered)
          CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _selectedFriendIds.contains(friend.id),
              onChanged: _inviting
                  ? null
                  : (selected) => setState(() {
                        if (selected == true) {
                          if (!_selectedFriendIds.contains(friend.id)) {
                            _selectedFriendIds.add(friend.id);
                          }
                        } else {
                          _selectedFriendIds.remove(friend.id);
                        }
                      }),
              title: Text(
                  friend.firstName?.isNotEmpty == true
                      ? friend.firstName!
                      : friend.username,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: Text('@${friend.username}',
                  style: TextStyle(fontSize: 12, color: context.colors.light)),
              secondary: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ProfileAvatarView(
                      avatar: friend.avatar,
                      profileBadges: friend.profileBadges,
                      fallbackText: friend.username.isEmpty
                          ? '?'
                          : friend.username[0].toUpperCase(),
                      fallbackColor: FlixieColors.primary,
                      size: 36)),
              activeColor: FlixieColors.primary,
              checkColor: Colors.white),
      if (_selectedFriendIds.isNotEmpty)
        Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
                '${_selectedFriendIds.length} ${_selectedFriendIds.length == 1 ? 'friend' : 'friends'} selected',
                style: TextStyle(fontSize: 12, color: context.colors.light))),
    ]);
  }

  InputDecoration _decoration() => InputDecoration(
        filled: true,
        fillColor: context.colors.surfaceElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.colors.primaryText)),
      );

  Widget _inputField(
          {required TextEditingController controller,
          required String label,
          int? maxLength,
          int maxLines = 1,
          String? Function(String?)? validator}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 12, color: context.colors.white)),
        const SizedBox(height: 6),
        TextFormField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            validator: validator,
            style: const TextStyle(fontSize: 14),
            decoration: _decoration().copyWith(
                counterText: '',
                suffixIcon: maxLength == null
                    ? null
                    : ValueListenableBuilder<TextEditingValue>(
                        valueListenable: controller,
                        builder: (context, value, _) => Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: Center(
                                widthFactor: 1,
                                heightFactor: 1,
                                child: Text(
                                    '${value.text.characters.length}/$maxLength',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: context.colors.medium))))))),
        if (maxLength != null) ...[
          const SizedBox(height: 6),
          Text('Up to $maxLength characters',
              style: TextStyle(fontSize: 11, color: context.colors.medium)),
        ],
      ]);
}

Future<void> showProfileCreateGroupSheet(BuildContext context,
        {required ValueChanged<Group> onCreated}) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: context.colors.tabBarBackgroundFocused,
      builder: (_) => CreateGroupSheet(onCreated: onCreated),
    );
