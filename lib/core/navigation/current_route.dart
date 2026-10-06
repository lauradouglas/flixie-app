import 'package:go_router/go_router.dart';

/// Includes imperative pushes, which the URL provider may not reflect.
Uri currentRouterUri(GoRouter router) {
  final matches = router.routerDelegate.currentConfiguration;
  if (matches.isEmpty) return router.routeInformationProvider.value.uri;
  return matches.last.buildState(router.configuration, matches).uri;
}
