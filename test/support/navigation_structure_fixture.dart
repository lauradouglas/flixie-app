import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flixie_app/app/router/router.dart';

GoRouter navigationStructureFixture(
        {Future<void> Function(String)? onRefresh}) =>
    GoRouter(routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => MainNavigationShell(navigationShell: shell),
        branches: [
          for (final path in ['/', '/search', '/plans', '/social', '/profile'])
            StatefulShellBranch(routes: [
              GoRoute(
                  path: path,
                  builder: (_, __) =>
                      _Destination(path: path, onRefresh: onRefresh))
            ]),
        ],
      ),
      GoRoute(
          path: '/detail',
          builder: (context, _) => Scaffold(
              appBar: AppBar(title: const Text('Film detail')),
              body: TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Return to results')))),
    ]);

class _Destination extends StatefulWidget {
  const _Destination({required this.path, this.onRefresh});
  final Future<void> Function(String)? onRefresh;
  final String path;
  @override
  State<_Destination> createState() => _DestinationState();
}

class _DestinationState extends State<_Destination> {
  final query = TextEditingController();
  final scroll = ScrollController();
  @override
  void dispose() {
    query.dispose();
    scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: SafeArea(
              child: Column(children: [
        Text('Screen ${widget.path}'),
        TextField(
            controller: query,
            decoration: const InputDecoration(labelText: 'Search titles')),
        Expanded(
            child: RefreshIndicator(
                onRefresh: () async {
                  await widget.onRefresh?.call(widget.path);
                },
                child: ListView.builder(
                    controller: scroll,
                    itemExtent: 64,
                    itemCount: 50,
                    itemBuilder: (_, i) => ListTile(
                        title: Text('Film $i'),
                        onTap: () => context.push('/detail'))))),
      ])));
}
