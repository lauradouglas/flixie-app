import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

class VisibilityChip extends StatelessWidget {
  const VisibilityChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.choice(
        label: Text(label), selected: selected, onSelected: (_) => onTap());
  }
}
