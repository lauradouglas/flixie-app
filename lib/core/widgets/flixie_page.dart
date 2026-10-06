import 'package:flutter/material.dart';

import 'package:flixie_app/app/theme/app_theme.dart';

class FlixiePageScaffold extends StatelessWidget {
  const FlixiePageScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.backgroundColor = Colors.transparent,
    this.extendBodyBehindAppBar = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Color backgroundColor;
  final bool extendBodyBehindAppBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: extendBodyBehindAppBar,
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
    this.leading,
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color backgroundColor;
  final bool centerTitle;
  final Widget? leading;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: context.colors.light,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: context.colors.light),
      actionsIconTheme: IconThemeData(color: context.colors.light),
      elevation: 0,
      centerTitle: centerTitle,
      title: title,
      leading: leading,
      actions: actions,
      bottom: bottom,
    );
  }
}
