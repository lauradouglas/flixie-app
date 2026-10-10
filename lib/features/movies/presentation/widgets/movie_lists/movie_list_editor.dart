import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flixie_app/core/auth/auth_provider.dart';
import 'package:flixie_app/core/widgets/flixie_toast.dart';
import 'package:flixie_app/features/profile/data/user_service.dart';
import 'package:flixie_app/models/movie_list.dart';
import '../../controllers/movie_lists_controller.dart';
import '../../controllers/list_editor_relationships.dart';
import 'list_collaborator_picker.dart';
import 'list_editor_layout.dart';

Future<void> showMovieListEditor(
  BuildContext context, {
  String? listId,
  String? initialName,
  String? initialDescription,
  String? initialVisibility,
  String? initialWhoCanAddMovies,
  String initialScope = ListScope.personal,
  String? initialGroupId,
  List<MovieListCollaborator> initialCollaborators = const [],
}) async {
  final auth = context.read<AuthProvider>();
  final userId = auth.dbUser?.id;
  if (userId == null) return;
  final provider = context.read<MovieListsProvider>();
  ModalRoute<dynamic>? route;
  final created = await showModalBottomSheet<MovieList>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (ctx) {
      route = ModalRoute.of(ctx);
      return _MovieListEditor(
          provider: provider,
          userId: userId,
          isCurrentUser: () => auth.dbUser?.id == userId,
          listId: listId,
          initialName: initialName,
          initialDescription: initialDescription,
          initialVisibility: initialVisibility,
          initialWhoCanAddMovies: initialWhoCanAddMovies,
          initialScope: initialScope,
          initialGroupId: initialGroupId,
          initialCollaborators: initialCollaborators);
    },
  );
  await route?.completed;
  if (created != null && context.mounted && auth.dbUser?.id == userId) {
    await context
        .push(Uri(path: '/movie-lists/${created.id}', queryParameters: {
      'name': created.name,
      'isOwner': 'true',
      'canEdit': 'true',
      'add': 'true',
    }).toString());
    if (context.mounted && auth.dbUser?.id == userId) {
      await provider.loadLists();
    }
  }
}

class _MovieListEditor extends StatefulWidget {
  const _MovieListEditor(
      {required this.provider,
      required this.userId,
      required this.isCurrentUser,
      this.listId,
      this.initialName,
      this.initialDescription,
      this.initialVisibility,
      this.initialWhoCanAddMovies,
      required this.initialScope,
      this.initialGroupId,
      required this.initialCollaborators});
  final MovieListsProvider provider;
  final String userId;
  final bool Function() isCurrentUser;
  final String? listId,
      initialName,
      initialDescription,
      initialVisibility,
      initialWhoCanAddMovies,
      initialGroupId;
  final String initialScope;
  final List<MovieListCollaborator> initialCollaborators;
  @override
  State<_MovieListEditor> createState() => _MovieListEditorState();
}

class _MovieListEditorState extends State<_MovieListEditor> {
  late final name = TextEditingController(text: widget.initialName ?? '');
  late final description =
      TextEditingController(text: widget.initialDescription ?? '');
  late final relationships = ListEditorRelationships(
      userId: widget.userId, isCurrentUser: widget.isCurrentUser);
  late String visibility = widget.initialVisibility ?? ListVisibility.private;
  late String whoCanAdd = widget.initialWhoCanAddMovies ?? 'owner';
  late String scope = widget.initialScope;
  late String? groupId = widget.initialGroupId;
  late final originalFriends =
      widget.initialCollaborators.map((c) => c.id).toSet();
  late final selectedFriends = Set<String>.of(originalFriends);
  bool saving = false;
  bool get isEdit => widget.listId != null;
  bool get active => mounted && widget.isCurrentUser();

  @override
  void initState() {
    super.initState();
    if (scope == ListScope.friends) relationships.load(scope);
  }

  @override
  void dispose() {
    relationships.dispose();
    name.dispose();
    description.dispose();
    super.dispose();
  }

  void changeScope(String value) {
    setState(() {
      scope = value;
      if (!isEdit || scope != ListScope.group) groupId = null;
      if (!isEdit || scope == ListScope.personal) selectedFriends.clear();
      if (!isEdit) {
        whoCanAdd = scope == ListScope.personal ? 'owner' : 'members';
      }
    });
    relationships.load(scope);
  }

