import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/models/movie_list.dart';
import 'package:flixie_app/models/friendship.dart';
import '../../controllers/movie_lists_controller.dart';
import '../../controllers/list_editor_relationships.dart';

class CreateMediaListSheet extends StatefulWidget {
  const CreateMediaListSheet({super.key});

  @override
  State<CreateMediaListSheet> createState() => CreateMediaListSheetState();
}

class CreateMediaListSheetState extends State<CreateMediaListSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _selectedFriendIds = <String>{};

  String _visibility = ListVisibility.friends;
  String _scope = ListScope.personal;
  bool _submitting = false;
  late final AuthProvider _auth;
  late final String _userId;
  late final ListEditorRelationships _relationships;
  List<FriendshipUser> get _friends => _relationships.friends;
  bool get _loadingFriends => _relationships.loadingFriends;
  bool get _active => mounted && _auth.dbUser?.id == _userId;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>();
    _userId = context.read<MovieListsProvider>().userId;
    _relationships = ListEditorRelationships(
        userId: _userId, isCurrentUser: () => _auth.dbUser?.id == _userId)
      ..addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _relationships.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.92,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed:
                        _submitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Expanded(
                    child: Text(
                      'Create New List',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _submitting ? null : _createList,
                    child: const Text('Create'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                maxLength: 50,
                decoration: const InputDecoration(
                  labelText: 'List Name',
                  hintText: 'e.g. 90s Classics',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionController,
                maxLength: 140,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: "What's this list about?",
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'List Type',
                style: TextStyle(
                  color: context.colors.light,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _VisibilityOptionTile(
                label: 'Private',
                subtitle: 'Only you can see',
                icon: Icons.lock_outline,
                selected: _visibility == ListVisibility.private,
                onTap: () =>
                    setState(() => _visibility = ListVisibility.private),
              ),
              const SizedBox(height: 8),
              _VisibilityOptionTile(
                label: 'Friends',
                subtitle: 'Your friends can see',
                icon: Icons.group_outlined,
                selected: _visibility == ListVisibility.friends,
                onTap: () =>
                    setState(() => _visibility = ListVisibility.friends),
              ),
              const SizedBox(height: 8),
              _VisibilityOptionTile(
                label: 'Public',
                subtitle: 'Anyone can see',
                icon: Icons.public,
                selected: _visibility == ListVisibility.public,
                onTap: () =>
                    setState(() => _visibility = ListVisibility.public),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                itemHeight: null,
                initialValue: _scope,
                decoration: const InputDecoration(
                  labelText: 'Who can add to this list?',
                ),
                items: const [
                  DropdownMenuItem(
                    value: ListScope.personal,
                    child: Text('Just me'),
                  ),
                  DropdownMenuItem(
                    value: ListScope.friends,
                    child: Text('Me and selected friends'),
                  ),
                ],
                onChanged: _submitting
                    ? null
                    : (value) => setState(() {
                          _scope = value ?? ListScope.personal;
                          _relationships.load(_scope);
                          if (_scope == ListScope.personal) {
                            _selectedFriendIds.clear();
                          }
                        }),
              ),
              if (_scope == ListScope.friends) ...[
                const SizedBox(height: 14),
                const Text(
                  'Choose friends who can add to the list',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 9),
                if (_loadingFriends)
                  const Center(child: CircularProgressIndicator())
                else if (_relationships.friendsError != null)
                  TextButton(
                      onPressed: () => _relationships.load(_scope),
                      child: Text(_relationships.friendsError!))
                else if (_friends.isEmpty)
                  Text(
                    'No accepted friends available.',
                    style: TextStyle(color: context.colors.medium),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: _friends
                        .map(
                          (friend) => FlixiePill.filter(
                              label: Text('@${friend.username}'),
                              selected: _selectedFriendIds.contains(friend.id),
                              onSelected: _submitting
                                  ? null
                                  : (selected) => setState(() {
                                        if (selected) {
                                          _selectedFriendIds.add(friend.id);
                                        } else {
                                          _selectedFriendIds.remove(friend.id);
                                        }
                                      })),
                        )
                        .toList(growable: false),
                  ),
              ],
              if (_submitting) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createList() async {
    if (!_active || _submitting) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.warning,
            content: const Text('List name is required')),
      );
      return;
    }
    if (_scope == ListScope.friends && _selectedFriendIds.isEmpty) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.warning,
            content: const Text('Select at least one friend')),
      );
      return;
    }

    setState(() => _submitting = true);
    final provider = context.read<MovieListsProvider>();
    final created = await provider.createList(
      name,
      description: _descriptionController.text.trim(),
      visibility: _visibility,
      whoCanAddMovies: _scope == ListScope.friends ? 'members' : 'owner',
      scope: _scope,
      collaboratorIds: _selectedFriendIds.toList(),
    );
    if (!mounted || !_active) return;
    setState(() => _submitting = false);

    if (created == null) {
      ScaffoldMessenger.of(context).showFlixieToast(
        FlixieToast(
            type: FlixieToastType.error,
            content: Text(provider.error ?? 'Unable to create list')),
      );
      return;
    }
    Navigator.pop(context, created);
  }
}

class _VisibilityOptionTile extends StatelessWidget {
  const _VisibilityOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                selected ? FlixieColors.primary : context.colors.tabBarBorder,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: context.colors.medium),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.colors.medium,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? FlixieColors.primary : context.colors.medium,
            ),
          ],
        ),
      ),
    );
  }
}
