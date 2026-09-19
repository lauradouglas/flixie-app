import 'package:flutter/material.dart';
import 'package:flixie_app/app/theme/flixie_pill_style.dart';

/// Shared app pill. Selectable filters, actions and non-interactive labels use
/// the same visual language. Interactive variants retain a 48px touch target.
class FlixiePill extends StatelessWidget {
  const FlixiePill.choice(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected,
      this.avatar,
      this.tooltip,
      this.showCheckmark = true})
      : onPressed = null,
        compact = false,
        _interactive = true,
        colorKey = null;
  const FlixiePill.filter(
      {super.key,
      required this.label,
      required this.selected,
      required this.onSelected,
      this.avatar,
      this.tooltip,
      this.showCheckmark = true})
      : onPressed = null,
        compact = false,
        _interactive = true,
        colorKey = null;
  const FlixiePill.action(
      {super.key,
      required this.label,
      required this.onPressed,
      this.avatar,
      this.tooltip,
      this.selected = false,
      this.showCheckmark = false})
      : onSelected = null,
        compact = false,
        _interactive = true,
        colorKey = null;
  const FlixiePill.label(
      {super.key,
      required this.label,
      this.avatar,
      this.tooltip,
      this.compact = true,
      this.colorKey,
      this.selected = false})
      : onSelected = null,
        onPressed = null,
        showCheckmark = false,
        _interactive = false;

  final Widget label;

  /// Keep the caller's complete avatar (including its own badge border).
  final Widget? avatar;
  final bool selected, compact, showCheckmark, _interactive;
  final ValueChanged<bool>? onSelected;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// Stable palette key for decorative, non-interactive genre labels.
  final String? colorKey;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final enabled = !_interactive || onSelected != null || onPressed != null;
    final tint = colorKey == null
        ? null
        : FlixiePillStyle.genreColors(colorKey!, brightness);
    final color = selected
        ? FlixiePillStyle.selectedText
        : tint?.$2 ?? FlixiePillStyle.foreground(brightness);
    final style = FlixiePillStyle.label(brightness).copyWith(
        color: color,
        fontSize: compact ? 12 : 14,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500);
    return IconTheme.merge(
        data: const IconThemeData(color: FlixiePillStyle.iconColor, size: 16),
        child: RawChip(
          iconTheme:
              const IconThemeData(color: FlixiePillStyle.iconColor, size: 16),
          label: DefaultTextStyle(
            style: style,
            softWrap: true,
            overflow: TextOverflow.visible,
            child: label,
          ),
          avatar: avatar,
          tooltip: tooltip,
          selected: selected,
          onSelected: onSelected,
          onPressed: onPressed,
          isEnabled: enabled,
          showCheckmark: showCheckmark && avatar == null,
          labelStyle: style,
          checkmarkColor: color,
          backgroundColor: tint?.$1 ?? FlixiePillStyle.fill(brightness),
          disabledColor: FlixiePillStyle.fill(brightness),
          selectedColor: FlixiePillStyle.selectedFill,
          side: BorderSide.none,
          shape: FlixiePillStyle.shape,
          elevation: 0,
          pressElevation: 0,
          padding: EdgeInsets.symmetric(
              horizontal: compact ? 5 : 8, vertical: compact ? 1 : 5),
          labelPadding: const EdgeInsets.symmetric(horizontal: 5),
          materialTapTargetSize: _interactive
              ? MaterialTapTargetSize.padded
              : MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
        ));
  }
}