  void feedback(String message, FlixieToastType type) {
    ScaffoldMessenger.of(context)
        .showFlixieToast(FlixieToast(type: type, content: Text(message)));
  }

  Future<void> save() async {
    if (!active || saving || name.text.trim().isEmpty) return;
    if (scope == ListScope.friends && selectedFriends.isEmpty) {
      feedback('Select at least one friend', FlixieToastType.warning);
      return;
    }
    if (scope == ListScope.group && groupId == null) {
      feedback('Choose a group', FlixieToastType.warning);
      return;
    }
    setState(() => saving = true);
    MovieList? created;
    var ok = false;
    try {
      ok = isEdit
          ? await widget.provider.renameList(widget.listId!, name.text.trim(),
              description: description.text.trim(),
              visibility: visibility,
              whoCanAddMovies: whoCanAdd,
              scope: scope,
              groupId: groupId,
              collaboratorIds: selectedFriends.toList())
          : (created = await widget.provider.createList(name.text.trim(),
                  description: description.text.trim(),
                  visibility: visibility,
                  whoCanAddMovies: whoCanAdd,
                  scope: scope,
                  groupId: groupId,
                  collaboratorIds: selectedFriends.toList())) !=
              null;
      if (!active) return;
      if (ok && isEdit && scope == ListScope.friends) {
        final added = selectedFriends.difference(originalFriends);
        final removed = originalFriends.difference(selectedFriends);
        for (final id in added) {
          if (!active) return;
          await UserService.addMovieListMember(
              widget.userId, widget.listId!, id);
        }
        for (final id in removed) {
          if (!active) return;
          await UserService.removeMovieListMember(
              widget.userId, widget.listId!, id);
        }
        if (!active) return;
        if (added.isNotEmpty || removed.isNotEmpty) {
          await widget.provider.loadLists();
        }
      }
    } catch (_) {
      ok = false;
    }
    if (!mounted || !active) return;
    if (!ok) {
      setState(() => saving = false);
      feedback(widget.provider.error ?? 'Unable to save list',
          FlixieToastType.error);
      return;
    }
    feedback(isEdit ? 'List renamed' : 'List created', FlixieToastType.success);
    Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: relationships,
        builder: (context, _) => ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .9),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 16),
            child: AbsorbPointer(
                absorbing: saving,
                child: ListEditorLayout(children: [
                  Text(isEdit ? 'Edit list' : 'Make a little collection.',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextField(
                      controller: name,
                      maxLength: 50,
                      decoration: const InputDecoration(
                          labelText: 'List name',
                          hintText: 'Films for a rainy Sunday')),
                  TextField(
                      controller: description,
                      maxLength: 140,
                      minLines: 2,
                      maxLines: 3,
                      decoration: const InputDecoration(
                          hintText: 'Description (optional)')),
                  ListChoiceGroup(
                      value: visibility,
                      title: 'Who can see it?',
                      items: const [
                        DropdownMenuItem(
                            value: ListVisibility.private,
                            child: Text('Private')),
                        DropdownMenuItem(
                            value: ListVisibility.friends,
                            child: Text('Friends only')),
                        DropdownMenuItem(
                            value: ListVisibility.public,
                            child: Text('Public')),
                      ],
                      onChanged: (value) => setState(
                          () => visibility = value ?? ListVisibility.private)),
                  const SizedBox(height: 8),
                  ListCollaboratorPicker(
                      isEdit: isEdit,
                      initialScope: widget.initialScope,
                      scope: scope,
                      groupId: groupId,
                      selectedFriends: selectedFriends,
                      relationships: relationships,
                      onScope: changeScope,
                      onGroup: (value) => setState(() => groupId = value),
                      onFriend: (id, selected) => setState(() {
                            if (selected) {
                              selectedFriends.add(id);
                            } else {
                              selectedFriends.remove(id);
                            }
                          })),
                  const SizedBox(height: 8),
                  SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                          onPressed: saving ? null : save,
                          child: Text(saving
                              ? 'Saving…'
                              : isEdit
                                  ? 'Save'
                                  : 'Create'))),
                ])),
          ),
        ),
      );
}
