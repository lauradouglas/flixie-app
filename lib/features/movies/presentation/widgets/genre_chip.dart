import 'package:flixie_app/core/widgets/flixie_pill.dart';
import 'package:flutter/material.dart';

class GenreChip extends StatelessWidget {
  const GenreChip({
    super.key,
    required this.label,
    this.color,
    this.compact = false,
  });

  final String label;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return FlixiePill.label(
        colorKey: label, label: Text(label), compact: compact);
  }
}
