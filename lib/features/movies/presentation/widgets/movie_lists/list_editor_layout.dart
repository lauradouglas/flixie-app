import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/app_theme.dart';
import 'package:flixie_app/core/widgets/flixie_pill.dart';

/// Keeps the submission action reachable while the editor body scrolls.
class ListEditorLayout extends StatelessWidget {
  const ListEditorLayout({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
              child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: context.colors.medium,
                      borderRadius: BorderRadius.circular(3)))),
          Flexible(
              child: SingleChildScrollView(
                  child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children.sublist(0, children.length - 1),
          ))),
          const SizedBox(height: 12),
          children.last,
        ],
      );
}

class ListChoiceGroup extends StatelessWidget {
  const ListChoiceGroup(
      {super.key,
      required this.value,
      required this.title,
      required this.items,
      required this.onChanged});
  final String value;
  final String title;
  final List<DropdownMenuItem<String>> items;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final item in items)
              FlixiePill.choice(
                label: item.child,
                selected: item.value == value,
                onSelected: (_) => onChanged(item.value),
              ),
          ]),
        ],
      );
}
