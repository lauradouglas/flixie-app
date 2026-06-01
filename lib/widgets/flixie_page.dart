import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class FlixiePageScaffold extends StatelessWidget {
  const FlixiePageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor = Colors.transparent,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}

class FlixieTitleAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FlixieTitleAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.backgroundColor = Colors.transparent,
    this.centerTitle = false,
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color backgroundColor;
  final bool centerTitle;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: FlixieColors.light,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: FlixieColors.light),
      actionsIconTheme: const IconThemeData(color: FlixieColors.light),
      elevation: 0,
      centerTitle: centerTitle,
      title: title,
      actions: actions,
      bottom: bottom,
    );
  }
}
