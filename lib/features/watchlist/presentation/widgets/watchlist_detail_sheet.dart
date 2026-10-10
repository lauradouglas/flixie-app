import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

Future<void> showWatchlistDetailSheet(
    BuildContext context, String title, List<Widget> children) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: context.colors.surface,
    builder: (context) => ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .8),
      child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            Row(children: [
              Expanded(
                  child: Text(title,
                      style: TextStyle(
                          color: context.colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700))),
              IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close))
            ]),
            ...children,
          ]),
    ),
  );
}
