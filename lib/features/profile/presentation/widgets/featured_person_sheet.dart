import 'package:flutter/material.dart';
import 'package:flixie_app/core/widgets/load_failure_notice.dart';

/// A draft selection: only a successful explicit save closes the sheet.
class FeaturedPersonSheet extends StatefulWidget {
  const FeaturedPersonSheet(
      {super.key,
      required this.role,
      required this.people,
      required this.initialId,
      required this.onSave});
  final String role;
  final List<Map> people;
  final int? initialId;
  final Future<void> Function(int?) onSave;
  @override
  State<FeaturedPersonSheet> createState() => _FeaturedPersonSheetState();
}

class _FeaturedPersonSheetState extends State<FeaturedPersonSheet> {
  late int? selected = widget.initialId;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String query = '';
  bool allPeople = false, saving = false, failed = false;
  String department(Map p) => (p['department'] ??
          p['knownForDepartment'] ??
          p['known_for_department'] ??
          '')
      .toString()
      .trim();
  bool matchesRole(Map p) =>
      department(p).toLowerCase() ==
      (widget.role == 'director' ? 'directing' : 'acting');
  Future<void> save() async {
    if (saving) return;
    FocusScope.of(context).unfocus();
    setState(() {
      saving = true;
      failed = false;
    });
    try {
      await widget.onSave(selected);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          failed = true;
          saving = false;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scroll.hasClients) {
            _scroll.animateTo(_scroll.position.maxScrollExtent,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut);
          }
        });
      }
    }
  }

  Widget _portrait(Map person) {
    final path = (person['profileImgUrl'] ?? person['profilePath'])?.toString();
    return ExcludeSemantics(
        child: ClipOval(
            child: SizedBox(
                width: 44,
                height: 44,
                child: path == null || path.isEmpty
                    ? const Icon(Icons.person_outline)
                    : Image.network(
                        path.startsWith('http')
                            ? path
                            : 'https://image.tmdb.org/t/p/w185$path',
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person_outline)))));
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.people
        .where((p) =>
            (allPeople ||
                matchesRole(p) ||
                department(p).isEmpty ||
                p['id'] == selected) &&
            (p['name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(query.toLowerCase()))
        .toList()
      ..sort(
          (a, b) => (matchesRole(b) ? 1 : 0).compareTo(matchesRole(a) ? 1 : 0));
    return PopScope(
        canPop: !saving,
        child: Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom),
            child: SizedBox(
                height: MediaQuery.sizeOf(context).height * .8,
                child: Column(children: [
                  Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                      child: Row(children: [
                        Expanded(
                            child: Text('Favourite ${widget.role}',
                                style: Theme.of(context).textTheme.titleLarge)),
                        IconButton(
                            tooltip: 'Close',
                            onPressed:
                                saving ? null : () => Navigator.pop(context),
                            icon: const Icon(Icons.close)),
                      ])),
                  Expanded(
                      child: CustomScrollView(controller: _scroll, slivers: [
                    SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.list(children: [
                          Text(widget.role == 'director'
                              ? 'Directing favourites appear first. Use All people for other credits.'
                              : 'Acting favourites appear first. You choose who to feature as your ${widget.role}.'),
                          const SizedBox(height: 12),
                          TextField(
                              enabled: !saving,
                              decoration: const InputDecoration(
                                  labelText: 'Search favourite people',
                                  prefixIcon: Icon(Icons.search)),
                              onChanged: (value) =>
                                  setState(() => query = value)),
                          const SizedBox(height: 12),
                          Wrap(spacing: 8, children: [
                            ChoiceChip(
                                label: Text(widget.role == 'director'
                                    ? 'Directing & unknown'
                                    : 'Acting & unknown'),
                                selected: !allPeople,
                                onSelected: saving
                                    ? null
                                    : (_) => setState(() => allPeople = false)),
                            ChoiceChip(
                                label: const Text('All people'),
                                selected: allPeople,
                                onSelected: saving
                                    ? null
                                    : (_) => setState(() => allPeople = true)),
                          ]),
                          if (candidates.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                    'No matching favourites. Try another name or All people.')),
                        ])),
                    SliverList.builder(
                        itemCount: candidates.length,
                        itemBuilder: (_, index) {
                          final person = candidates[index];
                          final id = person['id'] ?? person['personId'];
                          final role = department(person);
                          return Semantics(
                              selected: selected == id,
                              child: ListTile(
                                enabled: !saving && id is int,
                                leading: _portrait(person),
                                title: Text(
                                    (person['name'] ?? 'Person').toString()),
                                subtitle: Text(
                                    '${role.isEmpty ? 'Role information unavailable' : role}${widget.initialId == id ? ' · Current highlight' : ''}'),
                                trailing: Icon(selected == id
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked),
                                onTap: () => setState(() {
                                  selected = id as int;
                                  failed = false;
                                }),
                              ));
                        }),
                    SliverToBoxAdapter(
                        child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Semantics(
                                      selected: selected == null,
                                      child: TextButton.icon(
                                          onPressed: saving
                                              ? null
                                              : () => setState(() {
                                                    selected = null;
                                                    failed = false;
                                                  }),
                                          icon: Icon(selected == null
                                              ? Icons.check_circle_outline
                                              : Icons.remove_circle_outline),
                                          label: const Text(
                                              'Clear this highlight'))),
                                  const Text(
                                      'Your favourite people stay saved.'),
                                  if (failed)
                                    LoadFailureNotice(
                                        message:
                                            'Couldn’t save your highlight. Your selection is still here.',
                                        onRetry: save),
                                ]))),
                  ])),
                  SafeArea(
                      top: false,
                      child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                  onPressed: saving ? null : save,
                                  child: Text(saving
                                      ? 'Saving…'
                                      : 'Save highlight'))))),
                ]))));
  }
}
